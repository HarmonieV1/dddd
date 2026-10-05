-- gs_city (serveur) · V11 « Ville en timelapse ». La ville garde 24 h de son histoire publique pour que le site la rejoue
-- en 30 s : une photo de la tension des quartiers toutes les 10 min, et les faits marquants (crime signalé, fait divers,
-- rumeur devenue vraie, verdict, cavale, légende). Jamais de position de joueur ni d'identité : le quartier suffit.
local KVP = 'gs_city:timelapse'
local KEEP, MAX_EVENTS, SNAP_EVERY = 24 * 3600, 600, 600

Timelapse = { snaps = {}, events = {} }
local Kinds = { crime = 'Incident signalé', faitdivers = 'Fait divers', rumeur = 'Rumeur confirmée', verdict = 'Verdict rendu',
    cavale = 'Cavale en cours', legende = 'Nouvelle légende', memoire = 'Nouveau lieu de mémoire' }

local function prune(now)
    local cut = now - KEEP
    while Timelapse.snaps[1] and Timelapse.snaps[1].t < cut do table.remove(Timelapse.snaps, 1) end
    while Timelapse.events[1] and Timelapse.events[1].t < cut do table.remove(Timelapse.events, 1) end
    while #Timelapse.events > MAX_EVENTS do table.remove(Timelapse.events, 1) end
end

--- Ajoute un fait marquant. `coords` (facultatif) ne sert qu'à trouver le quartier, puis est oublié.
function Timelapse.record(kind, coords, now)
    if not Kinds[kind] then return false end
    now = now or os.time()
    local d = coords and City.district(coords)
    Timelapse.events[#Timelapse.events + 1] = { t = now, k = kind, d = d and d.id or nil }
    prune(now)
    return true
end

function Timelapse.snapshot(now)
    now = now or os.time()
    local lv = {}
    for _, d in ipairs(Config.Districts) do
        local l = City.level(City.heat[d.id])
        if l > 1 then lv[d.id] = l end
    end
    Timelapse.snaps[#Timelapse.snaps + 1] = { t = now, lv = lv }
    prune(now)
end

--- Pour /ville.json : photos + faits, et les libellés des types (le site n'a rien à deviner)
function Timelapse.export()
    return { snaps = Timelapse.snaps, events = Timelapse.events, kinds = Kinds, span = KEEP }
end

local function save() SetResourceKvp(KVP, json.encode({ snaps = Timelapse.snaps, events = Timelapse.events })) end

CreateThread(function()
    local raw = GetResourceKvpString(KVP)
    local ok, d = pcall(json.decode, raw or '')
    if ok and type(d) == 'table' then
        Timelapse.snaps, Timelapse.events = d.snaps or {}, d.events or {}
        prune(os.time())
    end
    while true do
        Timelapse.snapshot()
        save()
        Wait(SNAP_EVERY * 1000)
    end
end)

AddEventHandler('gs_wanted:server:reported', function(_, _, _, coords) Timelapse.record('crime', coords) end)
AddEventHandler('gs_faitsdivers:server:new', function() Timelapse.record('faitdivers') end)
AddEventHandler('gs_rumors:server:realized', function() Timelapse.record('rumeur') end)
AddEventHandler('gs_justice:server:verdict', function() Timelapse.record('verdict') end)
AddEventHandler('gs_wanted:server:fugitive', function() Timelapse.record('cavale') end)
AddEventHandler('gs_wanted:server:legend', function() Timelapse.record('legende') end)
AddEventHandler('gs_scars:server:plaque', function(_, coords) Timelapse.record('memoire', coords) end) -- V11 : plaques
