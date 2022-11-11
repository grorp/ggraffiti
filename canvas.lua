local DESIRED_PIXEL_SIZE = 1/16
local TRANSPARENT = "#00000000"

local CanvasEntity = {
    initial_properties = {
        visual = "upright_sprite",
        pointable = false,
        physical = false,
    },
}

function CanvasEntity:on_activate(staticdata)
    self.object:set_armor_groups({immortal = 1})

    -- https://github.com/minetest/minetest/blob/5.6.1/src/script/cpp_api/s_entity.cpp#L77-L104
    assert(type(staticdata) == "string")

    if staticdata ~= "" then
        local data = minetest.deserialize(staticdata)
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
