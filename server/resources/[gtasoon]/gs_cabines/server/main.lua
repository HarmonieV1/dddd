-- gs_cabines (serveur) · V12.60. Appels depuis une cabine : vérifiés ici (à côté de la cabine, à pied, pièce payée, délai),
-- envoyés au central police (même alerte que gs_wanted, « appel anonyme ») ou à la rédaction Weazel.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Cabines = { last = {}, tips = {}, nextId = 90000 } -- last[cid] = os.time() du dernier appel ; tips = tuyaux en attente

local function now() return os.time() end
local function started(r) return GetResourceState(r) == 'started' end
local function onDuty(job)
    if not started('gs_jobs') then return {} end
    local ok, l = pcall(function() return exports.gs_jobs:GetOnDutyPlayers(job) end)
    return ok and l or {}
end

--- kind = 'police' | 'press' ; booth = { x, y, z } (position de la cabine, envoyée par le client, vérifiée à Config.Reach)
function Cabines.call(src, kind, text, booth)
    if kind ~= 'police' and kind ~= 'press' then return false, 'Numéro inconnu.' end
    text = Security:Sanitize(text, 400)
    if not text or (utf8.len(text) or 0) < 5 then return false, 'Message trop court.' end
    if utf8.len(text) and utf8.len(text) > Config.MaxLength then text = text:sub(1, utf8.offset(text, Config.MaxLength + 1) - 1) end
    if type(booth) ~= 'table' or not tonumber(booth.x) or not tonumber(booth.y) or not tonumber(booth.z) then return false, 'Cabine introuvable.' end
    local at = vec3(booth.x + 0.0, booth.y + 0.0, booth.z + 0.0)
    if not Security:InRange(src, at, Config.Reach) then return false, 'Approche-toi de la cabine.' end
    local ped = GetPlayerPed(src)
    if ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'Descends du véhicule.' end
    local cid = Bridge:GetIdentifier(src) or tostring(src)
    if Cabines.last[cid] and Cabines.last[cid] + Config.Cooldown > now() then
        return false, ('La cabine est occupée… réessaie dans %d min.'):format(math.ceil((Cabines.last[cid] + Config.Cooldown - now()) / 60))
    end
    local targets = onDuty(kind == 'police' and Config.PoliceJob or Config.PressJob)
    if kind == 'police' and #targets == 0 then return false, 'Ça sonne dans le vide : aucun policier en service au central.' end
    if not Bridge:RemoveMoney(src, 'cash', Config.Price, 'cabine téléphonique') then return false, ('Il te faut %d $ en pièces (liquide).'):format(Config.Price) end
    Cabines.last[cid] = now()
    -- Trace staff (abus) : jamais montrée aux joueurs
    Security:LogStaff(('[Cabine] appel %s de %s [%d] : %s'):format(kind == 'police' and 'police' or 'Weazel', GetPlayerName(src) or '?', src, text), 'staff')
    if kind == 'police' then
        local a, shift = math.random() * math.pi * 2, math.random() * Config.Blur * 0.7
        Cabines.nextId = Cabines.nextId + 1
        local report = { id = Cabines.nextId, crime = 'anonymous_call', label = 'Appel anonyme (cabine)', radius = math.floor(Config.Blur),
            coords = vec3(at.x + math.cos(a) * shift, at.y + math.sin(a) * shift, at.z), witnesses = 0, precision = 0.3, delay = 0,
            desc = { '« ' .. text .. ' »' } }
        for _, cop in ipairs(targets) do TriggerClientEvent('gs_wanted:client:dispatch', cop, report) end
        return true, 'Le central a pris ton appel. Tu raccroches sans laisser ton nom.'
    end
    local tip = { text = text, at = now(), street = booth.street and Security:Sanitize(booth.street, 60) or nil }
    if #targets == 0 then
        table.insert(Cabines.tips, 1, tip)
        Cabines.tips[Config.Tips.keep + 1] = nil
        return true, 'Messagerie de la rédaction : ton tuyau est enregistré, un journaliste l\'écoutera.'
    end
    for _, j in ipairs(targets) do TriggerClientEvent('gs_cabines:client:tip', j, tip) end
    return true, 'Un journaliste a noté ton tuyau. Tu raccroches sans laisser ton nom.'
end

--- Tuyaux en attente (journalistes en service) : rendus puis effacés
function Cabines.pending(src)
    local mine = false
    for _, j in ipairs(onDuty(Config.PressJob)) do if j == src then mine = true end end
    if not mine then return false, 'Réservé à la rédaction Weazel en service.' end
    local out = {}
    for _, t in ipairs(Cabines.tips) do if now() - t.at <= Config.Tips.hours * 3600 then out[#out + 1] = t end end
    Cabines.tips = {}
    return true, out
end

lib.callback.register('gs_cabines:call', function(src, kind, text, booth)
    if not Security:RateLimit(src, 'gs_cabines:call', 3, 10000) then return false, 'Doucement.' end
    return Cabines.call(src, kind, text, booth)
end)
lib.callback.register('gs_cabines:tips', function(src)
    if not Security:RateLimit(src, 'gs_cabines:tips', 3, 10000) then return false, 'Doucement.' end
    return Cabines.pending(src)
end)
