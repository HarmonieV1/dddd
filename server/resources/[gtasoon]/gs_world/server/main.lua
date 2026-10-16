-- gs_world (serveur) : vols réguliers vers Cayo Perico (comptoir vérifié, billet payé en banque, puis téléportation).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

World = {}

-- V12.63 · Journée North Yankton (proposition n° 191) ------------------------------------------------------------------
local Y = Config.Yankton
local NAMES = { cayo = 'Cayo Perico', yankton = 'North Yankton' }

--- Décalage de l'heure du serveur par rapport à UTC (s), pour le jour de jeu
local function utcOffset(t)
    local l, u = os.date('*t', t), os.date('!*t', t)
    local dd = l.yday - u.yday
    if dd > 1 then dd = -1 elseif dd < -1 then dd = 1 end -- passage d'année
    return dd * 86400 + (l.hour - u.hour) * 3600 + (l.min - u.min) * 60
end

--- Numéro du jour de jeu (il commence à Y.dayStartHour h, heure du serveur)
function World.dayIndex(t)
    t = t or os.time()
    return math.floor((t + utcOffset(t) - (Y.dayStartHour or 6) * 3600) / 86400)
end
function World.autoMode(t)
    if not Y.alternate then return 'cayo' end
    return World.dayIndex(t) % 2 == 0 and 'cayo' or 'yankton'
end
--- Choix du staff : 'auto' (alternance), 'cayo' ou 'yankton' ; gardé après redémarrage
function World.choice()
    local c = GetResourceKvpString('gs_world:islandChoice')
    return (c == 'cayo' or c == 'yankton') and c or 'auto'
end
function World.mode() return GlobalState.gsIslandMode == 'yankton' and 'yankton' or 'cayo' end
local function wanted() local c = World.choice() return c == 'auto' and World.autoMode() or c end

--- Sur l'île (zone chargée de Cayo ou de North Yankton) ?
function World.onIsland(c)
    local I = Config.Island
    local dx, dy = c.x - I.center.x, c.y - I.center.y
    if dx * dx + dy * dy < I.loadRadius * I.loadRadius then return true end
    dx, dy = c.x - Y.zone.x, c.y - Y.zone.y
    return dx * dx + dy * dy < Y.loadRadius * Y.loadRadius
end

-- Séjour sur l'île (KVP par personnage) : sur quelle île le joueur se trouvait. Revenu après une déconnexion alors que l'île
-- a changé (il serait apparu dans le ciel de Cayo ou sous le sol de North Yankton) → reprise à l'aéroport.
World.trips, World.loadedAt = {}, {}
local function tripKey(cid) return 'gs_world:trip:' .. tostring(cid) end
local function tripOf(cid)
    local v = World.trips[cid]
    if v == nil then v = GetResourceKvpString(tripKey(cid)) or false World.trips[cid] = v end
    return v or nil
end
local function setTrip(cid, m)
    if not cid or (World.trips[cid] or false) == (m or false) then return end
    World.trips[cid] = m or false
    if m then SetResourceKvp(tripKey(cid), m) else DeleteResourceKvp(tripKey(cid)) end
end
local function evacuate(src, text)
    pcall(function() Security:AllowTeleport(src, 20) end)
    setTrip(Bridge:GetIdentifier(src), nil)
    TriggerClientEvent('gs_world:client:evacuate', src, text)
end

--- Suivi d'un joueur (chaque minute, et juste après sa connexion)
function World.track(src)
    local ped, cid = GetPlayerPed(src), Bridge:GetIdentifier(src)
    if not cid or not ped or ped == 0 then return end
    local m, rec = World.mode(), tripOf(cid)
    if not World.onIsland(GetEntityCoords(ped)) then
        -- hors de l'île : séjour terminé (pas dans les 10 min après la connexion : choix du personnage, du point d'apparition)
        if rec and os.time() - (World.loadedAt[src] or 0) > 600 then setTrip(cid, nil) end
        return
    end
    if rec and rec ~= m then
        evacuate(src, ('Pendant ton absence, le vol régulier a changé de destination (%s aujourd\'hui) : tu reprends à l\'aéroport.'):format(NAMES[m]))
    elseif not rec then
        setTrip(cid, m)
    end
end

AddEventHandler('gs_bridge:server:playerLoaded', function(src)
    World.loadedAt[src] = os.time()
    for _, ms in ipairs({ 15000, 45000, 90000 }) do SetTimeout(ms, function() if GetPlayerPed(src) ~= 0 then World.track(src) end end) end
end)
AddEventHandler('playerDropped', function() local src = source World.loadedAt[src] = nil end)

