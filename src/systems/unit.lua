local Unit = {}

local hooks

local KEY_TO_DIR = {
    w = "up",
    s = "down",
    a = "left",
    d = "right",
}

local DIR_DELTA = {
    left       = { -1, 1 },
    right      = { 1, -1 },
    up         = { -1, -1 },
    down       = { 1, 1 },
    up_left    = { -1, 0 },
    up_right   = { 0, -1 },
    down_left  = { 0, 1 },
    down_right = { 1, 0 },
}

local function dir_from_key(key)
    return KEY_TO_DIR[key] or KEY_TO_DIR[string.lower(key or "")]
end

local function held_move_dir()
    local is_w = love.keyboard.isDown("w")
    local is_s = love.keyboard.isDown("s")
    local is_a = love.keyboard.isDown("a")
    local is_d = love.keyboard.isDown("d")

    if is_w and is_a then return "up_left" end
    if is_w and is_d then return "up_right" end
    if is_s and is_a then return "down_left" end
    if is_s and is_d then return "down_right" end

    if is_w then return "up" end
    if is_s then return "down" end
    if is_a then return "left" end
    if is_d then return "right" end

    return nil
end

function Unit.init(h)
    hooks = h
end

function Unit.register(world, npc_id)
    if not world.unit then
        world.unit = {}
    end

    world.unit.controlled_npc_id = npc_id
end

function Unit.spawn(world, opts)
    opts = opts or {}

    Unit.register(world, opts.npc_id)
    world.unit.input_enabled = opts.input_enabled ~= false
end

function Unit.set_tile(world, tile_x, tile_y)
    if world.unit then
        world.unit.tile_x = tile_x
        world.unit.tile_y = tile_y
    end
end

function Unit.set_input_enabled(world, enabled)
    if world.unit then
        world.unit.input_enabled = enabled
    end
end

function Unit.sync_tile(world)
    if hooks and hooks.sync_tile then
        hooks.sync_tile(world)
    end
end

local function controlled_id(world)
    local p = world and world.unit
    return p and p.controlled_npc_id
end

function Unit.can_input(world)
    if not world then
        return false
    end

    local p = world.unit

    if not p or not p.controlled_npc_id or p.input_enabled == false then
        return false
    end

    return p.tile_x ~= nil and p.tile_y ~= nil
end

function Unit.is_busy(world)
    if not hooks or not hooks.npc_busy then
        return false
    end

    return hooks.npc_busy(controlled_id(world))
end

function Unit.try_move_dir(world, dir)
    if not Unit.can_input(world) or not hooks or not dir then
        return false
    end

    if Unit.is_busy(world) then
        return false
    end

    local delta = DIR_DELTA[dir]
    local id = controlled_id(world)

    if not hooks.walk_npc(delta[1], delta[2], id) then
        return false
    end

    Unit.sync_tile(world)

    return true
end

function Unit.try_move(world, key)
    local dir = held_move_dir() or dir_from_key(key)

    if not dir then
        return false
    end

    return Unit.try_move_dir(world, dir)
end

function Unit.keypressed(world, key)
    return Unit.try_move(world, key)
end

function Unit.try_walk_query(world, query)
    if not query or not query.placement or query.target == "npc" then
        return false
    end

    if not Unit.can_input(world) or Unit.is_busy(world) or not hooks then
        return false
    end

    local placement = query.placement

    if not hooks.walk_to_placement(placement.x, placement.y, controlled_id(world)) then
        return false
    end

    Unit.sync_tile(world)

    return true
end

function Unit.update(world, _dt)
    Unit.sync_tile(world)

    if not Unit.can_input(world) or not hooks or Unit.is_busy(world) then
        return
    end

    local dir = held_move_dir()

    if dir then
        Unit.try_move_dir(world, dir)
    end
end

return Unit
