--[[
  Combat + progression for bullet-hell loop.
  Scene wires Iso hooks; this module never calls Iso directly.
]]

local Combat = {}

local hooks

local PLAYER_ID = "pop"

local BASE = {
    max_hp = 100,
    damage = 12,
    fire_rate = 0.45,
    move_speed = 2,
    xp_to_level = 100,
    xp_level_scale = 0.1,
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
local CHASE_REPATH = 1.5
local HIT_INVULN = 0.55
local MAX_ACTIVE_SHOTS = 100
local HIT_RADIUS_SQ = HIT_RADIUS * HIT_RADIUS
local PHASES_PER_SHOT = 5

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
        shot_count = 1,
    }
end

local function shot_count_for_phase(phase)
    phase = phase or 1

    return 1 + math.floor(phase / PHASES_PER_SHOT)
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

local function register_enemy(c, def)
    local attack = def.attack or "melee"

    c.enemies[def.id] = {
        hp = def.hp,
        max_hp = def.hp,
        damage = def.damage,
        fire_rate = def.fire_rate,
        speed = def.speed,
        xp = def.xp or 10,
        attack = attack,
        kind = def.kind,
        facing = def.facing or "se",
        projectile = def.projectile or (attack == "ranged" and "bolt" or nil),
        attack_cd = love.math.random() * def.fire_rate,
    }
    c.enemy_ids[#c.enemy_ids + 1] = def.id
end

local function remove_enemy_entry(c, id)
    c.enemies[id] = nil

    for i, eid in ipairs(c.enemy_ids) do
        if eid == id then
            c.enemy_ids[i] = c.enemy_ids[#c.enemy_ids]
            c.enemy_ids[#c.enemy_ids] = nil
            return
        end
    end
end

function Combat.reset(world, carry_player)
    world.combat = {
        player = copy_player(carry_player),
        enemies = {},
        enemy_ids = {},
        upgrade_pending = false,
        dead = false,
    }

    Combat.apply_player_speed(world)
end

function Combat.start_wave(world, enemy_list, phase)
    local c = world.combat

    if not c then
        return
    end

    c.dead = false
    c.player.shot_count = shot_count_for_phase(phase)

    for _, def in ipairs(enemy_list or {}) do
        register_enemy(c, def)
    end
end

function Combat.clear_enemies(world)
    local c = world.combat

    if not c then
        return
    end

    for id in pairs(c.enemies) do
        hooks.retire_npc(id)
    end

    c.enemies = {}
    c.enemy_ids = {}
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

    for _, id in ipairs(world.combat.enemy_ids) do
        local e = world.combat.enemies[id]

        if e and e.hp > 0 then
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

local function dist_sq(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by

    return dx * dx + dy * dy
end

local function dist(ax, ay, bx, by)
    return math.sqrt(dist_sq(ax, ay, bx, by))
end

local function nearest_enemies(world, count)
    local player = hooks.find_piece(PLAYER_ID)

    if not player or player.pos_x == nil or count <= 0 then
        return {}
    end

    local ranked = {}

    for _, id in ipairs(world.combat.enemy_ids) do
        local e = world.combat.enemies[id]

        if e and e.hp > 0 then
            local piece = hooks.find_piece(id)

            if piece
                and not piece._pooled
                and piece.pos_x ~= nil
            then
                ranked[#ranked + 1] = {
                    id = id,
                    d = dist(player.pos_x, player.pos_y, piece.pos_x, piece.pos_y),
                }
            end
        end
    end

    table.sort(ranked, function(a, b)
        return a.d < b.d
    end)

    local out = {}

    for i = 1, math.min(count, #ranked) do
        out[i] = ranked[i].id
    end

    return out
end

local function shoot(world, npc_id, to_px, to_py, damage, projectile_kind)
    if not hooks.spawn_projectile then
        return
    end

    if hooks.projectile_count() >= MAX_ACTIVE_SHOTS then
        return
    end

    local piece = hooks.find_piece(npc_id)

    if not piece or piece.pos_x == nil then
        return
    end

    local kind = projectile_kind

    if is_player(npc_id) then
        kind = "arrow"
    end

    hooks.spawn_projectile(npc_id, to_px, to_py, {
        owner_id = npc_id,
        damage = damage,
        kind = kind or "bolt",
    })
end

local function try_level_up(world)
    local p = world.combat.player

    while p.xp >= p.xp_to_next do
        p.xp = p.xp - p.xp_to_next
        p.level = p.level + 1
        p.xp_to_next = math.floor(
            BASE.xp_to_level * (1 + (p.level - 1) * BASE.xp_level_scale)
        )
        world.combat.upgrade_pending = true
        world.combat.dead = false
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

    p.hp = p.max_hp
    c.upgrade_pending = false
    try_level_up(world)

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
        world.combat.player.xp = world.combat.player.xp + (e.xp or 10)
        hooks.retire_npc(id)
        remove_enemy_entry(world.combat, id)
        try_level_up(world)
    end
end

local function update_projectile_hits(world)
    local c = world.combat

    if c.upgrade_pending or not hooks.each_projectile then
        return
    end

    local player = hooks.find_piece(PLAYER_ID)

    hooks.each_projectile(function(proj)
        local meta = proj.meta

        if not meta or meta.hit then
            return
        end

        local px = proj.px
        local py = proj.py

        if px == nil or py == nil then
            return
        end

        if is_player(meta.owner_id) then
            for _, id in ipairs(c.enemy_ids) do
                local e = c.enemies[id]

                if e and e.hp > 0 then
                    local piece = hooks.find_piece(id)

                    if piece
                        and not piece._pooled
                        and piece.pos_x ~= nil
                    then
                        if dist_sq(px, py, piece.pos_x, piece.pos_y) <= HIT_RADIUS_SQ then
                            meta.hit = true
                            damage_enemy(world, id, meta.damage)
                            return
                        end
                    end
                end
            end

            return
        end

        if c.enemies[meta.owner_id]
            and c.enemies[meta.owner_id].attack == "ranged"
            and player
            and player.pos_x ~= nil
        then
            if dist_sq(px, py, player.pos_x, player.pos_y) <= HIT_RADIUS_SQ then
                meta.hit = true
                damage_player(world, meta.damage)
            end
        end
    end)
end

local function update_player_shoot(world, dt)
    local c = world.combat
    local p = c.player

    p.shoot_cd = math.max(0, p.shoot_cd - dt)

    if p.shoot_cd > 0 or c.upgrade_pending or c.dead then
        return
    end

    local targets = nearest_enemies(world, p.shot_count or 1)

    if #targets == 0 then
        return
    end

    local fired = 0
    local shots = p.shot_count or 1

    for i = 1, shots do
        if hooks.projectile_count() >= MAX_ACTIVE_SHOTS then
            break
        end

        local target_id = targets[((i - 1) % #targets) + 1]
        local target = hooks.find_piece(target_id)

        if target and target.pos_x ~= nil then
            shoot(world, PLAYER_ID, target.pos_x, target.pos_y, p.damage)
            fired = fired + 1
        end
    end

    if fired > 0 then
        p.shoot_cd = p.fire_rate
    end
end

local function update_enemies(world, dt)
    local c = world.combat
    local player = hooks.find_piece(PLAYER_ID)

    if not player or player.pos_x == nil or c.dead then
        return
    end

    for _, id in ipairs(c.enemy_ids) do
        local e = c.enemies[id]

        if e and e.hp > 0 then
            local piece = hooks.find_piece(id)

            if not piece or piece._pooled or piece.pos_x == nil then
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
                        shoot(
                            world,
                            id,
                            player.pos_x,
                            player.pos_y,
                            e.damage,
                            e.projectile
                        )
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

    update_projectile_hits(world)
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

local function copy_player_state(p)
    local out = {}

    for k, v in pairs(p or {}) do
        out[k] = v
    end

    return out
end

local function copy_enemy_state(e)
    if not e then
        return nil
    end

    return {
        hp = e.hp,
        max_hp = e.max_hp,
        damage = e.damage,
        fire_rate = e.fire_rate,
        speed = e.speed,
        xp = e.xp,
        attack = e.attack,
        kind = e.kind,
        facing = e.facing,
        projectile = e.projectile,
        attack_cd = e.attack_cd,
        chase_px = e.chase_px,
        chase_py = e.chase_py,
    }
end

function Combat.snapshot(world)
    local c = world and world.combat

    if not c then
        return nil
    end

    local enemies = {}
    local enemy_ids = {}

    for _, id in ipairs(c.enemy_ids) do
        enemy_ids[#enemy_ids + 1] = id
        enemies[id] = copy_enemy_state(c.enemies[id])
    end

    return {
        player = copy_player_state(c.player),
        enemies = enemies,
        enemy_ids = enemy_ids,
        upgrade_pending = c.upgrade_pending,
        dead = c.dead,
    }
end

function Combat.restore(world, data)
    if not world or not data then
        return
    end

    local enemies = {}
    local enemy_ids = {}

    for _, id in ipairs(data.enemy_ids or {}) do
        enemy_ids[#enemy_ids + 1] = id
        enemies[id] = copy_enemy_state(data.enemies[id])
    end

    world.combat = {
        player = copy_player_state(data.player),
        enemies = enemies,
        enemy_ids = enemy_ids,
        upgrade_pending = data.upgrade_pending == true,
        dead = data.dead == true,
    }

    Combat.apply_player_speed(world)
end

return Combat
