local config = require("src.data.config")
local gamestate = require("libraries.hump.gamestate")
local viewport = require("src.systems.viewport")
local DialogRender = require("src.render.dialog")

local M = {}

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function create_fonts()
    local w = config.DESIGN_WIDTH
    local h = config.DESIGN_HEIGHT
    local shorter = math.min(w, h)

    return {
        name = love.graphics.newFont(
            clamp(math.floor(shorter * 0.042), 16, 40)
        ),
        body = love.graphics.newFont(
            clamp(math.floor(shorter * 0.034), 14, 32)
        ),
        hint = love.graphics.newFont(
            clamp(math.floor(shorter * 0.024), 12, 22)
        ),
    }
end

function M:init()
    self.default_font = love.graphics.newFont()
end

--[[
  opts:
    lines = { { speaker = "...", text = "..." }, ... }
    image = path ใน love.filesystem (ไม่บังคับ)
    on_done = function()  -- เมื่อจบบทสนทนา
]]
function M:enter(_, opts)
    opts = opts or {}

    self.closing = false
    self.lines = opts.lines or {}
    self.on_done = opts.on_done
    self.line_index = 1
    self.fonts = create_fonts()
    self.image = DialogRender.load_image(opts.image)
    self.hint = opts.hint

    if #self.lines == 0 then
        M.finish(self)
    end
end

function M:resize()
    self.fonts = create_fonts()
end

function M.current_line(self)
    return self.lines[self.line_index]
end

function M.finish(self)
    if self.closing then
        return
    end

    if self.on_done then
        self.closing = true
        self.on_done()
        return
    end

    gamestate.switch(require("src.scenes.menu"))
end

function M:advance()
    if self.line_index < #self.lines then
        self.line_index = self.line_index + 1
        return
    end

    M.finish(self)
end

function M:update(_dt)
end

local function confirm_key(key)
    return key == "return"
        or key == "space"
        or key == "kpenter"
        or key == "z"
        or key == "x"
end

function M:keypressed(key, _, isrepeat)
    if isrepeat then
        return
    end

    if confirm_key(key) then
        self:advance()
    end
end

function M:mousepressed(_, _, button)
    if button == 1 then
        self:advance()
    end
end

function M:draw()
    viewport.begin()

    DialogRender.draw({
        line = M.current_line(self),
        image = self.image,
        fonts = self.fonts,
        default_font = self.default_font,
        hint = self.hint,
    })

    viewport.finish()
end

function M.open(opts)
    gamestate.switch(M, opts)
end

return M
