-- gs_security · V9 « Anti-triche » côté serveur : téléportations répétées, vitesse à pied / en voiture impossible,
-- armes interdites, gains d'argent anormaux, rafales d'entités. ALERTE seulement (log Discord + staff en service) :
-- aucune sanction automatique, donc aucun faux positif ne peut bannir un joueur.
-- Le staff (gs_admin, niveau ≥ 1) et les ACE « command » sont exemptés : vol libre, TP, invisible restent possibles.
Watch = { last = {}, flags = {}, money = {}, alerts = {}, ents = {}, grace = {} }

local AC = {
    enabled = GetConvar('gs_anticheat', 'true') ~= 'false',
    sample = 2000,                                  -- ms entre deux relevés de position
    teleport = 400.0,                               -- m parcourus en un relevé à pied (hors véhicule)
    teleportCount = 4, teleportWindow = 300,        -- 4 sauts en 5 min = alerte (entrer / sortir d'un intérieur = 2 sauts)
    footSpeed = 18.0, footCount = 3,                -- m/s à pied (sprint ≈ 7, chute ≈ 50 vertical : on ne compte que l'horizontal)
    carSpeed = 125.0, carCount = 2,                 -- m/s en voiture / moto (≈ 450 km/h)
    money = tonumber(GetConvar('gs_anticheat_money', '250000')) or 250000, moneyWindow = 300, -- gains cumulés sur 5 min
    entities = 60, entityWindow = 10000,            -- entités réseau créées par un joueur en 10 s
    alertCooldown = 300,                            -- une alerte par joueur et par type toutes les 5 min
    keep = 100,                                     -- alertes gardées pour le menu staff
}
Watch.config = AC

local BLACKLIST = {} -- armes qui n'existent pas sur le serveur (aucun shop / craft ne les donne)
for _, w in ipairs({ 'WEAPON_RPG', 'WEAPON_MINIGUN', 'WEAPON_RAILGUN', 'WEAPON_HOMINGLAUNCHER', 'WEAPON_GRENADELAUNCHER',
    'WEAPON_COMPACTLAUNCHER', 'WEAPON_RAYPISTOL', 'WEAPON_RAYCARBINE', 'WEAPON_RAYMINIGUN', 'WEAPON_STICKYBOMB', 'WEAPON_PROXMINE',
    'WEAPON_GRENADE', 'WEAPON_PIPEBOMB', 'WEAPON_EMPLAUNCHER', 'WEAPON_FIREWORK' }) do BLACKLIST[GetHashKey(w)] = w end

local function now() return os.time() end
local function name(src) return ('%s [%s]'):format(GetPlayerName(src) or '?', src) end

--- Exempté : staff (tous niveaux, en service ou non) ou ACE « command » (console / fondateur)
Watch.staff = {} -- [src] = { exempt, at } : niveau staff relu toutes les 30 s (pas un export par relevé)
function Watch.exempt(src)
    local c = Watch.staff[src]
    if c and now() - c.at < 30 then return c.exempt end
    local exempt = IsPlayerAceAllowed(tostring(src), 'command')
    if not exempt and GetResourceState('gs_admin') == 'started' then
        local ok, lvl = pcall(function() return exports.gs_admin:GetStaffLevel(src) end)
        exempt = ok and (tonumber(lvl) or 0) >= 1
    end
    Watch.staff[src] = { exempt = exempt, at = now() }
    return exempt
end

--- Une ressource qui téléporte un joueur peut le signaler (prison, hôpital, intérieurs…) : pas de faux positif
function Watch.allow(src, seconds) Watch.grace[src] = now() + (seconds or 10) Watch.last[src] = nil end

function Watch.alert(src, kind, detail)
    Watch.flags[src] = Watch.flags[src] or {}
    local f = Watch.flags[src]
    f.sent = f.sent or {}
    if f.sent[kind] and now() - f.sent[kind] < AC.alertCooldown then return false end
    f.sent[kind] = now()
    local a = { at = now(), src = src, name = GetPlayerName(src) or '?', kind = kind, detail = detail }
    table.insert(Watch.alerts, 1, a)
    Watch.alerts[AC.keep + 1] = nil
    GSSec.LogStaff(('[Anti-triche] %s : %s (%s)'):format(name(src), kind, detail), 'anticheat')
    if GetResourceState('gs_admin') == 'started' then
        pcall(function() exports.gs_admin:NotifyStaff(('Anti-triche · %s : %s'):format(name(src), kind)) end)
    end
    return true
end

local function count(src, key, window)
    Watch.flags[src] = Watch.flags[src] or {}
    local l = Watch.flags[src][key] or {}
    local t, out = now(), {}
    for _, at in ipairs(l) do if t - at < window then out[#out + 1] = at end end
    out[#out + 1] = t
    Watch.flags[src][key] = out
    return #out
end

--- Un relevé pour un joueur (appelé toutes les AC.sample ms)
function Watch.check(src)
    local ped = GetPlayerPed(src)
    if ped == 0 or Watch.exempt(src) then Watch.last[src] = nil return end
    if Watch.grace[src] and now() < Watch.grace[src] then Watch.last[src] = nil return end
    local pos, veh = GetEntityCoords(ped), GetVehiclePedIsIn(ped, false)
    local prev = Watch.last[src]
    Watch.last[src] = { pos = pos, veh = veh }
    -- arme interdite en main
    local w = GetSelectedPedWeapon(ped)
    if BLACKLIST[w] then Watch.alert(src, 'arme interdite', BLACKLIST[w]) end
    if not prev or prev.veh ~= veh then return end -- monter / descendre d'un véhicule : pas de mesure
    local dx, dy = pos.x - prev.pos.x, pos.y - prev.pos.y
    local flat = math.sqrt(dx * dx + dy * dy)
    local speed = flat / (AC.sample / 1000)
    if veh == 0 then
        if flat >= AC.teleport then
            if count(src, 'tp', AC.teleportWindow) >= AC.teleportCount then
                Watch.alert(src, 'téléportations répétées', ('%d sauts en %d min, dernier %d m'):format(AC.teleportCount, AC.teleportWindow // 60, math.floor(flat)))
            end
        elseif speed >= AC.footSpeed and prev.pos.z - pos.z < 8.0 then -- chute libre / parachute : ignoré
            if count(src, 'foot', 30) >= AC.footCount then Watch.alert(src, 'vitesse à pied', ('%d m/s'):format(math.floor(speed))) end
        end
    else
        local vt = GetVehicleType and GetVehicleType(veh) or 'automobile'
        if (vt == 'automobile' or vt == 'bike') and speed >= AC.carSpeed and flat < AC.teleport * 3 then
            if count(src, 'car', 30) >= AC.carCount then Watch.alert(src, 'vitesse en véhicule', ('%d km/h'):format(math.floor(speed * 3.6))) end
        end
    end
end

--- Gains d'argent : cumul glissant sur 5 min (les dons du staff ne comptent pas)
-- Mouvements internes (retrait, dépôt, remboursement, caisse) : ce n'est pas de l'argent gagné
local function internal(reason)
    if type(reason) ~= 'string' then return false end
    return reason:find('^retrait') ~= nil or reason:find('^dépôt') ~= nil or reason:find('rembours') ~= nil or reason:find('caisse') ~= nil
end
function Watch.onMoney(src, amount, action, reason)
    if action ~= 'add' or (tonumber(amount) or 0) <= 0 or Watch.exempt(src) then return end
    if (type(reason) == 'string' and reason:find('staff')) or internal(reason) then return end
    local l, t, total, out = Watch.money[src] or {}, now(), 0, {}
    for _, e in ipairs(l) do if t - e.at < AC.moneyWindow then out[#out + 1] = e total = total + e.n end end
    out[#out + 1] = { at = t, n = amount }
    total = total + amount
    Watch.money[src] = out
    if total >= AC.money then Watch.alert(src, 'gain d\'argent anormal', ('%d $ en %d min (dernier : %s)'):format(total, AC.moneyWindow // 60, tostring(reason or '?'))) end
end

--- Création d'entité réseau par un client : au-delà de la rafale, bloquée (menus « pluie d'objets »)
function Watch.onEntity(src)
    if not src or src <= 0 or Watch.exempt(src) then return true end
    if not GSSec.RateLimit(src, 'native:entity', AC.entities, AC.entityWindow) then
        Watch.alert(src, 'rafale d\'entités', ('plus de %d en %d s'):format(AC.entities, AC.entityWindow // 1000))
        return false
    end
    return true
end

if AC.enabled then
    AddEventHandler('QBCore:Server:OnMoneyChange', function(src, _, amount, action, reason) Watch.onMoney(src, amount, action, reason) end) -- [API] qbx_core
    AddEventHandler('entityCreating', function(ent)
        if GetEntityPopulationType(ent) ~= 7 then return end -- seulement les entités créées par script (pas le trafic / les passants)
        local owner = NetworkGetEntityOwner(ent)
        if owner and owner > 0 and not Watch.onEntity(owner) then CancelEvent() end
    end)
    AddEventHandler('playerDropped', function()
        local src = source
        Watch.last[src], Watch.flags[src], Watch.money[src], Watch.grace[src], Watch.staff[src] = nil, nil, nil, nil, nil
    end)
    CreateThread(function()
        while true do
            Wait(AC.sample)
            for _, id in ipairs(GetPlayers()) do Watch.check(tonumber(id)) end
        end
    end)
end

exports('AllowTeleport', Watch.allow)
exports('GetAlerts', function() return Watch.alerts end)
