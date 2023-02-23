local shared = ...
shared.aabb = {}

-- AABB = Axis-aligned bounding box

local aabb = shared.aabb
aabb.__index = aabb

function aabb.new(pos_min, pos_max)
    local t = {
        pos_min = pos_min,
        pos_max = pos_max,
    }
    setmetatable(t, aabb)
    return t
end

function aabb.from(list)
    return aabb.new(
        vector.new(list[1], list[2], list[3]),
        vector.new(list[4], list[5], list[6])
    )
end

function aabb:repair()
    self.pos_min, self.pos_max = vector.sort(self.pos_min, self.pos_max)
end

function aabb:get_center()
    return (self.pos_min + self.pos_max) / 2
end

function aabb:get_size()
    return self.pos_max - self.pos_min
end
