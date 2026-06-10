local M = {}

local LEVELS = {
    "level1",
}

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

function M.load(id)
    if cache[id] then
        return cache[id]
    end

    local stacks = require(mod_path(id, "stacks"))
    local events = require(mod_path(id, "events"))
    local dialogs = try_require(mod_path(id, "dialog")) or {}
    local flow = try_require(mod_path(id, "flow")) or {}
    local ai = try_require(mod_path(id, "ai")) or {}

    local level = {
        id = id,
        flow = flow,
        stacks = stacks,
        events = events,
        dialogs = dialogs,
        ai = ai,
    }

    cache[id] = level

    return level
end

function M.default()
    return LEVELS[1]
end

return M
