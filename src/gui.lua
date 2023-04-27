local shared = ...
local gui = flow.widgets
local S = minetest.get_translator("ggraffiti")

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

local available_sizes = {}
for size = 1, 5 do
    table.insert(available_sizes, size)
end

function shared.meta_get_size(meta)
    return tonumber(meta:get_string("ggraffiti_size")) or 1
end
function shared.meta_get_rgb_color(meta)
    return minetest.deserialize(meta:get_string("ggraffiti_rgb_color"))
end

local function update_item_description(item, meta)
    local spray_def = shared.get_raw_spray_def(item)

    local desc
    if spray_def.rgb then
        local color = shared.meta_get_rgb_color(meta)
        local color_block = minetest.colorize(minetest.colorspec_to_colorstring(color), "█")
        local size = shared.meta_get_size(meta)
        desc = item:get_short_description() .. "\n" ..
            S("Left-click to spray, right-click to configure.") .. "\n\n" ..
            S("Color: ") .. color_block .. S(" @1, @2, @3", color.r, color.g, color.b) .. "\n" ..
            S("Size: @1", size)
    else
        local size = shared.meta_get_size(meta)
        desc = item:get_short_description() .. "\n" ..
            S("Left-click to spray, right-click to configure.") .. "\n\n" ..
            S("Size: @1", size)
    end
    meta:set_string("description", desc)
end

local function meta_set_size(item, meta, size)
    meta:set_string("ggraffiti_size", tostring(size))
    update_item_description(item, meta)
end
local function meta_set_rgb_color(item, meta, color)
    meta:set_string("ggraffiti_rgb_color", minetest.serialize(color))
    update_item_description(item, meta)
end

local gui_configure
local gui_change_rgb_color
local gui_change_size

local function make_color_texture(color)
    local png = minetest.encode_png(1, 1, { color }, 9)
    return "[png:" .. minetest.encode_base64(png)
end

local function get_gui_experimental_str(player)
    -- MT orange
    -- https://github.com/minetest/minetest/blob/5.6.1/builtin/mainmenu/init.lua#L23
    return minetest.colorize("#ff8800", ServerS(player, "[Experimental]"))
end

local function get_gui_size_str(player, size)
    return size == 1 and ServerS(player, "1 pixel") or
        ServerS(player, "@1 pixels", size)
end

gui_configure = flow.make_gui(function(player, ctx)
    local built = gui.VBox {
        padding = 0.4,
        spacing = 0.4,
        gui.label { label = ServerSDouble(player, ctx.item_desc) },
    }
    if ctx.rgb_color then
        table.insert(built, gui.HBox {
            spacing = 0.4,
            gui.VBox {
                spacing = 0,
                expand = true,
                align_h = "left",
                gui.Label { label = ServerS(player, "Color") },
                gui.Label {
                    label = ServerS(player, "R: @1, G: @2, B: @3",
                        ctx.rgb_color.r, ctx.rgb_color.g, ctx.rgb_color.b),
                },
            },
            gui.Image {
                w = 0.8,
                h = 0.8,
                texture_name = make_color_texture(ctx.rgb_color),
            },
            gui.Button {
                label = ServerS(player, "Change"),
                on_event = function(player, ctx)
                    gui_change_rgb_color:show(player, {
                        item_name = ctx.item_name,
                        item_desc = ctx.item_desc,
                        rgb_color = ctx.rgb_color,
                        size = ctx.size,
                    })
                end,
            },
        })
    end
    table.insert(built, gui.HBox {
        spacing = 0.4,
        gui.VBox {
            spacing = 0,
            expand = true,
            align_h = "left",
            gui.Label {
                label = ServerS(player, "Size") .. " " .. get_gui_experimental_str(player),
            },
            gui.Label { label = get_gui_size_str(player, ctx.size) },
        },
        gui.Button {
            label = ServerS(player, "Change"),
            on_event = function(player, ctx)
                gui_change_size:show(player, {
                    item_name = ctx.item_name,
                    item_desc = ctx.item_desc,
                    rgb_color = ctx.rgb_color,
                    size = ctx.size,
                })
            end,
        },
    })
    return built
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
        rgb_color = ctx.rgb_color,
        size = ctx.size,
    })
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

local function change_rgb_color_save_button_on_event(player, ctx)
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
        on_event = change_rgb_color_save_button_on_event,
    })

    return gui.VBox {
        padding = 0.4,
        spacing = 0.4,
        gui.Label {
            label = ctx.initial_setup and
                ServerS(player, "Set Color") or
                ServerS(player, "Change Color"),
        },
        gui.HBox {
            spacing = 0.4,
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
        gui.Label { label = ServerS(player, "Values must be integers in the range [0..255].") },
        gui.VBox {
            spacing = 0,
            gui.Label { label = ServerS(player, "Preview") },
            preview_h_box,
        },
        buttons_h_box,
    }
end)

local function find_index(list, item)
    for l_idx, l_item in ipairs(list) do
        if l_item == item then
            return l_idx
        end
    end
end

local function change_size_save_button_on_event(player, ctx)
    local size = available_sizes[ctx.form.dropdown_size]

    if size then
        local item = player:get_wielded_item()
        if is_correct_item(ctx, item) then
            local meta = item:get_meta()
            meta_set_size(item, meta, size)
            player:set_wielded_item(item)

            gui_configure:show(player, {
                item_name = ctx.item_name,
                item_desc = ctx.item_desc,
                rgb_color = ctx.rgb_color,
                size = size,
            })
        end
    end
end

gui_change_size = flow.make_gui(function(player, ctx)
    local available_size_strs = {}
    for _, size in ipairs(available_sizes) do
        table.insert(available_size_strs, get_gui_size_str(player, size))
    end

    return gui.VBox {
        padding = 0.4,
        spacing = 0.4,
        gui.Label { label = ServerS(player, "Change Size") .. " " .. get_gui_experimental_str(player) },
        gui.Dropdown {
            name = "dropdown_size",
            items = available_size_strs,
            selected_idx = find_index(available_sizes, ctx.size),
            index_event = true,
        },
        gui.HBox {
            spacing = 0.4,
            gui.Button {
                label = ServerS(player, "Cancel"),
                expand = true,
                on_event = cancel_button_on_event,
            },
            gui.Button {
                label = ServerS(player, "Save"),
                expand = true,
                on_event = change_size_save_button_on_event,
            },
        },
    }
end)

function shared.gui_show_rgb_initial_setup(player, item, meta)
    gui_change_rgb_color:show(player, {
        initial_setup = true,
        item_name = item:get_name(),
        item_desc = item:get_short_description(),
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
        rgb_color = rgb_color,
        size = shared.meta_get_size(meta),
    })
end
