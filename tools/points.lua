-- Extrait tous les points de carte des configs gs_* (vec3 / vec4) → tools/points.json (utilisé par tools/pdf.py).
-- Lancer depuis la racine : lua5.4 tools/points.lua
local R = 'server/resources/[gtasoon]/'
local function vec(x, y, z, w) return { __vec = true, x = x, y = y, z = z, w = w } end
local out = {}

local function labelOf(t, key)
    if type(t) ~= 'table' then return tostring(key) end
    return t.label or t.title or t.name or t.id or tostring(key)
end

local function walk(res, t, path, parent, depth)
    if depth > 8 or type(t) ~= 'table' then return end
    if t.__vec then
        out[#out + 1] = { res = res, path = path, label = parent, x = t.x, y = t.y, z = t.z }
        return
    end
    local label = labelOf(t, path:match('[^.]+$'))
    for k, v in pairs(t) do
        if type(v) == 'table' then walk(res, v, path .. '.' .. tostring(k), (type(k) == 'number' or k == 'coords' or k == 'pos' or k == 'spawn' or k == 'entrance' or k == 'counter' or k == 'arrival' or k == 'center' or k == 'clerk') and label or tostring(k), depth + 1) end
    end
end

local function load(res, files, globals)
    local env = setmetatable({ vec3 = vec, vector3 = vec, vec4 = vec, vector4 = vec, vec2 = vec, Config = {}, json = { encode = function() return '' end } }, { __index = _G })
    for _, f in ipairs(files) do
        local chunk = loadfile(R .. res .. '/' .. f, 't', env)
        if chunk then pcall(chunk) end
    end
    for _, g in ipairs(globals or { 'Config' }) do walk(res, env[g], res .. '.' .. g, res, 0) end
end

local p = io.popen('ls "' .. R .. '"')
for res in p:lines() do
    local f = io.open(R .. res .. '/shared/config.lua')
    if f then f:close() load(res, { 'shared/config.lua' }) end
end
p:close()
load('gs_jobs', { 'shared/jobs.lua' }, { 'Jobs' })
load('gs_quests', { 'shared/quests.lua' }, { 'Quests', 'Config' })

table.sort(out, function(a, b) if a.res ~= b.res then return a.res < b.res end return a.path < b.path end)
local fh = io.open('tools/points.json', 'w')
fh:write('[\n')
for i, e in ipairs(out) do
    fh:write(('  {"res": %q, "path": %q, "label": %q, "x": %.2f, "y": %.2f, "z": %.2f}%s\n'):format(e.res, e.path, e.label, e.x or 0, e.y or 0, e.z or 0, i < #out and ',' or ''))
end
fh:write(']\n')
fh:close()
print(#out .. ' points')
