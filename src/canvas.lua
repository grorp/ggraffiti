local shared = ...

local canvas_update_queue = {}

local function add_canvas_to_update_queue(canvas)
    for _, item in ipairs(canvas_update_queue) do
        if item == canvas then
            return
        end
    end
    table.insert(canvas_update_queue, canvas)
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
        self:update_immediately()

        -- "Overwrite" other canvases in the same place.
        local rivals = minetest.get_objects_inside_radius(self.object:get_pos(), 0.0001)
        for _, obj in ipairs(rivals) do
            if obj ~= self.object then
                local ent = obj:get_luaentity()
                if ent and ent.name == "ggraffiti:canvas" then
                    obj:remove()
                end
            end
        end
    end
end

function CanvasEntity:setup(size)
    self.size = size
    self.bitmap_size = {
        x = math.max(math.round(self.size.x / shared.DESIRED_PIXEL_SIZE), 1), -- minimum 1x1 pixels
        y = math.max(math.round(self.size.y / shared.DESIRED_PIXEL_SIZE), 1),
    }
    self.bitmap = {}
    for i = 1, self.bitmap_size.x * self.bitmap_size.y do
        self.bitmap[i] = shared.TRANSPARENT
    end
end

function CanvasEntity:update_later()
    add_canvas_to_update_queue(self)
end

function CanvasEntity:update_immediately()
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

local function clamp(val, min, max)
    return math.max(min, math.min(val, max))
end

function CanvasEntity:rectangle(x, y, width, height, color)
    local x1, y1 =
        clamp(x, 0, self.bitmap_size.x - 1),
        clamp(y, 0, self.bitmap_size.y - 1)
    local x2, y2 =
        clamp(x + width - 1, 0, self.bitmap_size.x - 1),
        clamp(y + height - 1, 0, self.bitmap_size.y - 1)
    for xx = x1, x2 do
        for yy = y1, y2 do
            self.bitmap[yy * self.bitmap_size.x + xx + 1] = color
        end
    end
end

function CanvasEntity:is_empty()
    for _, c in ipairs(self.bitmap) do
        if c ~= shared.TRANSPARENT then
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

function shared.update_canvases()
    for _, canvas in ipairs(canvas_update_queue) do
        -- This doesn't cause a crash if the canvas entity has been removed.
        canvas:update_immediately()
    end
    canvas_update_queue = {}
end
