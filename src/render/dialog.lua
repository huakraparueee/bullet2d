local config = require("src.data.config")

local M = {}

local image_cache = {}

local BOX_HEIGHT_RATIO = 0.28
local MARGIN = 24
local PANEL_PAD = 20

function M.load_image(path)
    if not path or path == "" then
        return nil
    end

    if image_cache[path] then
        return image_cache[path]
    end

    if not love.filesystem.getInfo(path) then
        return nil
    end

    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    image_cache[path] = image

    return image
end

function M.clear_cache()
    image_cache = {}
end

local function dialog_box_y(screen_h)
    return screen_h - math.floor(screen_h * BOX_HEIGHT_RATIO)
end

function M.draw(state)
    local lg = love.graphics
    local w = config.DESIGN_WIDTH
    local h = config.DESIGN_HEIGHT
    local box_y = dialog_box_y(h)
    local box_h = h - box_y
    local line = state.line

    lg.clear(0, 0, 0, 1)

    if state.image then
        local image = state.image
        local iw, ih = image:getWidth(), image:getHeight()
        local max_w = w - MARGIN * 2
        local max_h = box_y - MARGIN * 2
        local scale = math.min(max_w / iw, max_h / ih)
        local draw_w = iw * scale
        local draw_h = ih * scale
        local x = math.floor((w - draw_w) * 0.5)
        local y = math.floor((box_y - draw_h) * 0.5)

        lg.setColor(1, 1, 1, 1)
        lg.draw(image, x, y, 0, scale, scale)
    end

    lg.setColor(0.07, 0.07, 0.09, 0.96)
    lg.rectangle("fill", 0, box_y, w, box_h)

    lg.setColor(0.32, 0.32, 0.38, 1)
    lg.rectangle("fill", 0, box_y, w, 2)

    if not line then
        lg.setColor(1, 1, 1, 1)
        return
    end

    local body_font = state.fonts.body
    local name_font = state.fonts.name
    local text_w = w - PANEL_PAD * 2
    local text_x = PANEL_PAD
    local cursor_y = box_y + PANEL_PAD

    if line.speaker and line.speaker ~= "" then
        lg.setFont(name_font)
        lg.setColor(0.88, 0.82, 0.55, 1)
        lg.print(line.speaker, text_x, cursor_y)
        cursor_y = cursor_y + name_font:getHeight() + 6
    end

    lg.setFont(body_font)
    lg.setColor(0.92, 0.92, 0.96, 1)
    lg.printf(line.text or "", text_x, cursor_y, text_w, "left")

    local hint = state.hint or "Enter / Click"
    lg.setFont(state.fonts.hint)
    lg.setColor(0.45, 0.45, 0.5, 1)
    lg.printf(
        hint,
        text_x,
        box_y + box_h - state.fonts.hint:getHeight() - 12,
        text_w,
        "right"
    )

    lg.setFont(state.default_font)
    lg.setColor(1, 1, 1, 1)
end

return M
