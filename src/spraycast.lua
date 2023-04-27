local shared = ...

local is_protected_cache = {}
local get_node_selectionboxes_cache = {}

local function is_protected_cached(pos, player_name)
    local key = pos.x .. ":" .. pos.y .. ":" .. pos.z .. ":" .. player_name
    local result = is_protected_cache[key]
    if result ~= nil then
        return result
    end

    local new_result = minetest.is_protected(pos, player_name)
    if new_result then
        minetest.record_protection_violation(pos, player_name)
    end
    is_protected_cache[key] = new_result
    return new_result
end

local function get_node_selectionboxes_cached(pos)
    local key = pos.x .. ":" .. pos.y .. ":" .. pos.z
    local result = get_node_selectionboxes_cache[key]
    if result ~= nil then
        return result
    end

    -- There is no such function :(
    -- local new_result = minetest.get_node_selection_boxes(pos)
    local new_result = modlib.minetest.get_node_selectionboxes(pos)
    get_node_selectionboxes_cache[key] = new_result
    return new_result
end

local function calc_bitmap_size(canvas_size)
    return { -- minimum 1x1 pixels
        x = math.max(math.round(canvas_size.x / shared.DESIRED_PIXEL_SIZE), 1),
        y = math.max(math.round(canvas_size.y / shared.DESIRED_PIXEL_SIZE), 1),
    }
end

local function find_canvas(pos)
    local findings = minetest.get_objects_inside_radius(pos, shared.EPSILON)

    for _, obj in ipairs(findings) do
        local ent = obj:get_luaentity()
        if ent and ent.name == "ggraffiti:canvas" then
            return ent
        end
    end
end

local function create_canvas(node_pos, pos, rot, size, bitmap_size)
    local obj = minetest.add_entity(pos, "ggraffiti:canvas")
    if not obj then return end
    obj:set_rotation(rot)

    local canvas = obj:get_luaentity()
    canvas:setup(node_pos, size, bitmap_size)
    canvas:update_immediately() -- Avoid flash of "no texture" texture.
    return canvas
end

local function vec_to_canvas_space(vec, canvas_rot)
    return vector.new(-vec.x, -vec.y, vec.z):rotate(canvas_rot)
end

local draw_rect, spread_rect, spread_rect_to_node, spread_rect_to_box

function shared.spraycast(player, pos, dir, def)
    local ray = minetest.raycast(pos, pos + dir * shared.MAX_SPRAY_DISTANCE, true, false)
    local pthing
    for i_pthing in ray do
        if i_pthing.ref ~= player then
            pthing = i_pthing
            break
        end
    end
    if not pthing or pthing.type ~= "node" then return end

    local node_pos = pthing.under
    local player_name = player:get_player_name()
    if is_protected_cached(node_pos, player_name) then
        return
    end

    local raw_box = get_node_selectionboxes_cached(pthing.under)[pthing.box_id]
    if not raw_box then return end -- Modlib failed 😱
    local box = shared.aabb.from(raw_box)
    box:repair()
    local box_center = box:get_center()

    local canvas_rot = vector.dir_to_rotation(pthing.intersection_normal)
    local rot_box = shared.aabb.new(
        box.pos_min:rotate(canvas_rot),
        box.pos_max:rotate(canvas_rot)
    )
    rot_box:repair()
    local rot_box_size = rot_box:get_size()

    local canvas_pos = node_pos + box_center + vector.new(0, 0, rot_box_size.z * 0.501):rotate(canvas_rot)

    -- TODO: Only create canvases if we're not currently removing graffiti
    -- (probably requires a major refactor of the rectangle spreading code)
    -- (Update: The major refactor is done now 🎉)
    local canvas = find_canvas(canvas_pos)
    if not canvas and not (def.remover and def.size == 1) then
        local canvas_size = { x = rot_box_size.x, y = rot_box_size.y }
        local bitmap_size = calc_bitmap_size(canvas_size)
        canvas = create_canvas(
            node_pos, canvas_pos, canvas_rot, canvas_size, bitmap_size)
    end
    if not canvas then return end

    local root_pos = node_pos + box_center + vector.new(0, 0, rot_box_size.z * 0.5):rotate(canvas_rot)
    local pointed_pos = pthing.intersection_point
    local distance = pointed_pos - root_pos

    -- 2D (Z is always zero)
    local pos_on_canvas = vector.new(rot_box_size.x / 2, rot_box_size.y / 2, 0) +
        vec_to_canvas_space(distance, canvas_rot)

    local pos_on_bitmap_x = pos_on_canvas.x / rot_box_size.x * canvas.bitmap_size.x
    local pos_on_bitmap_y = pos_on_canvas.y / rot_box_size.y * canvas.bitmap_size.y

    local color = def.remover and shared.TRANSPARENT or def.color

    if def.size == 1 then
        local index = math.floor(pos_on_bitmap_y) * canvas.bitmap_size.x + math.floor(pos_on_bitmap_x) + 1

        if canvas.bitmap[index] ~= color then
            canvas.bitmap[index] = color

            if def.remover and canvas:is_empty() then
                canvas.object:remove()
            else
                canvas:update_later()
            end
        end
    else
        draw_rect(canvas, {
            player = player,
            self_node_pos = node_pos,
            self_root_pos = root_pos,
            self_rot = canvas_rot,
            self_size = canvas.size,
            skip_box_index = pthing.box_id,

            x = math.round(pos_on_bitmap_x - def.size / 2),
            y = math.round(pos_on_bitmap_y - def.size / 2),
            width = def.size,
            height = def.size,
            color = color,
            remover = def.remover,
        })

        if def.remover and canvas:is_empty() then
            canvas.object:remove()
        else
            canvas:update_later()
        end
    end

    -- shared.profiler_someone_spraying = true
end

local function clamp(val, min, max)
    return math.min(math.max(val, min), max)
end

draw_rect = function(canvas, props, do_not_spread)
    local x1_tgt, y1_tgt =
        props.x,
        props.y
    local x2_tgt, y2_tgt =
        props.x + props.width - 1,
        props.y + props.height - 1

    local max_x = canvas.bitmap_size.x - 1
    local max_y = canvas.bitmap_size.y - 1
    local x1, y1 =
        clamp(x1_tgt, 0, max_x),
        clamp(y1_tgt, 0, max_y)
    local x2, y2 =
        clamp(x2_tgt, 0, max_x),
        clamp(y2_tgt, 0, max_y)

    for xx = x1, x2 do
        for yy = y1, y2 do
            canvas.bitmap[yy * canvas.bitmap_size.x + xx + 1] = props.color
        end
    end

    if not do_not_spread and
            (x1 ~= x1_tgt or y1 ~= y1_tgt or x2 ~= x2_tgt or y2 ~= y2_tgt) then
        spread_rect(props)
    end
end

local spread_node_offsets = {
    vector.new(-1, -1, 0),
    vector.new(-1, 0, 0),
    vector.new(-1, 1, 0),
    vector.new(0, -1, 0),
    vector.new(0, 0, 0),
    vector.new(0, 1, 0),
    vector.new(1, -1, 0),
    vector.new(1, 0, 0),
    vector.new(1, 1, 0),
}

spread_rect = function(props)
    local self_node_pos = props.self_node_pos
    local self_rot = props.self_rot
    local self_root_pos_canvas = vec_to_canvas_space(props.self_root_pos, self_rot)

    for _, offset in ipairs(spread_node_offsets) do
        local other_node_pos = self_node_pos + offset:rotate(self_rot)
        spread_rect_to_node(props, self_root_pos_canvas, other_node_pos)
    end
end

spread_rect_to_node = function(props, self_root_pos_canvas, other_node_pos)
    local player_name = props.player:get_player_name()
    if is_protected_cached(other_node_pos, player_name) then
        return
    end

    local is_same_node = other_node_pos == props.self_node_pos
    local raw_boxes = get_node_selectionboxes_cached(other_node_pos)

    for index, raw_box in ipairs(raw_boxes) do
        if not is_same_node or index ~= props.skip_box_index then
            spread_rect_to_box(props, self_root_pos_canvas, other_node_pos, raw_box)
        end
    end
end

local function nearly_equal(a, b)
    return math.abs(a - b) < shared.EPSILON
end

spread_rect_to_box = function(props, self_root_pos_canvas, other_node_pos, raw_box)
    local box = shared.aabb.from(raw_box)
    box:repair()
    local box_center = box:get_center()

    local self_rot = props.self_rot
    local rot_box = shared.aabb.new(
        box.pos_min:rotate(self_rot),
        box.pos_max:rotate(self_rot)
    )
    rot_box:repair()
    local rot_box_size = rot_box:get_size()

    local other_root_pos = other_node_pos + box_center + vector.new(0, 0, rot_box_size.z * 0.5):rotate(self_rot)
    local other_root_pos_canvas = vec_to_canvas_space(other_root_pos, self_rot)
    if not nearly_equal(self_root_pos_canvas.z, other_root_pos_canvas.z) then
        return
    end

    local self_size_vec = vector.new(props.self_size.x, props.self_size.y, 0)
    -- The Z value of this vector is never used.
    local canvas_offset = (self_root_pos_canvas - self_size_vec / 2) -
        (other_root_pos_canvas - rot_box_size / 2)
    local bitmap_offset_x = math.round(canvas_offset.x / shared.DESIRED_PIXEL_SIZE)
    local bitmap_offset_y = math.round(canvas_offset.y / shared.DESIRED_PIXEL_SIZE)

    local new_x = bitmap_offset_x + props.x
    local new_y = bitmap_offset_y + props.y

    local bitmap_size = calc_bitmap_size(rot_box_size)
    if new_x + props.width - 1 < 0 or
            new_y + props.height - 1 < 0 or
            new_x > bitmap_size.x - 1 or
            new_y > bitmap_size.y - 1 then
        return
    end

    local other_pos = other_node_pos + box_center + vector.new(0, 0, rot_box_size.z * 0.501):rotate(self_rot)

    local canvas = find_canvas(other_pos)
    if not canvas and not props.remover then
        local other_size = { x = rot_box_size.x, y = rot_box_size.y }
        canvas = create_canvas(
            other_node_pos, other_pos, props.self_rot, other_size, bitmap_size)
    end
    if not canvas then return end

    local lessprops_new = {
        x = new_x,
        y = new_y,
        width = props.width,
        height = props.height,
        color = props.color,
    }
    draw_rect(canvas, lessprops_new, true)
    if props.remover and canvas:is_empty() then
        canvas.object:remove()
    else
        canvas:update_later()
    end
end

function shared.after_spraycasts()
    shared.update_canvases()
    is_protected_cache = {}
    get_node_selectionboxes_cache = {}
end
