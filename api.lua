digall._detail = {}
local _detail = digall._detail

function _detail.dig_node_common(pos, node, meta, digger)
	meta:set_int("digall", 1)

	local curwear = digger:get_wielded_item():get_wear()
	minetest.node_dig(pos, node, digger)

	local wielditem = digger:get_wielded_item()
	wielditem:set_wear(curwear)
	digger:set_wielded_item(wielditem)
end

_detail.player_data = {}
setmetatable(_detail.player_data, {
	__index = function(self, playername)
		self[playername] = {
			activated = true,
			association = {},
		}
		return self[playername]
	end
})

--- Activates digall of the player.
function digall.activate(playername)
	if _detail.player_data[playername].activated == true then
		return false, "already activated"
	end
	_detail.player_data[playername].activated = true
	return true, "activate digall"
end

--- Deactivates digall of the player.
function digall.deactivate(playername)
	if _detail.player_data[playername].activated == false then
		return false, "already deactivated"
	end
	_detail.player_data[playername].activated = false
	return true, "deactivate digall"
end

digall.registered_methods = {}

--- Registers a new method for digging.
function digall.register_method(name, def)
	def.params = def.params or nil
	def.default_arguments = def.default_arguments or nil

	if not def.body then
		error("definition table must have value of 'body'")
		return
	end
	digall.registered_methods[name] = def
end

local function _is_valid_arguments(params, args)
	if type(params) == "table" then
		if type(args) ~= "table" then
			return false
		end

		for k, v in pairs(params) do
			if not _is_valid_arguments(v, args[k]) then
				return false
			end
		end
		return true

	elseif type(params) == "string" then
		return params == type(args)
	elseif type(params) == "nil" then
		return true
	end

	return false
end

--- Associates the nodes and methods.
function digall.associate_node_and_method(playername, nodename, methodname, args)
	local node = minetest.registered_nodes[nodename]
	local method = digall.registered_methods[methodname]

	if not node then
		local msg = string.format("cannot find a such node: %s", nodename)
		minetest.log("error", msg)
		return false, msg
	end

	if not method then
		local msg = string.format("cannot find a such method: %s", methodname)
		minetest.log("error", msg)
		return false, msg
	end

	if not _is_valid_arguments(minetest.deserialize(method.params), args) then
		local msg = string.format("but arguments of %s", methodname)
		minetest.log("error", msg)
		return false, msg
	end

	_detail.player_data[playername].association[nodename] = {
		methodname = methodname,
		arguments = args,
	}
	return true, "association success"
end

--- Sets the default association to the player.
function digall.set_default_association(playername)
	for nodename, nodedef in pairs(minetest.registered_nodes) do
		if minetest.get_node_group(nodename, "tree") > 0 or minetest.get_node_group(nodename, "leaves") > 0 then
			_detail.player_data[playername].association[nodename] = {
				methodname = "digall:tree_and_leaves",
				arguments = nil,
			}

		elseif minetest.get_node_group(nodename, "soil") > 0 then
			_detail.player_data[playername].association[nodename] = {
				methodname = "digall:soil",
				arguments = { x = 5, y = 5, z = 5 },
			}

		elseif minetest.get_node_group(nodename, "falling_node") > 0 then
			_detail.player_data[playername].association[nodename] = {
				methodname = "digall:falling_node",
				arguments = { x = 5, y = 5, z = 5 },
			}

		elseif nodedef.drawtype == "normal" then
			_detail.player_data[playername].association[nodename] = {
				methodname = "digall:default",
				arguments = { x = 5, y = 5, z = 5 },
			}
		end
	end
	return true, "association success"
end

_detail.maxrange = { x = 25, y = 25, z = 25 }

function _detail.inrange(p1, p2, range)
	if math.abs(p1.x - p2.x) > range.x / 2
	or math.abs(p1.y - p2.y) > range.y / 2
	or math.abs(p1.z - p2.z) > range.z / 2 then
		return false
	end
	return true
end

