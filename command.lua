minetest.register_chatcommand("digall:activate", {
	description = "Activate DigAll",
	privs = { digall = true },
	func = function(name)
		return digall.activate(name)
	end,
})

minetest.register_chatcommand("digall:deactivate", {
	description = "Deactivate DigAll",
	privs = { digall = true },
	func = function(name)
		return digall.deactivate(name)
	end,
})

minetest.register_chatcommand("digall:init", {
	description = "Initialize config",
	privs = { digall = true },
	func = function(name)
		digall._detail.player_data[name].association = {}
		digall.set_default_association(name)
		return true, "initialized."
	end,
})

minetest.register_chatcommand("digall:quickmode", {
	description = "Quick mode toggle",
	privs = { digall = true },
	func = function(name)
		if digall._detail.player_data[name].quickmode then
			digall._detail.player_data[name].quickmode = false
			return true, "Disable quick mode."
		else
			digall._detail.player_data[name].quickmode = true
			return true, "Enable quick mode."
		end
	end,
})

local _player_formspec = {}
setmetatable(_player_formspec, {
	__index = function(self, playername)
		self[playername] = {
			nodeidx = 1,
			methodidx = 1,
		}
		return self[playername]
	end
})

local _nodelist = {}
local _methodlist = {}
minetest.after(0, function()
	for nodename, nodedef in pairs(minetest.registered_nodes) do
		if (not nodedef.connects_to) and nodedef.description ~= "" and (not (minetest.get_node_group(nodename, "not_in_creative_inventory") > 0)) then
			table.insert(_nodelist, nodename)
		end
	end
	table.sort(_nodelist)

	for methodname, _ in pairs(digall.registered_methods) do
		table.insert(_methodlist, methodname)
	end
	table.sort(_methodlist)
	table.insert(_methodlist, 1, "None")
end)

local function _create_formspec(name, nodeidx, methodidx)
	local function _create_arguments()
		if methodidx == 1 then
			return ""
		end

		local methodname = _methodlist[methodidx]
		local params = minetest.deserialize(digall.registered_methods[methodname].params)
		local nodename = _nodelist[nodeidx]
		local assoc = digall._detail.player_data[name].association[nodename]
		local args = assoc.arguments

		if type(params) == "table" then
			local res = {
				"button[8.5,2;1,0.5;ok;ok]",
				"label[7,2;Arguments]",
			}
			local offset = 0

			for k, v in pairs(params) do
				local str = string.format("field[7.5,%f;2,0.5;args:%s;%s;%s]", 3.5 + offset, k, k, tostring(args[k]))
				table.insert(res, str)
				offset = offset + 1.0
			end
			return table.concat(res)

		elseif type(params) == "string" then
			return "button[8.5,2;1,0.5;ok;ok]" ..
				"label[7,2;Arguments]" ..
				string.format("field[7.5,3.5;2,0.5;args;;%s]", tostring(args))
		end

		return ""
	end

	return "size[10,6]" ..
		string.format("textlist[0.5,0.5;2.5,5;nodelist;%s;%d]", table.concat(_nodelist, ","), nodeidx) ..
		string.format("textlist[3.5,0.5;2.5,5;methodlist;%s;%d]", table.concat(_methodlist, ","), methodidx) ..
		string.format("item_image[7.5,0.5;1,1;%s]", _nodelist[nodeidx]) ..
		_create_arguments()
end

local function _get_methodidx_by_nodeidx(name, nodeidx)
	local assoc = digall._detail.player_data[name].association
	local nodename = _nodelist[nodeidx]

	local methodidx
	if not assoc[nodename] then
		methodidx = 1
	else
		local methodname = assoc[nodename].methodname
		for i, n in ipairs(_methodlist) do
			if n == methodname then
				methodidx = i
				break
			end
		end
	end

	return methodidx
end

minetest.register_chatcommand("digall:conf", {
	description = "Show digall configuration",
	privs = { digall = true },
	func = function(name)
		minetest.after(0.25, function(name)
			local nodeidx = _player_formspec[name].nodeidx
			local methodidx = _get_methodidx_by_nodeidx(name, nodeidx)

			_player_formspec[name].methodidx = methodidx
			minetest.show_formspec(name, "digall:gui", _create_formspec(name, nodeidx, methodidx))
		end, name)
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "digall:gui" then
		return
	end

	local name = player:get_player_name()
	if fields.nodelist then
		local nodeidx = tonumber(fields.nodelist:match("%w+:(%d+)"))
		local methodidx = _get_methodidx_by_nodeidx(name, nodeidx)
		_player_formspec[name].nodeidx = nodeidx
		_player_formspec[name].methodidx = methodidx

		minetest.show_formspec(name, "digall:gui", _create_formspec(name, nodeidx, methodidx))

	elseif fields.methodlist then
		local methodidx = tonumber(fields.methodlist:match("%w+:(%d+)"))
		local methodname = _methodlist[methodidx]
		local nodeidx = _player_formspec[name].nodeidx
		_player_formspec[name].methodidx = methodidx
		local nodename = _nodelist[nodeidx]

		if methodname == "none" then
			digall.clear_association(name, nodename)
			return
		else
			local args = digall.registered_methods[methodname].default_arguments
			digall.associate_node_and_method(name, nodename, methodname, args)
		end

		minetest.show_formspec(name, "digall:gui", _create_formspec(name, nodeidx, methodidx))

	elseif fields.ok then
		local nodeidx = _player_formspec[name].nodeidx
		local methodidx = _player_formspec[name].methodidx
		local nodename = _nodelist[nodeidx]
		local methodname = _methodlist[methodidx]
		local params = minetest.deserialize(digall.registered_methods[methodname].params)

		local function _get_literal_common(tp, key)
			if tp == "string" then
				return fields[key]
			elseif tp == "number" then
				return tonumber(fields[key])
			elseif tp == "boolean" then
				if fields[key] == "true" then
					return true
				else
					return false
				end
			end
		end

		if type(params) == "table" then
			local args = {}
			for k, v in pairs(params) do
				args[k] = _get_literal_common(v, "args:"..k)
			end
			digall.associate_node_and_method(name, nodename, methodname, args)
			minetest.show_formspec(name, "digall:gui", _create_formspec(name, nodeidx, methodidx))

		elseif type(params) == "string" then
			local args = _get_literal_common(v, "args")
			digall.associate_node_and_method(name, nodename, methodname, args)
			minetest.show_formspec(name, "digall:gui", _create_formspec(name, nodeidx, methodidx))
		end
	end
end)
