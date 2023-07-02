local shared = {}

if minetest.get_modpath("default") and minetest.get_modpath("dye") and
        minetest.get_modpath("flowers") then
    shared.game = "mtg"
elseif minetest.get_modpath("mcl_core") and minetest.get_modpath("mcl_dye") and
        minetest.get_modpath("mcl_mushrooms") then
    shared.game = "mcl"
else
    error(
        '\n' ..
        'GGraffiti\n' ..
        "────────────────────────────────────────────────────────────────────────────────────────────────────\n" ..
        'No supported game found. Supported games are:\n' ..
        ' - Minetest Game\n' ..
        ' - MineClone 2\n' ..
        "────────────────────────────────────────────────────────────────────────────────────────────────────\n",
        0
    )
end

local function dependency_version_error(mod_title)
    error(
        '\n' ..
        'GGraffiti\n' ..
        "────────────────────────────────────────────────────────────────────────────────────────────────────\n" ..
        'You have an outdated version of the mod "' .. mod_title .. '" installed. ' ..
        'Please go to "Content" → "Browse online content" and update the mod "' .. mod_title .. '".\n' ..
        "────────────────────────────────────────────────────────────────────────────────────────────────────\n",
        0
    )
end
if not modlib.version or modlib.version < 102 then
    dependency_version_error("Modding Library")
end
if not flow.widgets or not rawget(flow.widgets, "Nil") then
    dependency_version_error("Flow")
end

-- For the largest available spray size (3×3=9 pixels), this results in 33.33 seconds.
shared.SPRAY_DURATION = 5 * 60
-- Clients send the position of their player every 0.1 seconds.
-- https://github.com/minetest/minetest/blob/5.6.1/src/client/client.h#L563
-- https://github.com/minetest/minetest/blob/5.6.1/src/client/client.cpp#L528
shared.SPRAY_STEP_INTERVAL = 0.1
shared.NUM_SPRAY_STEPS = 5

shared.MAX_SPRAY_DISTANCE = 4
shared.DESIRED_PIXEL_SIZE = 1/16
shared.TRANSPARENT = "#00000000"

shared.EPSILON = 0.0001

if shared.game == "mtg" then
    -- Creative inventory concept:
    -- All spray cans: "Tools"
    -- Red mushroom extract: "Items"

    shared.game_items = {
        iron_ingot   = "default:steel_ingot",
        red_dye      = "dye:red",
        green_dye    = "dye:green",
        blue_dye     = "dye:blue",
        red_mushroom = "flowers:mushroom_red",
        red_mushroom_extract_count = 4,
    }

    -- The color of the pixel at (8, 9) (probably 0-based indexing) in the dye texture.
    shared.game_dyes = {
        { item_name = "dye:white", name = "white", desc = "White", color = "#eeeeee" },
        { item_name = "dye:grey", name = "grey", desc = "Grey", color = "#9c9c9c" },
        { item_name = "dye:dark_grey", name = "dark_grey", desc = "Dark Grey", color = "#494949" },
        { item_name = "dye:black", name = "black", desc = "Black", color = "#292929" },
        { item_name = "dye:violet", name = "violet", desc = "Violet", color = "#480680" },
        { item_name = "dye:blue", name = "blue", desc = "Blue", color = "#00519d" },
        { item_name = "dye:cyan", name = "cyan", desc = "Cyan", color = "#00959d" },
        { item_name = "dye:dark_green", name = "dark_green", desc = "Dark Green", color = "#2b7b00" },
        { item_name = "dye:green", name = "green", desc = "Green", color = "#67eb1c" },
        { item_name = "dye:yellow", name = "yellow", desc = "Yellow", color = "#fcf611" },
        { item_name = "dye:brown", name = "brown", desc = "Brown", color = "#6c3800" },
        { item_name = "dye:orange", name = "orange", desc = "Orange", color = "#e0601a" },
        { item_name = "dye:red", name = "red", desc = "Red", color = "#c91818" },
        { item_name = "dye:magenta", name = "magenta", desc = "Magenta", color = "#d80481" },
        { item_name = "dye:pink", name = "pink", desc = "Pink", color = "#ffa5a5" },
    }
elseif shared.game == "mcl" then
    -- Creative inventory concept:
    -- All spray cans: "Miscellaneous"
    -- Red mushroom extract: "Materials"

    shared.game_items = {
        iron_ingot   = "mcl_core:iron_ingot",
        red_dye      = "mcl_dye:red",
        green_dye    = "mcl_dye:dark_green", -- "mcl_dye:green" is "Lime"
        blue_dye     = "mcl_dye:blue",
        red_mushroom = "mcl_mushrooms:mushroom_red",
        red_mushroom_extract_count = 1,
    }

    -- The color of the pixel at (8, 6) (0-based indexing) in the dye texture.
    shared.game_dyes = {
        { item_name = "mcl_dye:white", name = "white", desc = "White", color = "#f2ebd9" },
        { item_name = "mcl_dye:grey", name = "grey", desc = "Light Grey", color = "#afafae" },
        { item_name = "mcl_dye:dark_grey", name = "dark_grey", desc = "Grey", color = "#7a7771" },
        { item_name = "mcl_dye:black", name = "black", desc = "Black", color = "#232323" },
        { item_name = "mcl_dye:violet", name = "violet", desc = "Purple", color = "#764791" },
        { item_name = "mcl_dye:blue", name = "blue", desc = "Blue", color = "#84a4d3" },
        { item_name = "mcl_dye:lightblue", name = "lightblue", desc = "Light Blue", color = "#56c4ff" },
        { item_name = "mcl_dye:cyan", name = "cyan", desc = "Cyan", color = "#61ccad" },
        { item_name = "mcl_dye:dark_green", name = "dark_green", desc = "Green", color = "#238231" },
        { item_name = "mcl_dye:green", name = "green", desc = "Lime", color = "#7fe07d" },
        { item_name = "mcl_dye:yellow", name = "yellow", desc = "Yellow", color = "#fae54d" },
        { item_name = "mcl_dye:brown", name = "brown", desc = "Brown", color = "#c9804d" },
        { item_name = "mcl_dye:orange", name = "orange", desc = "Orange", color = "#f2aa4d" },
        { item_name = "mcl_dye:red", name = "red", desc = "Red", color = "#a5413a" },
        { item_name = "mcl_dye:magenta", name = "magenta", desc = "Magenta", color = "#a06bad" },
        { item_name = "mcl_dye:pink", name = "pink", desc = "Pink", color = "#e07dc1" },
    }
else
    error("Something is rotten in the state of Denmark.")
end

local basepath = minetest.get_modpath("ggraffiti") .. "/src"
assert(loadfile(basepath .. "/aabb.lua"))(shared)
assert(loadfile(basepath .. "/canvas.lua"))(shared)
assert(loadfile(basepath .. "/spraycast.lua"))(shared)
assert(loadfile(basepath .. "/gui.lua"))(shared)
assert(loadfile(basepath .. "/items.lua"))(shared)
