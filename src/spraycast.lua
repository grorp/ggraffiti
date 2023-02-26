local shared = ...

function shared.spraycast(player, pos, dir, def)
    def = {
        -- Somehow it doesn't work (= crashes) with tables.
        color = minetest.colorspec_to_colorstring(def),
    }

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
    if minetest.is_protected(node_pos, player:get_player_name()) then
        minetest.record_protection_violation(node_pos, player:get_player_name())
        return
    end

    -- There is no such function. :(
    -- local raw_box = minetest.get_node_selection_boxes(pthing.under)[pthing.box_id]
    local raw_box = modlib.minetest.get_node_selectionboxes(pthing.under)[pthing.box_id]
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
        canvas:setup(node_pos, {x = rot_box_size.x, y = rot_box_size.y})
        canvas:update_immediately() -- Avoid flash of "no texture" texture.
    end

    local root_pos = node_pos + box_center + vector.new(0, 0, rot_box_size.z * 0.5):rotate(canvas_rot)
    local pointed_pos = pthing.intersection_point
    local distance = pointed_pos - root_pos

    local pos_on_face = vector.new(-distance.x, -distance.y, distance.z):rotate(canvas_rot) -- 2D (Z is always zero)
    pos_on_face = pos_on_face + vector.new(rot_box_size.x / 2, rot_box_size.y / 2, 0)

    local pos_on_bitmap = vector.new( -- 2D too, of course
        math.floor(pos_on_face.x / rot_box_size.x * canvas.bitmap_size.x),
        math.floor(pos_on_face.y / rot_box_size.y * canvas.bitmap_size.y),
        0
    )
    local index = pos_on_bitmap.y * canvas.bitmap_size.x + pos_on_bitmap.x + 1

    if def.remover then
        if canvas.bitmap[index] ~= shared.TRANSPARENT then
            canvas.bitmap[index] = shared.TRANSPARENT
            if canvas:is_empty() then
                canvas.object:remove()
            else
                canvas:update_later()
            end
        end
    else
        if canvas.bitmap[index] ~= def.color then
            canvas.bitmap[index] = def.color
            canvas:update_later()
        end
    end
end
