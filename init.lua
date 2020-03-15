-- Depth Finder [depth_finder]
-- by David G (kestral246@gmail.com)
-- 2020-03-15

-- Currently just two flints--bang them together and the return echo indicates depth.

local scan_angle = math.pi/4  -- corresponds to 90°

-- Maximum number of nodes to check
local maxcount = 150000

-- The wear and radius can now be set independently for each lamp tool.

-- Set to true to print debug statistics.
local debug = false

local scanned = {}  -- Set containing scanned nodes, so they don't get scanned multiple times.
local tocheck = {}  -- Table of nodes to check.
local max_depth = {}  -- Deepest node scanned.

minetest.register_on_joinplayer(function(player)
	local pname = player:get_player_name()
	scanned[pname] = {}
	tocheck[pname] = {}
	max_depth[pname] = 0
end)

minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	scanned[pname] = nil
	tocheck[pname] = nil
	max_depth[pname] = nil
end)

-- Determine number of elements in table, for summary output.
local tlength = function(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

-- Scan neighboring nodes, flag for checking if air.
local scan_node = function(pname, pos, origin, vdir, maxdist)
	-- Update to search a cone pattern in direction pointed.
	-- Need small sphere to get cone out.
	local origin2d = {x=origin.x, y=0, z=origin.z}
	local pos2d = {x=pos.x, y=0, z=pos.z}
	local radius = vector.distance(origin2d, pos2d)
	if radius <= 2 or (radius <= maxdist and vector.angle(vdir, vector.direction(origin2d, pos2d)) < scan_angle) then
		local enc_pos = minetest.hash_node_position(pos)
		if scanned[pname][enc_pos] ~= true then  -- hasn't been scanned
			local name = minetest.get_node(pos).name
			if name == "air" then  -- checkable
				table.insert(tocheck[pname], enc_pos)  -- add to check list
			end
			scanned[pname][enc_pos] = true  -- don't scan again
		end
	end
end

-- To check, scan all neighbors and determine if this node needs to be converted to light.
local check_node = function(pname, pos, origin, vdir, maxdist, height, depth)
	local enc_pos = minetest.hash_node_position(pos)
	local name = minetest.get_node(pos).name
	scan_node(pname, vector.add(pos, {x=0,y=0,z=1}), origin, vdir, maxdist)  -- north
	scan_node(pname, vector.add(pos, {x=1,y=0,z=0}), origin, vdir, maxdist)  -- east
	scan_node(pname, vector.add(pos, {x=0,y=0,z=-1}), origin, vdir, maxdist)  -- south
	scan_node(pname, vector.add(pos, {x=-1,y=0,z=0}), origin, vdir, maxdist)  -- west
	if pos.y > origin.y - depth then
		scan_node(pname, vector.add(pos, {x=0,y=-1,z=0}), origin, vdir, maxdist)  -- down
	end
	if pos.y < origin.y + height then
		scan_node(pname, vector.add(pos, {x=0,y=1,z=0}), origin, vdir, maxdist)  -- up
	end
	if pos.y < max_depth[pname] then
		max_depth[pname] = pos.y
	end
end

local use_finder = function(player, itemstack, radius, height, depth, wear)
	local pname = player:get_player_name()
	local pos = vector.add(vector.round(player:get_pos()), {x=0,y=0,z=0})  -- position of wand
	local theta = math.fmod(player:get_look_horizontal() + math.pi/2, 2*math.pi)
	local vdir = vector.normalize({x=math.cos(theta), y=0, z=math.sin(theta)})
	local key_stats = player:get_player_control()
	local wear_cost = wear

	-- Initialize temporary tables for safety.
	scanned[pname] = {}
	tocheck[pname] = {}
	max_depth[pname] = pos.y
	-- Search starts at finder position.
	table.insert(tocheck[pname], minetest.hash_node_position(pos))
	local count = 1
	while count <= table.getn(tocheck[pname]) and count <= maxcount do
		check_node(pname, minetest.get_position_from_hash(tocheck[pname][count]), pos, vdir, radius, height, depth)
		count = count + 1
	end
	count = count - 1 
	if debug then  -- print statistics
		minetest.debug("depth_finder: y = "..tostring(pos.y)..", scan = "..
			tostring(tlength(scanned[pname]))..", check = "..tostring(count)..", depth = "..
			tostring(max_depth[pname]))
	end
	--minetest.chat_send_player(pname, "pdir = "..tostring(minetest.serialize(vdir)))
	minetest.chat_send_player(pname, "depth = "..tostring(max_depth[pname] - pos.y))
	-- Clear temporary tables, which could be large.
	scanned[pname] = {}
	tocheck[pname] = {}
	max_depth[pname] = 0
	-- Add wear to finder
	itemstack:add_wear(wear_cost)
	return itemstack
end

minetest.register_tool("depth_finder:simple", {
	description = "Simple Depth Finder",
	inventory_image = "depth_finder_simple.png",
	stack_max = 1,
	on_use = function(itemstack, player, pointed_thing)
		local radius = 50
		local height = 10
		local depth = 80
		local wear = math.floor(65535/25)
		local worn_item = use_finder(player, itemstack, radius, height, depth, wear)
		return worn_item
	end,
})

-- Need default for crafting recipe.
-- Example craft recipe.
if minetest.get_modpath("default") ~= nil then
	minetest.register_craft({
		output = "depth_finder:simple",
		recipe = {
			{"default:flint", "default:flint"}
		}
	})
end