--- Change la destination. Les joueurs sur l'île sont d'abord rapatriés à l'aéroport (fondu, sol chargé avant de reprendre la main).
function World.applyMode(mode)
    if GlobalState.gsIslandMode == mode then return false, 0 end
    local n = 0
    if GlobalState.gsIslandMode then -- pas au démarrage (personne n'est encore là)
        for _, s in ipairs(GetPlayers()) do
            local src = tonumber(s)
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 and World.onIsland(GetEntityCoords(ped)) then
                n = n + 1
                evacuate(src, ('Changement de destination : le dernier vol te ramène à Los Santos. Le vol de l\'aéroport mène maintenant à %s.'):format(NAMES[mode]))
            end
        end
    end
    GlobalState.gsIslandMode = mode
    if mode == 'yankton' then GlobalState.gsCayoParty = nil end
    return true, n
end

lib.callback.register('gs_world:islandInfo', function(src)
    if not Security:RateLimit(src, 'gs_world:island', 6, 10000) then return nil end
    if GetResourceState('gs_admin') ~= 'started' or (exports.gs_admin:GetStaffLevel(src) or 0) < Y.staffLevel then return nil end
    return { mode = World.mode(), choice = World.choice(), tomorrow = World.autoMode(os.time() + 86400) }
end)

lib.callback.register('gs_world:setIslandMode', function(src, c)
    if not Security:RateLimit(src, 'gs_world:island', 6, 10000) then return false, 'Doucement.' end
    if GetResourceState('gs_admin') ~= 'started' or (exports.gs_admin:GetStaffLevel(src) or 0) < Y.staffLevel then return false, 'Réservé au staff.' end
    if c ~= 'auto' and not NAMES[c] then return false, 'Choix inconnu.' end
    SetResourceKvp('gs_world:islandChoice', c)
    local changed, n = World.applyMode(wanted())
    pcall(function() Security:LogStaff(('[Monde] destination du vol de l\'île : %s par %s [%d]'):format(c == 'auto' and 'alternance' or NAMES[c], GetPlayerName(src) or '?', src), 'staff') end)
    if changed then
        TriggerClientEvent('ox_lib:notify', -1, { title = 'Aéroport de Los Santos', icon = 'plane-departure', type = 'inform', duration = 10000,
            description = ('Le vol régulier mène maintenant à %s.'):format(NAMES[World.mode()]) })
    end
    return true, ('Destination : %s%s%s.'):format(NAMES[World.mode()], c == 'auto' and ' (alternance)' or ' (forcée)',
        n > 0 and (' · %d joueur(s) rapatrié(s)'):format(n) or '')
end)

exports('IslandMode', World.mode)

--- Soirée plage de Cayo Perico (appelée par gs_admin, événements en un clic). seconds = 0 pour arrêter.
--- V12.63 : refusée les jours North Yankton (Cayo n'est pas chargée).
function World.party(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then GlobalState.gsCayoParty = nil return true end
    if World.mode() == 'yankton' then return false end
    GlobalState.gsCayoParty = { untilAt = os.time() + math.min(seconds, 4 * 3600) }
    SetTimeout(math.min(seconds, 4 * 3600) * 1000, function()
        local g = GlobalState.gsCayoParty
        if g and os.time() >= g.untilAt then GlobalState.gsCayoParty = nil end
    end)
    return true
end
exports('StartParty', World.party)

lib.callback.register('gs_world:fly', function(src, side)
    if not Security:RateLimit(src, 'gs_world:fly', 2, 10000) then return false, 'Doucement.' end
    local f = Config.Island.flight
    local mode = World.mode() -- V12.63 : Cayo Perico ou North Yankton selon le jour
    local island = mode == 'yankton' and Y.flight.island or f.island
    local from = (side == 'mainland' and f.mainland) or (side == 'island' and island) or nil
    if not from then return false, 'Vol inconnu.' end
    if not Security:InRangeFlat(src, from.counter, 4.0, 8.0) then return false, 'Présente-toi au comptoir.' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return false, 'Descends du véhicule.' end
    -- V12.40 · vol « discret » vers l'île : espèces, sinon argent sale (jamais la banque : pas de trace)
    local price = mode == 'yankton' and (Y.flight.price or 0) or f.price
    if price > 0 and not Bridge:RemoveMoney(src, 'cash', price, 'vol ' .. NAMES[mode])
        and not (Bridge:GetItemCount(src, 'black_money') >= price and Bridge:RemoveItem(src, 'black_money', price)) then
        return false, ('Billet : %d $ en liquide ou en argent sale, pas de carte ici.'):format(price)
    end
    local to = side == 'mainland' and island.arrival or f.mainland.arrival
    local ped = GetPlayerPed(src)
    pcall(function() Security:AllowTeleport(src, 15) end) -- V12.63 : un vol n'est pas un saut suspect
    SetEntityCoords(ped, to.x, to.y, to.z, false, false, false, false)
    SetEntityHeading(ped, to.w)
    setTrip(Bridge:GetIdentifier(src), side == 'mainland' and mode or nil) -- V12.63 : séjour sur l'île
    return true, side == 'mainland' and ('Bienvenue à %s.'):format(NAMES[mode]) or 'Retour à Los Santos.', mode
end)

-- V12.63 : destination du jour dès le chargement, puis bascule à l'heure du jour de jeu (alternance) si le serveur n'a pas redémarré
World.applyMode(wanted())
CreateThread(function()
    while true do
        Wait(60000)
        World.applyMode(wanted())
        for _, s in ipairs(GetPlayers()) do World.track(tonumber(s)) end
    end
end)

-- Nombre de joueurs connectés, lu par les clients pour réduire PNJ / trafic quand le serveur se remplit.
CreateThread(function()
    while true do
        GlobalState.gsPlayers = #GetPlayers()
        Wait(30000)
    end
end)
