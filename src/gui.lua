local shared = ...
local gui = flow.widgets
local S = minetest.get_translator("ggraffiti")

local FORMSPEC_MIN_WIDTH = 7
-- named as in the Minetest Modding Book
local FORMSPEC_PADDING = 0.4
local FORMSPEC_SPACING = 0.25
local FORMSPEC_LOWSPACING = 0.1

-- In formspecs, I use server-side translations so that the layout of the
-- formspecs can adapt to the length of the translated strings.
local function ServerSDouble(player, string)
    local player_name = player:get_player_name()
    local lang_code = minetest.get_player_information(player_name).lang_code
    return minetest.get_translated_string(lang_code, string)
end
local function ServerS(player, string, ...)
    return ServerSDouble(player, S(string, ...))
end

function shared.get_raw_spray_def(item)
    local def = item:get_definition()
    return def and def._ggraffiti_spray_can
end

function shared.meta_get_size(meta)
    return tonumber(meta:get_string("ggraffiti_size")) or 1
end
function shared.meta_get_rgb_color(meta)
    return minetest.deserialize(meta:get_string("ggraffiti_rgb_color"))
end

local function update_item_meta(item, meta)
    local spray_def = shared.get_raw_spray_def(item)

    local size = shared.meta_get_size(meta)
    meta:set_string("count_meta",      size == 1 and "" or tostring(size))
    meta:set_string("count_alignment", size == 1 and "" or "13") -- 1 + 3 * 4
    if spray_def.rgb then
        local color = shared.meta_get_rgb_color(meta)
        local color_str = minetest.colorspec_to_colorstring(color)
        local color_block = minetest.colorize(color_str, "█")

        meta:set_string("description",
            item:get_short_description() .. "\n" ..
            S("Left-click to spray, right-click to configure.") .. "\n\n" ..
            S("Color: ") .. color_block .. S(" @1, @2, @3", color.r, color.g, color.b) .. "\n" ..
            S("Size: @1", size)
        )
        -- 5.8.0-dev feature
        meta:set_string("inventory_image", shared.get_colored_can_texmod(color_str))
    else
        meta:set_string("description",
            item:get_short_description() .. "\n" ..
            S("Left-click to spray, right-click to configure.") .. "\n\n" ..
            S("Size: @1", size)
        )
    end
end

local function meta_set_size(item, meta, size)
    meta:set_string("ggraffiti_size", tostring(size))
    update_item_meta(item, meta)
end
local function meta_set_rgb_color(item, meta, color)
    meta:set_string("ggraffiti_rgb_color", minetest.serialize(color))
    update_item_meta(item, meta)
end

local gui_configure
local gui_change_rgb_color

local function get_color(item_name)
    local hex = minetest.registered_items[item_name]._ggraffiti_spray_can.color
    if not hex then return end
    local r, g, b = hex:sub(2):match("(..)(..)(..)")
    return { r = tonumber(r, 16), g = tonumber(g, 16), b = tonumber(b, 16) }
end

local function make_color_texture(color)
    local png = minetest.encode_png(1, 1, { color }, 9)
    return "[png:" .. minetest.encode_base64(png)
end

local function is_correct_item(ctx, item)
    if ctx.item_name ~= item:get_name() then
        return false
    end

    local meta = item:get_meta()
    local rgb_color = shared.meta_get_rgb_color(meta)
    if not (ctx.rgb_color == nil and rgb_color == nil) and
            not (ctx.rgb_color ~= nil and rgb_color ~= nil and
            ctx.rgb_color.r == rgb_color.r and
            ctx.rgb_color.g == rgb_color.g and
            ctx.rgb_color.b == rgb_color.b) then
        return false
    end

    local size = shared.meta_get_size(meta)
    if ctx.size ~= size then
        return false
    end

    return true
end

