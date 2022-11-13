if not modlib.minetest.get_node_selectionboxes then
    error(
        '\n' ..
        '────────────────────────────────────────────────────────────────────────────────────────────────────\n' ..
        'You have an outdated version of the "Modding Library" mod installed. Please go to the "Content" tab and update the "Modding Library" mod.\n' ..
        '────────────────────────────────────────────────────────────────────────────────────────────────────\n',
        0
    )
end

local S = minetest.get_translator("ggraffiti")
local aabb = dofile(minetest.get_modpath("ggraffiti") .. "/aabb.lua")
dofile(minetest.get_modpath("ggraffiti") .. "/canvas.lua")

local SPRAY_DURATION = 240
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

local function get_canvas(pos, box, face_normal)
    local box_center = box:get_center()

    local canvas_rot = vector.dir_to_rotation(face_normal)
    local rot_box = aabb.new(
        box.pos_min:rotate(canvas_rot),
        box.pos_max:rotate(canvas_rot)
    )
    rot_box:repair()
    local rot_box_size = rot_box:get_size()

    local canvas_pos = pos +
        box_center +
        vector.new(0, 0, rot_box_size.z * 0.5 + 0.001):rotate(canvas_rot)

    local objs = minetest.get_objects_inside_radius(canvas_pos, 0.001)
    for _, obj in ipairs(objs) do
        local ent = obj:get_luaentity()
        if ent and ent.name == "ggraffiti:canvas" then
            return ent
        end
    end
end

local function create_canvas(pos, box, face_normal)
    local box_center = box:get_center()

    local canvas_rot = vector.dir_to_rotation(face_normal)
    local rot_box = aabb.new(
        box.pos_min:rotate(canvas_rot),
        box.pos_max:rotate(canvas_rot)
    )
    rot_box:repair()
    local rot_box_size = rot_box:get_size()

    local canvas_pos = pos +
        box_center +
        vector.new(0, 0, rot_box_size.z * 0.5 + 0.001):rotate(canvas_rot)

    local obj = minetest.add_entity(canvas_pos, "ggraffiti:canvas")
    obj:set_rotation(canvas_rot)
    local ent = obj:get_luaentity()
    ent:setup({x = rot_box_size.x, y = rot_box_size.y})
    return ent
end

local function get_point_on_canvas(pos, box, face_normal, point)
    local box_center = box:get_center()

    local canvas_rot = vector.dir_to_rotation(face_normal)
    local rot_box = aabb.new(
        box.pos_min:rotate(canvas_rot),
        box.pos_max:rotate(canvas_rot)
    )
    rot_box:repair()
    local rot_box_size = rot_box:get_size()

    local root_pos = pos +
        box_center +
        vector.new(0, 0, rot_box_size.z * 0.5):rotate(canvas_rot)

    local distance = point - root_pos

    -- 2D (Z is always zero)
    return vector.new(-distance.x, -distance.y, distance.z):rotate(canvas_rot) +
        vector.new(rot_box_size.x / 2, rot_box_size.y / 2, 0)
end

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

    local pos = pthing.under
    if minetest.is_protected(pos, player:get_player_name()) then
        minetest.record_protection_violation(pos, player:get_player_name())
        return
    end

    -- There is no such function. :(
    -- local raw_box = minetest.get_node_selection_boxes(pthing.under)[pthing.box_id]
    local raw_box = modlib.minetest.get_node_selectionboxes(pthing.under)[pthing.box_id]
    if not raw_box then return end -- Modlib failed 😱
    local box = aabb.from(raw_box)

    local canvas = get_canvas(pos, box, pthing.intersection_normal)
    if not canvas then
        if def.anti then return end
        canvas = create_canvas(pos, box, pthing.intersection_normal)
    end

    local point = get_point_on_canvas(
        pos, box, pthing.intersection_normal, pthing.intersection_point)
    local pixel = vector.new(
        math.floor(point.x / canvas.size.x * canvas.bitmap_size.x),
        math.floor(point.y / canvas.size.y * canvas.bitmap_size.y),
        0
    )
    local index = pixel.y * canvas.bitmap_size.x + pixel.x + 1

    if def.anti then
        if canvas.bitmap[index] ~= TRANSPARENT then
            canvas.bitmap[index] = TRANSPARENT
            if canvas:is_empty() then
                canvas.object:remove()
            else
                canvas:update()
            end
        end
    else
        if canvas.bitmap[index] ~= def.color then
            canvas.bitmap[index] = def.color
            canvas:update()
        end
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

minetest.register_tool("ggraffiti:spray_can_anti", {
    description = S("Anti-Graffiti Spray Can"),
    inventory_image = "ggraffiti_spray_can_anti.png",

    range = MAX_SPRAY_DISTANCE,
    on_use = spray_can_on_use,
    _ggraffiti_spray_can = {
        anti = true,
    },

    groups = {ggraffiti_spray_can = 1},
})

minetest.register_craft({
    recipe = {
        {"default:steel_ingot"},
        {"ggraffiti:mushroom_red_extract"},
        {"default:steel_ingot"},
    },
    output = "ggraffiti:spray_can_anti",
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
