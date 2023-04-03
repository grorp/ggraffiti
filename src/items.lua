local shared = ...
local S = minetest.get_translator("ggraffiti")

local player_lasts = {}

local function get_eye_pos(player)
    local pos = player:get_pos()
    pos.y = pos.y + player:get_properties().eye_height
    return pos
end

local function wear_out(player_name, item, uses)
    if minetest.is_creative_enabled(player_name) then
        -- Don't wear out the item and allow unlimited uses if the player is in
        -- creative mode.
        return item, uses
    end
    for i = 1, uses do
        item:add_wear_by_uses(shared.SPRAY_DURATION / shared.SPRAY_STEP_INTERVAL * shared.NUM_SPRAY_STEPS)
        if item:is_empty() then
            return ItemStack("ggraffiti:spray_can_empty"), i
        end
    end
    return item, uses
end

local function spray_can_on_use(item, player)
    local player_name = player:get_player_name()

    local spray_def = shared.get_raw_spray_def(item)
    if spray_def.rgb then
        spray_def = {
            color = shared.rgb_get_color(item),
        }
        if not spray_def.color then
            shared.rgb_show_gui_initial_setup(player)
            return
        end
    end

    local pos = get_eye_pos(player)
    local dir = player:get_look_dir()
    shared.spraycast(player, pos, dir, spray_def)
    player_lasts[player_name] = { pos = pos, dir = dir }

    item = wear_out(player_name, item, 1)
    return item
end

local function spray_can_rgb_on_place(item, player)
    shared.rgb_show_gui(player, item)
end

minetest.register_craftitem("ggraffiti:spray_can_empty", { -- stackable
    description = S("Empty Spray Can"),
    inventory_image = "ggraffiti_spray_can.png",

    range = shared.MAX_SPRAY_DISTANCE,
    on_use = function() end,

    groups = { ggraffiti_spray_can = 1, tool = shared.game == "mtg" and 1 or nil },
})

for _, dye in ipairs(shared.game_dyes) do
    local item_name = "ggraffiti:spray_can_" .. dye.name

    minetest.register_tool(item_name, {
        description = S("Graffiti Spray Can (" .. dye.desc .. ")") .. "\n" ..
            S("Press left mouse button to spray."),
        inventory_image = "ggraffiti_spray_can.png^(ggraffiti_spray_can_color.png^[multiply:" .. dye.color .. ")",

        range = shared.MAX_SPRAY_DISTANCE,
        on_use = spray_can_on_use,
        _ggraffiti_spray_can = {
            color = dye.color,
        },

        groups = { ggraffiti_spray_can = 1 },
    })

    minetest.register_craft({
        recipe = {
            { shared.game_items.iron_ingot },
            { dye.item_name                },
            { shared.game_items.iron_ingot },
        },
        output = item_name,
    })
end

minetest.register_tool("ggraffiti:spray_can_rgb", {
    description = S("RGB Graffiti Spray Can") .. "\n" ..
        S("No color set.") .. "\n" ..
        S("Press left mouse button to spray, press right mouse button to configure."),
    inventory_image = "ggraffiti_spray_can_rgb.png",

    range = shared.MAX_SPRAY_DISTANCE,
    on_use = spray_can_on_use,
    _ggraffiti_spray_can = {
        rgb = true,
    },
    on_place = spray_can_rgb_on_place,
    on_secondary_use = spray_can_rgb_on_place,

    groups = { ggraffiti_spray_can = 1 },
})

minetest.register_craft({
    recipe = {
        { "",                        shared.game_items.iron_ingot, ""                         },
        { shared.game_items.red_dye, shared.game_items.green_dye,  shared.game_items.blue_dye },
        { "",                        shared.game_items.iron_ingot, ""                         },
    },
    output = "ggraffiti:spray_can_rgb",
})

minetest.register_craftitem("ggraffiti:mushroom_red_extract", {
    description = S("Red Mushroom Extract"),
    inventory_image = "ggraffiti_mushroom_red_extract.png",
    groups = { craftitem = shared.game == "mcl" and 1 or nil },
})

