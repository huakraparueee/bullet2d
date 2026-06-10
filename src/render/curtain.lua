
local config = require("src.data.config")

local M = {}

function M.draw(view)
    view = view or {}

    local lg = love.graphics
    local w = config.DESIGN_WIDTH
    local h = config.DESIGN_HEIGHT
    local ph = view.panel_h or h
    local y = view.offset_y or 0

    local top = math.max(0, y)
    local bot = math.min(h, y + ph)

    if bot <= top then
        return
    end

    lg.setColor(0, 0, 0, 1)
    lg.rectangle("fill", 0, top, w, bot - top)
    lg.setColor(1, 1, 1, 1)
end

return M
