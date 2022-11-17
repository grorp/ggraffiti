if not modlib.minetest.get_node_selectionboxes then
    error(
        '\n' ..
        '────────────────────────────────────────────────────────────────────────────────────────────────────\n' ..
        'You have an outdated version of the "Modding Library" mod installed. ' ..
        'Please go to the "Content" tab and update the "Modding Library" mod.\n' ..
        '────────────────────────────────────────────────────────────────────────────────────────────────────\n',
        0
    )
end

local S = minetest.get_translator("ggraffiti")
local aabb = dofile(minetest.get_modpath("ggraffiti") .. "/aabb.lua")
dofile(minetest.get_modpath("ggraffiti") .. "/canvas.lua")

local SPRAY_DURATION = 4 * 60
-- Clients send the position of their player every 0.1 seconds.
-- https://github.com/minetest/minetest/blob/5.6.1/src/client/client.h#L563
-- https://github.com/minetest/minetest/blob/5.6.1/src/client/client.cpp#L528
local SPRAY_STEP_INTERVAL = 0.1
local NUM_SPRAY_STEPS = 5

local MAX_SPRAY_DISTANCE = 4

local TRANSPARENT = "#00000000"
-- The color of the pixel at (8, 9) in the dye texture.
local DYE_COLORS = {
    black = "#292929",
    blue = "#00519d",
    brown = "#6c3800",
    cyan = "#00959d",
    dark_green = "#2b7b00",
    dark_grey = "#494949",
    green = "#67eb1c",
    grey = "#9c9c9c",
    magenta = "#d80481",
    orange = "#e0601a",
    pink = "#ffa5a5",
    red = "#c91818",
    violet = "#480680",
    white = "#eeeeee",
    yellow = "#fcf611",
}

local player_lasts = {}

