--[[
  Combat + progression for bullet-hell loop.
  Scene wires Iso hooks; this module never calls Iso directly.
]]

local Combat = {}

local hooks

local PLAYER_ID = "pop"

local BASE = {
    max_hp = 120,
    damage = 12,
    fire_rate = 0.45,
    move_speed = 2,
    xp_to_level = 40,
}

local UPGRADES = {
  { key = "1", stat = "move_speed",  label = "Move Speed",  delta = 0.35 },
  { key = "2", stat = "damage",      label = "Attack Damage", delta = 4 },
  { key = "3", stat = "fire_rate",   label = "Fire Rate",   delta = -0.06 },
  { key = "4", stat = "max_hp",      label = "Max Health",  delta = 25 },
}

local HIT_RADIUS = 1.2
local MELEE_RANGE = 1.0
local SHOOT_RANGE = 7
local CHASE_RANGE = 12
local CHASE_REPATH = 0.8
local SHOT_DURATION = 0.4
local HIT_INVULN = 0.55

function Combat.init(h)
    hooks = h
end

local function default_player()
    return {
        hp = BASE.max_hp,
        max_hp = BASE.max_hp,
        damage = BASE.damage,
        fire_rate = BASE.fire_rate,
        move_speed = BASE.move_speed,
        level = 1,
        xp = 0,
        xp_to_next = BASE.xp_to_level,
        shoot_cd = 0,
        hit_invuln = 0,
    }
end

local function copy_player(src)
    if not src then
        return default_player()
    end

    local p = default_player()

    for k, v in pairs(src) do
        p[k] = v
    end

    p.shoot_cd = 0
    p.hit_invuln = 0

    if p.hp <= 0 then
        p.hp = p.max_hp
    end

    return p
end

local function register_enemy(enemies, def)
    enemies[def.id] = {
        hp = def.hp,
        max_hp = def.hp,
        damage = def.damage,
        fire_rate = def.fire_rate,
        speed = def.speed,
        xp = def.xp or 10,
        attack = def.attack or "melee",
        attack_cd = love.math.random() * def.fire_rate,
    }
end

function Combat.reset(world, carry_player)
    world.combat = {
        player = copy_player(carry_player),
        enemies = {},
        shots = {},
        upgrade_pending = false,
        dead = false,
    }

    Combat.apply_player_speed(world)
end

function Combat.start_wave(world, enemy_list)
    local c = world.combat

    if not c then
        return
    end

    c.shots = {}
    c.dead = false

    for _, def in ipairs(enemy_list or {}) do
        register_enemy(c.enemies, def)
    end
end

function Combat.clear_enemies(world)
    local c = world.combat

    if not c then
        return
    end

    for id in pairs(c.enemies) do
        hooks.remove_npc(id)
    end

    c.enemies = {}
    c.shots = {}
end

function Combat.player_stats(world)
    local c = world and world.combat

    return c and c.player
end

function Combat.apply_player_speed(world)
    local c = world.combat
    local piece = hooks.find_piece(PLAYER_ID)

    if piece and piece.npc and c then
        piece.npc.walkspeed = c.player.move_speed
    end
end

function Combat.enemy_count(world)
    local n = 0

    for _, e in pairs(world.combat.enemies) do
        if e.hp > 0 then
            n = n + 1
        end
    end

    return n
end

function Combat.is_upgrade_pending(world)
    return world.combat and world.combat.upgrade_pending
end

function Combat.is_dead(world)
    return world.combat and world.combat.dead
end

local function player_id()
    return PLAYER_ID
end

local function is_player(id)
    return id == PLAYER_ID
end

