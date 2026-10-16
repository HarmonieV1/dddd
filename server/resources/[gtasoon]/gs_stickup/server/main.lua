-- gs_stickup (serveur) : décide de tout ce qui compte (lieu, cooldowns, durée réelle, butin, signalement).
-- Le client ne fait que l'ambiance (peur, animations). Chaque braquage est signalé via gs_wanted : aux policiers en
-- service, ou à la police IA quand aucun agent LSPD n'est connecté (gs_wanted, Config.NpcPolice).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Stickup = { pending = {}, zoneCd = {}, playerCd = {}, hour = {}, day = {}, notices = {}, live = {} } -- notices[zone] = avis en vitrine (V12.63)

-- V12.63 (backtest : « braquage de supérette à deux ultra bugué, pas synchronisé ») : un braquage de caisse / guichet est
-- PARTAGÉ. Le premier qui vise le lance (signalement, cooldown) ; un complice armé qui vise la même caisse le REJOINT. La peur
-- est commune (chaque complice qui vise et crie la fait monter, Stickup.aim), l'argent tombe une seule fois en sacs au
-- comptoir pour tout le monde, chacun reçoit son cooldown. live[zone] = { kind, members = { [src] = { last } }, fear, aims, startAt }
local function liveCount(l) local n = 0 for _ in pairs(l.members) do n = n + 1 end return n end
function Stickup.publishLive()
    local out = {}
    for id, l in pairs(Stickup.live) do out[id] = { fear = math.floor(l.fear), n = liveCount(l) } end
    GlobalState.gsStickups = out
end
local function leaveLive(src)
    for id, l in pairs(Stickup.live) do
        if l.members[src] then
            l.members[src] = nil
            if not next(l.members) then Stickup.live[id] = nil end
            Stickup.publishLive()
            return id
        end
    end
end

local UNARMED = GetHashKey('WEAPON_UNARMED')
local function started(res) return GetResourceState(res) == 'started' end
local function today() return os.date('%Y-%m-%d') end

--- Zones à caisse / guichet : vendeurs de gs_economy + guichetiers de la config.
function Stickup.zones()
    local z = {}
    if started('gs_economy') then
        for _, c in ipairs(exports.gs_economy:GetClerks() or {}) do z[c.id] = { kind = 'register', label = c.label, coords = c.coords } end
    end
    if started('gs_places') then -- V10.2 : coiffeurs, tatoueurs, boutiques de vêtements
        local ok, l = pcall(function() return exports.gs_places:GetVendors() end)
        for _, c in ipairs(ok and l or {}) do z[c.id] = { kind = 'register', label = c.label, coords = c.coords } end
    end
    for _, t in ipairs(Config.Tellers) do z[t.id] = { kind = 'teller', label = t.label, coords = t.coords } end
    return z
end

