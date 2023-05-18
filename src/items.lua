local shared = ...
local S = minetest.get_translator("ggraffiti")

local function make_spray_can_brush(color, remover)
    return function(item, player, is_on_use)
        local meta = item:get_meta()
        local size = shared.meta_get_size(meta)
        if not color and not remover then
            color = minetest.colorspec_to_colorstring(shared.meta_get_rgb_color(meta))
            if not color then
                if is_on_use then
                    shared.gui_show_rgb_initial_setup(player, item, meta)
                end
                return
            end
        end

        return {
            duration = ggraffiti.DEFAULT_DURATION / size / size,
            replacement_item = "ggraffiti:spray_can_empty",
            remover = remover,
            color = not remover and color or nil,
            size = size,
        }
    end
end

local function spray_can_on_place(item, player)
    local meta = item:get_meta()
    shared.gui_show_configure(player, item, meta)
end

minetest.register_craftitem("ggraffiti:spray_can_empty", { -- stackable
    description = S("Empty Spray Can"),
    inventory_image = "ggraffiti_spray_can.png",

    range = ggraffiti.DEFAULT_MAX_DISTANCE,
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

        range = ggraffiti.DEFAULT_MAX_DISTANCE,
        on_use = ggraffiti.brush_on_use,
        _ggraffiti_brush = make_spray_can_brush(dye.color, false),

        on_place = spray_can_on_place,
        on_secondary_use = spray_can_on_place,

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

    range = ggraffiti.DEFAULT_MAX_DISTANCE,
    on_use = ggraffiti.brush_on_use,
    _ggraffiti_brush = make_spray_can_brush(nil, false),

    on_place = spray_can_on_place,
    on_secondary_use = spray_can_on_place,

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

    range = ggraffiti.DEFAULT_MAX_DISTANCE,
    on_use = ggraffiti.brush_on_use,
    _ggraffiti_brush = make_spray_can_brush(nil, true),

    on_place = spray_can_on_place,
    on_secondary_use = spray_can_on_place,

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
