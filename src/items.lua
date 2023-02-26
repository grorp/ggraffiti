local shared = ...

local S = minetest.get_translator("ggraffiti")
-- In formspecs, I use server-side translations so that the layout of the
-- formspecs can adapt to the length of the translated strings.
local function ServerS(player, string, ...)
    local lang_code = minetest.get_player_information(player:get_player_name()).lang_code
    return minetest.get_translated_string(lang_code, S(string, ...))
end

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

    local spray_def = item:get_definition()._ggraffiti_spray_can
    if spray_def.rgb then
        spray_def = {
            color = shared.rgb_get_color(item),
        }
        if not spray_def.color then
            shared.rgb_show_gui_no_color(player)
            return
        end
    end

    local pos = get_eye_pos(player)
    local dir = player:get_look_dir()
    shared.spraycast(player, pos, dir, spray_def)
    player_lasts[player_name] = {pos = pos, dir = dir}

    item = wear_out(player_name, item, 1)
    return item
end

local function spray_can_rgb_on_place(item, player)
    local spray_def = item:get_definition()._ggraffiti_spray_can
    if spray_def.rgb then
        shared.rgb_show_gui(player)
    end
end

minetest.register_craftitem("ggraffiti:spray_can_empty", { -- stackable
    description = S("Empty Spray Can"),
    inventory_image = "ggraffiti_spray_can.png",

    range = shared.MAX_SPRAY_DISTANCE,
    on_use = function() end,

    groups = {ggraffiti_spray_can = 1, tool = 1},
})

for _, dye in ipairs(dye.dyes) do
    local dye_name, dye_desc = unpack(dye)
    local dye_color = shared.DYE_COLORS[dye_name]

    local item_name = "ggraffiti:spray_can_" .. dye_name

    minetest.register_tool(item_name, {
        description = S("Graffiti Spray Can (" .. dye_desc:lower() .. ")"),
        inventory_image = "ggraffiti_spray_can.png^(ggraffiti_spray_can_color.png^[multiply:" .. dye_color .. ")",

        range = shared.MAX_SPRAY_DISTANCE,
        on_use = spray_can_on_use,
        _ggraffiti_spray_can = {
            color = dye_color,
        },

        groups = {ggraffiti_spray_can = 1},
    })

    minetest.register_craft({
        recipe = {
            {"default:steel_ingot"},
            {"dye:" .. dye_name},
            {"default:steel_ingot"},
        },
        output = item_name,
    })
end

minetest.register_tool("ggraffiti:spray_can_rgb", {
    description = S("RGB Graffiti Spray Can"),
    inventory_image = "ggraffiti_spray_can_rgb.png",

    range = shared.MAX_SPRAY_DISTANCE,
    on_use = spray_can_on_use,
    _ggraffiti_spray_can = {
        rgb = true,
    },
    on_place = spray_can_rgb_on_place,
    on_secondary_use = spray_can_rgb_on_place,

    groups = {ggraffiti_spray_can = 1},
})

minetest.register_craft({
    recipe = {
        {"",        "default:steel_ingot", ""        },
        {"dye:red", "dye:green",           "dye:blue"},
        {"",        "default:steel_ingot", ""        },
    },
    output = "ggraffiti:spray_can_rgb",
})

minetest.register_craftitem("ggraffiti:mushroom_red_extract", {
    description = S("Red Mushroom Extract"),
    inventory_image = "ggraffiti_mushroom_red_extract.png",
})

minetest.register_craft({
    recipe = {{"flowers:mushroom_red"}},
    output = "ggraffiti:mushroom_red_extract 4",
})

minetest.register_tool("ggraffiti:spray_can_remover", {
    description = S("Graffiti Remover Spray Can"),
    inventory_image = "ggraffiti_spray_can_remover.png",

    range = shared.MAX_SPRAY_DISTANCE,
    on_use = spray_can_on_use,
    _ggraffiti_spray_can = {
        remover = true,
    },

    groups = {ggraffiti_spray_can = 1},
})

minetest.register_alias("ggraffiti:spray_can_anti", "ggraffiti:spray_can_remover")

minetest.register_craft({
    recipe = {
        {"default:steel_ingot"},
        {"ggraffiti:mushroom_red_extract"},
        {"default:steel_ingot"},
    },
    output = "ggraffiti:spray_can_remover",
})

minetest.register_craft({
    type = "cooking",
    recipe = "group:ggraffiti_spray_can",
    output = "default:steel_ingot 2",
})

local function lerp_factory(t)
    return function(a, b)
        return a + (b - a) * t
    end
end

local function spray_step()
    for _, player in ipairs(minetest.get_connected_players()) do
        local player_name = player:get_player_name()
        local item = player:get_wielded_item()
        local def = item:get_definition()

        if def then
            local spray_def = def._ggraffiti_spray_can
            if spray_def then
                if spray_def.rgb then
                    spray_def = {
                        color = shared.rgb_get_color(item),
                    }
                    if not spray_def.color then
                        return
                    end

        if def._ggraffiti_spray_can and player:get_player_control().dig then
            local last = player_lasts[player_name]

            local now_pos = get_eye_pos(player)
            local now_dir = player:get_look_dir()

            if last then
                local n_steps = shared.NUM_SPRAY_STEPS
                item, n_steps = wear_out(player_name, item, n_steps)
                player:set_wielded_item(item)

                if now_pos:equals(last.pos) and now_dir:equals(last.dir) then
                    -- The player hasn't moved, but the world may have changed.
                    shared.spraycast(player, now_pos, now_dir, def._ggraffiti_spray_can)
                else
                    for step_n = 1, n_steps do
                        local lerp = lerp_factory(step_n / n_steps)
                        local pos = vector.combine(last.pos, now_pos, lerp)
                        local dir = vector.combine(last.dir, now_dir, lerp):normalize() -- "nlerp"

                        shared.spraycast(player, pos, dir, def._ggraffiti_spray_can)
                    end
                end
            end

            player_lasts[player_name] = {pos = now_pos, dir = now_dir}
        else
            player_lasts[player_name] = nil
        end
    end
end

local dtime_accu = 0

minetest.register_globalstep(function(dtime)
    dtime_accu = dtime_accu + dtime
    if dtime_accu >= shared.SPRAY_STEP_INTERVAL then
        dtime_accu = dtime_accu % shared.SPRAY_STEP_INTERVAL
        spray_step()
        shared.update_canvases()
    end
end)
