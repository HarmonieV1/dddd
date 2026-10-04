-- gs_wanted (serveur) · V9 « La cavale ». Publication : GlobalState.gsFugitives = { { id, title, desc, bounty, since } }.
-- Légendes gardées en KVP (gs_legends). Le temps de cavale ne compte que connecté.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local F = Config.Fugitive

Fugitive = { list = {} } -- [src] = { cid, name, title, desc, bounty, played, lastTick, since }

local function now() return os.time() end

local function publish()
    local out = {}
    for src, f in pairs(Fugitive.list) do
        out[#out + 1] = { id = src, title = f.title, desc = f.desc, bounty = f.bounty, left = math.max(0, F.hours * 3600 - f.played) }
    end
    GlobalState.gsFugitives = out
end

local function legends()
    local ok, l = pcall(function() return json.decode(GetResourceKvpString('gs_legends') or '[]') end)
    return ok and type(l) == 'table' and l or {}
end

function Fugitive.start(src)
    if Fugitive.list[src] then return false, 'Tu es déjà en cavale.' end
    local heat = Wanted.heat[src] or 0
    if heat <= F.minHeat then return false, 'Il faut être recherché à 5 étoiles pour entrer en cavale.' end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return false end
    -- l'avis de recherche : le nom seulement si la personne est fichée ; sinon la description des témoins
    local known = GetResourceState('gs_evidence') == 'started' and (select(2, pcall(function() return exports.gs_evidence:IsFiled(cid) end))) == true
    local desc = Memory and table.concat((Memory.describe(src, 1.0, GetVehiclePedIsIn(GetPlayerPed(src), false))), ', ') or ''
    local bounty = F.bountyBase + heat * F.bountyPerHeat
    Fugitive.list[src] = { cid = cid, name = Bridge:GetName(src) or '?', title = known and (Bridge:GetName(src) or 'Inconnu') or 'Individu non identifié',
        desc = desc, bounty = bounty, played = 0, lastTick = now(), since = now() }
    publish()
    TriggerClientEvent('gs_wanted:client:fugitive', -1, Fugitive.list[src].title, bounty)
    TriggerEvent('gs_wanted:server:fugitive', Fugitive.list[src].title, bounty) -- V10 : Radio Los Santos
    if GetResourceState('gs_social') == 'started' then
        pcall(function() exports.gs_social:Newsroom('flash', ('AVIS DE RECHERCHE : %s. Prime : %d $.'):format(Fugitive.list[src].title, bounty)) end)
    end
    return true, ('Tu es en cavale. Tiens %d h sans te faire prendre et tu deviendras une légende.'):format(F.hours)
end

--- Fin de cavale : capture (prime à `hunter`), légende, ou abandon
function Fugitive.finish(src, outcome, hunter)
    local f = Fugitive.list[src]
    if not f then return false end
    Fugitive.list[src] = nil
    publish()
    if outcome == 'caught' then
        if hunter and GetPlayerName(hunter) then
            Bridge:AddMoney(hunter, 'bank', f.bounty)
            Bridge:Notify(hunter, ('Prime touchée : %d $ pour la capture de %s.'):format(f.bounty, f.title), 'success')
        end
        if GetResourceState('gs_social') == 'started' then
            pcall(function() exports.gs_social:Newsroom('flash', ('Fin de cavale : %s a été arrêté.'):format(f.title)) end)
        end
    elseif outcome == 'legend' then
        local l = legends()
        table.insert(l, 1, { name = f.name, date = os.date('%d/%m/%Y'), hours = F.hours, kind = 'cavale' })
        for i = 31, #l do l[i] = nil end
        SetResourceKvp('gs_legends', json.encode(l))
        Wanted.clearHeat(src)
        Bridge:Notify(src, 'Tu as tenu. Los Santos parlera de toi longtemps : tu es une légende.', 'success')
        if GetResourceState('gs_reputation') == 'started' then pcall(function() exports.gs_reputation:Add(src, 'street', 150) end) end
        if GetResourceState('gs_social') == 'started' then
            pcall(function() exports.gs_social:Newsroom('flash', ('LÉGENDE : %s a échappé à toute la ville pendant %d heures.'):format(f.name, F.hours)) end)
        end
        TriggerEvent('gs_wanted:server:legend', src, f.name)
    end
    return true
end

--- Chaque minute : temps de cavale (connecté), chaleur maintenue, légende au bout du compte
function Fugitive.tick()
    local t = now()
    for src, f in pairs(Fugitive.list) do
        if not GetPlayerName(src) then
            if t - f.lastTick > F.offlineGrace then Fugitive.finish(src, 'abandon') end
        else
            f.played = f.played + math.min(120, t - f.lastTick)
            f.lastTick = t
            Wanted.heat[src] = math.max(Wanted.heat[src] or 0, F.minHeat + 1)
            Wanted.lastReport[src] = t
            if f.played >= F.hours * 3600 then Fugitive.finish(src, 'legend') end
        end
    end
    publish()
end

--- Citoyen chasseur de primes : livre le fugitif à terre devant un commissariat
function Fugitive.claim(src, target)
    target = tonumber(target)
    local f = target and Fugitive.list[target]
    if not f or target == src then return false, 'Ce n\'est pas un fugitif.' end
    if not Bridge:IsDowned(target) then return false, 'Il faut qu\'il soit à terre.' end
    if not Security:PlayersInRange(src, target, 5.0) then return false, 'Trop loin.' end
    local ped = GetPlayerPed(target)
    local here, ok = GetEntityCoords(ped), false
    for _, s in ipairs(F.stations) do if #(here - s) <= F.stationRange then ok = true end end
    if not ok then return false, 'Amène-le devant un commissariat ou un bureau du shérif.' end
    Bridge:Revive(target)
    pcall(function() exports.gs_police:Jail(target, F.jailMinutes, 'Capturé en cavale (chasseur de primes)') end)
    Fugitive.finish(target, 'caught', src)
    return true, 'Fugitif livré.'
end

-- Incarcéré par un policier pendant la cavale : prime au policier
AddEventHandler('gs_police:server:jailed', function(target, _, by)
    if Fugitive.list[target] then Fugitive.finish(target, 'caught', by) end
end)

lib.callback.register('gs_wanted:fugitive', function(src, action, target)
    if not Security:RateLimit(src, 'gs_wanted:fugitive', 3, 5000) then return false, 'Doucement.' end
    if action == 'start' then return Fugitive.start(src)
    elseif action == 'claim' then return Fugitive.claim(src, target)
    elseif action == 'legends' then return true, legends() end
    return false
end)

CreateThread(function() while true do Wait(60000) Fugitive.tick() end end)
exports('IsFugitive', function(src) return Fugitive.list[src] ~= nil end)
