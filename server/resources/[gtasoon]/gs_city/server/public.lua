-- gs_city (serveur) · V10.2 « Carte vivante ». Ce que la ville montre au monde, pour le site (aucune donnée privée :
-- ni position de joueur, ni identité hormis les légendes déjà publiques en jeu) :
--   http://ADRESSE:30120/gs_city/ville.json   (ou l'adresse https « …users.cfx.re » du serveur + /gs_city/ville.json)
-- Mis en cache 30 s. Lisible depuis le site (en-tête CORS). V11 : + timelapse (24 h de la ville, voir timelapse.lua).
local cache, cachedAt = nil, 0

local function started(r) return GetResourceState(r) == 'started' end
local function try(fn, default) local ok, v = pcall(fn) if ok and v ~= nil then return v end return default end

function CityPublic()
    local districts = {}
    local tension, standing = GlobalState.gsCity or {}, GlobalState.gsStanding or {}
    for _, d in ipairs(Config.Districts) do
        local lvl, st = tension[d.id] or 1, standing[d.id] or 3
        districts[#districts + 1] = { id = d.id, label = d.label, x = d.center.x, y = d.center.y,
            tension = lvl, tensionLabel = Config.Levels[lvl] and Config.Levels[lvl].label or 'calme',
            standing = st, standingLabel = Config.Standing.levels[st] and Config.Standing.levels[st].label or 'ordinaire' }
    end
    local weekly = started('gs_events') and try(function() return exports.gs_events:Weekly() end, {}) or {}
    local legends = {}
    for i, l in ipairs(started('gs_wanted') and try(function() return exports.gs_wanted:Legends() end, {}) or {}) do
        if i > 5 then break end
        legends[#legends + 1] = { name = l.name, date = l.date }
    end
    local fugitives = #(GlobalState.gsFugitives or {})
    return { at = os.time(), players = #GetPlayers(), max = GetConvarInt('sv_maxclients', 48), version = GetConvar('gs_version', ''),
        weather = started('gs_weather') and try(function() return exports.gs_weather:GetWeather() end, nil) or nil,
        districts = districts, weekly = weekly, legends = legends, fugitives = fugitives,
        ids = (function() local m = {} for _, d in ipairs(districts) do m[d.id] = { x = d.x, y = d.y, label = d.label } end return m end)(),
        timelapse = Timelapse and Timelapse.export() or nil, -- V11 : 24 h rejouées sur le site
        gazette = Gazette and Gazette.last or nil } -- V11.2 : dernière édition
end

SetHttpHandler(function(req, res)
    if req.path ~= '/ville.json' then
        res.writeHead(404, { ['Content-Type'] = 'text/plain' })
        return res.send('Introuvable.')
    end
    if not cache or os.time() - cachedAt >= 30 then cache, cachedAt = json.encode(CityPublic()), os.time() end
    res.writeHead(200, { ['Content-Type'] = 'application/json; charset=utf-8', ['Access-Control-Allow-Origin'] = '*', ['Cache-Control'] = 'max-age=30' })
    res.send(cache)
end)
