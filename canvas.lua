local DESIRED_PIXEL_SIZE = 1/16
local TRANSPARENT = "#00000000"

local aabb = dofile(minetest.get_modpath("ggraffiti") .. "/aabb.lua")

local canvas = {}

function canvas.get(pos, box, face_normal)
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

function canvas.create(pos, box, face_normal)
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

function canvas.transform_point(pos, box, face_normal, point)
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

local CanvasEntity = {
    initial_properties = {
        visual = "upright_sprite",
        pointable = false,
        physical = false,
    },
}

local function validate_staticdata(data)
    return
        type(data) == "table" and
        type(data.size) == "table" and
        type(data.size.x) == "number" and
        type(data.size.y) == "number" and
        type(data.bitmap_size) == "table" and
        type(data.bitmap_size.x) == "number" and
        type(data.bitmap_size.y) == "number" and
        type(data.bitmap) == "table" and
        #data.bitmap == data.bitmap_size.x * data.bitmap_size.y
end

function CanvasEntity:on_activate(staticdata)
    self.object:set_armor_groups({immortal = 1})

    -- https://github.com/minetest/minetest/blob/5.6.1/src/script/cpp_api/s_entity.cpp#L77-L104
    assert(type(staticdata) == "string")

    if staticdata ~= "" then
        local data = minetest.deserialize(staticdata)

        if not validate_staticdata(data) then
            -- This should never happen.
            local p = self.object:get_pos():to_string()
            self.object:remove()
            minetest.log("warning",
                "Removed ggraffiti:canvas entity at " .. p .. " in on_activate because of invalid staticdata")
            return
        end

        self.size = data.size
        self.bitmap_size = data.bitmap_size
        self.bitmap = data.bitmap
        self:update()
    end
end

function CanvasEntity:setup(size)
    self.size = size
    self.bitmap_size = {
        x = math.max(math.round(self.size.x / DESIRED_PIXEL_SIZE), 1), -- minimum 1x1 pixels
        y = math.max(math.round(self.size.y / DESIRED_PIXEL_SIZE), 1),
    }
    self.bitmap = {}
    for i = 1, self.bitmap_size.x * self.bitmap_size.y do
        self.bitmap[i] = TRANSPARENT
    end
end

function CanvasEntity:update()
    local png = minetest.encode_base64(
        minetest.encode_png(self.bitmap_size.x, self.bitmap_size.y, self.bitmap, 9)
    )
    self.object:set_properties({
        visual_size = vector.new(self.size.x, self.size.y, 0),
        textures = {
            "[png:" .. png,
            "[png:" .. png .. "^[transformFX",
            -- "ggraffiti_debug_coordinates.png^([png:" .. png .. "^[resize:128x128)",
            -- "ggraffiti_debug_coordinates.png^([png:" .. png .. "^[resize:128x128)^[transformFX",
        },
    })
end

local function clamp(min, val, max) return math.max(min, math.min(val, max)) end

function CanvasEntity:rectangle(x, y, width, height, color)
    local x1, y1 =
        clamp(0, x, self.bitmap_size.x - 1),
        clamp(0, y, self.bitmap_size.y - 1)
    local x2, y2 =
        clamp(0, x + width - 1, self.bitmap_size.x - 1),
        clamp(0, y + height - 1, self.bitmap_size.y - 1)
    for xx = x1, x2 do
        for yy = y1, y2 do
            self.bitmap[yy * self.bitmap_size.x + xx + 1] = color
        end
    end
end

function CanvasEntity:is_empty()
    for _, c in ipairs(self.bitmap) do
        if c ~= TRANSPARENT then
            return false
        end
    end
    return true
end

function CanvasEntity:get_staticdata()
    return minetest.serialize({
        size = self.size,
        bitmap_size = self.bitmap_size,
        bitmap = self.bitmap,
    })
end

minetest.register_entity("ggraffiti:canvas", CanvasEntity)

return canvas
