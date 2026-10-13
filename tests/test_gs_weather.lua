-- Tests gs_weather : horloge déterministe, graphe de météo, événements, commandes staff.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_weather', { R .. 'gs_weather/shared/config.lua', R .. 'gs_weather/shared/clock.lua', R .. 'gs_weather/server/main.lua', R .. 'gs_weather/server/storm.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

-- Horloge ---------------------------------------------------------------------------------
local day = Clock.dayLength()
check('journée ~49,5 min réelles', near(day, 2970))
check('journée complète = même heure', near(Clock.advance(600, day), 600))
check('golden hour : 4 s réelles = 1 min', near(Clock.advance(18 * 60, 4), 18 * 60 + 1))
check('journée : 2 s = 1 min', near(Clock.advance(12 * 60, 2), 12 * 60 + 1))
check('passage de segment 17:59 → 18:00:30', near(Clock.advance(17 * 60 + 59, 2 + 2), 18 * 60 + 0.5))
check('passage de minuit', near(Clock.advance(23 * 60 + 59, 1.5 + 1), 1))
check('temps négatif (dérive) sans crash', Clock.advance(600, -10) >= 0)
check('figée = ne bouge pas', Clock.now({ real = 0, minute = 700, frozen = true }, 99999) == 700)
local h, m, s = Clock.split(18 * 60 + 30.5)
check('split', h == 18 and m == 30 and s == 30)

-- Démarrage --------------------------------------------------------------------------------
Weather.init()
check('météo publiée', GlobalState.gsWeather.type == Config.StartWeather)
check('heure publiée', GlobalState.gsClock.minute == Config.StartTime.hour * 60 + Config.StartTime.minute)

-- Graphe de transitions --------------------------------------------------------------------------
local okGraph = true
for from, options in pairs(Config.Transitions) do
    for _ = 1, 300 do
        if not options[Weather.pickNext(from)] then okGraph = false end
    end
end
check('météo suivante toujours autorisée par le graphe', okGraph)
for _, options in pairs(Config.Transitions) do
    for to in pairs(options) do check('transition vers météo connue : ' .. to, Config.Transitions[to] ~= nil) end
end

-- Cycle : pas de changement avant la fin ----------------------------------------------------------
local before = Weather.endsAt
Weather.tick()
check('pas de changement avant la fin', Weather.endsAt == before)
advance((Weather.endsAt - os.time() + 1) * 1000)
Weather.tick()
check('changement après la fin', Weather.endsAt > before)

-- Événements ---------------------------------------------------------------------------------------
for id in pairs(Config.Events) do
    check('événement valide ' .. id, Config.Transitions[Config.Events[id].weather] ~= nil)
end
W.commands.meteoevent(0, { id = 'storm' })
check('tempête lancée', GlobalState.gsWeather.event == 'storm' and GlobalState.gsWeather.type == 'THUNDER')
check('annonce envoyée à tous', lastClientEvent('gs_weather:client:announce', -1) ~= nil)
Weather.tick()
check('météo tenue pendant l\'événement', GlobalState.gsWeather.type == 'THUNDER')
advance((Weather.eventEndsAt - os.time() + 1) * 1000)
Weather.tick()
check('fin d\'événement', GlobalState.gsWeather.event == nil and not GlobalState.gsWeather.blackout)
W.commands.meteoevent(0, { id = 'nimporte' })
check('événement inconnu refusé', GlobalState.gsWeather.event == nil)

-- Commandes staff ---------------------------------------------------------------------------------
W.commands.meteo(0, { type = 'rain', minutes = 30 })
check('/meteo force', GlobalState.gsWeather.type == 'RAIN')
advance(10 * 60 * 1000); Weather.tick()
check('/meteo tient la durée demandée', GlobalState.gsWeather.type == 'RAIN')
W.commands.meteo(0, { type = 'LAVE' })
check('/meteo type inconnu refusé', GlobalState.gsWeather.type == 'RAIN')
W.commands.heure(0, { h = 25, m = 0 })
check('/heure invalide refusée', GlobalState.gsClock.minute ~= 25 * 60)
W.commands.heure(0, { h = 6, m = 15 })
check('/heure ok', GlobalState.gsClock.minute == 6 * 60 + 15)
W.commands.figerheure(0, {})
local frozenAt = Weather.gameMinute()
advance(600000)
check('/figerheure fige', near(Weather.gameMinute(), frozenAt))
W.commands.figerheure(0, {})
advance(60000)
check('/figerheure relance', Weather.gameMinute() > frozenAt)
W.commands.blackout(0, {})
check('/blackout', GlobalState.gsWeather.blackout == true)

-- Robustesse : 10 000 ticks sur ~3 jours sans erreur ni météo inconnue --------------------------------
local okLong = true
for _ = 1, 10000 do
    advance(30000)
    Weather.tick()
    if not Config.Transitions[GlobalState.gsWeather.type] then okLong = false end
end
check('3 jours simulés sans météo invalide', okLong)

