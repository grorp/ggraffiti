local shared = ...
local S = minetest.get_translator("ggraffiti")

local function get_eye_pos(player)
    local pos = player:get_pos()
    pos.y = pos.y + player:get_properties().eye_height
    return pos
end

local function wear_out(player_name, item, n_steps, size)
    if minetest.is_creative_enabled(player_name) then
        return item
    end

    item:add_wear_by_uses(shared.SPRAY_DURATION / shared.SPRAY_STEP_INTERVAL *
            shared.NUM_SPRAY_STEPS / n_steps / (size * size))
    if item:is_empty() then
        return ItemStack("ggraffiti:spray_can_empty")
    end
    return item
end

local function table_copy_shallow(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = v
    end
    return t2
end

local function get_processed_spray_def(item, prompt_player)
    local spray_def = shared.get_raw_spray_def(item)
    if not spray_def then return end
    spray_def = table_copy_shallow(spray_def)

    local meta = item:get_meta()
    spray_def.size = shared.meta_get_size(meta)

    if spray_def.rgb then
        spray_def.color = minetest.colorspec_to_colorstring(shared.meta_get_rgb_color(meta))

        if not spray_def.color then
            if prompt_player then
                shared.gui_show_rgb_initial_setup(prompt_player, item, meta)
            end
            return
        end
    end

    return spray_def
end

local player_lasts = {}

local function spray_can_on_use(item, player)
    local player_name = player:get_player_name()

    local spray_def = get_processed_spray_def(item, player)
    if not spray_def then return end

    local pos = get_eye_pos(player)
    local dir = player:get_look_dir()
    shared.spraycast(player, pos, dir, spray_def)
    player_lasts[player_name] = { pos = pos, dir = dir }
    shared.after_spraycasts()

    return wear_out(player_name, item, 1, spray_def.size)
end

local function spray_can_on_place(item, player)
    local meta = item:get_meta()
    shared.gui_show_configure(player, item, meta)
end

minetest.register_craftitem("ggraffiti:spray_can_empty", { -- stackable
    description = S("Empty Spray Can"),
    inventory_image = "ggraffiti_spray_can.png",

    range = shared.MAX_SPRAY_DISTANCE,
    on_use = function() end,

    groups = { ggraffiti_spray_can = 1, tool = shared.game == "mtg" and 1 or nil },
})

function shared.get_colored_can_texmod(color)
    return "ggraffiti_spray_can.png^(ggraffiti_spray_can_color.png^[multiply:" .. color .. ")"
end

for _, dye in ipairs(shared.game_dyes) do
    local item_name = "ggraffiti:spray_can_" .. dye.name

    minetest.register_tool(item_name, {
        description = S("Graffiti Spray Can (" .. dye.desc .. ")") .. "\n" ..
            S("Left-click to spray, right-click to configure.") .. "\n\n" ..
            S("Size: @1", 1),
        inventory_image = shared.get_colored_can_texmod(dye.color),

        range = shared.MAX_SPRAY_DISTANCE,
        on_use = spray_can_on_use,
        on_place = spray_can_on_place,
        on_secondary_use = spray_can_on_place,
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
        S("Left-click to spray, right-click to configure.") .. "\n\n" ..
        S("No color set.") .. "\n" ..
        S("Size: @1", 1),
    inventory_image = "ggraffiti_spray_can_rgb.png",

    range = shared.MAX_SPRAY_DISTANCE,
    on_use = spray_can_on_use,
    on_place = spray_can_on_place,
    on_secondary_use = spray_can_on_place,
    _ggraffiti_spray_can = {
        rgb = true,
    },

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
        S("Left-click to spray, right-click to configure.") .. "\n\n" ..
        S("Size: @1", 1),
    inventory_image = "ggraffiti_spray_can_remover.png",

    range = shared.MAX_SPRAY_DISTANCE,
    on_use = spray_can_on_use,
    on_place = spray_can_on_place,
    on_secondary_use = spray_can_on_place,
    _ggraffiti_spray_can = {
        remover = true,
    },

    groups = { ggraffiti_spray_can = 1 },
})

minetest.register_alias("ggraffiti:spray_can_anti", "ggraffiti:spray_can_remover")

minetest.register_craft({
    recipe = {
        { shared.game_items.iron_ingot     },
        { "ggraffiti:mushroom_red_extract" },
        { shared.game_items.iron_ingot     },
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

local function spray_step(player)
    local player_name = player:get_player_name()

    if not player:get_player_control().dig then
        player_lasts[player_name] = nil
        return
    end

    local item = player:get_wielded_item()
    local spray_def = get_processed_spray_def(item)
    if not spray_def then
        player_lasts[player_name] = nil
        return
    end

    -- Seems to be kind of expensive.
    if not minetest.check_player_privs(player_name, "interact") then
        player_lasts[player_name] = nil
        return
    end

    local last = player_lasts[player_name]
    local now_pos = get_eye_pos(player)
    local now_dir = player:get_look_dir()

    if last then
        local n_steps = shared.NUM_SPRAY_STEPS

        if now_pos == last.pos and now_dir == last.dir then
            -- The player hasn't moved, but the world may have changed.
            shared.spraycast(player, now_pos, now_dir, spray_def)
        else
            for step_n = 1, n_steps do
                local lerp = lerp_factory(step_n / n_steps)
                local pos = vector.combine(last.pos, now_pos, lerp)
                local dir = vector.combine(last.dir, now_dir, lerp):normalize() -- "nlerp"

                shared.spraycast(player, pos, dir, spray_def)
            end
        end

        item = wear_out(player_name, item, n_steps, spray_def.size)
        player:set_wielded_item(item)
    end

    player_lasts[player_name] = { pos = now_pos, dir = now_dir }
end

local dtime_accu = 0

-- local deltas = {}
-- local delta_index = 1

minetest.register_globalstep(function(dtime)
    dtime_accu = dtime_accu + dtime

    if dtime_accu >= shared.SPRAY_STEP_INTERVAL then
        -- shared.profiler_someone_spraying = false
        -- local t1 = minetest.get_us_time()

        dtime_accu = dtime_accu % shared.SPRAY_STEP_INTERVAL
        for _, player in ipairs(minetest.get_connected_players()) do
            spray_step(player)
        end
        shared.after_spraycasts()

        -- if shared.profiler_someone_spraying then
        --     local t2 = minetest.get_us_time()
        --     deltas[delta_index] = (t2 - t1) / 1000
        --     delta_index = delta_index + 1
        --     if delta_index > 100000 then
        --         delta_index = 1
        --     end

        --     local avg = 0
        --     for _, v in ipairs(deltas) do
        --         avg = avg + v
        --     end
        --     avg = avg / #deltas
        --     print(string.format("[ggraffiti] average spray step time: %.6f ms", avg))
        -- end
    end
end)
