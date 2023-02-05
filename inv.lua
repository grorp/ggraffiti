local S = minetest.get_translator("ggraffiti")

local DYE_COLORS = {
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

local color_items = {}

for _, dye in ipairs(dye.dyes) do
    local dye_name, dye_desc = unpack(dye)
    local dye_color = DYE_COLORS[dye_name]

    minetest.register_craftitem("ggraffiti:inv_color_" .. dye_name, {
        description = S(dye_desc),
        inventory_image = "ggraffiti_inv_color.png^[multiply:" .. dye_color,
        wield_image = "ggraffiti_spray_can.png",
        groups = { not_in_creative_inventory = 1 },
    })
    table.insert(color_items, "ggraffiti:inv_color_" .. dye_name)
end

minetest.register_craftitem("ggraffiti:inv_color_remover", {
    description = S("Remover"),
    inventory_image = "ggraffiti_inv_color_remover.png",
    wield_image = "ggraffiti_spray_can.png",
    groups = { not_in_creative_inventory = 1 },
})
table.insert(color_items, "ggraffiti:inv_color_remover")

local SPRAY_SIZES = {1, 2, 3, 4, 5, 6, 7, 8}

local player_color = {}
local player_size = {}

local player_size_inv = {}

local function activate_color_inv(player)
    local name = player:get_player_name()
    player_size[name] = player:get_wield_index()

    local inv = player:get_inventory()
    inv:set_size("main", #color_items)
    for i, item in ipairs(color_items) do
        inv:set_stack("main", i, ItemStack(item))
    end
    player:hud_set_hotbar_itemcount(#color_items)

    -- player:set_wield_index(player_color[name] or 1)
end

for _, size in ipairs(SPRAY_SIZES) do
    minetest.register_craftitem("ggraffiti:inv_size_" .. size, {
        description = S(tostring(size)),
        inventory_image = "ggraffiti_inv_size_" .. size .. ".png",
        wield_image = "ggraffiti_spray_can.png",
        groups = { not_in_creative_inventory = 1 },
    })
end

local function activate_size_inv(player)
    local name = player:get_player_name()
    player_color[name] = player:get_wield_index()

    local inv = player:get_inventory()
    inv:set_size("main", #SPRAY_SIZES)
    for i, size in ipairs(SPRAY_SIZES) do
        inv:set_stack("main", i, ItemStack("ggraffiti:inv_size_" .. size))
    end
    player:hud_set_hotbar_itemcount(#SPRAY_SIZES)

    -- player:set_wield_index(player_size[name] or 1)
end

minetest.register_chatcommand("spray_mode", {
    func = function(name, args)
        local player = minetest.get_player_by_name(name)
        activate_color_inv(player)
        -- minetest.chat_send_all("adding hud for " .. name)
        -- player:hud_set_flags({
        --     hotbar = false,
        -- })
        -- local hud_id = player:hud_add({
        --     hud_elem_type = "inventory",
        --     position = {x = 0.5, y = 0.5},
        --     offset = {},
        --     text = "ggraffiti:colors",
        --     number = #dye.dyes,
        --     item = 1,
        -- })
        -- minetest.chat_send_all("hud id: " .. hud_id)
    end,
})

minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local control = player:get_player_control()
        if control.sneak and not player_size_inv[name] then
            activate_size_inv(player)
            player_size_inv[name] = true
        elseif not control.sneak and player_size_inv[name] then
            activate_color_inv(player)
            player_size_inv[name] = false
        end
    end
end)