local function dist(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by

    return math.sqrt(dx * dx + dy * dy)
end

local function nearest_enemy(world)
    local player = hooks.find_piece(PLAYER_ID)

    if not player or player.pos_x == nil then
        return nil
    end

    local best_id
    local best_d = math.huge

    for id, e in pairs(world.combat.enemies) do
        if e.hp > 0 then
            local piece = hooks.find_piece(id)

            if piece and piece.pos_x ~= nil then
                local d = dist(player.pos_x, player.pos_y, piece.pos_x, piece.pos_y)

                if d < best_d then
                    best_d = d
                    best_id = id
                end
            end
        end
    end

  return best_id, best_d
end

local function shoot(world, npc_id, to_px, to_py, damage)
    local piece = hooks.find_piece(npc_id)

    if not piece or piece.pos_x == nil then
        return
    end

    world.combat.shots[#world.combat.shots + 1] = {
        owner_id = npc_id,
        from_px = piece.pos_x,
        from_py = piece.pos_y,
        to_px = to_px,
        to_py = to_py,
        damage = damage,
        duration = SHOT_DURATION,
        elapsed = 0,
        hit = false,
    }

    hooks.shoot(npc_id, to_px, to_py)
end

local function try_level_up(world)
    local p = world.combat.player

    while p.xp >= p.xp_to_next do
        p.xp = p.xp - p.xp_to_next
        p.level = p.level + 1
        p.xp_to_next = math.floor(BASE.xp_to_level * (1 + (p.level - 1) * 0.35))
        world.combat.upgrade_pending = true
    end
end

function Combat.apply_upgrade(world, index)
    local c = world.combat

    if not c.upgrade_pending then
        return false
    end

    local up = UPGRADES[index]

    if not up then
        return false
    end

    local p = c.player

    if up.stat == "max_hp" then
        p.max_hp = p.max_hp + up.delta
        p.hp = math.min(p.hp + up.delta, p.max_hp)
    elseif up.stat == "fire_rate" then
        p.fire_rate = math.max(0.12, p.fire_rate + up.delta)
    else
        p[up.stat] = p[up.stat] + up.delta
    end

    if up.stat == "move_speed" then
        Combat.apply_player_speed(world)
    end

    c.upgrade_pending = false

    return true
end

function Combat.upgrade_options()
    return UPGRADES
end

local function damage_player(world, amount)
    local p = world.combat.player

    if p.hit_invuln > 0 then
        return
    end

    p.hp = p.hp - amount
    p.hit_invuln = HIT_INVULN

    if p.hp <= 0 then
        p.hp = 0
        world.combat.dead = true
    end
end

local function tick_player(world, dt)
    local p = world.combat.player

    if p.hit_invuln > 0 then
        p.hit_invuln = math.max(0, p.hit_invuln - dt)
    end
end

local function damage_enemy(world, id, amount)
    local e = world.combat.enemies[id]

    if not e or e.hp <= 0 then
        return
    end

    e.hp = e.hp - amount

    if e.hp <= 0 then
        e.hp = 0
        world.combat.player.xp = world.combat.player.xp + (e.xp or 10)
        hooks.remove_npc(id)
        try_level_up(world)
    end
end

local function update_shots(world, dt)
    local c = world.combat
    local player = hooks.find_piece(PLAYER_ID)
    local i = 1

    while i <= #c.shots do
        local shot = c.shots[i]
        shot.elapsed = shot.elapsed + dt
        local t = math.min(1, shot.elapsed / shot.duration)
        local px = shot.from_px + (shot.to_px - shot.from_px) * t
        local py = shot.from_py + (shot.to_py - shot.from_py) * t

        if not shot.hit and not c.upgrade_pending then
            if is_player(shot.owner_id) then
                for id, e in pairs(c.enemies) do
                    if e.hp > 0 then
                        local piece = hooks.find_piece(id)

                        if piece and piece.pos_x ~= nil then
                            if dist(px, py, piece.pos_x, piece.pos_y) <= HIT_RADIUS then
                                shot.hit = true
                                damage_enemy(world, id, shot.damage)
                                break
                            end
                        end
                    end
                end
            elseif c.enemies[shot.owner_id]
                and c.enemies[shot.owner_id].attack == "ranged"
                and player
                and player.pos_x ~= nil
            then
                if dist(px, py, player.pos_x, player.pos_y) <= HIT_RADIUS then
                    shot.hit = true
                    damage_player(world, shot.damage)
                end
            end
        end

        if shot.elapsed >= shot.duration then
            table.remove(c.shots, i)
        else
            i = i + 1
        end
    end
end

local function update_player_shoot(world, dt)
    local c = world.combat
    local p = c.player

    p.shoot_cd = math.max(0, p.shoot_cd - dt)

    if p.shoot_cd > 0 or c.upgrade_pending or c.dead then
        return
    end

    local target_id = nearest_enemy(world)

    if not target_id then
        return
    end

    local target = hooks.find_piece(target_id)

    if not target or target.pos_x == nil then
        return
    end

    shoot(world, PLAYER_ID, target.pos_x, target.pos_y, p.damage)
    p.shoot_cd = p.fire_rate
end

local function update_enemies(world, dt)
    local c = world.combat
    local player = hooks.find_piece(PLAYER_ID)

    if not player or player.pos_x == nil or c.dead then
        return
    end

    for id, e in pairs(c.enemies) do
        if e.hp > 0 then
            local piece = hooks.find_piece(id)

            if not piece or piece.pos_x == nil then
                goto continue
            end

            local d = dist(player.pos_x, player.pos_y, piece.pos_x, piece.pos_y)

            if piece.npc then
                piece.npc.walkspeed = e.speed
            end

            e.attack_cd = math.max(0, e.attack_cd - dt)

            local strike_range = e.attack == "ranged" and SHOOT_RANGE or MELEE_RANGE

            if d <= strike_range then
                e.chase_px = nil
                e.chase_py = nil

                if e.attack_cd <= 0 and not c.upgrade_pending then
                    if e.attack == "ranged" then
                        shoot(world, id, player.pos_x, player.pos_y, e.damage)
                    else
                        damage_player(world, e.damage)
                    end

                    e.attack_cd = e.fire_rate
                end
            elseif d <= CHASE_RANGE then
                if not hooks.npc_busy(id) then
                    local repath = not e.chase_px
                        or dist(e.chase_px, e.chase_py, player.pos_x, player.pos_y)
                            >= CHASE_REPATH

                    if repath then
                        hooks.walk_to_pos(id, player.pos_x, player.pos_y)
                        e.chase_px = player.pos_x
                        e.chase_py = player.pos_y
                    end
                end
            else
                e.chase_px = nil
                e.chase_py = nil
            end

            ::continue::
        end
    end
end

function Combat.update(world, dt, active)
    if not world or not world.combat or not active then
        return
    end

    local c = world.combat

    tick_player(world, dt)

    if not c.dead and not c.upgrade_pending then
        update_player_shoot(world, dt)
        update_enemies(world, dt)
    end

    update_shots(world, dt)
end

function Combat.keypressed(world, key)
    if not world or not world.combat or not world.combat.upgrade_pending then
        return false
    end

    for i, up in ipairs(UPGRADES) do
        if key == up.key then
            Combat.apply_upgrade(world, i)
            return true
        end
    end

    return false
end

function Combat.player_id()
    return player_id()
end

return Combat
