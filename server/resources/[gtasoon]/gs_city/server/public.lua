-- gs_city (serveur) · V10.2 « Carte vivante ». Ce que la ville montre au monde, pour le site (aucune donnée privée :
-- ni position de joueur, ni identité hormis les légendes déjà publiques en jeu) :
--   http://ADRESSE:30120/gs_city/ville.json   (ou l'adresse https « …users.cfx.re » du serveur + /gs_city/ville.json)
-- Mis en cache 30 s. Lisible depuis le site (en-tête CORS). V11 : + timelapse (24 h de la ville, voir timelapse.lua).
local cache, cachedAt = nil, 0

local function started(r) return GetResourceState(r) == 'started' end
local function try(fn, default) local ok, v = pcall(fn) if ok and v ~= nil then return v end return default end

-- V12 · « En ce moment en ville » (bandeau du site) : météo en français, heure, quartiers chauds, prochain rendez-vous,
-- dernière rumeur vérifiée, nombre de lieux de mémoire. Toujours public, jamais personnel.
local WEATHER = { CLEAR = 'Ensoleillé', EXTRASUNNY = 'Grand soleil', CLOUDS = 'Nuageux', OVERCAST = 'Couvert', RAIN = 'Pluie',
    CLEARING = 'Éclaircies', THUNDER = 'Orage', SMOG = 'Brume', FOGGY = 'Brouillard', XMAS = 'Neige', SNOW = 'Neige', BLIZZARD = 'Blizzard', HALLOWEEN = 'Nuit d\'Halloween' }
local lastRumor
AddEventHandler('gs_rumors:server:realized', function(text) if type(text) == 'string' then lastRumor = text:sub(1, 140) end end)

function CityNow()
    local w = started('gs_weather') and try(function() return exports.gs_weather:GetWeather() end, nil) or nil
    local h, m = nil, nil
    if started('gs_weather') then try(function() h, m = exports.gs_weather:GetGameTime() return true end, nil) end
    local weekly = started('gs_events') and try(function() return exports.gs_events:Weekly() end, {}) or {}
    local hot = started('gs_city') and try(function() return exports.gs_city:HotDistricts() end, {}) or {}
    return {
        weather = w and (WEATHER[w] or w) or nil, hour = h and ('%02d:%02d'):format(h, m or 0) or nil,
        hot = hot, next = weekly[1] and { label = weekly[1].label, dayName = weekly[1].dayName, from = weekly[1].from } or nil,
        rumor = lastRumor, memories = #(GlobalState.gsMemoire or {}), fugitives = #(GlobalState.gsFugitives or {}),
    }
end

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
    return { at = os.time(), players = #GetPlayers(), max = GetConvarInt('sv_maxclients', 48), version = GetConvar('gs_public_version', 'V4 · bêta'),
        weather = started('gs_weather') and try(function() return exports.gs_weather:GetWeather() end, nil) or nil,
        districts = districts, weekly = weekly, legends = legends, fugitives = fugitives,
        ids = (function() local m = {} for _, d in ipairs(districts) do m[d.id] = { x = d.x, y = d.y, label = d.label } end return m end)(),
        timelapse = Timelapse and Timelapse.export() or nil, -- V11 : 24 h rejouées sur le site
        gazette = Gazette and Gazette.last or nil, -- V11.2 : dernière édition
        now = CityNow() } -- V12 : bandeau « En ce moment en ville »
end

