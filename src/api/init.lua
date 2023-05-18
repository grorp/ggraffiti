ggraffiti = {}
local shared = {}

-- Clients send the position of their player every 0.1 seconds.
-- https://github.com/minetest/minetest/blob/5.6.1/src/client/client.h#L563
-- https://github.com/minetest/minetest/blob/5.6.1/src/client/client.cpp#L528
-- Using a lower value doesn't make any sense.
shared.SPRAY_STEP_INTERVAL = 0.1

shared.DESIRED_PIXEL_SIZE = 1/16
shared.TRANSPARENT = "#00000000"

shared.EPSILON = 0.0001

local basepath = minetest.get_modpath("ggraffiti") .. "/src/api"
assert(loadfile(basepath .. "/aabb.lua"))(shared)
assert(loadfile(basepath .. "/canvas.lua"))(shared)
assert(loadfile(basepath .. "/spraycast.lua"))(shared)
assert(loadfile(basepath .. "/interface.lua"))(shared)