local function recent(src)
    local list, now, keep = Stickup.hour[src] or {}, os.time(), {}
    for _, t in ipairs(list) do if now - t < 3600 then keep[#keep + 1] = t end end
    Stickup.hour[src] = keep
    return #keep
end

local function earnedToday(cid)
    local d = Stickup.day[cid]
    if not d or d.day ~= today() then d = { day = today(), amount = 0 } Stickup.day[cid] = d end
    return d
end

--- V12.63 · Avis en vitrine (proposition n° 157) : publiés pour tous, effacés au bout de Config.ShopNotice.hours
function Stickup.publishNotices()
    local out, now = {}, os.time()
    for id, n in pairs(Stickup.notices) do
        if n.untilAt > now then out[#out + 1] = { id = id, label = n.label, x = n.x, y = n.y, z = n.z, desc = n.desc, when = n.when }
        else Stickup.notices[id] = nil end
    end
    GlobalState.gsShopNotices = out
end

function Stickup.notice(src, zoneId, zone)
    local N = Config.ShopNotice
    if not N or not zone or math.random() >= (N.camera or 0.7) then return false end
    local desc = 'silhouette floue'
    if started('gs_wanted') then
        local ok, d = pcall(function() return exports.gs_wanted:Describe(src) end)
        if ok and type(d) == 'string' and d ~= '' then
            local parts = {}
            for part in d:gmatch('[^,]+') do
                parts[#parts + 1] = part:gsub('^%s+', ''):gsub('%s+$', '')
                if #parts >= (N.details or 2) then break end
            end
            desc = table.concat(parts, ', ')
        end
    end
    local c = zone.coords
    Stickup.notices[zoneId] = { label = zone.label, x = c.x, y = c.y, z = c.z, desc = desc, when = os.date('%d/%m à %H:%M'), untilAt = os.time() + (N.hours or 24) * 3600 }
    Stickup.publishNotices()
    return true
end

--- Début : contrôles, puis signalement (la victime ou un témoin appelle, selon gs_wanted).
lib.callback.register('gs_stickup:begin', function(src, kindName, zoneId)
    if not Security:RateLimit(src, 'gs_stickup:begin', 4, 10000) then return false, 'Doucement.' end
    local kind = Config.Kinds[kindName]
    if not kind then return false, 'Invalide.' end
    if Stickup.pending[src] then return false, 'Déjà en cours.' end
    local ped = GetPlayerPed(src)
    if ped == 0 or GetSelectedPedWeapon(ped) == UNARMED then return false, 'Il te faut une arme en main.' end
    if started('gs_jobs') and exports.gs_jobs:IsOnDutyAs(src, Config.PoliceJob) then return false, 'Pas en service de police.' end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return false, 'Invalide.' end
    local now = os.time()
    local pcd = Stickup.playerCd[src] and Stickup.playerCd[src][kindName]
    if pcd and pcd > now then return false, ('Fais-toi oublier encore %d s.'):format(pcd - now) end
    if recent(src) >= Config.MaxPerHour then return false, 'Trop de braquages cette heure-ci : les rues sont en alerte.' end
    if earnedToday(cid).amount >= Config.MaxPerDay then return false, 'Tu as assez tenté ta chance pour aujourd\'hui.' end
    local coords = GetEntityCoords(ped)
    local zone
    if kindName ~= 'street' then
        zone = Stickup.zones()[zoneId]
        if not zone or zone.kind ~= kindName then return false, 'Invalide.' end
        if not Security:InRange(src, zone.coords, kind.radius + 3.0) then return false, 'Trop loin.' end
        local l = Stickup.live[zoneId]
        if l then -- V12.63 : un complice rejoint le braquage en cours (pas de 2e signalement, même chrono)
            l.members[src] = { last = GetGameTimer() }
            Stickup.pending[src] = { kind = kindName, zone = zoneId, startAt = l.startAt, coords = coords, joined = true }
            Stickup.publishLive()
            return true, 'join'
        end
        if (Stickup.zoneCd[zoneId] or 0) > now then return false, 'La caisse vient d\'être vidée, il n\'y a plus rien.' end
        Stickup.live[zoneId] = { kind = kindName, members = { [src] = { last = GetGameTimer() } }, fear = 0.0, aims = 0, startAt = GetGameTimer() }
        Stickup.publishLive()
    end
    Stickup.pending[src] = { kind = kindName, zone = zoneId, startAt = GetGameTimer(), coords = coords }
    local where = zone and zone.coords or coords
    if started('gs_wanted') then
        exports.gs_wanted:ReportCrime(src, kind.crime, vec3(where.x, where.y, where.z), { alarm = kind.alarmChance and math.random() < kind.alarmChance })
    end
    return true
end)

lib.callback.register('gs_stickup:finish', function(src)
    if not Security:RateLimit(src, 'gs_stickup:finish', 4, 10000) then return false, 'Doucement.' end
    local p = Stickup.pending[src]
    if not p then return false, 'Rien en cours.' end
    local kind = Config.Kinds[p.kind]
    local l = p.zone and Stickup.live[p.zone]
    if l and l.aims > 0 and l.fear < 100 then return false, 'Il n\'a pas encore assez peur.' end -- V12.63 : peur commune
    Stickup.pending[src] = nil
    if GetGameTimer() - p.startAt < kind.minTime * 1000 then return false, 'Trop rapide.' end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - p.coords) > Config.AimRange + 6.0 then return false, 'Tu t\'es éloigné.' end
    local cid = Bridge:GetIdentifier(src)
    local d = earnedToday(cid)
    local amount = math.min(math.random(kind.reward[1], kind.reward[2]), Config.MaxPerDay - d.amount)
    if amount <= 0 then return false, 'Plus rien à prendre aujourd\'hui.' end
    local now = os.time()
    d.amount = d.amount + amount
    Stickup.hour[src] = Stickup.hour[src] or {}
    table.insert(Stickup.hour[src], now)
    Stickup.playerCd[src] = Stickup.playerCd[src] or {}
    Stickup.playerCd[src][p.kind] = now + kind.playerCooldown
    if p.zone then Stickup.zoneCd[p.zone] = now + kind.zoneCooldown end
    -- V12.63 : braquage partagé terminé pour tous les complices (même cooldown, prévenus, sacs communs au comptoir)
    local mates = {}
    if l then
        for m in pairs(l.members) do
            if m ~= src then
                mates[#mates + 1] = m
                Stickup.pending[m] = nil
                Stickup.playerCd[m] = Stickup.playerCd[m] or {}
                Stickup.playerCd[m][p.kind] = now + kind.playerCooldown
                Stickup.hour[m] = Stickup.hour[m] or {}
                table.insert(Stickup.hour[m], now)
            end
        end
        Stickup.live[p.zone] = nil
        Stickup.publishLive()
    end
    local msg
    if kind.dirty and p.zone and Bridge:ItemExists(Config.DirtyItem) then
        -- Caisse / guichet : l'argent tombe en sacs plastique au comptoir, à ramasser (Alt ou inventaire au sol)
        local bags = math.random(Config.Bags.min, Config.Bags.max)
        local left, c = amount, p.coords
        for i = 1, bags do
            local part = i == bags and left or math.floor(amount / bags)
            left = left - part
            local a = (i / bags) * math.pi * 2
            Bridge:CreateDrop({ { Config.DirtyItem, part } }, vec3(c.x + math.cos(a) * 0.7, c.y + math.sin(a) * 0.7, c.z - 0.95),
                Config.Bags.label, Config.Bags.model)
        end
        msg = ('%d $ en argent sale, dans %d sac(s) au sol : ramasse-les'):format(amount, bags)
    elseif kind.dirty and Bridge:ItemExists(Config.DirtyItem) and Bridge:AddItem(src, Config.DirtyItem, amount) then
        msg = ('%d $ en argent sale'):format(amount)
    else
        Bridge:AddMoney(src, 'cash', amount, 'racket')
        msg = ('%d $'):format(amount)
    end
    if kind.items and math.random() < kind.itemChance then
        local item = kind.items[math.random(#kind.items)]
        if Bridge:ItemExists(item) and Bridge:AddItem(src, item, 1) then msg = msg .. ' + un objet' end
    end
    if started('gs_reputation') then exports.gs_reputation:Add(src, 'street', 1) end
    if p.zone then Stickup.notice(src, p.zone, Stickup.zones()[p.zone]) end -- V12.63 : avis en vitrine si la caméra a filmé
    Security:LogStaff(('[Braquage solo] %s : %s (%s)'):format(GetPlayerName(src) or src, kind.label, msg), 'jobs')
    if p.zone and started('gs_social') then
        local z = Stickup.zones()[p.zone]
        exports.gs_social:Newsroom('stickup', ('FAITS DIVERS · %s braqué(e) à main armée : %s sous le choc, l\'auteur court toujours.'):format(z and z.label or 'Un commerce', p.kind == 'teller' and 'le guichetier' or 'le caissier'))
    end
    for _, m in ipairs(mates) do TriggerClientEvent('gs_stickup:client:shared', m, p.zone, ('Butin commun : %s. Vite, la police arrive !'):format(msg)) end
    return true, ('Butin : %s. Vite, la police arrive !'):format(msg)
end)

--- V12.63 · Peur commune d'un braquage partagé : chaque complice signale s'il vise (et sa voix) ~3 fois par seconde ;
--- le serveur additionne (durée réelle entre deux appels, 1 s au plus) et renvoie { fear, n } à tous ceux qui demandent.
function Stickup.aim(src, zoneId, aiming, voiceIdx)
    local l = Stickup.live[zoneId]
    local m = l and l.members[src]
    if not m then return nil end
    local nowMs = GetGameTimer()
    local dt = math.max(0.0, math.min(1.0, (nowMs - (m.last or nowMs)) / 1000))
    m.last = nowMs
    local kind = Config.Kinds[l.kind]
    if aiming == true then
        local v = Config.Fear.voice[math.tointeger(tonumber(voiceIdx)) or 0] or 0
        l.fear = math.min(100.0, l.fear + (Config.Fear.aim + v) * kind.fearScale * dt)
        l.aims = l.aims + 1
    end
    if not l.pub or nowMs - l.pub >= 1000 or l.fear >= 100 then l.pub = nowMs Stickup.publishLive() end
    return { fear = math.floor(l.fear), n = liveCount(l) }
end
lib.callback.register('gs_stickup:aim', function(src, zoneId, aiming, voiceIdx)
    if not Security:RateLimit(src, 'gs_stickup:aim', 12, 3000) then return nil end
    return Stickup.aim(src, zoneId, aiming, voiceIdx)
end)

--- Abandon : la victime s'enfuit. Le crime a déjà été signalé au début ; petit cooldown quand même.
RegisterNetEvent('gs_stickup:server:cancel', function()
    local src = source
    if not Security:RateLimit(src, 'gs_stickup:cancel', 4, 10000) then return end
    local p = Stickup.pending[src]
    Stickup.pending[src] = nil
    leaveLive(src) -- V12.63 : les complices continuent sans lui
    if p then
        Stickup.playerCd[src] = Stickup.playerCd[src] or {}
        Stickup.playerCd[src][p.kind] = os.time() + 30
    end
end)

lib.callback.register('gs_stickup:zones', function(src)
    if not Security:RateLimit(src, 'gs_stickup:zones', 3, 10000) then return nil end
    return Stickup.zones()
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    leaveLive(src)
    Stickup.pending[src], Stickup.playerCd[src], Stickup.hour[src] = nil, nil, nil
end)

CreateThread(function() -- V12.63 : avis périmés retirés (toutes les 10 min)
    while true do Wait(600000) Stickup.publishNotices() end
end)
