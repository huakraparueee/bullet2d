--[[ orchestrator ]]

local gamestate = require("libraries.hump.gamestate")
local Iso = require("isolet2d")
local config = require("src.data.config")
local viewport = require("src.systems.viewport")
local Flow = require("src.systems.flow")
local Unit = require("src.systems.unit")
local AI = require("src.systems.ai")
local PlayUi = require("src.render.play")
local CurtainUI = require("src.scenes.curtain")
local DialogUI = require("src.scenes.dialog")
local MenuUI = require("src.scenes.menu")
local Maps = require("src.data.maps.loader")

local M = {}
M.map = nil

local default_flow_key = Maps.default()

local scenes = {
    play = M,
    menu = MenuUI,
}

local wired = false

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

        evs[#evs + 1] = ev
    end

    Iso.run_many(evs)
end

local function level_data(flow_key)
    return Maps.load(flow_key or Flow.flow_key())
end

local function flow_phases(flow_key)
    return Maps.load(flow_key).flow
end

function M:load_level(s)
    Iso.load_map({
        stack_chars = s.stacks.STACK_CHARS,
        stacks = s.stacks.STACKS,
        background = s.stacks.BACKGROUND,
        map_offset_y = config.MAP_OFFSET_Y,
    })

    self.map = {
        id = s.id,
        events = s.events,
        flow = s.flow,
        dialogs = s.dialogs,
        started = false,
    }

    Unit.spawn(self.map, { npc_id = "pop" })
    AI.reset()
    AI.register(self.map, s.ai.wander_ids)
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
            on_switch = function()
                M.pan_drag = false
                M:load_level(level_data())
                Iso.camera.reset()
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
    end

    if opts.continue_flow then
        Flow.queue_flush()
        Flow.flush()
        return
    end

    if opts.boot then
        self.pan_drag = false
        Iso.camera.reset()
        Flow.boot(opts.flow_key or default_flow_key)
        self:load_level(level_data())
        Flow.queue_flush()
        Flow.flush()
    end
end

function M:update(dt)
    Flow.tick_after_switch()
    CurtainUI.update(dt)

    local map = self.map

    if not map then
        return
    end

    Iso.tick(dt)
    Unit.update(map, dt)
    AI.update(map, dt)

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

    if Unit.keypressed(map, key) then
        return
    end

    local move_delta = {
        left = -1,
        up = -1,
        right = 1,
        down = 1,
    }

    if move_delta[key] then
        if map.started
            and not map.finished
            and Flow.can_use_actions()
        then

        end

        return
    end

    if key == "r" then
        gamestate.switch(M, {
            boot = true,
            flow_key = self.flow_key or default_flow_key,
        })
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

    if self.map then

    end

    CurtainUI.draw()

    viewport.finish()
end

return M
