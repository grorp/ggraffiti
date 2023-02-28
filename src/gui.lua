local shared = ...
local gui = flow.widgets
local S = minetest.get_translator("ggraffiti")

-- In formspecs, I use server-side translations so that the layout of the
-- formspecs can adapt to the length of the translated strings.
local function ServerS(player, string, ...)
    local lang_code = minetest.get_player_information(player:get_player_name()).lang_code
    return minetest.get_translated_string(lang_code, S(string, ...))
end

function shared.get_raw_spray_def(item)
    local def = item:get_definition()
    return def and def._ggraffiti_spray_can
end

function shared.rgb_get_color(item)
    local meta = item:get_meta()
    return minetest.deserialize(meta:get_string("ggraffiti_color"))
end

function shared.rgb_set_color(item, color)
    local meta = item:get_meta()
    meta:set_string("ggraffiti_color", minetest.serialize(color))

    local color_block = minetest.colorize(minetest.colorspec_to_colorstring(color), "█")
    local desc = S("RGB Graffiti Spray Can") .. "\n" ..
        color_block .. " " .. S("R: @1, G: @2, B: @3", color.r, color.g, color.b)
    meta:set_string("description", desc)
end

local rgb_gui
local rgb_change_color_gui

local function make_color_texture(color)
    local png = minetest.encode_png(1, 1, { color }, 9)
    return "[png:" .. minetest.encode_base64(png)
end

rgb_gui = flow.make_gui(function(player, ctx)
    return gui.VBox {
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
                    rgb_change_color_gui:show(player, {
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

local function cancel_button_on_event(player, ctx)
    rgb_gui:show(player, {
        color = ctx.color,
    })
end

local function save_button_on_event(player, ctx)
    -- We have to do this again here because this callback isn't
    -- always called after the others.
    ctx.form.field_r = adjust_field_value(ctx.form.field_r)
    ctx.form.field_g = adjust_field_value(ctx.form.field_g)
    ctx.form.field_b = adjust_field_value(ctx.form.field_b)

    local item = player:get_wielded_item()
    local spray_def = shared.get_raw_spray_def(item)
    -- verify that we're replacing the correct item
    if spray_def and spray_def.rgb then
        local color = shared.rgb_get_color(item)
        -- verify that we're *really* replacing the correct item
        if (ctx.color == nil and color == nil) or
                (ctx.color ~= nil and color ~= nil and
                ctx.color.r == color.r and ctx.color.g == color.g and ctx.color.b == color.b) then
            color = {
                r = tonumber(ctx.form.field_r),
                g = tonumber(ctx.form.field_g),
                b = tonumber(ctx.form.field_b),
            }
            shared.rgb_set_color(item, color)
            player:set_wielded_item(item)
            if ctx.initial_setup then
                rgb_change_color_gui:close(player)
            else
                rgb_gui:show(player, {
                    color = color,
                })
            end
        end
    end
end

rgb_change_color_gui = flow.make_gui(function(player, ctx)
    local has_input_color = not not (ctx.form.field_r and ctx.form.field_g and ctx.form.field_b)
    local has_default_color = not ctx.initial_setup
    local png_color
    if has_input_color or has_default_color then
        png_color = {
            r = has_input_color and tonumber(ctx.form.field_r) or ctx.color.r,
            g = has_input_color and tonumber(ctx.form.field_g) or ctx.color.g,
            b = has_input_color and tonumber(ctx.form.field_b) or ctx.color.b,
        }
    end

    local preview_h_box = gui.HBox {
        spacing = 0.4,
    }
    if png_color then
        table.insert(preview_h_box, gui.Image {
            w = 0.8,
            h = 0.8,
            expand = true,
            align_h = "fill",
            texture_name = make_color_texture(png_color),
        })
    end
    table.insert(preview_h_box, gui.Button {
        label = ServerS(player, "Update"),
        expand = not png_color or nil,
        align_h = not png_color and "right" or nil,
        -- no on_event needed
    })

    local buttons_h_box = gui.HBox {
        spacing = 0.4,
    }
    if not ctx.initial_setup then
        table.insert(buttons_h_box, gui.Button {
            label = ServerS(player, "Cancel"),
            expand = true,
            on_event = cancel_button_on_event,
        })
    end
    table.insert(buttons_h_box, gui.Button {
        label = ServerS(player, "Save"),
        expand = true,
        on_event = save_button_on_event,
    })

    return gui.VBox {
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
                default = not ctx.initial_setup and tostring(ctx.color.r) or nil,
                expand = true,
                on_event = function(player, ctx)
                    ctx.form.field_r = adjust_field_value(ctx.form.field_r)
                    return true
                end,
            },
            gui.Field {
                name = "field_g",
                label = minetest.colorize("#0f0", ServerS(player, "G (Green)")),
                default = not ctx.initial_setup and tostring(ctx.color.g) or nil,
                expand = true,
                on_event = function(player, ctx)
                    ctx.form.field_g = adjust_field_value(ctx.form.field_g)
                    return true
                end,
            },
            gui.Field {
                name = "field_b",
                label = minetest.colorize("#00f", ServerS(player, "B (Blue)")),
                default = not ctx.initial_setup and tostring(ctx.color.b) or nil,
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
            preview_h_box,
        },
        buttons_h_box,
    }
end)

function shared.rgb_show_gui_initial_setup(player)
    rgb_change_color_gui:show(player, {
        initial_setup = true,
    })
end

function shared.rgb_show_gui(player, item)
    local color = shared.rgb_get_color(item)
    if not color then
        shared.rgb_show_gui_initial_setup(player)
    else
        rgb_gui:show(player, {
            color = color,
        })
    end
end
