-- gs_discord (serveur) · V12.61 « Rapport staff de fin de soirée » (proposition n° 146). Chaque jour à Config.StaffReport.hour
-- (4 h par défaut), un résumé de la soirée dans le salon STAFF (webhook gs_webhook_staff, sinon gs_staff_webhook ; jamais
-- dans un salon public) : joueurs au plus haut, tickets, sanctions, alertes anti-triche, Lives ouverts, crimes signalés,
-- morts RP, membres du staff actifs. Compteurs gardés en KVP (un redémarrage ne remet pas la soirée à zéro).
local R = Config.StaffReport

StaffReport = { since = 0, peak = 0, peakAt = nil, crimes = 0, deaths = {}, sentDay = nil,
    seen = { tickets = 0, lives = 0, alerts = 0 }, carry = { tickets = 0, lives = 0, alerts = 0 } } -- V12.62 : voir StaffReport.counters

local function save() SetResourceKvp('staffreport', json.encode(StaffReport)) end
local function restore()
    local ok, t = pcall(json.decode, GetResourceKvpString('staffreport') or '{}')
    if ok and type(t) == 'table' then for k, v in pairs(t) do StaffReport[k] = v end end
    if (StaffReport.since or 0) == 0 then StaffReport.since = os.time() end
end
local function started(r) return GetResourceState(r) == 'started' end
local function try(fn, default) local ok, v = pcall(fn) if ok and v ~= nil then return v end return default end

--- Compteurs vivants des autres ressources (tickets et alertes : gs_admin, Lives : gs_lives) depuis `since`
local function live()
    local since = StaffReport.since or 0
    local a = started('gs_admin') and try(function() return exports.gs_admin:NightStats(since) end, nil) or nil
    local lives = started('gs_lives') and try(function() return exports.gs_lives:ViewsSince(since) end, 0) or 0
    return a, { tickets = a and tonumber(a.tickets) or 0, lives = tonumber(lives) or 0, alerts = a and tonumber(a.alerts) or 0 }
end

--- V12.62 (relecture) · Ces compteurs vivent en mémoire chez gs_admin / gs_lives : un redémarrage pendant la soirée les remet
--- à zéro. On garde ici (KVP) la dernière valeur vue ; si elle redescend, la ressource a redémarré : on reporte l'ancienne.
function StaffReport.counters()
    local _, cur = live()
    StaffReport.seen = StaffReport.seen or { tickets = 0, lives = 0, alerts = 0 }
    StaffReport.carry = StaffReport.carry or { tickets = 0, lives = 0, alerts = 0 }
    local changed = false
    for k, v in pairs(cur) do
        local was = tonumber(StaffReport.seen[k]) or 0
        if v < was then StaffReport.carry[k] = (tonumber(StaffReport.carry[k]) or 0) + was end
        if v ~= was then StaffReport.seen[k] = v changed = true end
    end
    if changed then save() end
    return cur
end

--- Pic de joueurs (appelé chaque minute)
function StaffReport.sample(n)
    n = tonumber(n) or #GetPlayers()
    if n > (StaffReport.peak or 0) then StaffReport.peak, StaffReport.peakAt = n, os.date('%H:%M') save() end
    StaffReport.counters()
end

