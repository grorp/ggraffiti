local shared = ...

-- For the largest spray size available for the default spray cans
-- (5×5=25 pixels), this results in 12 seconds.
ggraffiti.DEFAULT_DURATION = 5 * 60
ggraffiti.DEFAULT_NUM_STEPS = 5
ggraffiti.DEFAULT_MAX_DISTANCE = 4
ggraffiti.DEFAULT_SIZE = 1

local function table_copy_shallow(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = v
    end
    return t2
end

local function process_brush_def(def)
    local cp = table_copy_shallow(def)

    cp.duration = cp.duration or ggraffiti.DEFAULT_DURATION
    cp.num_steps = cp.num_steps or ggraffiti.DEFAULT_NUM_STEPS
    cp.max_distance = cp.max_distance or ggraffiti.DEFAULT_MAX_DISTANCE
    cp.size = cp.size or ggraffiti.DEFAULT_SIZE

    assert(type(cp.duration) == "number")
    assert(cp.replacement_item == nil or type(cp.replacement_item) == "string")
    assert(type(cp.num_steps) == "number")
    assert(type(cp.max_distance) == "number")
    assert(cp.remover == nil or type(cp.remover) == "boolean")
    if not cp.remover then
        assert(type(cp.color) == "string")
    else
        assert(cp.color == nil)
    end
    assert(type(cp.size) == "number")

    return cp
end

local function get_brush_def(player, item, is_on_use)
    local def = item:get_definition()
    if not def then return end
    local brush_def = def._ggraffiti_brush
    if not brush_def then return end

    if type(brush_def) == "function" then
        -- different order for consistency with other item callbacks
        return process_brush_def(brush_def(item, player, is_on_use))
    else
        return process_brush_def(brush_def)
    end
end

local function get_eye_pos(player)
    local pos = player:get_pos()
    pos.y = pos.y + player:get_properties().eye_height
    return pos
end

local function wear_out(player_name, item, brush_def, n_steps)
    if minetest.is_creative_enabled(player_name) then
        return item
    end

    item:add_wear_by_uses(brush_def.duration / shared.SPRAY_STEP_INTERVAL *
            brush_def.num_steps / n_steps)
    if brush_def.replacement_item and item:is_empty() then
        return ItemStack(brush_def.replacement_item)
    end
    return item
end

local player_lasts = {}

function ggraffiti.brush_on_use(item, player)
    local player_name = player:get_player_name()

    local brush_def = get_brush_def(player, item, true)
    if not brush_def then return end

    local pos = get_eye_pos(player)
    local dir = player:get_look_dir()
    shared.spraycast(player, pos, dir, brush_def)
    player_lasts[player_name] = { pos = pos, dir = dir }
    shared.after_spraycasts()

    return wear_out(player_name, item, brush_def, 1)
end

local function lerp_factory(t)
    return function(a, b)
        return a + (b - a) * t
    end
end

local function spray_step(player)
    local player_name = player:get_player_name()

    if not player:get_player_control().dig then
        player_lasts[player_name] = nil
        return
    end

    local item = player:get_wielded_item()
    local brush_def = get_brush_def(player, item, false)
    if not brush_def then
        player_lasts[player_name] = nil
        return
    end

    -- Seems to be kind of expensive.
    if not minetest.check_player_privs(player_name, "interact") then
        player_lasts[player_name] = nil
        return
    end

    local last = player_lasts[player_name]
    local now_pos = get_eye_pos(player)
    local now_dir = player:get_look_dir()

    if last then
        local n_steps = brush_def.num_steps

        if now_pos == last.pos and now_dir == last.dir then
            -- The player hasn't moved, but the world may have changed.
            shared.spraycast(player, now_pos, now_dir, brush_def)
        else
            for step_n = 1, n_steps do
                local lerp = lerp_factory(step_n / n_steps)
                local pos = vector.combine(last.pos, now_pos, lerp)
                local dir = vector.combine(last.dir, now_dir, lerp):normalize() -- "nlerp"

                shared.spraycast(player, pos, dir, brush_def)
            end
        end

        item = wear_out(player_name, item, brush_def, n_steps)
        player:set_wielded_item(item)
    end

    player_lasts[player_name] = { pos = now_pos, dir = now_dir }
end

local dtime_accu = 0

minetest.register_globalstep(function(dtime)
    dtime_accu = dtime_accu + dtime

    if dtime_accu >= shared.SPRAY_STEP_INTERVAL then
        dtime_accu = dtime_accu % shared.SPRAY_STEP_INTERVAL
        for _, player in ipairs(minetest.get_connected_players()) do
            spray_step(player)
        end
        shared.after_spraycasts()
    end
end)

minetest.register_on_mods_loaded(function()
    for name, item in pairs(minetest.registered_items) do
        if item._ggraffiti_brush and item.on_use ~= ggraffiti.brush_on_use then
            error('"' .. name .. '" was declared as GGraffiti brush, but doesn\'t ' ..
                    'have "ggraffiti.brush_on_use" set as its "on_use" callback.')
        end
    end
end)
