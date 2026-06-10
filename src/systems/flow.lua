local M = {}

local script
local scene
local handlers
local runners = {}
local flushing = false

function M.init(s, h)
    scene = s
    handlers = h
end

function M.add(type, fn)
    runners[type] = fn
end

function M.clear_map_wait()
    if script then
        script.map_wait = nil
    end
end

function M.set_map_wait(mode)
    if script then
        script.map_wait = mode
    end
end

function M.script()
    return script
end

function M.default_flow_key()
    return handlers and handlers.default_flow_key
end

function M.map_wait()
    return script and script.map_wait
end

function M.can_use_actions()
    return M.map_wait() == "play"
end

function M.flow_key()
    return script and script.flow_key
end

local function current_block()
    if not script then
        return nil
    end

    return script.phases[script.phase_i]
end

local function has_block()
    return current_block() ~= nil
end

function M.boot(flow_key)
    if not scene or not handlers then
        error("flow: call Flow.init from play first")
    end

    local phases = handlers.flows[flow_key]

    if not phases then
        error("flow: unknown flow " .. tostring(flow_key))
    end

    script = {
        flow_key = flow_key,
        phases = phases,
        phase_i = 1,
        map_wait = nil,
        flow_pending = false,
        flow_after_switch = false,
    }
end

function M.advance()
    if not script then
        return
    end

    script.phase_i = script.phase_i + 1

    if not has_block() then
        return
    end

    if handlers.is_scene_active() then
        script.flow_pending = true
        if not flushing then
            M.flush()
        end
        return
    end

    handlers.resume_scene()
end

function M.flush()
    if flushing or not script or not script.flow_pending then
        return
    end

    flushing = true

    while script and script.flow_pending do
        script.flow_pending = false
        M.run_block()
        if not handlers.is_scene_active() then
            break
        end
    end

    flushing = false
end

function M.run_block()
    local block = current_block()

    if not block or not handlers then
        return
    end

    local runner = runners[block.type]

    if runner then
        runner(block, function()
            M.advance()
        end)
        return
    end

    if block.type == "switch" then
        M.boot(block.flow)
        handlers.on_switch()
        script.flow_after_switch = true
        return
    end

    error("flow: unknown block type " .. tostring(block.type))
end

function M.queue_flush()
    if script then
        script.flow_pending = true
    end
end

function M.tick_after_switch()
    if script and script.flow_after_switch then
        script.flow_after_switch = false
        script.flow_pending = true
        M.flush()
    end
end

function M.tick_map_wait(map, is_busy)
    if not script or not script.map_wait or is_busy then
        return
    end

    if script.map_wait == "event" then
        script.map_wait = nil
        M.advance()
        return
    end

    if script.map_wait == "play" and map.finished then
        script.map_wait = nil
        M.advance()
    end
end

return M