AddEventHandler('gs_wanted:server:reported', function() StaffReport.crimes = (StaffReport.crimes or 0) + 1 save() end) -- V12.62 : gardé en KVP
AddEventHandler('gs_cimetiere:server:buried', function(name)
    StaffReport.deaths = StaffReport.deaths or {}
    StaffReport.deaths[#StaffReport.deaths + 1] = tostring(name or '?')
    save()
end)

--- Contenu du rapport (embed Discord)
function StaffReport.embed()
    local since = StaffReport.since or 0
    local a = live()
    local cur = StaffReport.counters()
    local c = StaffReport.carry or {}
    local tickets, lives, alerts = cur.tickets + (tonumber(c.tickets) or 0), cur.lives + (tonumber(c.lives) or 0), cur.alerts + (tonumber(c.alerts) or 0)
    local sanc = {}
    for label, n in pairs(a and a.sanctions or {}) do sanc[#sanc + 1] = ('%d %s'):format(n, label) end
    table.sort(sanc)
    local f = {
        { name = '👥 Joueurs au plus haut', value = ('**%d**%s'):format(StaffReport.peak or 0, StaffReport.peakAt and (' à ' .. StaffReport.peakAt) or ''), inline = true },
        { name = '🎫 Tickets', value = a and ('%d ouvert(s) · %d encore en attente'):format(tickets, a.openTickets) or '—', inline = true },
        { name = '⚖️ Sanctions', value = #sanc > 0 and table.concat(sanc, '\n') or 'aucune', inline = true },
        { name = '🛡️ Alertes anti-triche', value = a and tostring(alerts) or '—', inline = true },
        { name = '📺 Lives ouverts', value = tostring(lives), inline = true },
        { name = '🚨 Crimes signalés', value = tostring(StaffReport.crimes or 0), inline = true },
    }
    if StaffReport.deaths and #StaffReport.deaths > 0 then f[#f + 1] = { name = '✝️ Morts RP', value = table.concat(StaffReport.deaths, ', '):sub(1, 1000) } end
    if a and #a.staff > 0 then f[#f + 1] = { name = '🧑‍✈️ Staff actif', value = table.concat(a.staff, ', '):sub(1, 1000) } end
    return { title = ('📋 Rapport de fin de soirée · %s'):format(os.date('%d/%m')), color = Config.Color, fields = f,
        footer = { text = ('Depuis le %s'):format(os.date('%d/%m %H:%M', since)) } }
end

--- Envoi au salon staff, puis remise à zéro des compteurs. Renvoie false sans webhook staff.
function StaffReport.send()
    local hook = GetConvar('gs_webhook_staff', '')
    if hook == '' then hook = GetConvar('gs_staff_webhook', '') end
    if not hook:match('^https://discord%.com/api/webhooks/') and not hook:match('^https://discordapp%.com/api/webhooks/') then return false end
    local embed = StaffReport.embed()
    PerformHttpRequest(hook, function(code)
        if code < 200 or code >= 300 then print(('^3[gs_discord] Rapport staff non envoyé (code %d) : vérifie le webhook staff.^0'):format(code)) end
    end, 'POST', json.encode({ username = Config.Name .. ' · Staff', embeds = { embed }, allowed_mentions = { parse = {} } }), { ['Content-Type'] = 'application/json' })
    StaffReport.since, StaffReport.peak, StaffReport.peakAt, StaffReport.crimes, StaffReport.deaths = os.time(), #GetPlayers(), nil, 0, {}
    StaffReport.seen, StaffReport.carry = { tickets = 0, lives = 0, alerts = 0 }, { tickets = 0, lives = 0, alerts = 0 }
    StaffReport.sentDay = os.date('%Y-%m-%d')
    save()
    return true
end

--- À l'heure dite, une fois par jour
function StaffReport.tick(t)
    if not R or not R.enabled then return false end
    t = t or os.date('*t')
    local day = os.date('%Y-%m-%d')
    if t.hour == R.hour and t.min >= (R.minute or 0) and StaffReport.sentDay ~= day then return StaffReport.send() end
    return false
end

RegisterCommand('rapportstaff', function(src) -- console serveur ou fondateur : envoi immédiat (test)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'gs.admin.founder') then return end
    print(StaffReport.send() and '[gs_discord] Rapport staff envoyé.' or '[gs_discord] Pas de webhook staff (gs_webhook_staff / gs_staff_webhook).')
end, true)

CreateThread(function()
    restore()
    while true do
        Wait(60000)
        StaffReport.sample()
        StaffReport.tick()
    end
end)
