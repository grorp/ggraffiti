-- Tests for self-invalidating canvases.

local CanvasEntity = core.registered_entities["ggraffiti:canvas"]

local function test_canvas(test_fn)
    local test = {
        bitmap_size = {x = 38, y = 19},
        bitmap = {},
        update_later = function() end,
    }
    for i = 1, test.bitmap_size.x * test.bitmap_size.y do
        test.bitmap[i] = "#ff0000"
    end

    test_fn(test)

    -- no # operator since I want all keys, not just consecutive positive
    -- integer keys
    local count = 0
    for _, _ in pairs(test.bitmap) do
        count = count + 1
    end
    assert(count == test.bitmap_size.x * test.bitmap_size.y)

    for i = 1, test.bitmap_size.x * test.bitmap_size.y do
        -- lua_api.md on core.colorspec_to_colorstring:
        -- If the ColorSpec is invalid, returns nil.
        assert(core.colorspec_to_colorstring(test.bitmap[i]) ~= nil)
    end
end

-- Test draw_pixel.
test_canvas(function(test)
    print("[test] draw_pixel fill")
    for x = 0, test.bitmap_size.x - 1 do
        for y = 0, test.bitmap_size.y - 1 do
            CanvasEntity.draw_pixel(test, x, y, "#00ff00", false)
        end
    end
    for i = 1, test.bitmap_size.x * test.bitmap_size.y do
        assert(test.bitmap[i] == "#00ff00")
    end
end)

for x = -50, 50 do
    for y = -50, 50 do
        test_canvas(function(test)
            print("[test] draw_pixel at (" .. x .. ", " .. y .. ")")
            CanvasEntity.draw_pixel(test, x, y, "#00ff00", false)
        end)
    end
end

-- Test draw_rect.
for x = -50, 50 do
    for y = -50, 50 do
        for size = 1, 12 do
            test_canvas(function(test)
                print("[test] draw_rect at (" .. x .. ", " .. y .. ") size=" .. size)
                CanvasEntity.draw_rect(test, x, y, size, "#00ff00", false)
            end)
        end
    end
end
