local DESIRED_PIXEL_SIZE = 1/16
local TRANSPARENT = "#00000000"

minetest.register_entity("ggraffiti:canvas", {
    initial_properties = {
        visual = "upright_sprite",
        pointable = false,
        physical = false,
    },

    get_staticdata = function(self)
        return minetest.serialize({
            size = self.size,
            bitmap_size = self.bitmap_size,
            bitmap = self.bitmap,
        })
    end,

    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1})

        local data = minetest.deserialize(staticdata)
        if data then
            self.size = data.size
            self.bitmap_size = data.bitmap_size
            self.bitmap = data.bitmap
            self:update()
        end
    end,

    create_bitmap = function(self)
        self.bitmap_size = {
            x = math.max(math.round(self.size.x / DESIRED_PIXEL_SIZE), 1), -- minimum 1x1 pixels
            y = math.max(math.round(self.size.y / DESIRED_PIXEL_SIZE), 1),
        }

        self.bitmap = {}
        for i = 1, self.bitmap_size.x * self.bitmap_size.y do
            self.bitmap[i] = TRANSPARENT
        end
    end,

    update = function(self)
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
    end,

    is_bitmap_empty = function(self)
        for _, c in ipairs(self.bitmap) do
            if c ~= TRANSPARENT then
                return false
            end
        end
        return true
    end,
})
