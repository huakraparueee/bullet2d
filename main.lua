--[[
  Main bootstrap entrypoint.

  Responsibilities:
  - Initialize development tools
  - Setup hot reload
  - Register gamestate events
  - Start initial scene

  Notes:
  - Restart the game after changing:
    - main.lua
    - conf.lua
]]

package.path = package.path .. ";libraries/isolet2d/?.lua"

local config = require("src.data.config")
local gamestate = require("libraries.hump.gamestate")
local viewport = require("src.systems.viewport")
local Audio = require("src.systems.audio")

local DEV = false
local lurker

local GS_EVENTS = {
    "update",
    "draw",
    "mousepressed",
    "mousereleased",
    "keypressed",
    "keyreleased",
    "focus",
    "quit",
}

-- --------------------------------------------------
-- Module Reload
-- --------------------------------------------------

local ISOLET_MODULES = {
    "isolet2d",
    "stack",
    "tile",
    "events",
    "setup",
    "terrain",
    "npc",
    "structure",
    "projectile",
    "camera",
    "path",
    "placement",
    "anim8",
}

local function clear_modules()
    for name in pairs(package.loaded) do
        if name:match("^src%.") then
            package.loaded[name] = nil
        end
    end

    for _, name in ipairs(ISOLET_MODULES) do
        package.loaded[name] = nil
    end

    collectgarbage("collect")
end

local function boot()
    gamestate.switch(require("src.scenes.menu"))
end

local function setup_devtools()
    if not DEV then
        return
    end

    lurker = require("libraries.lurker")
    lurker.path = "src"
    lurker.interval = 0.35
    lurker.quiet = false
end

local function hot_reload()
    local w, h = love.graphics.getDimensions()

    if Audio.stop_all then
        Audio.stop_all()
    end

    clear_modules()
    viewport = require("src.systems.viewport")
    config = require("src.data.config")
    Audio = require("src.systems.audio")
    Audio.preload(config.SOUNDS)
    viewport.resize(w, h, config.DESIGN_WIDTH, config.DESIGN_HEIGHT)
    require("src.render.dialog").clear_cache()
    boot()

    if lurker then
        lurker.updatewrappers()
    end

    print("[DEV] Hot reload complete (F8)")
end

-- --------------------------------------------------
-- Love Callbacks
-- --------------------------------------------------

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")

    DEV = not love.filesystem.isFused()

    local win_w, win_h = love.graphics.getDimensions()
    viewport.resize(win_w, win_h, config.DESIGN_WIDTH, config.DESIGN_HEIGHT)

    setup_devtools()
    Audio.preload(config.SOUNDS)
    boot()

    if lurker then
        lurker.update()
    end

    if DEV then
        print("[DEV] F8 = hot reload src/")
    end
end

function love.update(dt)
    if lurker then
        lurker.update()
    end

    gamestate.update(dt)
end

function love.resize(w, h)
    viewport.resize(w, h, config.DESIGN_WIDTH, config.DESIGN_HEIGHT)

    local scene = gamestate.current()

    if scene and scene.resize then
        scene:resize(w, h)
    end
end

function love.draw()
    love.graphics.clear(
        config.DEFAULT_BACKGROUND_R,
        config.DEFAULT_BACKGROUND_G,
        config.DEFAULT_BACKGROUND_B
    )
end

-- draw โ’ gamestate โ’ scene:draw (resize เธขเธฑเธเนเธกเน register)
gamestate.registerEvents(GS_EVENTS)

local gs_keypressed = love.keypressed

function love.keypressed(key, scancode, isrepeat)
    if key == "f11" then
        local going_fullscreen = not love.window.getFullscreen()
        if going_fullscreen then
            love.window.setFullscreen(true, "desktop")
        else
            love.window.setFullscreen(false)
            love.window.setMode(
                config.DESIGN_WIDTH,
                config.DESIGN_HEIGHT,
                {
                    resizable = false,
                    minwidth = 1280,
                    minheight = 720,
                    vsync = 0,
                }
            )
        end
        return
    end

    if DEV and key == "f8" then
        hot_reload()
        return
    end

    if gs_keypressed then
        return gs_keypressed(key, scancode, isrepeat)
    end
end

function love.mousepressed(x, y, button, istouch)
    local scene = gamestate.current()

    if scene and scene.mousepressed then
        scene:mousepressed(x, y, button, istouch)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    local scene = gamestate.current()

    if scene and scene.mousemoved then
        scene:mousemoved(x, y, dx, dy, istouch)
    end
end

function love.mousereleased(x, y, button, istouch)
    local scene = gamestate.current()

    if scene and scene.mousereleased then
        scene:mousereleased(x, y, button, istouch)
    end
end
