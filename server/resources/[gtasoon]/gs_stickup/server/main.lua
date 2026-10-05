-- gs_stickup (serveur) : décide de tout ce qui compte (lieu, cooldowns, durée réelle, butin, signalement).
-- Le client ne fait que l'ambiance (peur, animations). Chaque braquage est signalé via gs_wanted : aux policiers en
-- service, ou à la police IA quand aucun agent LSPD n'est connecté (gs_wanted, Config.NpcPolice).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Stickup = { pending = {}, zoneCd = {}, playerCd = {}, hour = {}, day = {} }

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
        if (Stickup.zoneCd[zoneId] or 0) > now then return false, 'La caisse vient d\'être vidée, il n\'y a plus rien.' end
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
    Stickup.pending[src] = nil
    if not p then return false, 'Rien en cours.' end
    local kind = Config.Kinds[p.kind]
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
    Security:LogStaff(('[Braquage solo] %s : %s (%s)'):format(GetPlayerName(src) or src, kind.label, msg), 'jobs')
    if p.zone and started('gs_social') then
        local z = Stickup.zones()[p.zone]
        exports.gs_social:Newsroom('stickup', ('FAITS DIVERS · %s braqué(e) à main armée : %s sous le choc, l\'auteur court toujours.'):format(z and z.label or 'Un commerce', p.kind == 'teller' and 'le guichetier' or 'le caissier'))
    end
    return true, ('Butin : %s. Vite, la police arrive !'):format(msg)
end)

--- Abandon : la victime s'enfuit. Le crime a déjà été signalé au début ; petit cooldown quand même.
RegisterNetEvent('gs_stickup:server:cancel', function()
    local src = source
    if not Security:RateLimit(src, 'gs_stickup:cancel', 4, 10000) then return end
    local p = Stickup.pending[src]
    Stickup.pending[src] = nil
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
    Stickup.pending[src], Stickup.playerCd[src], Stickup.hour[src] = nil, nil, nil
end)