local function spraycast(player, pos, dir, def)
    local ray = minetest.raycast(pos, pos + dir * MAX_SPRAY_DISTANCE, true, false)
    local pthing
    for i_pthing in ray do
        if i_pthing.ref ~= player then
            pthing = i_pthing
            break
        end
    end
    if not pthing or pthing.type ~= "node" then return end

    local node_pos = pthing.under
    if minetest.is_protected(node_pos, player:get_player_name()) then
        minetest.record_protection_violation(node_pos, player:get_player_name())
        return
    end

    -- There is no such function. :(
    -- local raw_box = minetest.get_node_selection_boxes(pthing.under)[pthing.box_id]
    local raw_box = modlib.minetest.get_node_selectionboxes(pthing.under)[pthing.box_id]
    if not raw_box then return end -- Modlib failed 😱
    local box = aabb.from(raw_box)
    box:repair()
    local box_center = box:get_center()

    local canvas_rot = vector.dir_to_rotation(pthing.intersection_normal)
    local rot_box = aabb.new(
        box.pos_min:rotate(canvas_rot),
        box.pos_max:rotate(canvas_rot)
    )
    rot_box:repair()
    local rot_box_size = rot_box:get_size()

    local canvas_pos = node_pos + box_center + vector.new(0, 0, rot_box_size.z * 0.5 + 0.001):rotate(canvas_rot)
    local canvas

    local findings = minetest.get_objects_inside_radius(canvas_pos, 0.0001)
    for _, obj in ipairs(findings) do
        local ent = obj:get_luaentity()
        if ent and ent.name == "ggraffiti:canvas" then
            canvas = ent
            break
        end
    end

    if not canvas then
        if def.remover then return end

        local obj = minetest.add_entity(canvas_pos, "ggraffiti:canvas")
        obj:set_rotation(canvas_rot)
        canvas = obj:get_luaentity()
        canvas:setup({x = rot_box_size.x, y = rot_box_size.y})
    end

    local root_pos = node_pos + box_center + vector.new(0, 0, rot_box_size.z * 0.5):rotate(canvas_rot)
    local pointed_pos = pthing.intersection_point
    local distance = pointed_pos - root_pos

    local pos_on_face = vector.new(-distance.x, -distance.y, distance.z):rotate(canvas_rot) -- 2D (Z is always zero)
    pos_on_face = pos_on_face + vector.new(rot_box_size.x / 2, rot_box_size.y / 2, 0)

    local pos_on_bitmap = vector.new( -- 2D too, of course
        pos_on_face.x / rot_box_size.x * canvas.bitmap_size.x,
        pos_on_face.y / rot_box_size.y * canvas.bitmap_size.y,
        0
    )

    local rect_size = 3
    local rect_x, rect_y =
        math.round(pos_on_bitmap - rect_size / 2),
        math.round(pos_on_bitmap - rect_size / 2)

    if def.remover then
        canvas:rectangle(rect_x, rect_y, rect_size, rect_size, TRANSPARENT)
        if canvas:is_empty() then
            canvas.object:remove()
        else
            canvas:update()
        end
    else
        canvas:rectangle(rect_x, rect_y, rect_size, rect_size, def.color)
        canvas:update()
    end
end

local function wear_out(item, uses)
    for i = 1, uses do
        item:add_wear_by_uses(SPRAY_DURATION / SPRAY_STEP_INTERVAL * NUM_SPRAY_STEPS)
        if item:is_empty() then
            return ItemStack("ggraffiti:spray_can_empty"), i
        end
    end
    return item, uses
end

local function spray_can_on_use(item, player)
    local player_name = player:get_player_name()

    local pos = player:get_pos()
    pos.y = pos.y + player:get_properties().eye_height
    local dir = player:get_look_dir()
    spraycast(player, pos, dir, item:get_definition()._ggraffiti_spray_can)
    player_lasts[player_name] = {pos = pos, dir = dir}

    if not minetest.is_creative_enabled(player_name) then
        item = wear_out(item, 1)
        return item
    end
end

minetest.register_craftitem("ggraffiti:spray_can_empty", { -- stackable
    description = S("Empty Spray Can"),
    inventory_image = "ggraffiti_spray_can.png",

    range = MAX_SPRAY_DISTANCE,
    on_use = function() end,

    groups = {ggraffiti_spray_can = 1},
})

for _, dye in ipairs(dye.dyes) do
    local dye_name, dye_desc = unpack(dye)
    local dye_color = DYE_COLORS[dye_name]

    local item_name = "ggraffiti:spray_can_" .. dye_name

    minetest.register_tool(item_name, {
        description = S("Graffiti Spray Can (" .. dye_desc:lower() .. ")"),
        inventory_image = "ggraffiti_spray_can.png^(ggraffiti_spray_can_color.png^[multiply:" .. dye_color .. ")",

        range = MAX_SPRAY_DISTANCE,
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

    range = MAX_SPRAY_DISTANCE,
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

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function spray_step()
    for _, player in ipairs(minetest.get_connected_players()) do
        local player_name = player:get_player_name()

        if player:get_player_control().dig then
            local item = player:get_wielded_item()
            local def = item:get_definition()

            if def._ggraffiti_spray_can then
                local last = player_lasts[player_name]

                local now_pos = player:get_pos()
                now_pos.y = now_pos.y + player:get_properties().eye_height
                local now_dir = player:get_look_dir()

                if last then
                    local n_steps = NUM_SPRAY_STEPS
                    if not minetest.is_creative_enabled(player_name) then
                        item, n_steps = wear_out(item, n_steps)
                        player:set_wielded_item(item)
                    end

                    if now_pos:equals(last.pos) and now_dir:equals(last.dir) then
                        -- The player hasn't moved, but the world may have changed.
                        spraycast(player, now_pos, now_dir, def._ggraffiti_spray_can)
                    else
                        for step_n = 1, n_steps do
                            local combine_lerp = function(a, b)
                                return lerp(a, b, step_n / n_steps)
                            end
                            local pos = vector.combine(last.pos, now_pos, combine_lerp)
                            local dir = vector.combine(last.dir, now_dir, combine_lerp):normalize()

                            spraycast(player, pos, dir, def._ggraffiti_spray_can)
                        end
                    end
                end

                player_lasts[player_name] = {pos = now_pos, dir = now_dir}
            else
                player_lasts[player_name] = nil
            end
        else
            player_lasts[player_name] = nil
        end
    end
end

local dtime_accu = 0

minetest.register_globalstep(function(dtime)
    dtime_accu = dtime_accu + dtime
    if dtime_accu >= SPRAY_STEP_INTERVAL then
        dtime_accu = dtime_accu % SPRAY_STEP_INTERVAL
        spray_step()
    end
end)
