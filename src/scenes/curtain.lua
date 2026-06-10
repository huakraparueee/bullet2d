local Timer = require("libraries.hump.timer")
local viewport = require("src.systems.viewport")
local CurtainRender = require("src.render.curtain")

local M = {}

local DURATION_CLOSE = 0.5
local DURATION_OPEN = 1.5
local HOLD = 0.5

local state
local latched_closed = false

local function finish()
    local cb = state and state.on_done
    local mode = state and state.mode

    if mode == "close" then
        latched_closed = true
    end

    state = nil

    if cb then
        cb()
    end
end

local function start(mode, on_done, opts)
    opts = opts or {}
    latched_closed = false

    local scr_h = viewport.design_h

    state = {
        mode = mode,
        timer = Timer.new(),
        panel_h = scr_h,
        on_done = on_done,
    }

    if mode == "close" then
        state.offset_y = scr_h

        state.timer:tween(
            opts.duration or DURATION_CLOSE,
            state,
            { offset_y = 0 },
            "in-out-quad",
            function()
                state.timer:after(opts.hold or HOLD, finish)
            end
        )
    elseif mode == "open" then
        state.offset_y = 0

        state.timer:after(opts.hold or HOLD, function()
            state.timer:tween(
                opts.duration or DURATION_OPEN,
                state,
                { offset_y = scr_h },
                "in-out-quad",
                finish
            )
        end)
    else
        error("curtain: unknown mode " .. tostring(mode))
    end
end

function M.active()
    return state ~= nil
end

function M.update(dt)
    if state then
        state.timer:update(dt)
    end
end

function M.draw()
    if state then
        CurtainRender.draw({
            offset_y = state.offset_y,
            panel_h = state.panel_h,
        })
        return
    end

    if latched_closed then
        CurtainRender.draw({
            offset_y = 0,
            panel_h = viewport.design_h,
        })
    end
end

function M.open_transition(on_done, opts)
    start("open", on_done, opts)
end

function M.close_transition(on_done, opts)
    start("close", on_done, opts)
end

return M
