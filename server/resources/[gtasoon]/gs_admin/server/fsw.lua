-- gs_admin · V12.18 : écritures disque pour server/maps.js. Les FXServer récents interdisent au JavaScript d'écrire sur
-- le disque (« Access to this API has been restricted. Use --allow-fs-write ») : fusion des maps, « Retirer cette map »
-- et suppression passent donc par ici. Réservé à gs_admin, et seulement sous le dossier qui contient server-data.
-- V12.23 : écriture par SaveResourceFile (API FiveM) d'abord, io.open ensuite.
-- V12.21 : rien n'est calculé au chargement (une erreur ici empêchait tout le fichier de se charger) ; chaque demande
-- répond (ok, message d'erreur) par la fonction cb.
local SELF = GetCurrentResourceName()
local ROOT, isWin

local function norm(p)
    p = tostring(p or ''):gsub('\\', '/'):gsub('/+', '/')
    if isWin then p = p:lower() end
    return p
end

local function setup()
    if ROOT then return end
    local here = tostring(GetResourcePath(SELF) or '')
    isWin = here:find('^%a:') ~= nil or here:find('\\', 1, true) ~= nil -- C:\… = Windows
    local r = norm(here):gsub('/+$', '')
    for _ = 1, 4 do r = r:match('^(.*)/[^/]+$') or r end -- …/resources/[gtasoon]/gs_admin → dossier parent de server-data
    ROOT = r
end

local function allowed(p)
    local by = GetInvokingResource()
    if by and by ~= SELF then return false, 'demande venue de ' .. tostring(by) end
    local n = norm(p)
    if n:sub(1, #ROOT + 1) ~= ROOT .. '/' or n:find('/%.%./') or n:find('[\r\n"]') then
        return false, 'chemin hors de ' .. ROOT .. ' : ' .. n
    end
    return true
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

-- Ressource qui contient ce chemin → (nom, chemin relatif). SaveResourceFile est l'API officielle de FiveM pour écrire dans
-- une ressource : elle passe quand io.open et le JavaScript sont bloqués (V12.23, constaté sur le serveur du 12/10).
local function inResource(p)
    local plain = tostring(p):gsub('\\', '/'):gsub('/+', '/')
    local n = norm(p)
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        local rp = name and GetResourcePath(name)
        if rp and rp ~= '' then
            rp = norm(rp):gsub('/+$', '')
            if n:sub(1, #rp + 1) == rp .. '/' then return name, plain:sub(#rp + 2) end
        end
    end
end

local function fsWrite(p, b64)
    local ok, why = allowed(p)
    if not ok then return false, why end
    local data = b64dec(b64 or '')
    local res, rel = inResource(p)
    if res and SaveResourceFile(res, rel, data, #data) then return true end
    local f = io.open(p, 'wb')
    if not f then
        local dir = tostring(p):match('^(.*)[/\\]')
        if dir then mkdirs(dir) end
        f = io.open(p, 'wb')
    end
    if not f then
        return false, ('écriture impossible : %s (%s)'):format(tostring(p), res and ('SaveResourceFile(' .. res .. ', ' .. rel .. ') refusé : dossier « stream » absent ? relance METTRE-A-JOUR') or 'hors des ressources, io.open refusé')
    end
    f:write(data); f:close()
    return true
end

local function fsRemove(p) -- fichier, ou dossier vide
    local ok, why = allowed(p)
    if not ok then return false, why end
    if os.remove(p) then return true end
    if isWin then os.execute('rmdir "' .. tostring(p):gsub('/', '\\') .. '" 2>nul') end
    return true
end

local function run(fn, cb, ...)
    local ok, res, why = pcall(function(...) setup(); return fn(...) end, ...)
    if not ok then res, why = false, tostring(res) end
    if cb then cb(res and true or false, why) end
end

-- Événements LOCAUX au serveur (pas RegisterNetEvent : aucun joueur ne peut les déclencher). Un export appelé depuis le
-- JavaScript de la même ressource n'existe pas (« No such export ») ; l'événement local est synchrone, la réponse revient
-- par la fonction cb.
AddEventHandler('gs_admin:fsWrite', function(p, b64, cb) run(fsWrite, cb, p, b64) end)
AddEventHandler('gs_admin:fsRemove', function(p, cb) run(fsRemove, cb, p) end)
