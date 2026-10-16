-- gs_cabines (serveur) · V12.60. Appels depuis une cabine : vérifiés ici (à côté de la cabine, à pied, pièce payée, délai),
-- envoyés au central police (même alerte que gs_wanted, « appel anonyme ») ou à la rédaction Weazel.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Cabines = { last = {}, lastNum = {}, tips = {}, taps = {}, nextId = 90000, calls = {} } -- calls[n°] = appel anonyme police (V12.63 : fausse alerte) -- last[cid] = dernier appel police / Weazel ; lastNum = dernier appel vers un numéro ; taps[cabine] = écoute

local function now() return os.time() end
local function started(r) return GetResourceState(r) == 'started' end
local function onDuty(job)
    if not started('gs_jobs') then return {} end
    local ok, l = pcall(function() return exports.gs_jobs:GetOnDutyPlayers(job) end)
    return ok and l or {}
end

--- V12.61 · Identifiant d'une cabine (position arrondie à 2 m : la même cabine donne toujours la même clé)
local function boothKey(b) return ('%d:%d'):format(math.floor(b.x / 2.0), math.floor(b.y / 2.0)) end

--- V12.61 · Cabine sur écoute ? Le central reçoit l'appel (sans le nom de l'appelant : son genre et l'heure seulement).
function Cabines.wiretap(src, booth, what, text)
    local t = Cabines.taps[boothKey(booth)]
    if not t then return false end
    if t.untilAt <= now() then Cabines.taps[boothKey(booth)] = nil return false end
    local info = { street = t.street or Security:Sanitize(booth.street, 60), at = os.date('%H:%M'), what = what, text = text, -- V12.62 : rue nettoyée
        gender = Bridge:GetGender(src) == 'female' and 'une femme' or 'un homme' }
    for _, cop in ipairs(onDuty(Config.PoliceJob)) do TriggerClientEvent('gs_cabines:client:tapped', cop, info) end
    return true
end

