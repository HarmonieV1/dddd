-- gs_weather (serveur) : seule source de vérité de la météo et de l'heure.
-- Publication via GlobalState (répliqué par FiveM, 0 event réseau récurrent) :
--   GlobalState.gsWeather = { type, transition, event, blackout, wind }
--   GlobalState.gsClock   = { real, minute, frozen }
-- Règle : toujours réassigner une NOUVELLE table (modifier un champ ne se réplique pas).
local Security = exports.gs_security

Weather = {
    type = Config.StartWeather, endsAt = 0, event = nil, eventEndsAt = 0, blackout = false, wind = 0.0,
    forcedUntil = 0,
}

local function now() return os.time() end

local function publishWeather()
    GlobalState.gsWeather = {
        type = Weather.type, transition = Config.TransitionSeconds,
        event = Weather.event, blackout = Weather.blackout, wind = Weather.wind,
    }
end

local function publishClock(minute, frozen)
    GlobalState.gsClock = { real = now(), minute = minute % 1440, frozen = frozen == true }
end

function Weather.gameMinute()
    return Clock.now(GlobalState.gsClock, now())
end

local function randomRange(r) return math.random(r[1], r[2]) end

--- Tire la prochaine météo selon le graphe de transitions (poids).
function Weather.pickNext(current)
    local options = Config.Transitions[current] or Config.Transitions[Config.StartWeather]
    local total = 0
    for _, w in pairs(options) do total = total + w end
    local roll = math.random() * total
    local names = {}
    for name in pairs(options) do names[#names + 1] = name end
    table.sort(names) -- ordre stable
    for _, name in ipairs(names) do
        roll = roll - options[name]
        if roll <= 0 then return name end
    end
    return names[#names]
end

local function announce(msg, icon)
    TriggerClientEvent('gs_weather:client:announce', -1, { title = Config.AnnouncePrefix, description = msg, icon = icon })
    Security:LogStaff(('**%s** — %s'):format(Config.AnnouncePrefix, msg), 'annonces')
end

function Weather.set(wtype, minutes)
    Weather.type = wtype
    Weather.endsAt = now() + (minutes or randomRange(Config.WeatherMinutes)) * 60
    publishWeather()
end

function Weather.startEvent(id)
    local e = Config.Events[id]
    if not e then return false end
    if Weather.event then Weather.endEvent(true) end
    local minutes = randomRange(e.minutes)
    Weather.event, Weather.eventEndsAt = id, now() + minutes * 60
    Weather.wind = e.wind or 0.0
    Weather.blackout = e.blackoutChance ~= nil and math.random() < e.blackoutChance
    Weather.set(e.weather, minutes)
    announce(e.announce, e.icon)
    TriggerEvent('gs_weather:server:eventStarted', id, minutes)
    return true
end

function Weather.endEvent(silent)
    local id = Weather.event
    if not id then return end
    Weather.event, Weather.eventEndsAt, Weather.wind, Weather.blackout = nil, 0, 0.0, false
    Weather.set(Weather.pickNext(Weather.type))
    if not silent then announce(('Fin de l\'alerte : %s.'):format(Config.Events[id].label), 'sun') end
    TriggerEvent('gs_weather:server:eventEnded', id)
end

--- Tente un événement éligible (heure de jeu) ; sinon météo normale.
local function rollEvent()
    local hour = math.floor(Weather.gameMinute() / 60)
    local ids = {}
    for id in pairs(Config.Events) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local e = Config.Events[id]
        local okHour = not e.hours or (hour >= e.hours[1] and hour < e.hours[2])
        if okHour and math.random() < e.chance then return Weather.startEvent(id) end
    end
    return false
end

--- Appelé toutes les 10 s : fin d'événement, changement de météo.
function Weather.tick()
    local t = now()
    if Weather.event then
        if t >= Weather.eventEndsAt then Weather.endEvent(false) end
        return
    end
    if t < Weather.endsAt or t < Weather.forcedUntil then return end
    if not rollEvent() then Weather.set(Weather.pickNext(Weather.type)) end
end

function Weather.init()
    publishClock(Config.StartTime.hour * 60 + Config.StartTime.minute, false)
    Weather.set(Config.StartWeather)
end

CreateThread(function()
    Weather.init()
    while true do
        Wait(10000)
        Weather.tick()
    end
end)

-- Heure serveur pour que les clients calent leur horloge (os.time n'existe pas côté client).
lib.callback.register('gs_weather:now', function(src)
    if not Security:RateLimit(src, 'gs_weather:now', 3, 60000) then return nil end
    return now()
end)

-- Commandes staff (ACE group.admin, créées par ox_lib) ------------------------------------------

local function reply(src, msg)
    if src == 0 then print('[gs_weather] ' .. msg) else TriggerClientEvent('ox_lib:notify', src, { description = msg }) end
end

local function logCmd(src, what)
    Security:LogStaff(('%s par %s'):format(what, src == 0 and 'console' or GetPlayerName(src) or '?'))
end

lib.addCommand('meteo', {
    help = 'Forcer une météo (ex : /meteo RAIN 30)',
    params = {
        { name = 'type', type = 'string', help = 'CLEAR, RAIN, THUNDER, FOGGY...' },
        { name = 'minutes', type = 'number', help = 'Durée (défaut 30)', optional = true },
    },
    restricted = 'group.admin',
}, function(src, args)
    local wtype = args.type:upper()
    local minutes = args.minutes or 30
    if not Config.Transitions[wtype] or minutes < 1 or minutes > 240 then return reply(src, 'Météo ou durée invalide.') end
    if Weather.event then Weather.endEvent(true) end
    Weather.set(wtype, minutes)
    Weather.forcedUntil = now() + minutes * 60
    logCmd(src, ('/meteo %s %d min'):format(wtype, minutes))
    reply(src, ('Météo : %s pendant %d min.'):format(wtype, minutes))
end)

lib.addCommand('meteoevent', {
    help = 'Lancer ou arrêter un événement météo (storm, heatwave, fog, stop)',
    params = { { name = 'id', type = 'string', help = 'storm | heatwave | fog | stop' } },
    restricted = 'group.admin',
}, function(src, args)
    if args.id == 'stop' then
        Weather.endEvent(false)
        logCmd(src, '/meteoevent stop')
        return reply(src, 'Événement arrêté.')
    end
    if not Weather.startEvent(args.id) then return reply(src, 'Événement inconnu.') end
    logCmd(src, '/meteoevent ' .. args.id)
    reply(src, 'Événement lancé : ' .. Config.Events[args.id].label)
end)

lib.addCommand('heure', {
    help = "Régler l'heure du jeu (ex : /heure 18 30)",
    params = {
        { name = 'h', type = 'number', help = '0-23' },
        { name = 'm', type = 'number', help = '0-59', optional = true },
    },
    restricted = 'group.admin',
}, function(src, args)
    local h, m = args.h, args.m or 0
    if h < 0 or h > 23 or m < 0 or m > 59 or h ~= math.floor(h) or m ~= math.floor(m) then
        return reply(src, 'Heure invalide.')
    end
    publishClock(h * 60 + m, GlobalState.gsClock.frozen)
    logCmd(src, ('/heure %02d:%02d'):format(h, m))
    reply(src, ('Heure : %02d:%02d.'):format(h, m))
end)

lib.addCommand('figerheure', { help = "Figer / relancer l'heure", restricted = 'group.admin' }, function(src)
    local frozen = not GlobalState.gsClock.frozen
    publishClock(Weather.gameMinute(), frozen)
    logCmd(src, frozen and '/figerheure (figée)' or '/figerheure (relancée)')
    reply(src, frozen and 'Heure figée.' or 'Heure relancée.')
end)

lib.addCommand('blackout', { help = 'Coupure de courant on/off', restricted = 'group.admin' }, function(src)
    Weather.blackout = not Weather.blackout
    publishWeather()
    logCmd(src, Weather.blackout and '/blackout ON' or '/blackout OFF')
    reply(src, Weather.blackout and 'Blackout activé.' or 'Blackout désactivé.')
end)

-- API pour les autres ressources (économie dynamique, wanted, EMS...) ------------------------------

exports('GetWeather', function() return Weather.type end)
exports('GetEvent', function() return Weather.event end)
exports('IsBlackout', function() return Weather.blackout end)
exports('GetGameTime', function() return Clock.split(Weather.gameMinute()) end)