-- V8 · Météo événementielle : routes fermées et interventions pendant la tempête -----------------------------------
do
    local mech = {}
    provide('gs_jobs', { IsOnDutyAs = function(src, job) return mech[src] == job end })
    Weather.startEvent('storm')
    local st = GlobalState.gsStorm
    local n = 0 for _ in pairs(st.incidents) do n = n + 1 end
    check('tempête : routes fermées et interventions publiées', st and #st.roads == Config.Storm.closures and n == Config.Storm.incidents)
    local id, idx = next(Storm.incidents)
    local c = Config.Storm.spots[idx].coords
    join(41, 'CID41', 'Mécano', vec3(c.x + 1.0, c.y, c.z))
    join(42, 'CID42', 'Passant', vec3(c.x + 1.0, c.y, c.z))
    check('intervention : sans kit ni métier refusée', not Storm.fix(42, id))
    mech[41] = 'mechanic'
    check('intervention : mécano en service payé', Storm.fix(41, id) == true and W.players[41].money.bank > 0)
    check('intervention retirée de la carte', GlobalState.gsStorm.incidents[tostring(id)] == nil and not Storm.fix(41, id))
    local id2, idx2 = next(Storm.incidents)
    local c2 = Config.Storm.spots[idx2].coords
    tp(42, vec3(c2.x, c2.y, c2.z))
    W.players[42].items.repairkit = 1
    check('intervention : civil avec kit (consommé)', Storm.fix(42, id2) == true and W.players[42].items.repairkit == 0)
    Weather.endEvent(true)
    check('fin de tempête : routes rouvertes', GlobalState.gsStorm == nil)
end

-- V12.37 · Interventions : choix sans doublon, distance tolérée (véhicule posé sur la route jusqu'à snapRadius m du point,
-- arbre au point configuré), prime bornée, id inconnu / déjà dégagé refusés, réglages de streaming cohérents -------------------
do
    local S = Config.Storm
    check('réglages : streamOut > streamIn > snapRadius, fixRange > portée du marqueur (6 m)',
        S.streamOut > S.streamIn and S.streamIn > S.snapRadius and S.fixRange > 6.0 and type(S.strandedModel) == 'string')
    local okLabels = true
    for _, sp in ipairs(S.spots) do if type(sp.label) ~= 'string' or (sp.kind ~= 'tree' and sp.kind ~= 'stranded') then okLabels = false end end
    check('chaque intervention a un label (menu staff des points) et un type connu', okLabels)
    provide('gs_jobs', { IsOnDutyAs = function(src, job) return src == 51 and job == 'mechanic' end })
    local okDistinct = true
    for _ = 1, 50 do
        Weather.startEvent('storm')
        local seenR, seenS = {}, {}
        for _, i in ipairs(Storm.roads) do if seenR[i] then okDistinct = false end seenR[i] = true end
        for _, idx in pairs(Storm.incidents) do if seenS[idx] then okDistinct = false end seenS[idx] = true end
    end
    check('tirage : jamais deux fois la même route ni la même panne', okDistinct)
    -- Une panne (véhicule) et un arbre imposés pour un test déterministe
    local sIdx, tIdx
    for i, sp in ipairs(S.spots) do
        if sp.kind == 'stranded' and not sIdx then sIdx = i end
        if sp.kind == 'tree' and not tIdx then tIdx = i end
    end
    Storm.incidents = { [1] = sIdx, [2] = tIdx }
    local sc, tc = S.spots[sIdx].coords, S.spots[tIdx].coords
    join(51, 'CID51', 'Dépanneur', vec3(sc.x + S.snapRadius + S.fixRange + 1.0, sc.y, sc.z))
    local ok, msg = Storm.fix(51, 1)
    check('véhicule : au-delà de snapRadius + fixRange refusé', not ok and msg == 'Trop loin.')
    tp(51, vec3(sc.x + S.snapRadius + 4.0, sc.y, sc.z)) -- véhicule posé sur la route à 60 m du point, joueur à 4 m du véhicule
    local before = W.players[51].money.bank
    ok = Storm.fix(51, 1)
    local gain = W.players[51].money.bank - before
    check('véhicule : accepté jusqu\'à snapRadius + fixRange', ok == true)
    check('prime dans les bornes pay', gain >= S.pay[1] and gain <= S.pay[2])
    check('déjà dégagé refusé', not Storm.fix(51, 1) and not Storm.fix(51, 'abc') and not Storm.fix(51, nil))
    tp(51, vec3(tc.x + S.fixRange + 1.0, tc.y, tc.z))
    check('arbre : au-delà de fixRange refusé (pas de marge route)', not Storm.fix(51, 2))
    tp(51, vec3(tc.x + 5.0, tc.y, tc.z))
    check('arbre : accepté à 5 m', Storm.fix(51, 2) == true and GlobalState.gsStorm.incidents['2'] == nil)
    Weather.endEvent(true)
    check('fin de tempête : plus rien de publié', GlobalState.gsStorm == nil and next(Storm.incidents) == nil)
end

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
