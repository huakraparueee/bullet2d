--[[
  Game audio — preload and play SFX / music from config paths.
  Scene modules call this; no isolet2d dependency.
]]

local Audio = {}

local sources = {}
local music
local active = {}
local last_play = {}

local function spec(id)
    return sources[id]
end

local function prune_active(id)
    local list = active[id]

    if not list then
        return
    end

    local kept = {}
    local n = 0

    for _, inst in ipairs(list) do
        if inst:isPlaying() then
            n = n + 1
            kept[n] = inst
        end
    end

    active[id] = kept
end

function Audio.stop_all()
    if music then
        music:stop()
        music = nil
    end

    for _, entry in pairs(sources) do
        if entry.source then
            entry.source:stop()
        end
    end

    love.audio.stop()
    sources = {}
    active = {}
    last_play = {}
end

function Audio.preload(defs)
    Audio.stop_all()

    for id, def in pairs(defs or {}) do
        local src = love.audio.newSource(def.path, def.stream and "stream" or "static")

        src:setVolume(def.volume or 1)
        sources[id] = {
            source = src,
            volume = def.volume or 1,
            music = def.music == true,
            min_interval = def.min_interval,
            max_instances = def.max_instances,
        }
    end
end

function Audio.play(id)
    local entry = spec(id)

    if not entry or entry.music then
        return
    end

    prune_active(id)

    local now = love.timer.getTime()

    if entry.min_interval and last_play[id] then
        if now - last_play[id] < entry.min_interval then
            return
        end
    end

    local max_instances = entry.max_instances or 12
    local playing = active[id] or {}

    if #playing >= max_instances then
        return
    end

    local inst = entry.source:clone()
    inst:setVolume(entry.volume)
    inst:play()

    last_play[id] = now
    playing[#playing + 1] = inst
    active[id] = playing
end

function Audio.play_music(id)
    local entry = spec(id)

    if not entry then
        return
    end

    if music then
        music:stop()
        music = nil
    end

    music = entry.source
    music:setLooping(true)
    music:setVolume(entry.volume)
    music:play()
end

function Audio.stop_music()
    if music then
        music:stop()
        music = nil
    end
end

return Audio
