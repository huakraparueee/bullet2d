local M = {}

local MAP_ID = "level1"
local MAX_ENEMIES_PER_PHASE = 20

local cache = {}

local function mod_path(id, name)
    return "src.data.maps." .. id .. "." .. name
end

local function try_require(path)
    local ok, mod = pcall(require, path)

    if ok then
        return mod
    end

    return nil
end

function M.scale_enemy(phase, def)
    local t = phase - 1

    return {
        speed = def.speed * (1 + t * 0.08),
        damage = math.floor(def.damage * (1 + t * 0.1)),
        fire_rate = math.max(1.4, def.fire_rate * (1 - t * 0.04)),
        hp = math.floor(def.hp * (1 + t * 0.2)),
        xp = def.xp or 10,
    }
end

local function pick_spawn_point(spawn_points, used)
    if not spawn_points or #spawn_points == 0 then
        return 1, 1
    end

    local free = {}

    for i = 1, #spawn_points do
        if not used[i] then
            free[#free + 1] = i
        end
    end

    local idx

    if #free > 0 then
        idx = free[love.math.random(1, #free)]
    else
        idx = love.math.random(1, #spawn_points)
    end

    used[idx] = true

    local sp = spawn_points[idx]

    return sp.tile_x, sp.tile_y
end

function M.phase_enemies(phase, combat)
    local out = {}
    local templates = combat.enemies or {}
    local spawn_points = combat.spawn_points or {}
    local count = math.min(
        #templates + math.floor((phase - 1) / 2),
        MAX_ENEMIES_PER_PHASE
    )
    local used_spawns = {}

    for i = 1, count do
        local tpl = templates[((i - 1) % #templates) + 1]
        local scaled = M.scale_enemy(phase, tpl)
        local tile_x, tile_y = pick_spawn_point(spawn_points, used_spawns)

        out[#out + 1] = {
            id = "slime_" .. i,
            kind = tpl.kind,
            attack = tpl.attack or "melee",
            projectile = tpl.projectile,
            tile_x = tile_x,
            tile_y = tile_y,
            facing = tpl.facing or "se",
            speed = scaled.speed,
            damage = scaled.damage,
            fire_rate = scaled.fire_rate,
            hp = scaled.hp,
            xp = scaled.xp,
        }
    end

    return out
end

function M.player_spawn_events(combat)
    local spawn = combat.player_spawn or {
        id = "pop",
        kind = "human",
        tile_x = 5,
        tile_y = 5,
        facing = "se",
        mode = "stand",
    }

    return {
        {
            type = "npc.add",
            id = spawn.id,
            kind = spawn.kind,
            tile_x = spawn.tile_x,
            tile_y = spawn.tile_y,
            facing = spawn.facing or "se",
            mode = spawn.mode or "stand",
        },
    }
end

function M.enemy_spawn_events(enemies)
    local evs = {}

    for _, e in ipairs(enemies) do
        evs[#evs + 1] = {
            type = "npc.place",
            id = e.id,
            kind = e.kind,
            tile_x = e.tile_x,
            tile_y = e.tile_y,
            facing = e.facing,
            mode = "stand",
        }
    end

    return evs
end

function M.enemy_slot_ids(max)
    max = max or MAX_ENEMIES_PER_PHASE
    local ids = {}

    for i = 1, max do
        ids[i] = "slime_" .. i
    end

    return ids
end

function M.load(id)
    id = id or MAP_ID

    if cache[id] then
        return cache[id]
    end

    local stacks = require(mod_path(id, "stacks"))
    local combat = require(mod_path(id, "combat"))
    local events = try_require(mod_path(id, "events")) or {}
    local dialogs = try_require(mod_path(id, "dialog")) or {}
    local flow = try_require(mod_path(id, "flow")) or {}
    local ai = try_require(mod_path(id, "ai")) or { wander_ids = {} }

    events.spawn_player = M.player_spawn_events(combat)

    local level = {
        id = id,
        flow = flow,
        stacks = stacks,
        events = events,
        combat = combat,
        dialogs = dialogs,
        ai = ai,
    }

    cache[id] = level

    return level
end

function M.default()
    return MAP_ID
end

return M
