--[[ orchestrator ]]

local gamestate = require("libraries.hump.gamestate")
local Iso = require("isolet2d")
local config = require("src.data.config")
local viewport = require("src.systems.viewport")
local Flow = require("src.systems.flow")
local Unit = require("src.systems.unit")
local AI = require("src.systems.ai")
local Combat = require("src.systems.combat")
local PlayUi = require("src.render.play")
local CurtainUI = require("src.scenes.curtain")
local DialogUI = require("src.scenes.dialog")
local MenuUI = require("src.scenes.menu")
local Maps = require("src.data.maps.loader")
local Audio = require("src.systems.audio")

local M = {}
M.map = nil
M.carry_player = nil
M.saved_run = nil
M.death_count = 0

local default_flow_key = Maps.default()

local scenes = {
    play = M,
    menu = MenuUI,
}

local wired = false

local WAVE_CLEAR_DELAY = 0.75
local SPAWN_INTERVAL = 0.08
local RETIRE_BATCH = 8

local function walk_npc_to(id, px, py)
    if not px or Iso.is_npc_anim_busy(id) then
        return false
    end

    Iso.run({
        type = "npc.walk_to",
        id = id,
        pos_x = px,
        pos_y = py,
    })

    return true
end

local function append_event_steps(evs, ev)
    if ev[1] and not ev.type then
        for _, step in ipairs(ev) do
            evs[#evs + 1] = step
        end

        return
    end

    evs[#evs + 1] = ev
end

local function fire_event_ids(ids)
    if not M.map then
        return
    end

    local evs = {}

    for _, id in ipairs(ids) do
        local ev = M.map.events[id]

        if not ev then
            error("play: unknown event " .. tostring(id))
        end

        append_event_steps(evs, ev)
    end

    if #evs > 0 then
        Iso.run_many(evs)
    end
end

function M.apply_map_init()
    if M.map and M.map.events and M.map.events.init then
        fire_event_ids({ "init" })
    end
end

local function level_data(flow_key)
    return Maps.load(flow_key or Flow.flow_key())
end

local function flow_phases(flow_key)
    return Maps.load(flow_key).flow
end

local function copy_event(ev)
    local out = { type = ev.type }

    for k, v in pairs(ev) do
        out[k] = v
    end

    return out
end

local function copy_spawn_queue(queue)
    if not queue then
        return nil
    end

    local out = {}

    for i, ev in ipairs(queue) do
        out[i] = copy_event(ev)
    end

    return out
end

local function copy_id_list(ids)
    if not ids then
        return nil
    end

    local out = {}

    for i, id in ipairs(ids) do
        out[i] = id
    end

    return out
end

local function npc_anchor(piece)
    if not piece or not piece.npc or piece._pooled or piece.pos_x == nil then
        return nil
    end

    local w = piece.tiles_w or 1
    local d = piece.tiles_d or 1

    return {
        id = piece.npc_id,
        kind = piece.npc.kind,
        facing = piece.npc.facing,
        tile_x = math.floor(piece.pos_x - w * 0.5 + 0.0001),
        tile_y = math.floor(piece.pos_y - d * 0.5 + 0.0001),
    }
end

local function collect_npc_anchors(ids)
    local out = {}

    for _, id in ipairs(ids) do
        local anchor = npc_anchor(Iso.find_by_id(id))

        if anchor then
            out[#out + 1] = anchor
        end
    end

    return out
end

local function place_npc_anchors(anchors)
    local evs = {}

    for _, n in ipairs(anchors or {}) do
        evs[#evs + 1] = {
            type = "npc.place",
            id = n.id,
            kind = n.kind,
            tile_x = n.tile_x,
            tile_y = n.tile_y,
            facing = n.facing or "se",
            mode = "stand",
        }
    end

    if #evs > 0 then
        Iso.run_many(evs)
    end
end

function M.has_saved_run()
    return M.saved_run ~= nil
end

function M:load_map_shell(s)
    Iso.load_map({
        stack_chars = s.stacks.STACK_CHARS,
        stacks = s.stacks.STACKS,
        background = s.stacks.BACKGROUND,
        map_offset_y = config.MAP_OFFSET_Y,
    })

    self.level_data = s
    self.map = {
        id = s.id,
        events = s.events,
        flow = s.flow,
        dialogs = s.dialogs,
        phase = 0,
        started = false,
        wave_state = "idle",
    }

    Unit.spawn(self.map, { npc_id = Combat.player_id() })
    AI.reset()
    AI.register(self.map, s.ai.wander_ids)
end

function M:load_level(s)
    self:load_map_shell(s)
    Combat.reset(self.map, self.carry_player)
end

function M:build_snapshot()
    local map = self.map

    if not map or not map.combat then
        return nil
    end

    if Combat.is_dead(map) and not Combat.is_upgrade_pending(map) then
        return nil
    end

    if CurtainUI.active() then
        return nil
    end

    local npc_ids = { Combat.player_id() }

    for _, id in ipairs(map.combat.enemy_ids) do
        npc_ids[#npc_ids + 1] = id
    end

    return {
        flow_key = map.id or default_flow_key,
        phase = map.phase,
        wave_state = map.wave_state,
        started = map.started,
        wave_clear_timer = map.wave_clear_timer,
        next_phase = map.next_phase,
        spawn_queue = copy_spawn_queue(self.spawn_queue),
        spawn_i = self.spawn_i,
        spawn_timer = self.spawn_timer,
        retire_ids = copy_id_list(self.retire_ids),
        retire_i = self.retire_i,
        combat = Combat.snapshot(map),
        npcs = collect_npc_anchors(npc_ids),
        camera_pan_x = Iso.camera.pan_x,
        camera_pan_y = Iso.camera.pan_y,
        death_count = self.death_count or 0,
    }
end

function M:restore_run(snapshot)
    local s = level_data(snapshot.flow_key or default_flow_key)

    self:load_map_shell(s)
    M.apply_map_init()

    local map = self.map

    map.phase = snapshot.phase or 0
    map.started = snapshot.started == true
    map.wave_state = snapshot.wave_state or "idle"
    map.wave_clear_timer = snapshot.wave_clear_timer
    map.next_phase = snapshot.next_phase

    Combat.restore(map, snapshot.combat)

    if map.combat and map.combat.upgrade_pending then
        map.combat.dead = false
        Iso.clear_projectiles()
    end

    self.carry_player = Combat.player_stats(map)

    local anchors = snapshot.npcs or {}

    if #anchors == 0 then
        local spawn = s.combat and s.combat.player_spawn

        if spawn then
            anchors = {
                {
                    id = spawn.id,
                    kind = spawn.kind,
                    facing = spawn.facing or "se",
                    tile_x = spawn.tile_x,
                    tile_y = spawn.tile_y,
                },
            }
        end
    end

    place_npc_anchors(anchors)

    self.spawn_queue = copy_spawn_queue(snapshot.spawn_queue)
    self.spawn_i = snapshot.spawn_i or 1
    self.spawn_timer = snapshot.spawn_timer or 0
    self.retire_ids = snapshot.retire_ids
    self.retire_i = snapshot.retire_i or 1
    self.pan_drag = false

    Iso.camera.pan_x = snapshot.camera_pan_x or 0
    Iso.camera.pan_y = snapshot.camera_pan_y or 0
    Iso.camera.clamp()

    self.death_count = snapshot.death_count or 0
end

function M:save_and_exit()
    local snapshot = self:build_snapshot()

    if not snapshot then
        return false
    end

    M.saved_run = snapshot
    gamestate.switch(scenes.menu)

    return true
end

function M:begin_wave_spawn(phase)
    local map = self.map
    local data = self.level_data

    if not map or not data then
        return
    end

    Iso.clear_projectiles()
    Combat.clear_enemies(map)

    local enemies = Maps.phase_enemies(phase, data.combat)

    Combat.start_wave(map, enemies, phase)

    self.spawn_queue = Maps.enemy_spawn_events(enemies)
    self.spawn_i = 1
    self.spawn_timer = 0
    self.retire_ids = Maps.enemy_slot_ids()
    self.retire_i = 1

    map.phase = phase
    map.wave_state = "retiring"
    map.started = false
end

function M:queue_next_wave(phase)
    local map = self.map

    if not map or Combat.is_upgrade_pending(map) then
        return
    end

    map.next_phase = phase
    map.wave_state = "between"
    map.wave_clear_timer = WAVE_CLEAR_DELAY
    map.started = false
end

local function tick_wave(self, dt)
    local map = self.map

    if not map then
        return
    end

    if map.wave_state == "between" then
        map.wave_clear_timer = map.wave_clear_timer - dt

        if map.wave_clear_timer <= 0 then
            self:begin_wave_spawn(map.next_phase)
        end

        return
    end

    if map.wave_state == "retiring" then
        local ids = self.retire_ids
        local batch = {}

        if ids then
            for _ = 1, RETIRE_BATCH do
                if self.retire_i > #ids then
                    break
                end

                batch[#batch + 1] = {
                    type = "npc.retire",
                    id = ids[self.retire_i],
                }
                self.retire_i = self.retire_i + 1
            end
        end

        if #batch > 0 then
            Iso.run_many(batch)
        end

        if not ids or self.retire_i > #ids then
            self.retire_ids = nil
            self.retire_i = 1
            map.wave_state = "spawning"
            map.started = true
            self.spawn_timer = 0
        end

        return
    end

    if map.wave_state ~= "spawning" then
        return
    end

    local queue = self.spawn_queue

    if not queue or self.spawn_i > #queue then
        map.wave_state = "playing"
        self.spawn_queue = nil
        return
    end

    self.spawn_timer = self.spawn_timer - dt

    if self.spawn_timer <= 0 and self.spawn_i <= #queue then
        Iso.run(queue[self.spawn_i])
        self.spawn_i = self.spawn_i + 1
        self.spawn_timer = SPAWN_INTERVAL
    end
end

function M.start(flow_key)
    gamestate.switch(M, {
        boot = true,
        flow_key = flow_key or default_flow_key,
    })
end

function M:enter(_, opts)
    opts = opts or {}

    if not wired then
        wired = true

        Iso.init({
            design_width = config.DESIGN_WIDTH,
            design_height = config.DESIGN_HEIGHT,
            grid_origin_x = config.GRID_ORIGIN_X,
            grid_origin_y = config.GRID_ORIGIN_Y,
            map_offset_y = config.MAP_OFFSET_Y,
            tile_size = config.TILE_SIZE,
            iso_x_ratio = config.ISO_X_RATIO,
            iso_y_ratio = config.ISO_Y_RATIO,
            iso_eh_ratio = config.ISO_EH_RATIO,
            terrain_mats = config.TERRAIN_MATS,
            structures = config.STRUCTURES,
            npcs = config.NPCS,
            projectiles = config.PROJECTILES,
            grid_point_per_tile = config.GRID_POINT_PER_TILE,
            debug_draw_map = config.DEBUG_DRAW_MAP,
        })

        AI.init({
            each_npc_piece = function(fn)
                Iso.each_npc_piece(fn)
            end,
            find_piece = function(id)
                return Iso.find_by_id(id)
            end,
            npc_anim_busy = function(npc_id)
                return Iso.is_npc_anim_busy(npc_id)
            end,
            pick_placement_near = function(px, py)
                local node = Iso.pick_placement_near(px, py, 6)

                if node then
                    return node.px, node.py
                end
            end,
            walk_to_pos = function(id, px, py)
                walk_npc_to(id, px, py)
            end,
            set_mode = function(id, mode)
                Iso.run({
                    type = "npc.set_mode",
                    id = id,
                    mode = mode,
                })
            end,
        })

        Combat.init({
            find_piece = function(id)
                return Iso.find_by_id(id)
            end,
            projectile_count = function()
                return Iso.projectile_count()
            end,
            each_projectile = function(fn)
                Iso.each_projectile(fn)
            end,
            spawn_projectile = function(owner_id, to_px, to_py, meta)
                meta = meta or {}
                local kind = meta.kind or "arrow"
                local def = config.PROJECTILES[kind] or config.PROJECTILES.arrow

                if owner_id == Combat.player_id() then
                    Audio.play("fire")
                end

                Iso.run({
                    type = "projectile.spawn",
                    kind = kind,
                    from = { npc_id = owner_id },
                    to = { px = to_px, py = to_py },
                    move = def.move,
                    duration = def.duration,
                    arc_height = def.arc_height,
                    meta = meta,
                })
            end,
            walk_to_pos = function(id, px, py)
                return walk_npc_to(id, px, py)
            end,
            npc_busy = function(npc_id)
                return Iso.is_npc_anim_busy(npc_id)
            end,
            retire_npc = function(id)
                Iso.run({
                    type = "npc.retire",
                    id = id,
                })
            end,
        })

        Unit.init({
            walk_npc = function(dx, dy, id)
                local piece = Iso.find_by_id(id)

                if not piece or piece.pos_x == nil or piece.pos_y == nil then
                    return false
                end

                if dx == 0 and dy == 0 then
                    return false
                end

                local node = Iso.try_step_neighbor(piece.pos_x, piece.pos_y, dx, dy)

                if not node then
                    return false
                end

                return walk_npc_to(id, node.px, node.py)
            end,
            npc_busy = function(npc_id)
                return Iso.is_npc_anim_busy(npc_id)
            end,
            sync_tile = function(world)
                local id = world.unit and world.unit.controlled_npc_id

                if not id then
                    return
                end

                local piece = Iso.find_by_id(id)

                if piece then
                    local w = piece.tiles_w or 1
                    local d = piece.tiles_d or 1

                    if piece.pos_x ~= nil and piece.pos_y ~= nil then
                        Unit.set_tile(
                            world,
                            math.floor(piece.pos_x - w * 0.5 + 0.0001),
                            math.floor(piece.pos_y - d * 0.5 + 0.0001)
                        )
                    end
                end
            end,
            walk_to_placement = function(ix, iy, id)
                local px, py = Iso.placement_pos(ix, iy)

                return walk_npc_to(id, px, py)
            end,
        })

        Flow.init(M, {
            default_flow_key = default_flow_key,
            flows = setmetatable({}, {
                __index = function(_, key)
                    return flow_phases(key)
                end,
            }),
            is_scene_active = function()
                return gamestate.current() == M
            end,
            resume_scene = function()
                gamestate.switch(M, { continue_flow = true })
            end,
        })

        Flow.add("back_to_menu", function()
            gamestate.switch(scenes.menu)
        end)

        Flow.add("map", function(block)
            if block.command == "event" then
                if not block.id then
                    error("play: map event requires id")
                end

                fire_event_ids({ block.id })

                Flow.set_map_wait("event")
                return
            end

            if block.command == "start" then
                if M.map then
                    M.map.started = true
                end

                Flow.set_map_wait("play")
                return
            end

            error("play: unknown map command " .. tostring(block.command))
        end)

        Flow.add("events", function(block)
            if not block.ids then
                error("play: events block requires ids")
            end

            fire_event_ids(block.ids)
            Flow.set_map_wait("event")
        end)

        Flow.add("dialog", function(block, done)
            Flow.clear_map_wait()

            local data = level_data()
            local spec = data and data.dialogs[block.key]

            if not spec or not spec.lines or #spec.lines == 0 then
                done()
                return
            end

            DialogUI.open({
                lines = spec.lines,
                image = spec.image,
                on_done = done,
            })
        end)

        Flow.add("curtain_open", function(_, done)
            CurtainUI.open_transition(done)
        end)

        Flow.add("curtain_close", function(_, done)
            CurtainUI.close_transition(done)
        end)

        Flow.add("start_wave", function(block, done)
            M:begin_wave_spawn(block.phase or 1)
            done()
        end)
    end

    if opts.continue_flow then
        Flow.queue_flush()
        Flow.flush()
        return
    end

    if opts.resume then
        self.pan_drag = false
        self.gameover_sfx_played = false
        self:restore_run(opts.resume)
        Audio.play_music("background")
        return
    end

    if opts.boot then
        self.pan_drag = false
        self.gameover_sfx_played = false
        Iso.camera.reset()
        Flow.boot(opts.flow_key or default_flow_key)
        self:load_level(level_data(opts.flow_key or default_flow_key))
        Flow.queue_flush()
        Flow.flush()
        Audio.play_music("background")
    end
end

local function input_blocked(map)
    return Combat.is_upgrade_pending(map)
        or Combat.is_dead(map)
end

local function sim_paused(map)
    return Combat.is_upgrade_pending(map)
        or Combat.is_dead(map)
end

local function sync_input(map)
    Unit.set_input_enabled(map, not input_blocked(map))
end

local function sync_sim(map)
    local paused = sim_paused(map)

    Iso.set_npc_paused(paused)
    Iso.set_structure_paused(paused)
    Iso.set_projectile_paused(paused)
end

local function tick_gameover(self, map)
    if not map or not Combat.is_dead(map) or Combat.is_upgrade_pending(map) then
        return
    end

    M.saved_run = nil

    if not self.gameover_sfx_played then
        self.gameover_sfx_played = true
        self.death_count = (self.death_count or 0) + 1
        Audio.stop_music()
        Audio.play("gameover")
    end
end

local function combat_wave_active(map)
    if not map or not map.started then
        return false
    end

    return map.wave_state == "playing" or map.wave_state == "spawning"
end

local function tick_combat(map, dt)
    if not combat_wave_active(map) then
        return
    end

    if Combat.is_dead(map) then
        return
    end

    Combat.apply_player_speed(map)
    Combat.update(map, dt, true)

    if Combat.enemy_count(map) == 0
        and not Combat.is_upgrade_pending(map)
        and map.wave_state == "playing"
    then
        M.carry_player = Combat.player_stats(map)
        M:queue_next_wave(map.phase + 1)
    end
end

function M:update(dt)
    Flow.tick_after_switch()
    CurtainUI.update(dt)

    local map = self.map

    if not map then
        return
    end

    sync_input(map)
    sync_sim(map)
    Iso.tick(dt)
    tick_wave(self, dt)
    Unit.update(map, dt)
    AI.update(map, dt)
    tick_combat(map, dt)
    tick_gameover(self, map)

    Flow.tick_map_wait(map, false)
end

function M:keypressed(key, _, isrepeat)
    if isrepeat then
        return
    end

    local map = self.map

    if not map then
        return
    end

    if key == "escape" then
        self:save_and_exit()
        return
    end

    if Combat.keypressed(map, key) then
        Audio.play("choose")
        return
    end

    if Unit.keypressed(map, key) then
        return
    end

    if key == "r" then
        if Combat.is_dead(map) then
            M.carry_player = Combat.player_stats(map)
            Combat.reset(map, M.carry_player)
            Unit.spawn(map, { npc_id = Combat.player_id() })
            self.gameover_sfx_played = false
            M:begin_wave_spawn(map.phase)
            Audio.play_music("background")
        end

        return
    end
end

function M:mousepressed(sx, sy, button)
    local map = self.map

    if not map then
        return
    end

    local dx, dy = viewport.screen_to_design(sx, sy)

    local q = Iso.query_at_design(dx, dy)

    if q then
        Unit.try_walk_query(map, q)
    end
end

function M:mousereleased(_, _, button)
    if button == 2 or button == 3 then
        self.pan_drag = false
    end
end

function M:mousemoved(sx, sy, _, _)
    if not self.pan_drag then
        return
    end

    local dx = (sx - self.pan_last_x) / viewport.scale
    local dy = (sy - self.pan_last_y) / viewport.scale

    Iso.camera.pan(dx, dy)
    self.pan_last_x = sx
    self.pan_last_y = sy
end

function M:draw()
    viewport.begin()

    Iso.draw_map()

    if self.map and self.map.combat then
        PlayUi.draw_hud({
            combat = self.map.combat,
            phase = self.map.phase,
            enemy_count = Combat.enemy_count(self.map),
            death_count = self.death_count or 0,
        })
        PlayUi.draw_upgrade({
            upgrade_pending = Combat.is_upgrade_pending(self.map),
            upgrade_options = Combat.upgrade_options(),
        })
        PlayUi.draw_game_over({
            dead = Combat.is_dead(self.map)
                and not Combat.is_upgrade_pending(self.map),
            death_count = self.death_count or 0,
        })
    end

    CurtainUI.draw()

    viewport.finish()
end

return M