--- V12.61 · Police : mettre une cabine sur écoute (ou la retirer). action = 'on' | 'off' | 'list'
function Cabines.tap(src, action, booth)
    local isCop = false
    for _, c in ipairs(onDuty(Config.PoliceJob)) do if c == src then isCop = true end end
    local job = Bridge:GetJob(src)
    if not isCop or not job or (tonumber(job.grade) or 0) < Config.Tap.grade then return false, ('Réservé à la police en service (grade %d et plus).'):format(Config.Tap.grade) end
    if action == 'list' then
        local out = {}
        for _, t in pairs(Cabines.taps) do if t.untilAt > now() then out[#out + 1] = { street = t.street, left = math.ceil((t.untilAt - now()) / 60) } end end
        return true, out
    end
    if type(booth) ~= 'table' or not tonumber(booth.x) or not tonumber(booth.y) or not tonumber(booth.z) then return false, 'Cabine introuvable.' end
    if not Security:InRange(src, vec3(booth.x + 0.0, booth.y + 0.0, booth.z + 0.0), Config.Reach) then return false, 'Approche-toi de la cabine.' end
    local key = boothKey(booth)
    if action == 'off' then
        if not Cabines.taps[key] then return false, 'Cette cabine n\'est pas sur écoute.' end
        Cabines.taps[key] = nil
        return true, 'Écoute retirée.'
    end
    local n = 0
    for k, t in pairs(Cabines.taps) do if t.untilAt > now() then n = n + 1 else Cabines.taps[k] = nil end end
    if n >= Config.Tap.max and not Cabines.taps[key] then return false, ('%d cabines sur écoute au plus.'):format(Config.Tap.max) end
    local street = Security:Sanitize(booth.street, 60) -- V12.62 : texte du client, nettoyé avant d'être affiché ou journalisé
    Cabines.taps[key] = { untilAt = now() + Config.Tap.hours * 3600, street = street, by = Bridge:GetName(src) }
    Security:LogStaff(('[Cabine] écoute posée par %s [%d] (%s, %d h)'):format(GetPlayerName(src) or '?', src, street or key, Config.Tap.hours), 'staff')
    return true, ('Cabine sur écoute pendant %d h : chaque appel passé d\'ici arrivera au central.'):format(Config.Tap.hours)
end

--- V12.61 · Appeler un numéro depuis la cabine : le correspondant voit « Numéro masqué ».
function Cabines.callNumber(src, number, booth)
    number = type(number) == 'string' and number:gsub('%s', '') or nil
    if not number or number == '' then return false, 'Compose un numéro.' end
    if type(booth) ~= 'table' or not tonumber(booth.x) or not tonumber(booth.y) or not tonumber(booth.z) then return false, 'Cabine introuvable.' end
    if not Security:InRange(src, vec3(booth.x + 0.0, booth.y + 0.0, booth.z + 0.0), Config.Reach) then return false, 'Approche-toi de la cabine.' end
    local ped = GetPlayerPed(src)
    if ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'Descends du véhicule.' end
    local cid = Bridge:GetIdentifier(src) or tostring(src)
    if Cabines.lastNum[cid] and Cabines.lastNum[cid] + Config.NumberCooldown > now() then return false, 'Attends un peu avant de rappeler.' end
    if not started('gs_phone') then return false, 'Le réseau téléphonique est coupé.' end
    if (Bridge:GetMoney(src, 'cash') or 0) < Config.Price then return false, ('Il te faut %d $ en pièces (liquide).'):format(Config.Price) end
    local okC, ok, idOrErr = pcall(function() return exports.gs_phone:BoothCall(src, number) end)
    if not okC then return false, 'Le réseau téléphonique est coupé.' end
    if not ok then return false, idOrErr end
    Bridge:RemoveMoney(src, 'cash', Config.Price, 'cabine téléphonique')
    Cabines.lastNum[cid] = now()
    Security:LogStaff(('[Cabine] %s [%d] appelle le %s (numéro masqué)'):format(GetPlayerName(src) or '?', src, number), 'staff')
    Cabines.wiretap(src, booth, 'appel vers le ' .. number)
    return true, idOrErr
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
    local tapped = Cabines.wiretap(src, booth, kind == 'police' and 'appel au central (police)' or 'appel à la rédaction Weazel', text) -- V12.61
    if kind == 'police' then
        local a, shift = math.random() * math.pi * 2, math.random() * Config.Blur * 0.7
        Cabines.nextId = Cabines.nextId + 1
        -- V12.63 · fausse alerte : l'appel est-il retrouvable ? (cabine sur écoute, ou filmée par une caméra du quartier)
        local F = Config.FalseAlarm or {}
        for n, c in pairs(Cabines.calls) do if now() - c.at > (F.hours or 2) * 3600 then Cabines.calls[n] = nil end end
        Cabines.calls[Cabines.nextId] = { cid = cid, at = now(), how = tapped and 'écoute' or (math.random() < (F.camera or 0.35) and 'caméra' or nil) }
        local report = { id = Cabines.nextId, crime = 'anonymous_call', label = ('Appel anonyme (cabine) n° %d'):format(Cabines.nextId), radius = math.floor(Config.Blur),
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

--- V12.63 · Fausse alerte (proposition n° 161) : un policier en service marque un appel anonyme ; retrouvé (écoute, caméra) =
--- amende à l'appelant (en banque, ou à sa prochaine connexion s'il n'est pas en ville). n° absent = le dernier appel.
local function fineKey(cid) return 'fausse_alerte:' .. tostring(cid) end
function Cabines.falseAlarm(src, id)
    local isCop = false
    for _, c in ipairs(onDuty(Config.PoliceJob)) do if c == src then isCop = true end end
    if not isCop then return false, 'Réservé à la police en service.' end
    local F = Config.FalseAlarm or {}
    id = math.tointeger(tonumber(id))
    if not id then for n in pairs(Cabines.calls) do if not id or n > id then id = n end end end
    local c = id and Cabines.calls[id]
    if not c or now() - c.at > (F.hours or 2) * 3600 then return false, 'Appel inconnu ou trop ancien.' end
    if c.flagged then return false, 'Cet appel est déjà classé « fausse alerte ».' end
    c.flagged = true
    Security:LogStaff(('[Cabine] appel n° %d classé fausse alerte par %s [%d] (%s)'):format(id, GetPlayerName(src) or '?', src, c.how or 'introuvable'), 'staff')
    if not c.how then return true, ('Appel n° %d classé « fausse alerte ». Introuvable : ni écoute ni caméra sur cette cabine.'):format(id) end
    local fine = math.floor(tonumber(F.fine) or 2500)
    local caller = Bridge:GetSourceByIdentifier(c.cid)
    if caller and GetPlayerName(caller) then
        Bridge:RemoveMoney(caller, 'bank', fine, 'amende : fausse alerte depuis une cabine')
        TriggerClientEvent('ox_lib:notify', caller, { title = 'LSPD · amende', type = 'error', duration = 10000,
            description = ('Fausse alerte depuis une cabine : ton appel a été retrouvé (%s). Amende : %d $.'):format(c.how, fine) })
    else
        SetResourceKvpInt(fineKey(c.cid), (GetResourceKvpInt(fineKey(c.cid)) or 0) + fine) -- appliquée à sa prochaine connexion
    end
    return true, ('Appel n° %d retrouvé grâce à la %s : amende de %d $ envoyée à l\'appelant.'):format(id, c.how, fine)
end

AddEventHandler('gs_bridge:server:playerLoaded', function(src)
    src = tonumber(src) or source
    local cid = Bridge:GetIdentifier(src)
    local due = cid and GetResourceKvpInt(fineKey(cid)) or 0
    if due and due > 0 then
        DeleteResourceKvp(fineKey(cid))
        Bridge:RemoveMoney(src, 'bank', due, 'amende : fausse alerte depuis une cabine')
        TriggerClientEvent('ox_lib:notify', src, { title = 'LSPD · amende', type = 'error', duration = 10000,
            description = ('Pendant ton absence : fausse alerte depuis une cabine, appel retrouvé. Amende : %d $.'):format(due) })
    end
end)

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
lib.callback.register('gs_cabines:number', function(src, number, booth) -- V12.61
    if not Security:RateLimit(src, 'gs_cabines:number', 3, 10000) then return false, 'Doucement.' end
    return Cabines.callNumber(src, number, booth)
end)
lib.callback.register('gs_cabines:tap', function(src, action, booth) -- V12.61
    if not Security:RateLimit(src, 'gs_cabines:tap', 5, 10000) then return false, 'Doucement.' end
    return Cabines.tap(src, action, booth)
end)
lib.callback.register('gs_cabines:falseAlarm', function(src, id) -- V12.63
    if not Security:RateLimit(src, 'gs_cabines:falseAlarm', 3, 10000) then return false, 'Doucement.' end
    return Cabines.falseAlarm(src, id)
end)
lib.callback.register('gs_cabines:tips', function(src)
    if not Security:RateLimit(src, 'gs_cabines:tips', 3, 10000) then return false, 'Doucement.' end
    return Cabines.pending(src)
end)
