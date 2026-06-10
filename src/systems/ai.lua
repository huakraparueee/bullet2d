--[[
  Random walk for NPC ids registered on world.wander_ids (play sets from map data).
  Scene wires hooks; controlled unit NPC stays stand and does not wander.
]]

local AI = {}

local hooks
local timers = {}

local IDLE_MIN = 0.8
local IDLE_MAX = 2.5
local RADIUS = 6

function AI.init(h)
    hooks = h
end

function AI.reset()
    timers = {}
end

function AI.register(world, ids)
    if not world then
        return
    end

    world.wander_ids = {}

    for _, id in ipairs(ids or {}) do
        world.wander_ids[id] = true
    end
end

local function controlled_id(world)
    local p = world and world.unit
    return p and p.controlled_npc_id
end

local function should_wander(world, id)
    local set = world and world.wander_ids
    return set and set[id] == true
end

local function pick_goal(piece)
    if not piece.pos_x or not piece.pos_y then
        return nil, nil
    end

    if hooks and hooks.pick_placement_near then
        local px, py = hooks.pick_placement_near(piece.pos_x, piece.pos_y)

        if px and py then
            return px, py
        end
    end

    return nil, nil
end

local function npc_walking(id)
    if not hooks or not hooks.find_piece then
        return false
    end

    local piece = hooks.find_piece(id)

    return piece
        and piece.npc
        and piece.npc.path ~= nil
end

local function npc_busy(id)
    if npc_walking(id) then
        return true
    end

    if hooks and hooks.npc_anim_busy then
        return hooks.npc_anim_busy(id)
    end

    return false
end

function AI.update(world, dt)
    if not hooks or not hooks.each_npc_piece then
        return
    end

    local cid = controlled_id(world)

    hooks.each_npc_piece(function(piece)
        if not piece.npc_id or not piece.npc then
            return
        end

        local id = piece.npc_id

        if id == cid then
            if not npc_walking(id)
                and not piece.npc.mode_busy
                and piece.npc.mode ~= "stand"
                and hooks.set_mode
            then
                hooks.set_mode(id, "stand")
            end

            return
        end

        if not should_wander(world, id) then
            timers[id] = nil
            return
        end

        if npc_busy(id) then
            return
        end

        local t = timers[id]

        if not t then
            timers[id] = {
                wait = love.math.random()
                    * (IDLE_MAX - IDLE_MIN)
                    + IDLE_MIN,
            }
            return
        end

        t.wait = t.wait - dt

        if t.wait > 0 then
            return
        end

        local px, py = pick_goal(piece)

        if px and hooks.walk_to_pos then
            hooks.walk_to_pos(id, px, py)
        end

        t.wait = love.math.random() * (IDLE_MAX - IDLE_MIN) + IDLE_MIN
    end)
end

return AI
