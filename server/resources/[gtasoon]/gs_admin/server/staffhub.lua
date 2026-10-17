-- gs_admin (serveur) · V12.65 · Outils staff partagés entre F11 et l'appli :
--   · Chat staff (/sc en jeu ↔ appli) ;
--   · Carte des incidents de la soirée (tickets, joueurs à terre, alertes anti-triche) ;
--   · Événements programmés depuis l'appli (lieu de la liste « Téléporter vers… », heure du serveur) ;
--   · Double validation des bans définitifs (proposition n° 307).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local H = Config.StaffHub or {}

Hub = { chat = {}, nextChat = 0, incidents = {}, schedule = {}, nextSchedule = 0 }
BanReview = { list = {} }

local function now() return os.time() end
local function started(r) return GetResourceState(r) == 'started' end
local function staffOnline()
    local out = {}
    for _, id in ipairs(GetPlayers()) do local s = tonumber(id) if Admin.level(s) > 0 then out[#out + 1] = s end end
    return out
end
local function lbl(src) return ('%s [%s]'):format(GetPlayerName(src) or '?', tostring(src)) end

-- Chat staff -----------------------------------------------------------------------------------------------------------
function Hub.say(who, text, origin)
    text = Security:Sanitize(text, 300)
    if not text or text == '' then return false, 'Message vide.' end
    Hub.nextChat = Hub.nextChat + 1
    table.insert(Hub.chat, { id = Hub.nextChat, who = tostring(who), text = text, origin = origin, at = now() })
    while #Hub.chat > (H.chatKeep or 60) do table.remove(Hub.chat, 1) end
    for _, s in ipairs(staffOnline()) do
        TriggerClientEvent('chat:addMessage', s, { color = { 176, 72, 255 }, multiline = true,
            args = { ('[Staff%s] %s'):format(origin == 'appli' and ' · appli' or '', who), text } })
    end
    return true
end

RegisterCommand('sc', function(src, args)
    if src == 0 or Admin.level(src) < 1 then return end
    if not Security:RateLimit(src, 'gs_admin:sc', 5, 10000) then return end
    local ok, err = Hub.say(GetPlayerName(src) or ('#' .. src), table.concat(args or {}, ' '), 'jeu')
    if not ok then TriggerClientEvent('ox_lib:notify', src, { description = err .. ' Usage : /sc <message>', type = 'error' }) end
end, false)

-- Carte des incidents --------------------------------------------------------------------------------------------------
function Hub.incident(kind, coords, text)
    if not coords then return end
    table.insert(Hub.incidents, { kind = kind, x = coords.x + 0.0, y = coords.y + 0.0, at = now(), text = text })
    while #Hub.incidents > 300 do table.remove(Hub.incidents, 1) end
end
function Hub.recentIncidents()
    local since, out = now() - (H.incidentHours or 12) * 3600, {}
    for _, i in ipairs(Hub.incidents) do if i.at >= since then out[#out + 1] = i end end
    return out
end
-- joueur à terre ou mort (qbx_medical : 2 = à terre)
AddStateBagChangeHandler('qbx_medical:deathState', nil, function(bagName, _, value)
    if value ~= 2 then return end
    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end
    Hub.incident('death', GetEntityCoords(GetPlayerPed(src)), ('%s à terre'):format(lbl(src)))
end)
-- alertes anti-triche (relues toutes les minutes, position du joueur au moment de la lecture)
Hub.seenAlerts = {}
function Hub.pollAlerts()
    if not started('gs_security') then return end
    local ok, list = pcall(function() return exports.gs_security:GetAlerts() end)
    if not ok or type(list) ~= 'table' then return end
    for _, a in ipairs(list) do
        local key = ('%s:%s:%s'):format(tostring(a.src), tostring(a.at), tostring(a.kind))
        if not Hub.seenAlerts[key] then
            Hub.seenAlerts[key] = true
            local src = tonumber(a.src)
            if src and GetPlayerName(src) then Hub.incident('ac', GetEntityCoords(GetPlayerPed(src)), ('%s · %s'):format(lbl(src), tostring(a.kind))) end
        end
    end
end

-- Événements programmés ------------------------------------------------------------------------------------------------
local function saveSchedule() SetResourceKvp('gs_admin:schedule', json.encode(Hub.schedule)) end
do
    local ok, v = pcall(json.decode, GetResourceKvpString('gs_admin:schedule') or '[]')
    if ok and type(v) == 'table' then
        Hub.schedule = v
        for _, e in ipairs(v) do Hub.nextSchedule = math.max(Hub.nextSchedule, tonumber(e.id) or 0) end
    end
end

--- Types programmables : événements de Config.Events (au lieu choisi) et météos spéciales de gs_weather
function Hub.kinds()
    local out = {}
    for k, ev in pairs(Config.Events or {}) do out[#out + 1] = { id = k, label = ev.label, place = not ev.at and not ev.roadtrip and not ev.party } end
    for _, w in ipairs({ { 'weather:snow', 'Météo : neige' }, { 'weather:storm', 'Météo : tempête' }, { 'weather:fog', 'Météo : brouillard' }, { 'weather:heatwave', 'Météo : canicule' } }) do
        out[#out + 1] = { id = w[1], label = w[2], place = false }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

--- Programmer : kind, heure 'HH:MM' (heure du serveur, aujourd'hui ou demain), lieu (index de Config.Web.places)
function Hub.plan(kind, hhmm, place, by, level)
    if #Hub.schedule >= (H.scheduleMax or 12) then return false, 'Trop d\'événements programmés.' end
    local isWeather = type(kind) == 'string' and kind:find('^weather:') ~= nil
    local ev = not isWeather and Config.Events and Config.Events[kind]
    if not isWeather and not ev then return false, 'Événement inconnu.' end
    if (isWeather or (ev and ev.hunt)) and (tonumber(level) or 0) < 4 then return false, 'Météo spéciale et chasse au trésor : super-admins et fondateur.' end -- V12.65
    local h, m = tostring(hhmm or ''):match('^(%d%d?):(%d%d)$')
    h, m = tonumber(h), tonumber(m)
    if not h or h > 23 or m > 59 then return false, 'Heure au format HH:MM.' end
    local t = os.date('*t')
    t.hour, t.min, t.sec = h, m, 0
    local at = os.time(t)
    if at <= now() then at = at + 86400 end
    local pl
    if ev and not ev.at and not ev.roadtrip and not ev.party then
        pl = (Config.Web and Config.Web.places or {})[tonumber(place) or 0]
        if not pl then return false, 'Choisis le lieu de l\'événement.' end
    end
    Hub.nextSchedule = Hub.nextSchedule + 1
    local e = { id = Hub.nextSchedule, kind = kind, at = at, by = by, place = pl and pl.label or nil,
        x = pl and pl.coords.x or nil, y = pl and pl.coords.y or nil, z = pl and pl.coords.z or nil,
        label = isWeather and kind:sub(9) or ev.label }
    Hub.schedule[#Hub.schedule + 1] = e
    saveSchedule()
    Security:LogStaff(('[Programmé] %s : %s le %s%s'):format(by, e.label, os.date('%d/%m à %H:%M', at), e.place and (' · ' .. e.place) or ''), 'staff')
    return true, ('%s programmé le %s%s.'):format(e.label, os.date('%d/%m à %H:%M', at), e.place and (' · ' .. e.place) or '')
end

function Hub.unplan(id)
    for i, e in ipairs(Hub.schedule) do
        if e.id == tonumber(id) then table.remove(Hub.schedule, i) saveSchedule() return true, 'Événement déprogrammé.' end
    end
    return false, 'Introuvable.'
end

--- Lance un événement programmé (même chemin que F11, mais au lieu choisi, sans membre du staff en jeu)
function Hub.fire(e)
    if e.kind:find('^weather:') then
        if not started('gs_weather') then return false end
        return pcall(function() exports.gs_weather:StartEvent(e.kind:sub(9)) end)
    end
    local ev = Config.Events[e.kind]
    if not ev then return false end
    local at = e.x and vec3(e.x, e.y, e.z) or nil
    return pcall(function() Admin.runEventAt(e.kind, at, e.by) end)
end

function Hub.tick()
    local due = {}
    for i = #Hub.schedule, 1, -1 do
        if Hub.schedule[i].at <= now() then due[#due + 1] = table.remove(Hub.schedule, i) end
    end
    if #due > 0 then saveSchedule() end
    for _, e in ipairs(due) do
        local ok = Hub.fire(e)
        Security:LogStaff(('[Programmé] %s : %s %s'):format(e.by or '?', e.label, ok and 'lancé' or 'impossible'), 'staff')
    end
    Hub.pollAlerts()
end
CreateThread(function()
    while true do
        Wait(30000)
        Hub.tick()
    end
end)

-- Double validation des bans définitifs ---------------------------------------------------------------------------------
local R = H.banReview or {}
local function saveReviews() SetResourceKvp('gs_admin:banreviews', json.encode(BanReview.list)) end
do
    local ok, v = pcall(json.decode, GetResourceKvpString('gs_admin:banreviews') or '[]')
    if ok and type(v) == 'table' then BanReview.list = v end
end
BanReview.next = 0
for _, r in ipairs(BanReview.list) do BanReview.next = math.max(BanReview.next, tonumber(r.id) or 0) end

--- Un ban définitif demandé à ce rang doit-il être validé par un 2e admin ?
function BanReview.needed(level) return R.enabled and (tonumber(level) or 0) < (R.bypassLevel or 5) end

--- Ban définitif mis en attente : rend la fin du ban temporaire et le libellé de durée
function BanReview.hold(lic, name, reason, staff, staffKey)
    BanReview.next = BanReview.next + 1
    BanReview.list[#BanReview.list + 1] = { id = BanReview.next, license = lic, name = name, reason = reason, by = staff, byKey = staffKey or staff, at = now() }
    saveReviews()
    for _, s in ipairs(staffOnline()) do
        if Admin.level(s) >= (R.minLevel or 3) then
            TriggerClientEvent('ox_lib:notify', s, { title = 'Ban définitif à valider', description = ('%s : %s (par %s). F11 → Bans définitifs à valider.'):format(name, reason, staff), type = 'warning', duration = 12000 })
        end
    end
    return now() + (R.tempDays or 1) * 86400, ('définitif EN ATTENTE de validation (%d j en attendant)'):format(R.tempDays or 1)
end

function BanReview.pending()
    local keep, out = now() - (R.keepHours or 72) * 3600, {}
    for i = #BanReview.list, 1, -1 do if BanReview.list[i].at < keep then table.remove(BanReview.list, i) end end
    for _, r in ipairs(BanReview.list) do out[#out + 1] = { id = r.id, name = r.name, reason = r.reason, by = r.by, ago = now() - r.at } end
    return out
end

--- Valider (ban définitif) ou refuser (le ban temporaire reste) : jamais par celui qui l'a demandé
function BanReview.decide(id, accept, deciderKey, decider, level)
    if (tonumber(level) or 0) < (R.minLevel or 3) then return false, 'Réservé aux admins.' end
    for i, r in ipairs(BanReview.list) do
        if r.id == tonumber(id) then
            if r.byKey == deciderKey then return false, 'Un autre admin doit valider (pas celui qui a demandé le ban).' end
            table.remove(BanReview.list, i)
            saveReviews()
            if accept then
                Store.banSet(r.license, r.name, 0, r.reason, ('%s + %s'):format(r.by, decider))
                Store.addNote(r.license, 'warn', ('Bannissement définitif validé par %s : %s'):format(decider, r.reason), decider)
                Admin.publishSanction('Bannissement', r.name, r.reason, 'définitif')
                Security:LogStaff(('[Ban] définitif VALIDÉ par %s : %s (demandé par %s)'):format(decider, r.name, r.by), 'staff')
                return true, ('Ban définitif validé : %s.'):format(r.name)
            end
            Security:LogStaff(('[Ban] définitif REFUSÉ par %s : %s (demandé par %s, le ban temporaire reste)'):format(decider, r.name, r.by), 'staff')
            return true, ('Refusé : %s garde son ban temporaire.'):format(r.name)
        end
    end
    return false, 'Introuvable (déjà traité ?).'
end

lib.callback.register('gs_admin:banReviews', function(src)
    if not Security:RateLimit(src, 'gs_admin:banReviews', 6, 10000) or Admin.level(src) < (R.minLevel or 3) then return {} end
    return BanReview.pending()
end)
lib.callback.register('gs_admin:banDecide', function(src, id, accept)
    if not Security:RateLimit(src, 'gs_admin:banDecide', 4, 10000) then return false, 'Doucement.' end
    return BanReview.decide(id, accept == true, GetPlayerIdentifierByType(src, 'license') or lbl(src), lbl(src), Admin.level(src))
end)
