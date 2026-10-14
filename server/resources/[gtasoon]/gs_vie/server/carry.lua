-- gs_vie (serveur) · V12.57 Porter / prendre en otage : la demande passe par le serveur (distance, arme, accord).
-- Sans accord seulement si l'autre est menotté, à terre ou mort. Un lien = deux joueurs ; l'un ou l'autre qui part le coupe.
local Security, Bridge = exports.gs_security, exports.gs_bridge
Carry = { links = {}, pending = {} } -- links[src] = { other, role = 'carrier'|'carried', kind, forced } ; pending[cible] = { from, kind, at }

local function now() return os.time() end

local function cuffed(src)
    if GetResourceState('gs_police') ~= 'started' then return false end
    local ok, r = pcall(function() return exports.gs_police:IsCuffed(src) end)
    return ok and r == true
end

local function forcedOn(target) return cuffed(target) or Bridge:IsDowned(target) == true end

local function weaponOk(src)
    local w = GetSelectedPedWeapon(GetPlayerPed(src))
    for _, name in ipairs(Config.Carry.hostageWeapons) do
        if w == joaat(name) then return true end
    end
    return false
end

local function near(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= Config.Carry.range + 0.5
end

function Carry.start(a, b, kind, forced)
    Carry.pending[b] = nil
    Carry.links[a] = { other = b, role = 'carrier', kind = kind, forced = forced }
    Carry.links[b] = { other = a, role = 'carried', kind = kind, forced = forced }
    TriggerClientEvent('gs_vie:client:carryStart', a, 'carrier', kind, b, forced)
    TriggerClientEvent('gs_vie:client:carryStart', b, 'carried', kind, a, forced)
end

function Carry.stop(src, why)
    local l = Carry.links[src]
    if not l then return false end
    Carry.links[src], Carry.links[l.other] = nil, nil
    TriggerClientEvent('gs_vie:client:carryStop', src, why)
    TriggerClientEvent('gs_vie:client:carryStop', l.other, why)
    return true
end

function Carry.request(src, target, kind)
    target = tonumber(target)
    if kind ~= 'carry' and kind ~= 'hostage' then return false, 'Action inconnue.' end
    if not target or target == src or not Bridge:IsLoaded(target) then return false, 'Personne ici.' end
    if Carry.links[src] or Carry.links[target] then return false, 'Déjà occupé.' end
    if Bridge:IsDowned(src) or cuffed(src) then return false, 'Impossible dans ton état.' end
    if not near(src, target) then return false, 'Trop loin.' end
    if kind == 'hostage' and not weaponOk(src) then return false, 'Il faut une arme de poing ou un couteau en main.' end
    if forcedOn(target) then
        Carry.start(src, target, kind, true)
        return true
    end
    local p = Carry.pending[target]
    if p and now() - p.at < Config.Carry.askTimeout then return false, 'Cette personne a déjà une demande en cours.' end
    Carry.pending[target] = { from = src, kind = kind, at = now() }
    TriggerClientEvent('gs_vie:client:carryAsk', target, src, kind)
    return true, 'Demande envoyée.'
end

function Carry.answer(src, from, yes)
    local p = Carry.pending[src]
    if not p or p.from ~= tonumber(from) then return false end
    Carry.pending[src] = nil
    if now() - p.at > Config.Carry.askTimeout then return false end
    if not yes then
        Bridge:Notify(p.from, 'Refusé.', 'error')
        return false
    end
    if Carry.links[src] or Carry.links[p.from] or not near(p.from, src) then
        Bridge:Notify(p.from, 'Trop tard : vous n\'êtes plus à côté.', 'error')
        return false
    end
    if p.kind == 'hostage' and not weaponOk(p.from) then return false end
    Carry.start(p.from, src, p.kind, false)
    return true
end

--- Qui peut lâcher ? Le porteur toujours ; la personne portée seulement si elle a accepté (sinon : elle se débat en vain)
function Carry.release(src)
    local l = Carry.links[src]
    if not l then return false end
    if l.role == 'carried' and l.forced then return false end
    return Carry.stop(src, 'lâché')
end

lib.callback.register('gs_vie:carryRequest', function(src, target, kind)
    if not Security:RateLimit(src, 'gs_vie:carry', 3, 10000) then return false, 'Doucement.' end
    return Carry.request(src, target, kind)
end)
RegisterNetEvent('gs_vie:carryAnswer', function(from, yes)
    local src = source
    if not Security:RateLimit(src, 'gs_vie:carryAnswer', 3, 10000) then return end
    Carry.answer(src, from, yes == true)
end)
RegisterNetEvent('gs_vie:carryRelease', function()
    local src = source
    if not Security:RateLimit(src, 'gs_vie:carryRelease', 5, 10000) then return end
    Carry.release(src)
end)
-- Le porteur tombe (mort, à terre, menotté) : son client le signale
RegisterNetEvent('gs_vie:carryBroken', function()
    local src = source
    if not Security:RateLimit(src, 'gs_vie:carryBroken', 3, 10000) then return end
    local l = Carry.links[src]
    if l and l.role == 'carrier' then Carry.stop(src, 'lâché') end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Carry.pending[src] = nil
    Carry.stop(src, 'parti')
end)
