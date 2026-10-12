-- gs_admin · V12.18 : écritures disque pour server/maps.js. Les FXServer récents interdisent au JavaScript d'écrire sur
-- le disque (« Access to this API has been restricted. Use --allow-fs-write ») : fusion des maps, « Retirer cette map »
-- et suppression passent donc par ici. Réservé à gs_admin, et seulement sous le dossier qui contient server-data.
local isWin = package.config:sub(1, 1) == '\\'
local function norm(p) p = tostring(p or ''):gsub('\\', '/'):gsub('/+', '/'); return isWin and p:lower() or p end
local ROOT = norm(GetResourcePath(GetCurrentResourceName())):gsub('/+$', '')
for _ = 1, 4 do ROOT = ROOT:match('^(.*)/[^/]+$') or ROOT end -- …/resources/[gtasoon]/gs_admin → dossier parent de server-data

local function allowed(p)
    local by = GetInvokingResource()
    if by and by ~= GetCurrentResourceName() then return false end -- seulement gs_admin (ou le serveur lui-même)
    local n = norm(p)
    return n:sub(1, #ROOT + 1) == ROOT .. '/' and not n:find('/%.%./') and not n:find('[\r\n"]')
end

local B = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function b64dec(s)
    s = s:gsub('[^%w%+/=]', '')
    return (s:gsub('.', function(c)
        if c == '=' then return '' end
        local v, r = B:find(c, 1, true) - 1, ''
        for i = 6, 1, -1 do r = r .. (v % 2 ^ i - v % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
        return string.char(c)
    end))
end

local function mkdirs(dir)
    if isWin then os.execute('mkdir "' .. dir:gsub('/', '\\') .. '" 2>nul') else os.execute('mkdir -p "' .. dir .. '"') end
end

local function fsWrite(p, b64)
    if not allowed(p) then return false end
    local f = io.open(p, 'wb')
    if not f then
        local dir = tostring(p):match('^(.*)[/\\]')
        if dir then mkdirs(dir) end
        f = io.open(p, 'wb')
    end
    if not f then return false end
    f:write(b64dec(b64 or '')); f:close()
    return true
end

local function fsRemove(p) -- fichier, ou dossier vide
    if not allowed(p) then return false end
    if os.remove(p) then return true end
    if isWin then os.execute('rmdir "' .. tostring(p):gsub('/', '\\') .. '" 2>nul') end
    return true
end

-- Événements LOCAUX au serveur (pas RegisterNetEvent : aucun joueur ne peut les déclencher). Un export appelé depuis le
-- JavaScript de la même ressource n'existe pas (« No such export ») ; l'événement local est synchrone, la réponse revient
-- par la fonction cb.
AddEventHandler('gs_admin:fsWrite', function(p, b64, cb) local ok = fsWrite(p, b64); if cb then cb(ok) end end)
AddEventHandler('gs_admin:fsRemove', function(p, cb) local ok = fsRemove(p); if cb then cb(ok) end end)
