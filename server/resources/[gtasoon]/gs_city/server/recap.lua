-- gs_city (serveur) · V11.1 « Précédemment à Los Santos ». À la connexion, l'écran de chargement reçoit (handover FiveM)
-- un résumé des dernières 24 h tiré du timelapse : faits marquants, quartiers chauds, météo, joueurs, prochain rendez-vous.
-- Rien de privé : des nombres et des quartiers, et seulement les légendes déjà publiques en jeu.
local WEATHER = { EXTRASUNNY = 'grand soleil', CLEAR = 'ciel dégagé', CLOUDS = 'nuageux', OVERCAST = 'couvert', RAIN = 'pluie',
    CLEARING = 'éclaircies', THUNDER = 'orage', SMOG = 'brume de chaleur', FOGGY = 'brouillard', XMAS = 'neige', SNOW = 'neige',
    SNOWLIGHT = 'flocons', BLIZZARD = 'tempête de neige', HALLOWEEN = 'nuit étrange', NEUTRAL = 'temps calme' }

local function started(r) return GetResourceState(r) == 'started' end
local function plural(n, one, many) return n == 1 and one or (many):format(n) end

function CityRecap(now)
    now = now or os.time()
    local count, byDistrict = {}, {}
    for _, e in ipairs((Timelapse and Timelapse.events) or {}) do
        if now - e.t <= 24 * 3600 then
            count[e.k] = (count[e.k] or 0) + 1
            if e.k == 'crime' and e.d then byDistrict[e.d] = (byDistrict[e.d] or 0) + 1 end
        end
    end
    local labels = {}
    for _, d in ipairs(Config.Districts) do labels[d.id] = d.label end
    local top, topN = nil, 0
    for id, n in pairs(byDistrict) do if n > topN then top, topN = id, n end end

    local lines = {}
    if (count.crime or 0) > 0 then
        lines[#lines + 1] = plural(count.crime, 'Un incident signalé à la police', '%d incidents signalés à la police')
            .. (top and (', surtout à ' .. labels[top]) or '') .. '.'
    end
    if (count.faitdivers or 0) > 0 then lines[#lines + 1] = plural(count.faitdivers, 'Un fait divers a occupé le LSPD.', '%d faits divers ont occupé le LSPD.') end
    if (count.rumeur or 0) > 0 then lines[#lines + 1] = plural(count.rumeur, 'Une rumeur du comptoir s\'est vérifiée.', '%d rumeurs du comptoir se sont vérifiées.') end
    if (count.verdict or 0) > 0 then lines[#lines + 1] = plural(count.verdict, 'Un verdict est tombé au tribunal.', '%d verdicts sont tombés au tribunal.') end
    if (count.cavale or 0) > 0 then lines[#lines + 1] = plural(count.cavale, 'Une cavale a tenu la ville en haleine.', '%d cavales ont tenu la ville en haleine.') end
    if (count.memoire or 0) > 0 then lines[#lines + 1] = 'La ville a gravé un nouveau lieu de mémoire.' end
    local legends = started('gs_wanted') and (function() local ok, l = pcall(function() return exports.gs_wanted:Legends() end) return ok and l or {} end)() or {}
    if (count.legende or 0) > 0 and legends[1] then lines[#lines + 1] = ('Nouvelle légende : %s.'):format(legends[1].name) end
    if #lines == 0 then lines[1] = 'Une journée calme à Los Santos… pour l\'instant.' end
    while #lines > 4 do table.remove(lines) end

    local hot = {}
    for _, d in ipairs(Config.Districts) do
        local lvl = City.level(City.heat[d.id])
        if lvl >= 2 then hot[#hot + 1] = { label = d.label, level = lvl } end
    end
    table.sort(hot, function(a, b) return a.level > b.level end)

    local weather = started('gs_weather') and (function() local ok, w = pcall(function() return exports.gs_weather:GetWeather() end) return ok and w or nil end)() or nil
    local weekly = started('gs_events') and (function() local ok, w = pcall(function() return exports.gs_events:Weekly() end) return ok and w or {} end)() or {}
    return { lines = lines, hot = hot, players = #GetPlayers(), max = GetConvarInt('sv_maxclients', 48),
        weather = weather and (WEATHER[weather] or weather:lower()) or nil, next = weekly[1], version = GetConvar('gs_version', '') }
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    if not deferrals or not deferrals.handover then return end
    local ok, data = pcall(CityRecap)
    if ok then deferrals.handover({ roadline = data }) end
end)
