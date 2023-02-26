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

local shared = {}

shared.SPRAY_DURATION = 4 * 60
-- Clients send the position of their player every 0.1 seconds.
-- https://github.com/minetest/minetest/blob/5.6.1/src/client/client.h#L563
-- https://github.com/minetest/minetest/blob/5.6.1/src/client/client.cpp#L528
shared.SPRAY_STEP_INTERVAL = 0.1
shared.NUM_SPRAY_STEPS = 5

shared.MAX_SPRAY_DISTANCE = 4

shared.DESIRED_PIXEL_SIZE = 1/16

shared.TRANSPARENT = "#00000000"
-- The color of the pixel at (8, 9) in the dye texture.
shared.DYE_COLORS = {
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

local basepath = minetest.get_modpath("ggraffiti") .. "/src"
assert(loadfile(basepath .. "/aabb.lua"))(shared)
assert(loadfile(basepath .. "/canvas.lua"))(shared)
assert(loadfile(basepath .. "/spraycast.lua"))(shared)
assert(loadfile(basepath .. "/gui.lua"))(shared)
assert(loadfile(basepath .. "/items.lua"))(shared)
