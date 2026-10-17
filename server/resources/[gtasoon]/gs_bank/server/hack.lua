-- gs_bank (serveur) · V12.64 · Piratage de distributeur (proposition n° 227). Trois temps vérifiés ici :
--   1. hackBegin  : boîtier en poche, près du distributeur, pas policier en service, pas de cooldown → « installation »
--   2. hackResult : mini-jeu réussi ou raté (durée d'installation réelle vérifiée) → alarme si raté, sinon « retrait »
--   3. hackFinish : durée du retrait réelle vérifiée, toujours près du distributeur → butin en argent sale
-- Le butin, l'alarme, la caméra et l'usure du boîtier sont tirés ici, jamais côté joueur.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local H = Config.Hack

Hack = { pending = {}, atms = {}, players = {} } -- pending[src] = { key, coords, stage, readyAt } ; atms[clé] / players[cid] = fin du cooldown

local function started(r) return GetResourceState(r) == 'started' end
local function now() return os.time() end

--- Clé d'un distributeur : sa position arrondie au mètre (les props du jeu n'ont pas d'identifiant côté serveur)
function Hack.key(c) return ('%d:%d:%d'):format(math.floor(c.x + 0.5), math.floor(c.y + 0.5), math.floor(c.z + 0.5)) end

function Hack.isNight()
    if not started('gs_weather') then return false end
    local ok, hour = pcall(function() return exports.gs_weather:GetGameTime() end)
    hour = ok and tonumber(hour) or 12
    return hour >= H.night.from or hour < H.night.to
end

local function isCop(src)
    local job = Bridge:GetJob(src)
    return job and job.name == 'police' and job.onduty == true
end

local function report(src, coords, alarm)
    if not started('gs_wanted') then return end
    local camera = math.random() < H.camera and H.cameraLabel or nil
    pcall(function() exports.gs_wanted:ReportCrime(src, H.crime, coords, { alarm = alarm, camera = camera }) end)
end

local function wear(src, chance)
    if math.random() < chance then
        Bridge:RemoveItem(src, H.item, 1)
        return ' Le boîtier a grillé.'
    end
    return ''
end

local function validCoords(c)
    return type(c) == 'table' and type(c.x) == 'number' and type(c.y) == 'number' and type(c.z) == 'number'
end

lib.callback.register('gs_bank:hackBegin', function(src, coords)
    if not Security:RateLimit(src, 'gs_bank:hackBegin', 4, 10000) or not Bridge:IsLoaded(src) then return false, 'Doucement.' end
    if not validCoords(coords) then return false, 'Distributeur invalide.' end
    local at = vec3(coords.x, coords.y, coords.z)
    if not Security:InRange(src, at, Config.Range + 1.5) then return false, 'Trop loin du distributeur.' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return false, 'Descends du véhicule.' end
    if Hack.pending[src] then return false, 'Déjà en train de pirater.' end
    if (Bridge:GetItemCount(src, H.item) or 0) < 1 then return false, 'Il te faut un boîtier de piratage (marché noir).' end
    if isCop(src) then return false, 'Pas en service de police.' end
    local cid, key = Bridge:GetIdentifier(src), Hack.key(at)
    if (Hack.players[cid] or 0) > now() then return false, ('Fais-toi oublier encore %d min.'):format(math.ceil((Hack.players[cid] - now()) / 60)) end
    if (Hack.atms[key] or 0) > now() then return false, 'Ce distributeur a déjà été vidé : la banque le surveille.' end
    Hack.pending[src] = { key = key, coords = at, stage = 'install', readyAt = GetGameTimer() + H.install - 750 }
    return true, { install = H.install, skill = H.skill, keys = H.keys }
end)

lib.callback.register('gs_bank:hackResult', function(src, success)
    if not Security:RateLimit(src, 'gs_bank:hackResult', 4, 10000) then return false, 'Doucement.' end
    local p = Hack.pending[src]
    if not p or p.stage ~= 'install' then return false, 'Interrompu.' end
    if GetGameTimer() < p.readyAt then Hack.pending[src] = nil return false, 'Interrompu.' end
    if not Security:InRange(src, p.coords, Config.Range + 1.5) then Hack.pending[src] = nil return false, 'Tu t\'es éloigné.' end
    local cid = Bridge:GetIdentifier(src)
    if success ~= true then -- raté : l'alarme sonne, le distributeur se verrouille un moment
        Hack.pending[src] = nil
        Hack.atms[p.key] = now() + math.floor(H.atmCooldown / 3)
        Hack.players[cid] = now() + H.playerCooldown
        report(src, p.coords, true)
        Security:LogStaff(('[Distributeur] %s rate un piratage (alarme)'):format(GetPlayerName(src) or src), 'jobs')
        return false, 'Code refusé : l\'alarme du distributeur se déclenche !' .. wear(src, H.failBreak), true
    end
    p.stage, p.readyAt = 'drain', GetGameTimer() + H.drain - 750
    Hack.atms[p.key] = now() + H.atmCooldown -- vidé ou pas, il est grillé pour un moment
    report(src, p.coords, math.random() < (Hack.isNight() and H.alarm.night or H.alarm.day))
    return true, H.drain
end)

lib.callback.register('gs_bank:hackFinish', function(src)
    if not Security:RateLimit(src, 'gs_bank:hackFinish', 4, 10000) then return false, 'Doucement.' end
    local p = Hack.pending[src]
    Hack.pending[src] = nil
    if not p or p.stage ~= 'drain' or GetGameTimer() < p.readyAt then return false, 'Interrompu : le distributeur a avalé les billets.' end
    if not Security:InRange(src, p.coords, Config.Range + 1.5) then return false, 'Tu t\'es éloigné.' end
    local amount = math.random(H.reward[1], H.reward[2])
    if Hack.isNight() then amount = math.floor(amount * H.nightBonus) end
    local loot
    if H.dirtyItem and Bridge:ItemExists(H.dirtyItem) and Bridge:AddItem(src, H.dirtyItem, amount) then loot = ('%d $ en argent sale'):format(amount)
    else Bridge:AddMoney(src, 'cash', amount, 'piratage distributeur') loot = ('%d $'):format(amount) end
    Hack.players[Bridge:GetIdentifier(src)] = now() + H.playerCooldown
    Security:LogStaff(('[Distributeur] %s pirate un distributeur : %s'):format(GetPlayerName(src) or src, loot), 'jobs')
    return true, ('Butin : %s.'):format(loot) .. wear(src, H.breakChance)
end)

RegisterNetEvent('gs_bank:server:hackCancel', function()
    if Security:RateLimit(source, 'gs_bank:hackCancel', 5, 10000) then Hack.pending[source] = nil end
end)

AddEventHandler('playerDropped', function() Hack.pending[source] = nil end)
