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

    local pos = get_eye_pos(player)
    local dir = player:get_look_dir()
    shared.spraycast(player, pos, dir, item:get_definition()._ggraffiti_spray_can)
    player_lasts[player_name] = {pos = pos, dir = dir}

    item = wear_out(player_name, item, 1)
    return item
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

local function meta_get_color(meta)
    return minetest.deserialize(meta:get_string("ggraffiti_color"))
end

local function meta_set_color(meta, color)
    meta:set_string("ggraffiti_color", minetest.serialize(color))
end

local gui = flow.widgets

local rgb_spray_can_gui
local rgb_spray_can_change_color_gui

local function make_color_texture(color)
    local png = minetest.encode_png(1, 1, { color }, 9)
    return "[png:" .. minetest.encode_base64(png)
end

rgb_spray_can_gui = flow.make_gui(function(player, ctx)
    return gui.VBox {
        min_w = 20,
        padding = 0.4,
        spacing = 0.4,
        gui.label { label = ServerS(player, "RGB Graffiti Spray Can") },
        gui.Label { label = ServerS(player, "Color") },
        gui.HBox {
            spacing = 0.4,
            gui.Image {
                w = 0.8,
                h = 0.8,
                texture_name = make_color_texture(ctx.color),
            },
            gui.Label {
                label = ServerS(player, "R: @1, G: @2, B: @3", ctx.color.r, ctx.color.g, ctx.color.b),
                expand = true,
                align_h = "left",
            },
            gui.Button {
                label = ServerS(player, "Change"),
                on_event = function(player, ctx)
                    rgb_spray_can_change_color_gui:show(player, {
                        color = ctx.color,
                    })
                end,
            },
        },
    }
end)

local function adjust_field_value(val)
    local int = math.floor(tonumber(val) or 0)
    local clamped = math.min(math.max(int, 0), 255)
    return tostring(clamped)
end

rgb_spray_can_change_color_gui = flow.make_gui(function(player, ctx)
    return gui.VBox {
        min_w = 20,
        padding = 0.4,
        spacing = 0.4,
        gui.Label {
            label = ctx.initial_setup and
                    ServerS(player, "Set color") or
                    ServerS(player, "Change color"),
        },
        gui.HBox {
            spacing = 0.4,
            gui.Field {
                name = "field_r",
                label = minetest.colorize("#f00", ServerS(player, "R (Red)")),
                default = ctx.initial_setup and "" or tostring(ctx.color.r),
                expand = true,
                on_event = function(player, ctx)
                    ctx.form.field_r = adjust_field_value(ctx.form.field_r)
                    return true
                end,
            },
            gui.Field {
                name = "field_g",
                label = minetest.colorize("#0f0", ServerS(player, "G (Green)")),
                default = ctx.initial_setup and "" or tostring(ctx.color.g),
                expand = true,
                on_event = function(player, ctx)
                    ctx.form.field_g = adjust_field_value(ctx.form.field_g)
                    return true
                end,
            },
            gui.Field {
                name = "field_b",
                label = minetest.colorize("#00f", ServerS(player, "B (Blue)")),
                default = ctx.initial_setup and "" or tostring(ctx.color.b),
                expand = true,
                on_event = function(player, ctx)
                    ctx.form.field_b = adjust_field_value(ctx.form.field_b)
                    return true
                end,
            },
        },
        gui.Label { label = ServerS(player, "Values must be integers in the range [0..255].") },
        gui.VBox {
            spacing = 0,
            gui.Label { label = ServerS(player, "Preview") },
            gui.HBox {
                spacing = 0.4,
                gui.Button {
                    label = ServerS(player, "Update"),
                    -- no on_event needed
                },
            },
        },
        gui.HBox {
            spacing = 0.4,
            ctx.initial_setup and gui.Spacer {} or gui.Button {
                label = ServerS(player, "Cancel"),
                expand = true,
                on_event = function(player, ctx)
                    rgb_spray_can_gui:show(player, {
                        color = ctx.color,
                    })
                end,
            },
            gui.Button {
                label = ServerS(player, "Save"),
                expand = true,
                on_event = function(player, ctx)
                    -- We have to do this again here because this callback isn't
                    -- always called after the others.
                    ctx.form.field_r = adjust_field_value(ctx.form.field_r)
                    ctx.form.field_g = adjust_field_value(ctx.form.field_g)
                    ctx.form.field_b = adjust_field_value(ctx.form.field_b)

                    local item = player:get_wielded_item()
                    -- verify that we're replacing the correct item
                    if item:get_name() == "ggraffiti:spray_can_rgb" then
                        local meta = item:get_meta()
                        local color = meta_get_color(meta)
                        -- verify that we're *really* replacing the correct item
                        if (ctx.color == nil and color == nil) or
                                (ctx.color ~= nil and color ~= nil and
                                ctx.color.r == color.r and ctx.color.g == color.g and ctx.color.b == color.b) then
                            color = {
                                r = tonumber(ctx.form.field_r),
                                g = tonumber(ctx.form.field_g),
                                b = tonumber(ctx.form.field_b),
                            }
                            meta_set_color(meta, color)
                            player:set_wielded_item(item)
                            rgb_spray_can_gui:show(player, {
                                color = color,
                            })
                        end
                    end
                end,
            },
        },
    }
end)

local function rgb_spray_can_on_place(item, player, pointed_thing)
    local meta = item:get_meta()
    local color = meta_get_color(meta)
    if not color then
        rgb_spray_can_change_color_gui:show(player, {
            initial_setup = true,
        })
    else
        rgb_spray_can_gui:show(player, {
            color = color,
        })
    end
end

minetest.register_tool("ggraffiti:spray_can_rgb", {
    description = S("RGB Graffiti Spray Can"),
    inventory_image = "ggraffiti_spray_can.png",

    range = shared.MAX_SPRAY_DISTANCE,
    on_use = spray_can_on_use,
    _ggraffiti_spray_can = {
        color = "#f0f0f0",
    },
    on_place = rgb_spray_can_on_place,
    on_secondary_use = rgb_spray_can_on_place,

    groups = {ggraffiti_spray_can = 1},
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