local function make_size_button(selected_size, size)
    if size == selected_size then
        -- centering won't work without the gui.Stack ¯\_(ツ)_/¯
        return gui.Stack {
            -- prevent MineClone 2 formspec_prepend from interfering with Flow's
            -- centering hack
            gui.StyleType {
                selectors = { "image_button", "image_button:pressed" },
                props = {
                    bgimg = "",
                    bgimg_pressed = "",
                },
            },
            gui.Label {
                w = 0.8,
                h = 0.8,
                label = tostring(size),
                align_h = "centre",
            },
        }
    end

    return gui.Button {
        w = 0.8,
        label = tostring(size),
        on_event = function(player, ctx)
            local item = player:get_wielded_item()

            if is_correct_item(ctx, item) then
                local meta = item:get_meta()
                meta_set_size(item, meta, size)
                player:set_wielded_item(item)

                gui_configure:show(player, {
                    item_name = ctx.item_name,
                    item_desc = ctx.item_desc,
                    is_rgb = ctx.is_rgb,
                    rgb_color = ctx.rgb_color,
                    size = size,
                })
            end
        end,
    }
end

gui_configure = flow.make_gui(function(player, ctx)
    local color = ctx.is_rgb and ctx.rgb_color or get_color(ctx.item_name)

    return gui.VBox {
        min_w = FORMSPEC_MIN_WIDTH,
        padding = FORMSPEC_PADDING,
        spacing = FORMSPEC_PADDING,

        gui.label { label = ServerSDouble(player, ctx.item_desc) },
        color and gui.HBox {
            spacing = FORMSPEC_SPACING,
            gui.VBox {
                spacing = 0,
                expand = true,
                align_h = "left",
                gui.Label { label = ServerS(player, "Color") },
                gui.Label {
                    label = ServerS(player, "R: @1, G: @2, B: @3",
                        color.r, color.g, color.b),
                },
            },
            gui.Image {
                w = 0.8,
                h = 0.8,
                texture_name = make_color_texture(color),
            },
            ctx.is_rgb and gui.Button {
                label = ServerS(player, "Change"),
                on_event = function(player, ctx)
                    gui_change_rgb_color:show(player, {
                        item_name = ctx.item_name,
                        item_desc = ctx.item_desc,
                        is_rgb = ctx.is_rgb,
                        rgb_color = ctx.rgb_color,
                        size = ctx.size,
                    })
                end,
            } or gui.Nil {},
        } or gui.Nil {},
        gui.HBox {
            spacing = FORMSPEC_SPACING,
            gui.Label {
                label = ServerS(player, "Size"),
                expand = true,
                align_h = "left",
            },
            gui.HBox {
                spacing = FORMSPEC_LOWSPACING,
                make_size_button(ctx.size, 1),
                make_size_button(ctx.size, 2),
                make_size_button(ctx.size, 3),
                (ctx.size ~= 1 and ctx.size ~= 2 and ctx.size ~= 3) and
                    make_size_button(ctx.size, ctx.size) or gui.Nil {},
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
    gui_configure:show(player, {
        item_name = ctx.item_name,
        item_desc = ctx.item_desc,
        is_rgb = ctx.is_rgb,
        rgb_color = ctx.rgb_color,
        size = ctx.size,
    })
end

local function save_button_on_event(player, ctx)
    -- We have to do this again here because this callback isn't
    -- always called after the others.
    ctx.form.field_r = adjust_field_value(ctx.form.field_r)
    ctx.form.field_g = adjust_field_value(ctx.form.field_g)
    ctx.form.field_b = adjust_field_value(ctx.form.field_b)

    local item = player:get_wielded_item()
    if is_correct_item(ctx, item) then
        local rgb_color = {
            r = tonumber(ctx.form.field_r),
            g = tonumber(ctx.form.field_g),
            b = tonumber(ctx.form.field_b),
        }
        local meta = item:get_meta()
        meta_set_rgb_color(item, meta, rgb_color)
        player:set_wielded_item(item)

        gui_configure:show(player, {
            item_name = ctx.item_name,
            item_desc = ctx.item_desc,
            is_rgb = ctx.is_rgb,
            rgb_color = rgb_color,
            size = ctx.size,
        })
    end
end

gui_change_rgb_color = flow.make_gui(function(player, ctx)
    local has_input_color = not not (ctx.form.field_r and ctx.form.field_g and ctx.form.field_b)
    local has_default_color = not ctx.initial_setup
    local png_color
    if has_input_color or has_default_color then
        png_color = {
            r = has_input_color and tonumber(ctx.form.field_r) or ctx.rgb_color.r,
            g = has_input_color and tonumber(ctx.form.field_g) or ctx.rgb_color.g,
            b = has_input_color and tonumber(ctx.form.field_b) or ctx.rgb_color.b,
        }
    end

    return gui.VBox {
        min_w = FORMSPEC_MIN_WIDTH,
        padding = FORMSPEC_PADDING,
        spacing = FORMSPEC_PADDING,

        gui.Label {
            label = ctx.initial_setup and
                ServerS(player, "Set Color") or
                ServerS(player, "Change Color"),
        },
        gui.VBox {
            spacing = FORMSPEC_LOWSPACING,
            gui.HBox {
                spacing = FORMSPEC_SPACING,
                gui.Field {
                    name = "field_r",
                    label = minetest.colorize("#f00", ServerS(player, "R (Red)")),
                    default = not ctx.initial_setup and tostring(ctx.rgb_color.r) or nil,
                    expand = true,
                    on_event = function(player, ctx)
                        ctx.form.field_r = adjust_field_value(ctx.form.field_r)
                        return true
                    end,
                },
                gui.Field {
                    name = "field_g",
                    label = minetest.colorize("#0f0", ServerS(player, "G (Green)")),
                    default = not ctx.initial_setup and tostring(ctx.rgb_color.g) or nil,
                    expand = true,
                    on_event = function(player, ctx)
                        ctx.form.field_g = adjust_field_value(ctx.form.field_g)
                        return true
                    end,
                },
                gui.Field {
                    name = "field_b",
                    label = minetest.colorize("#00f", ServerS(player, "B (Blue)")),
                    default = not ctx.initial_setup and tostring(ctx.rgb_color.b) or nil,
                    expand = true,
                    on_event = function(player, ctx)
                        ctx.form.field_b = adjust_field_value(ctx.form.field_b)
                        return true
                    end,
                },
            },
            gui.Label { label = ServerS(player, "Values must be integers between 0 and 255.") },
        },
        gui.VBox {
            spacing = 0,
            gui.Label { label = ServerS(player, "Preview") },
            gui.HBox {
                spacing = FORMSPEC_SPACING,
                png_color and gui.Image {
                    w = 0.8,
                    h = 0.8,
                    expand = true,
                    align_h = "fill",
                    texture_name = make_color_texture(png_color),
                } or gui.Nil {},
                gui.Button {
                    label = ServerS(player, "Update"),
                    expand = not png_color or nil,
                    align_h = not png_color and "right" or nil,
                    -- no on_event needed
                },
            },
        },
        gui.HBox {
            spacing = FORMSPEC_SPACING,
            ctx.initial_setup and gui.Nil {} or gui.Button {
                label = ServerS(player, "Cancel"),
                expand = true,
                on_event = cancel_button_on_event,
            },
            gui.Button {
                label = ServerS(player, "Save"),
                expand = true,
                on_event = save_button_on_event,
            },
        },
    }
end)

function shared.gui_show_rgb_initial_setup(player, item, meta)
    gui_change_rgb_color:show(player, {
        initial_setup = true,
        item_name = item:get_name(),
        item_desc = item:get_short_description(),
        is_rgb = true,
        size = shared.meta_get_size(meta),
    })
end

function shared.gui_show_configure(player, item, meta)
    local spray_def = shared.get_raw_spray_def(item)
    local rgb_color = shared.meta_get_rgb_color(meta)
    if spray_def.rgb and not rgb_color then
        shared.gui_show_rgb_initial_setup(player, item, meta)
        return
    end
    gui_configure:show(player, {
        item_name = item:get_name(),
        item_desc = item:get_short_description(),
        is_rgb = spray_def.rgb,
        rgb_color = rgb_color,
        size = shared.meta_get_size(meta),
    })
end