-- V12 · Candidature depuis le site (POST /gs_city/candidature, JSON) → webhook Discord (#tickets / #candidatures).
-- Garde-fous : 1 envoi / 10 min par adresse, 30 / h au total, champs bornés, rien d'autre que du texte.
Candidature = { byIp = {}, hour = { at = 0, n = 0 } }
local CORS = { ['Access-Control-Allow-Origin'] = '*', ['Access-Control-Allow-Methods'] = 'POST, OPTIONS', ['Access-Control-Allow-Headers'] = 'Content-Type' }

local function clean(v, max)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('%c', ' '):gsub('[<>@]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    return v ~= '' and v:sub(1, max) or nil
end

--- Valide et met en forme une candidature. Retourne true, embed ou false, message.
function Candidature.build(d)
    if type(d) ~= 'table' then return false, 'Formulaire vide.' end
    local discord = clean(d.discord, 40)
    local age = tonumber(d.age)
    local q1, q2, q3 = clean(d.q1, 600), clean(d.q2, 600), clean(d.q3, 600)
    if not discord or #discord < 2 then return false, 'Ton pseudo Discord est obligatoire.' end
    if not age or age < 13 or age > 99 then return false, 'Âge invalide.' end
    if not q1 or #q1 < 10 or not q2 or #q2 < 10 or not q3 or #q3 < 10 then return false, 'Réponds aux trois questions (10 caractères minimum).' end
    return true, { username = 'Candidatures RoadLine', allowed_mentions = { parse = {} }, embeds = { {
        title = ('Candidature · %s'):format(discord), color = 0xB048FF, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        fields = { { name = 'Discord', value = discord, inline = true }, { name = 'Âge', value = tostring(math.floor(age)), inline = true },
            { name = 'Ton personnage en une phrase', value = q1 }, { name = 'Pourquoi RoadLine ?', value = q2 }, { name = 'Ton expérience RP', value = q3 } },
        footer = { text = 'Envoyée depuis le site · répondre sur Discord' } } } }
end

function Candidature.allowed(ip)
    local t = os.time()
    if t - Candidature.hour.at >= 3600 then Candidature.hour = { at = t, n = 0 } end
    if Candidature.hour.n >= 30 then return false, 'Trop de candidatures en ce moment, réessaie dans une heure.' end
    local last = Candidature.byIp[ip]
    if last and t - last < 600 then return false, 'Tu as déjà envoyé une candidature il y a moins de 10 min.' end
    Candidature.byIp[ip] = t
    Candidature.hour.n = Candidature.hour.n + 1
    return true
end

local function webhook()
    local u = GetConvar('gs_webhook_candidatures', '')
    if u == '' then u = GetConvar('gs_staff_webhook', '') end
    return u:match('^https://discord%.com/api/webhooks/%d+/[%w_%-]+$') and u or nil
end

SetHttpHandler(function(req, res)
    if req.path == '/candidature' then
        if req.method == 'OPTIONS' then res.writeHead(204, CORS) return res.send('') end
        if req.method ~= 'POST' then res.writeHead(405, CORS) return res.send('') end
        local ip = (req.address or ''):gsub(':%d+$', '')
        local xf = req.headers and (req.headers['X-Forwarded-For'] or req.headers['x-forwarded-for'])
        if xf and (ip == '127.0.0.1' or ip == '::1' or ip == '') then ip = xf:match('^[^,]+') or ip end
        req.setDataHandler(function(body)
            local okJ, d = pcall(json.decode, body or '')
            local ok, out = Candidature.build(okJ and d or nil)
            if ok then ok, out = Candidature.allowed(ip) end
            local hook = ok and webhook()
            if ok and not hook then ok, out = false, 'Les candidatures ne sont pas encore ouvertes (webhook non réglé).' end
            if ok then
                local _, embed = Candidature.build(d)
                PerformHttpRequest(hook, function() end, 'POST', json.encode(embed), { ['Content-Type'] = 'application/json' })
            end
            res.writeHead(ok and 200 or 400, (function() local h = { ['Content-Type'] = 'application/json; charset=utf-8', ['Cache-Control'] = 'no-store' } for k, v in pairs(CORS) do h[k] = v end return h end)())
            res.send(json.encode({ ok = ok == true, message = ok and 'Candidature envoyée : le staff te répond sur Discord.' or out }))
        end)
        return
    end
    if req.path ~= '/ville.json' then
        res.writeHead(404, { ['Content-Type'] = 'text/plain' })
        return res.send('Introuvable.')
    end
    if not cache or os.time() - cachedAt >= 30 then cache, cachedAt = json.encode(CityPublic()), os.time() end
    res.writeHead(200, { ['Content-Type'] = 'application/json; charset=utf-8', ['Access-Control-Allow-Origin'] = '*', ['Cache-Control'] = 'max-age=30' })
    res.send(cache)
end)
