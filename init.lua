digall = {}

dofile(minetest.get_modpath("digall").."/api.lua")
dofile(minetest.get_modpath("digall").."/command.lua")

local function _digall(pos, oldnode, oldmetadata, digger)
	local pdata = digall._detail.player_data[digger:get_player_name()]
	if not pdata.activated then
		return
	end

	if pdata.quickmode then
		local control = digger:get_player_control()
		if not control.sneak then
			return
		end
	end

	local state = oldmetadata.fields["digall"]
	if state and state == "1" then -- already reserved
		return
	end

	local assoc = pdata.association[oldnode.name]
	if not assoc then
		return
	end

	local method = digall.registered_methods[assoc.methodname]

	method.body(pos, oldnode, oldmetadata, digger, pos, oldnode)
end

minetest.register_privilege("digall", {
	description = "Player can digall",
	give_to_singleplayer = false,
})

local function _load_config_file()
	local worldpath = minetest.get_worldpath()
	local file = io.open(worldpath.."/digall.conf", "r")

	if file then
		digall._detail.player_data = minetest.deserialize(file:read("*all"))
		file:close()
	end
end
_load_config_file()

minetest.after(0, function()
	for nodename, nodedef in pairs(minetest.registered_nodes) do
		if not nodedef.connects_to then -- avoid connects_to node bug.
			local after_dig_node
			local prev_after_dig_node = nodedef.after_dig_node

			if prev_after_dig_node then
				after_dig_node = function(pos, oldnode, oldmetadata, digger)
					_digall(pos, oldnode, oldmetadata, digger)
					prev_after_dig_node(pos, oldnode, oldmetadata, digger)
				end
			else
				after_dig_node = _digall
			end

			minetest.override_item(nodename, { after_dig_node = after_dig_node })
		end
	end
end)

minetest.register_on_newplayer(function(player)
	digall.set_default_association(player:get_player_name())
end)

minetest.register_on_joinplayer(function(player)
	if not rawget(digall._detail.player_data, player:get_player_name()) then
		digall.set_default_association(player:get_player_name())
	end
end)

minetest.register_on_shutdown(function()
	local worldpath = minetest.get_worldpath()
	local file = io.open(worldpath.."/digall.conf", "w")

	file:write(minetest.serialize(digall._detail.player_data))
	file:close()
end)