function _detail.method_for_tree_and_leaves(origpos, orignode, origmeta, digger, curpos, curnode)
	for x = -1, 1 do
		for y = -1, 1 do
			for z = -1, 1 do
				if x ~= 0 or y ~= 0 or z ~= 0 then
					local p = vector.add(curpos, { x = x, y = y, z = z})
					local n = minetest.get_node(p)
					local meta = minetest.get_meta(p)
					local state = meta:get_int("digall")

					if orignode.name == n.name and _detail.inrange(origpos, p, _detail.maxrange) and ((not state) or state == 0) then
						_detail.dig_node_common(p, n, meta, digger)
						_detail.method_for_tree_and_leaves(origpos, orignode, origmeta, digger, p, n)
					end
				end
			end
		end
	end
end

digall.register_method("digall:tree_and_leaves", {
	params = nil,
	default_arguments = nil,
	body = _detail.method_for_tree_and_leaves,
})

local dirref = {
	{ x = 0, y = 0, z = -1 }, { x = 0, y = 0, z = 1 },
	{ x = 0, y = -1, z = 0 }, { x = 0, y = 1, z = 0 },
	{ x = -1, y = 0, z = 0 }, { x = 1, y = 0, z = 0 },
}

function _detail.method_for_soil(origpos, orignode, origmeta, digger, curpos, curnode)
	for _, dir in ipairs(dirref) do
		local p = vector.add(curpos, dir)
		local n = minetest.get_node(p)
		local meta = minetest.get_meta(p)
		local state = meta:get_int("digall")
		local range = _detail.player_data[digger:get_player_name()].association[orignode.name].arguments

		if minetest.get_node_group(n.name, "soil") > 0 and _detail.inrange(origpos, p, range) and ((not state) or state == 0) then
			_detail.dig_node_common(p, n, meta, digger)
			_detail.method_for_soil(origpos, orignode, origmeta, digger, p, n)
		end
	end
end

digall.register_method("digall:soil", {
	params = minetest.serialize({ x = "number", y = "number", z = "number" }),
	default_arguments = { x = 5, y = 5, z = 5 },
	body = _detail.method_for_soil,
})

function _detail.method_default(origpos, orignode, origmeta, digger, curpos, curnode)
	for _, dir in ipairs(dirref) do
		local p = vector.add(curpos, dir)
		local n = minetest.get_node(p)
		local meta = minetest.get_meta(p)
		local state = meta:get_int("digall")
		local range = _detail.player_data[digger:get_player_name()].association[orignode.name].arguments

		if orignode.name == n.name and _detail.inrange(origpos, p, range) and ((not state) or state == 0) then
			_detail.dig_node_common(p, n, meta, digger)
			_detail.method_default(origpos, orignode, origmeta, digger, p, n)
		end
	end
end

digall.register_method("digall:default", {
	params = minetest.serialize({ x = "number", y = "number", z = "number" }),
	default_arguments = { x = 5, y = 5, z = 5 },
	body = _detail.method_default,
})

function _detail.method_for_falling_node(origpos, orignode, origmeta, digger, curpos, curnode)
	-- dig nodes from top to bottmon
	local poss = {}
	local function _get_dig_nodes(curpos)
		for _, dir in pairs(dirref) do
			local p = vector.add(curpos, dir)
			local n = minetest.get_node(p)
			local meta = minetest.get_meta(p)
			local state = meta:get_int("digall")

			if not (state and state == 1) then
				local range = _detail.player_data[digger:get_player_name()].association[orignode.name].arguments

				if orignode.name == n.name and _detail.inrange(origpos, p, range) and ((not state) or state == 0) then
					table.insert(poss, p)
					meta:set_int("digall", 1)
					_get_dig_nodes(p)
				end
			end
		end
	end
	_get_dig_nodes(origpos)

	table.sort(poss, function(lhs, rhs)
		return lhs.y > rhs.y
	end)

	for _, pos in ipairs(poss) do
		local node = minetest.get_node(pos)
		local curwear = digger:get_wielded_item():get_wear()
		minetest.node_dig(pos, node, digger)

		local wielditem = digger:get_wielded_item()
		wielditem:set_wear(curwear)
		digger:set_wielded_item(wielditem)
	end
end

digall.register_method("digall:falling_node", {
	params = minetest.serialize({ x = "number", y = "number", z = "number" }),
	default_arguments = { x = 5, y = 5, z = 5 },
	body = _detail.method_for_falling_node,
})
