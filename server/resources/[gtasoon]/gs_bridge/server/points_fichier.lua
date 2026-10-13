-- gs_bridge (serveur) · V12.37 · Les points déplacés par le staff (KVP gs_points / gs_points_off, voir points.lua) sont aussi
-- écrits dans le fichier `points-deplaces.json` de cette ressource et relus au démarrage.
-- Pourquoi : les KVP sont propres à chaque serveur (le PC et le VPS n'ont pas la même mémoire). Le fichier, lui, voyage avec
-- [gtasoon] : METTRE-A-JOUR garde celui du PC, METTRE-A-JOUR-OVH l'envoie au VPS, « roadline maj » le conserve. Un point calé
-- en jeu sur le PC se retrouve donc sur le VPS à la mise à jour suivante, sans rien refaire.
-- Chargé AVANT points.lua (fxmanifest) : l'import écrit les KVP que points.lua lit juste après, de façon synchrone.
-- Règle : le PC est la référence. Un serveur sans aucun point déplacé n'écrit jamais de fichier (il ne peut donc pas effacer
-- les points de l'autre) ; une fois le fichier créé, il suit les changements (y compris une remise à zéro voulue).
local RES = GetCurrentResourceName()
local FILE = 'points-deplaces.json'
local KVP_STAMP = 'gs_points_fichier' -- marque du dernier fichier importé ou écrit ici : évite de réimporter son propre fichier

PointsFichier = PointsFichier or { periode = 60000 } -- export automatique toutes les 60 s (jamais par image)
local last -- dernier contenu (points|off) écrit ou importé : rien à faire tant qu'il ne change pas

local function current()
    return GetResourceKvpString('gs_points') or '{}', GetResourceKvpString('gs_points_off') or '{}'
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

--- Contenu du fichier ; nil si absent ou illisible.
function PointsFichier.read()
    local raw = LoadResourceFile(RES, FILE)
    if type(raw) ~= 'string' or raw == '' then return nil end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' or type(data.points) ~= 'table' then return nil end
    return data
end

--- Importe le fichier dans les KVP si sa marque diffère de la dernière connue. Retourne le nombre de points ou nil.
function PointsFichier.import()
    local data = PointsFichier.read()
    if not data then return nil end
    local stamp = tostring(data.stamp or '')
    if stamp == '' then return nil end
    if GetResourceKvpString(KVP_STAMP) == stamp then -- notre propre fichier : rien à importer, rien à réécrire
        local p, o = current()
        last = p .. '|' .. o
        return nil
    end
    local off = type(data.off) == 'table' and data.off or {}
    SetResourceKvp('gs_points', json.encode(data.points))
    SetResourceKvp('gs_points_off', json.encode(off))
    SetResourceKvp(KVP_STAMP, stamp)
    local p, o = current()
    last = p .. '|' .. o
    local n = count(data.points)
    print(('[gs_bridge] %d point(s) déplacé(s) et %d retiré(s) importés depuis %s (écrit le %s par %s).'):format(
        n, count(off), FILE, tostring(data.quand or '?'), tostring(data.par or '?')))
    return n
end

--- Écrit le fichier depuis les KVP quand quelque chose a changé (ou `force`). `par` : qui demande (console, nom du staff,
--- « auto »). Retourne true si écrit, false sinon (rien de neuf, aucun point et pas de fichier, écriture refusée).
function PointsFichier.export(par, force)
    local p, o = current()
    local cur = p .. '|' .. o
    if not force and cur == last then return false end
    local okP, points = pcall(json.decode, p)
    local okO, off = pcall(json.decode, o)
    if not okP or type(points) ~= 'table' then return false end
    if not okO or type(off) ~= 'table' then off = {} end
    if count(points) == 0 and count(off) == 0 and not PointsFichier.read() then
        last = cur -- rien à transmettre et pas de fichier : on n'en crée pas (il effacerait les points de l'autre serveur)
        return false
    end
    local stamp = ('%d-%d'):format(os.time(), math.random(1000, 9999))
    local data = { stamp = stamp, quand = os.date('%d/%m/%Y %H:%M'), par = tostring(par or 'auto'), points = points, off = off }
    if not SaveResourceFile(RES, FILE, json.encode(data), -1) then
        print(('[gs_bridge] impossible d\'écrire %s (dossier en lecture seule ?).'):format(FILE))
        return false
    end
    SetResourceKvp(KVP_STAMP, stamp)
    last = cur
    return true
end

-- Démarrage : import synchrone (points.lua lit les KVP juste après), puis export automatique périodique.
-- Sans fichier (première version avec cet outil, ou serveur neuf), `last` reste vide : des points déjà déplacés avant la mise à
-- jour sont écrits à la première minute, sans attendre qu'un point bouge.
PointsFichier.import()
CreateThread(function()
    while true do
        Wait(PointsFichier.periode)
        PointsFichier.export('auto')
    end
end)

-- /pointsexport (console ou staff avec l'ACE « admin ») : écrit le fichier tout de suite, sans attendre la minute.
RegisterCommand('pointsexport', function(src)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'admin') then return end
    local who = src == 0 and 'console' or tostring(GetPlayerName(src) or src)
    local ok = PointsFichier.export(who, true)
    local msg = ok and ('Points déplacés écrits dans gs_bridge/%s : METTRE-A-JOUR-OVH les emportera.'):format(FILE)
        or 'Aucun point déplacé à écrire (ou écriture impossible, voir la console).'
    if src == 0 then print('[gs_bridge] ' .. msg)
    else TriggerClientEvent('ox_lib:notify', src, { description = msg, type = ok and 'success' or 'inform' }) end
end, false)
