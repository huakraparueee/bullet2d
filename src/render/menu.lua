local config = require("src.data.config")

local M = {}

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function M.create_fonts(w, h)
    local shorter = math.min(w, h)

    return {
        title = love.graphics.newFont(
            clamp(math.floor(shorter * 0.11), 32, 160)
        ),
        body = love.graphics.newFont(
            clamp(math.floor(shorter * 0.038), 14, 36)
        ),
    }
end

function M.draw(view)
    if not view or not view.fonts then
        return
    end

    local lg = love.graphics
    local w = config.DESIGN_WIDTH
    local h = config.DESIGN_HEIGHT
    local title_font = view.fonts.title
    local body_font = view.fonts.body
    local center_x = w * 0.5
    local title = view.title

    lg.setFont(title_font)
    lg.setColor(0.92, 0.92, 0.96, 1)

    local title_y = h * 0.32

    lg.print(
        title,
        math.floor(center_x - title_font:getWidth(title) * 0.5),
        title_y
    )

    lg.setFont(body_font)

    local items = view.items or {}
    local spacing = body_font:getHeight() + 8
    local start_y = title_y + title_font:getHeight() * 2
    local selected_index = view.selected_index or 1

    for i, item in ipairs(items) do
        local selected = i == selected_index
        local label = item.label or item
        local text = selected and ("> " .. label) or ("  " .. label)
        local y = start_y + (i - 1) * spacing

        if selected then
            lg.setColor(1, 1, 1, 1)
        else
            lg.setColor(0.65, 0.65, 0.72, 1)
        end

        lg.print(
            text,
            math.floor(center_x - body_font:getWidth(text) * 0.5),
            y
        )
    end

    local hint = view.hint or "Up / Down • Enter"

    lg.setColor(0.5, 0.5, 0.55, 1)
    lg.print(
        hint,
        math.floor(center_x - body_font:getWidth(hint) * 0.5),
        h - body_font:getHeight() - 24
    )

    lg.setColor(1, 1, 1, 1)
end

function M.draw_credits(view)
    if not view or not view.fonts then
        return
    end

    local lg = love.graphics
    local w = config.DESIGN_WIDTH
    local h = config.DESIGN_HEIGHT
    local title_font = view.fonts.title
    local body_font = view.fonts.body
    local center_x = w * 0.5
    local title = "Credits"
    local lines = view.lines or {}

    lg.setFont(title_font)
    lg.setColor(0.92, 0.92, 0.96, 1)
    lg.print(
        title,
        math.floor(center_x - title_font:getWidth(title) * 0.5),
        h * 0.32
    )

    lg.setFont(body_font)
    local start_y = h * 0.32 + title_font:getHeight() * 2
    local spacing = body_font:getHeight() + 12

    for i, line in ipairs(lines) do
        lg.setColor(0.9, 0.9, 0.95, 1)
        lg.print(
            line,
            math.floor(center_x - body_font:getWidth(line) * 0.5),
            start_y + (i - 1) * spacing
        )
    end

    local hint = view.hint or "Enter / Esc"

    lg.setColor(0.5, 0.5, 0.55, 1)
    lg.print(
        hint,
        math.floor(center_x - body_font:getWidth(hint) * 0.5),
        h - body_font:getHeight() - 24
    )

    lg.setColor(1, 1, 1, 1)
end

return M