minetest.register_craft({
    recipe = {{ shared.game_items.red_mushroom }},
    output = "ggraffiti:mushroom_red_extract " .. shared.game_items.red_mushroom_extract_count,
})

minetest.register_tool("ggraffiti:spray_can_remover", {
    description = S("Graffiti Remover Spray Can") .. "\n" ..
        S("Press left mouse button to spray."),
    inventory_image = "ggraffiti_spray_can_remover.png",

    range = shared.MAX_SPRAY_DISTANCE,
    on_use = spray_can_on_use,
    _ggraffiti_spray_can = {
        remover = true,
    },

    groups = { ggraffiti_spray_can = 1 },
})

minetest.register_alias("ggraffiti:spray_can_anti", "ggraffiti:spray_can_remover")

minetest.register_craft({
    recipe = {
        { shared.game_items.iron_ingot          },
        { "ggraffiti:mushroom_red_extract"      },
        { shared.game_items.iron_ingot          },
    },
    output = "ggraffiti:spray_can_remover",
})

minetest.register_craft({
    type = "cooking",
    recipe = "group:ggraffiti_spray_can",
    output = shared.game_items.iron_ingot .. " 2",
})

local function lerp_factory(t)
    return function(a, b)
        return a + (b - a) * t
    end
end

local function fast_new(x, y, z)
	return setmetatable({x = x, y = y, z = z}, metatable)
end

-- Needed for compatibility with versions of minetest from before
-- vector.combine() was added (5.6.0)
local function vector_combine(a, b, func)
	return fast_new(
		func(a.x, b.x),
		func(a.y, b.y),
		func(a.z, b.z)
	)
end

-- Needed for compatibility with versions of minetest from before
-- vector.normalize() was added (5.6.0)
function normalize(v)
	local len = vector.length(v)
	if len == 0 then
		return fast_new(0, 0, 0)
	else
		return vector.divide(v, len)
	end
end

local function spray_step(player)
    local player_name = player:get_player_name()

    if not minetest.check_player_privs(player_name, "interact") or
            not player:get_player_control().dig then
        player_lasts[player_name] = nil
        return
    end

    local item = player:get_wielded_item()
    local spray_def = shared.get_raw_spray_def(item)
    if not spray_def then
        player_lasts[player_name] = nil
        return
    end

    if spray_def.rgb then
        spray_def = {
            color = shared.rgb_get_color(item),
        }
        if not spray_def.color then
            player_lasts[player_name] = nil
            return
        end
    end

    local last = player_lasts[player_name]
    local now_pos = get_eye_pos(player)
    local now_dir = player:get_look_dir()

    if last then
        local n_steps = shared.NUM_SPRAY_STEPS
        item, n_steps = wear_out(player_name, item, n_steps)
        player:set_wielded_item(item)

        if now_pos:equals(last.pos) and now_dir:equals(last.dir) then
            -- The player hasn't moved, but the world may have changed.
            shared.spraycast(player, now_pos, now_dir, spray_def)
        else
            for step_n = 1, n_steps do
                local lerp = lerp_factory(step_n / n_steps)
                local pos = vector_combine(last.pos, now_pos, lerp)
                local dir = normalize(vector_combine(last.dir, now_dir, lerp)) -- "nlerp"

                shared.spraycast(player, pos, dir, spray_def)
            end
        end
    end

    player_lasts[player_name] = { pos = now_pos, dir = now_dir }
end

local dtime_accu = 0

minetest.register_globalstep(function(dtime)
    dtime_accu = dtime_accu + dtime
    if dtime_accu >= shared.SPRAY_STEP_INTERVAL then
        dtime_accu = dtime_accu % shared.SPRAY_STEP_INTERVAL
        for _, player in ipairs(minetest.get_connected_players()) do
            spray_step(player)
        end
        shared.update_canvases()
    end
end)
