local config = require("src.data.config")

local M = {}

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

function M.create_fonts()
    local shorter = math.min(config.DESIGN_WIDTH, config.DESIGN_HEIGHT)

    return {
        hud = love.graphics.newFont(clamp(math.floor(shorter * 0.028), 14, 28)),
        title = love.graphics.newFont(clamp(math.floor(shorter * 0.04), 18, 40)),
    }
end

local function draw_bar(lg, x, y, w, h, frac, r, g, b)
    lg.setColor(0.12, 0.12, 0.16, 0.85)
    lg.rectangle("fill", x, y, w, h, 4, 4)
    lg.setColor(r, g, b, 1)
    lg.rectangle("fill", x + 2, y + 2, math.max(0, (w - 4) * frac), h - 4, 3, 3)
    lg.setColor(0.9, 0.9, 0.95, 0.5)
    lg.rectangle("line", x, y, w, h, 4, 4)
end

function M.draw_hud(view)
    if not view or not view.combat then
        return
    end

    local lg = love.graphics
    local fonts = view.fonts or M.create_fonts()
    local c = view.combat
    local p = c.player
    local margin = 24
    local bar_w = 280
    local bar_h = 22

    lg.setFont(fonts.hud)

    draw_bar(lg, margin, margin, bar_w, bar_h, p.hp / p.max_hp, 0.85, 0.25, 0.3)
    lg.setColor(1, 1, 1, 0.95)
    lg.print(
        string.format("HP %d / %d", math.ceil(p.hp), math.ceil(p.max_hp)),
        margin + 8,
        margin + 3
    )

    local xp_y = margin + bar_h + 10

    draw_bar(
        lg,
        margin,
        xp_y,
        bar_w,
        bar_h - 4,
        p.xp / p.xp_to_next,
        0.3,
        0.65,
        0.95
    )
    lg.print(
        string.format("Lv %d  XP %d / %d", p.level, p.xp, p.xp_to_next),
        margin + 8,
        xp_y + 2
    )

    lg.setColor(0.92, 0.92, 0.96, 0.9)
    lg.print(
        string.format(
            "Phase %d  Enemies: %d  Shots: %d",
            view.phase or 1,
            view.enemy_count or 0,
            p.shot_count or 1
        ),
        margin,
        xp_y + bar_h + 8
    )

    lg.setColor(1, 1, 1, 1)
end

function M.draw_upgrade(view)
    if not view or not view.upgrade_pending then
        return
    end

    local lg = love.graphics
    local w = config.DESIGN_WIDTH
    local h = config.DESIGN_HEIGHT
    local fonts = view.fonts or M.create_fonts()

    lg.setColor(0, 0, 0, 0.65)
    lg.rectangle("fill", 0, 0, w, h)

    lg.setFont(fonts.title)
    lg.setColor(1, 0.92, 0.35, 1)
    local title = "Level Up! Choose an upgrade"
    lg.print(
        title,
        math.floor(w * 0.5 - fonts.title:getWidth(title) * 0.5),
        h * 0.28
    )

    lg.setFont(fonts.hud)
    lg.setColor(0.95, 0.95, 1, 1)

    local options = view.upgrade_options or {}
    local start_y = h * 0.4
    local spacing = fonts.hud:getHeight() + 14

    for i, opt in ipairs(options) do
        local line = string.format("[%s] %s", opt.key, opt.label)
        lg.print(line, w * 0.5 - 120, start_y + (i - 1) * spacing)
    end

    lg.setColor(1, 1, 1, 1)
end

function M.draw_game_over(view)
    if not view or not view.dead then
        return
    end

    local lg = love.graphics
    local w = config.DESIGN_WIDTH
    local h = config.DESIGN_HEIGHT
    local fonts = view.fonts or M.create_fonts()

    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 0, 0, w, h)

    lg.setFont(fonts.title)
    lg.setColor(0.95, 0.3, 0.3, 1)
    local title = "Defeated"
    lg.print(
        title,
        math.floor(w * 0.5 - fonts.title:getWidth(title) * 0.5),
        h * 0.38
    )

    lg.setFont(fonts.hud)
    lg.setColor(0.9, 0.9, 0.95, 1)
    local hint = "Press R to retry"
    lg.print(
        hint,
        math.floor(w * 0.5 - fonts.hud:getWidth(hint) * 0.5),
        h * 0.48
    )

    lg.setColor(1, 1, 1, 1)
end

return M
