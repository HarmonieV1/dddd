-- gs_admin (serveur) · Appli staff externe (V10.1 → V12.63) : tableau de bord servi par le serveur FiveM lui-même, pour modérer
-- depuis une tablette, un téléphone ou un PC, sans être en jeu :
--   http(s)://ADRESSE/gs_admin/        (« Ajouter à l'écran d'accueil » = une appli)
-- Connexion : pseudo (pour le journal) + mot de passe collectif (secrets.cfg : set gs_admin_web_password "…", GERER-OVH → 20)
-- ou code personnel (set gs_admin_web "Pseudo:code-long,…"). Le mot de passe n'est envoyé qu'une fois : ensuite un jeton de
-- session tiré au hasard (crypto.js), valable Config.Web.sessionHours. 5 essais ratés depuis une adresse = blocage 15 min.
-- Tout passe par Admin.remote (mêmes vérifications et même journal « Web · pseudo » que le bot Discord).
local Security = exports.gs_security
local Web = { fails = {}, sessions = {}, seen = {}, global = {} } -- global = échecs récents (toutes adresses)
local RES = GetCurrentResourceName()

local function codes()
    local out = {}
    for entry in GetConvar('gs_admin_web', ''):gmatch('[^,]+') do
        -- « Pseudo:code » ou, V12.63, « Pseudo:code:rang » (1 à 5) : le rang suit le code, pas le pseudo tapé
        local name, code, lvl = entry:match('^%s*([^:]+):([^:]-):(%d)%s*$')
        if not name then name, code = entry:match('^%s*([^:]+):(.-)%s*$') end
        if name and code and #code >= 12 then -- code trop court = ignoré (sécurité)
            local l = math.tointeger(tonumber(lvl)) or ((Config.Web or {}).codeLevel or 2)
            out[code] = { name = name, level = math.max(1, math.min(5, l)) }
        end
    end
    return out
end
local function collective()
    local p = GetConvar('gs_admin_web_password', '')
    return #p >= 6 and p or nil -- trop court = désactivé
end
function Web.enabled() return collective() ~= nil or next(codes()) ~= nil end

local function intId(x) return math.tointeger(tonumber(x)) end -- V12.63 (relecture) : un id de joueur est un entier, rien d'autre

local function ipOf(req)
    local ip = tostring(req.address or '?'):gsub(':%d+$', '')
    -- derrière l'adresse https (Caddy sur le VPS), la vraie adresse est dans X-Forwarded-For (sinon tout le monde = 127.0.0.1)
    if ip == '127.0.0.1' or ip == '::1' or ip == '[::1]' then
        local h = req.headers or {}
        local fwd = h['X-Forwarded-For'] or h['x-forwarded-for']
        if type(fwd) == 'string' and fwd ~= '' then ip = fwd:match('^%s*([^,%s]+)') or ip end
    end
    return ip
end

local function safeEqual(a, b)
    local ok, r = pcall(function() return exports[RES]:SafeEqual(a, b) end)
    if ok then return r == true end
    return a == b
end
local function newToken()
    local ok, t = pcall(function() return exports[RES]:RandomToken() end)
    if ok and type(t) == 'string' and #t >= 32 then return t end
    -- V12.63 (backtest : « Redémarre gs_admin ») : secours si crypto.js n'a pas été chargé (serveur démarré pendant une copie…) :
    -- l'aléa du système (/dev/urandom, VPS Linux). Toujours aucun jeton prévisible (jamais math.random).
    if not Web.cryptoWarned then
        Web.cryptoWarned = true
        print(('^3[gs_admin] appli staff : RandomToken indisponible (%s) : secours /dev/urandom. Redémarre le serveur pour recharger server/crypto.js.^0'):format(tostring(t)))
    end
    local okF, f = pcall(io.open, '/dev/urandom', 'rb')
    if okF and f then
        local raw = f:read(24); f:close()
        if raw and #raw == 24 then return (raw:gsub('.', function(c) return ('%02x'):format(c:byte()) end)) end
    end
    return nil -- jamais de jeton prévisible : pas de session sans source d'aléa sûre
end

local function blocked(ip)
    local f = Web.fails[ip]
    return f and f.untilAt and os.time() < f.untilAt
end
--- V12.63 (relecture) : en plus du blocage par adresse, plus de 30 échecs en 15 min toutes adresses confondues = connexions
--- par mot de passe suspendues 15 min (attaque depuis plusieurs adresses), avec une alerte au staff.
local function globalPaused()
    local now, keep = os.time(), {}
    for _, t in ipairs(Web.global) do if now - t < 900 then keep[#keep + 1] = t end end
    Web.global = keep
    return Web.pausedUntil and now < Web.pausedUntil
end
local function failed(ip)
    local f = Web.fails[ip] or { n = 0 }
    f.n, f.at = f.n + 1, os.time()
    if f.n >= 5 then f.n, f.untilAt = 0, os.time() + 900 end
    Web.fails[ip] = f
    Web.global[#Web.global + 1] = os.time()
    if #Web.global > 30 and not (Web.pausedUntil and os.time() < Web.pausedUntil) then
        Web.pausedUntil = os.time() + 900
        Security:LogStaff('[Appli staff] plus de 30 mots de passe faux en 15 min : connexions suspendues 15 min (attaque probable).', 'staff')
    end
end

--- Connexion : renvoie le nom à journaliser et le secret utilisé, ou nil + message.
function Web.login(ip, pseudo, password)
    if blocked(ip) then return nil, 'Trop d\'essais : réessaie dans 15 min.' end
    if globalPaused() then return nil, 'Connexions suspendues 15 min (trop d\'essais ratés sur le serveur).' end
    if type(password) ~= 'string' or password == '' then failed(ip) return nil, 'Mot de passe refusé.' end
    local named = codes()[password]
    if named then Web.fails[ip] = nil return named.name, password, named.level end
    local pass = collective()
    if pass and safeEqual(password, pass) then
        local who = Security:Sanitize(pseudo, 20)
        if not who or #who < 2 then return nil, 'Indique ton pseudo staff (2 à 20 caractères) : il signe tes actions dans le journal.' end
        Web.fails[ip] = nil
        return who, password, (Config.Web or {}).collectiveLevel or 2
    end
    failed(ip)
    return nil, 'Mot de passe refusé.'
end

function Web.session(token)
    local s = type(token) == 'string' and Web.sessions[token] or nil
    if not s then return nil end
    if s.exp < os.time() then Web.sessions[token] = nil return nil end
    -- V12.63 (relecture) : mot de passe changé ou code retiré (même sans redémarrage) = session terminée
    if s.secret ~= collective() and not codes()[s.secret] then Web.sessions[token] = nil return nil end
    return s
end

-- Données --------------------------------------------------------------------------------------------------------
local function started(r) return GetResourceState(r) == 'started' end
local function replayInfo()
    if not started('gs_lives') then return {} end
    local ok, r = pcall(function() return exports.gs_lives:ReplayInfo() end)
    return ok and type(r) == 'table' and r or {}
end

function Web.overview(who, level)
    local players = Admin.playerList()
    local replays = replayInfo()
    local ticketOf = {} -- V12.63 (n° 192) : joueur → n° de son ticket ouvert (anneau sur la carte de l'appli)
    for id, t in pairs(Admin.tickets or {}) do if t.status ~= 'closed' and t.src then ticketOf[t.src] = id end end
    for _, p in ipairs(players) do
        p.char = p.name; p.name = p.account
        p.replay = replays[p.id] -- { ticket, frames } : ⏪ dans l'appli
        p.ticket = ticketOf[p.id]
    end
    local logs = {}
    for i = 1, math.min(#Admin.logs, 40) do local l = Admin.logs[i] logs[i] = { staff = l.staff, action = l.action, target = l.target, details = l.details, time = l.time } end
    local places = {}
    for i, p in ipairs((Config.Web or {}).places or {}) do places[i] = p.label end
    local staffOnDuty = 0
    for _ in pairs(Admin.onDuty) do staffOnDuty = staffOnDuty + 1 end
    return {
        who = who, players = players, tickets = Admin.openTickets(), logs = logs, history = Admin.history or {}, places = places,
        server = { players = #players, max = GetConvarInt('sv_maxclients', 48), staffOnDuty = staffOnDuty, version = GetConvar('gs_version', '?'),
            weather = started('gs_weather') and (function() local ok, w = pcall(function() return exports.gs_weather:GetWeather() end) return ok and w or nil end)() or nil,
            lives = started('screenshot-basic') },
        maxJail = Config.Jail.maxMinutes, txadmin = GetConvar('gs_admin_txadmin', ''),
        locked = Moderation and (function() local l = Moderation.lockInfo() return l and { left = l.untilAt - os.time(), reason = l.reason } or nil end)() or nil,
        -- V12.65 · chat staff, incidents de la soirée, événements programmés (types + lieux), bans définitifs à valider
        chat = Hub and Hub.chat or {}, incidents = Hub and Hub.recentIncidents() or {},
        schedule = Hub and Hub.schedule or {}, kinds = Hub and Hub.kinds() or {},
        banReviews = (BanReview and (level or 2) >= ((Config.StaffHub.banReview or {}).minLevel or 3)) and BanReview.pending() or {},
    }
end

-- Écran d'un joueur (Lives hors jeu) : même capture que F11 (gs_lives, export Capture : faite chez le joueur, renvoyée par le
-- réseau du jeu, partagée entre tous ceux qui le regardent). V12.63 : l'appli et le jeu sont synchronisés sur la même image.
function Web.frame(who, target, reply, since)
    target = intId(target)
    if not target or not GetPlayerName(target) then return reply({ ok = false, text = 'Ce joueur n\'est plus en ville.' }) end
    if not started('gs_lives') then return reply({ ok = false, text = 'gs_lives n\'est pas démarré.' }) end
    local key = who .. ':' .. target
    if not Web.seen[key] then
        Web.seen[key] = true
        Security:LogStaff(('[Lives] Web · %s regarde l\'écran de %s [%d]'):format(who, GetPlayerName(target) or '?', target), 'staff')
    end
    -- V12.63 : réponse IMMÉDIATE (dernière image, ou raison du dernier échec) + capture suivante lancée en arrière-plan ;
    -- avant, la requête restait ouverte jusqu'à 8 s en attendant le joueur et la tablette affichait « serveur injoignable »
    local okE, pk = pcall(function()
        exports.gs_lives:Request(target) -- V12.64 : qualité et taille de gs_lives (image réduite, flux continu)
        return exports.gs_lives:Peek(target)
    end)
    if not okE or type(pk) ~= 'table' then return reply({ ok = false, text = 'Capture impossible (gs_lives).' }) end
    local img, age, err, seq = pk.img, tonumber(pk.age), pk.err, tonumber(pk.seq)
    if err then return reply({ ok = false, text = err, img = (img and age and age < 15000) and img or nil, seq = seq }) end
    -- V12.64 : l'appli a déjà cette image (même numéro) → réponse de quelques octets au lieu de renvoyer l'image
    if img and age and age < 15000 and seq and tonumber(since) == seq then return reply({ ok = true, same = true, seq = seq, age = age }) end
    if img and age and age < 15000 then return reply({ ok = true, img = img, age = age, seq = seq }) end
    reply({ ok = false, wait = true, text = 'Connexion à l\'écran…' })
end

-- Actions autorisées depuis l'appli (toutes revérifiées et journalisées par Admin.remote)
local ACTIONS = { freeze = true, unfreeze = true, warn = true, message = true, kick = true, announce = true, jail = true, unjail = true,
    revive = true, heal = true, fixveh = true, clearheat = true, unstuck = true, note = true, tp = true, ban = true, unban = true, ticket_claim = true, ticket_close = true,
    watch = true, unwatch = true, lockdown = true, offlineban = true } -- V12.63 : modération avancée (admin et plus)

function Web.handle(ip, body, reply, direct)
    local ok, d = pcall(json.decode, body or '')
    if not ok or type(d) ~= 'table' then return reply({ ok = false, text = 'Requête invalide.' }) end
    -- V12.63 (relecture) : adresse https activée (GERER-OVH → 21) = plus rien en clair par le port 30120 direct
    if direct and GetConvar('gs_admin_web_https', '0') == '1' then
        return reply({ ok = false, text = 'Connexion non chiffrée refusée : ouvre l\'adresse https de l\'appli.', auth = false })
    end
    if d.action == 'login' then
        local who, secret, level = Web.login(ip, d.pseudo, d.password)
        if not who then return reply({ ok = false, text = secret, auth = false }) end
        local token = newToken()
        if not token then return reply({ ok = false, text = 'Connexion indisponible (aléa du serveur). Redémarre le serveur : GERER-OVH → 4.' }) end
        Web.sessions[token] = { who = who, ip = ip, secret = secret, level = level, exp = os.time() + ((Config.Web or {}).sessionHours or 12) * 3600 }
        local rank = Config.LevelNames and Config.LevelNames[level] or ('rang ' .. tostring(level))
        Security:LogStaff(('[Appli staff] connexion de %s (%s, %s)'):format(who, rank, ip), 'staff')
        return reply({ ok = true, token = token, who = who, level = level, text = ('Bonjour %s (%s).'):format(who, rank) })
    end
    local s = Web.session(d.token)
    if not s then return reply({ ok = false, text = 'Session expirée : reconnecte-toi.', auth = false }) end
    local now = GetGameTimer() -- anti-rafale par session : 160 requêtes / 10 s (V12.64 : 4 fenêtres Lives à 2,5 images/s + le tableau de bord)
    if not s.windowAt or now - s.windowAt >= 10000 then s.windowAt, s.calls = now, 0 end
    s.calls = s.calls + 1
    if s.calls > 160 then return reply({ ok = false, text = 'Doucement.' }) end
    if d.action == 'logout' then Web.sessions[d.token] = nil return reply({ ok = true }) end
    if d.action == 'overview' then return reply({ ok = true, data = Web.overview(s.who, s.level) }) end
    -- V12.65 · chat staff, événements programmés, double validation des bans définitifs
    if d.action == 'chat' then
        if not Hub then return reply({ ok = false, text = 'Indisponible.' }) end
        local okC, err = Hub.say(s.who, d.text, 'appli')
        return reply({ ok = okC, text = okC and '' or err })
    end
    if d.action == 'plan' or d.action == 'unplan' then
        if not Hub or (s.level or 2) < 3 then return reply({ ok = false, text = 'Réservé aux admins (rang 3 et plus).' }) end
        local okP, msg
        if d.action == 'plan' then okP, msg = Hub.plan(d.kind, d.time, d.place, 'Web · ' .. s.who, s.level) else okP, msg = Hub.unplan(d.id) end
        if okP then Admin.logRemote('Web · ' .. s.who, d.action == 'plan' and 'schedule' or 'unschedule', nil, msg) end
        return reply({ ok = okP == true, text = msg })
    end
    if d.action == 'banconfirm' or d.action == 'banreject' then
        if not BanReview then return reply({ ok = false, text = 'Indisponible.' }) end
        local okB, msg = BanReview.decide(d.id, d.action == 'banconfirm', 'Web · ' .. s.who, 'Web · ' .. s.who, s.level)
        return reply({ ok = okB == true, text = msg })
    end
    if d.action == 'dossier' then
        local id = intId(d.id)
        if not id or not GetPlayerName(id) then return reply({ ok = false, text = 'Ce joueur n\'est plus en ville.' }) end
        return reply({ ok = true, data = Admin.dossier(nil, id, 3) })
    end
    if d.action == 'bans' then
        local okB, list = pcall(function() return Store.bans(Security:Sanitize(d.q, 64), 50) end)
        list = okB and type(list) == 'table' and list or {}
        for _, b in ipairs(list) do b.when = (tonumber(b.until_ts) or 0) == 0 and 'définitif' or ('jusqu\'au ' .. os.date('%d/%m/%Y %H:%M', b.until_ts)) end
        return reply({ ok = true, data = list })
    end
    if d.action == 'moderation' then -- V12.63 : surveillés, départs récents, fermeture des arrivées (admin et plus)
        if (s.level or 2) < 3 or not Moderation then return reply({ ok = false, text = 'Réservé aux admins (rang 3 et plus).' }) end
        return reply({ ok = true, data = Moderation.state(s.level) })
    end
    if d.action == 'frame' then return Web.frame(s.who, d.id, reply, d.since) end
    if d.action == 'replay' then
        if not started('gs_lives') then return reply({ ok = false, text = 'gs_lives n\'est pas démarré.' }) end
        local okR, frames = pcall(function() return exports.gs_lives:ReplayFrames(intId(d.id)) end)
        if not okR or type(frames) ~= 'table' or #frames == 0 then return reply({ ok = false, text = 'Pas encore d\'images pour ce joueur.' }) end
        Security:LogStaff(('[Lives] Web · %s revoit les dernières images de %s [%s]'):format(s.who, GetPlayerName(intId(d.id)) or '?', tostring(intId(d.id))), 'staff')
        return reply({ ok = true, frames = frames })
    end
    if d.action == 'act' then
        if not ACTIONS[d.name] then return reply({ ok = false, text = 'Action inconnue.' }) end
        if d.id ~= nil and not intId(d.id) then return reply({ ok = false, text = 'Joueur invalide.' }) end
        local good, text = Admin.remote(d.name, intId(d.id), d.text, 'Web · ' .. s.who, d.extra, s.level or 2) -- V12.63 : rang de la session
        return reply({ ok = good == true, text = text or '' })
    end
    reply({ ok = false, text = 'Action inconnue.' })
end

-- Fichiers de l'appli (compilée dans web/dist par Vite : staff.html + assets/) ----------------------------------------------
local MIME = { js = 'text/javascript; charset=utf-8', css = 'text/css; charset=utf-8', webp = 'image/webp', png = 'image/png',
    svg = 'image/svg+xml', woff2 = 'font/woff2', html = 'text/html; charset=utf-8' }
-- V12.63 : installable comme une appli (téléphone, tablette, PC : Chrome / Edge « Installer », Safari « Sur l'écran d'accueil »),
-- icônes au logo RoadLine (R néon), version « maskable » pour Android (découpe ronde sans rogner le logo)
local MANIFEST = json.encode({ id = './', name = 'RoadLine Staff', short_name = 'RL Staff', description = 'Modération de RoadLine RP sans être en jeu.',
    start_url = './', scope = './', display = 'standalone', display_override = { 'standalone', 'minimal-ui' }, orientation = 'any',
    background_color = '#07040d', theme_color = '#0b0714', lang = 'fr', dir = 'ltr', categories = { 'utilities', 'productivity' },
    icons = { { src = 'icon-192.png', sizes = '192x192', type = 'image/png', purpose = 'any' },
        { src = 'icon-512.png', sizes = '512x512', type = 'image/png', purpose = 'any' },
        { src = 'icon-maskable-512.png', sizes = '512x512', type = 'image/png', purpose = 'maskable' } } })
local PWA_ICONS = { ['/icon-192.png'] = true, ['/icon-512.png'] = true, ['/icon-maskable-512.png'] = true, ['/apple-touch-icon.png'] = true, ['/favicon-32.png'] = true }
local SW = "self.addEventListener('install',e=>self.skipWaiting());self.addEventListener('activate',e=>self.clients.claim());"
    .. "self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;e.respondWith(fetch(e.request).catch(()=>new Response("
    .. "'<meta charset=utf-8><body style=\"background:#0b0714;color:#f3eaff;font:16px system-ui;padding:24px\">Serveur injoignable : réessaie dans un instant.',"
    .. "{headers:{'Content-Type':'text/html; charset=utf-8'}})))});"

local function file(res, path, mime, cache)
    local data = LoadResourceFile(RES, path)
    if not data then res.writeHead(404, { ['Content-Type'] = 'text/plain; charset=utf-8' }) return res.send('Introuvable.') end
    res.writeHead(200, { ['Content-Type'] = mime, ['Cache-Control'] = cache or 'no-cache', ['X-Content-Type-Options'] = 'nosniff' })
    res.send(data)
end

SetHttpHandler(function(req, res)
    local path = req.path or '/'
    if req.method == 'POST' and path == '/api' then
        local ip = ipOf(req)
        local raw = tostring(req.address or ''):gsub(':%d+$', '')
        local direct = not (raw == '127.0.0.1' or raw == '::1' or raw == '[::1]') -- pas passé par l'adresse https (Caddy)
        req.setDataHandler(function(body)
            local sent = false
            local okH, err = pcall(Web.handle, ip, body, function(out)
                if sent then return end
                local okE, text = pcall(json.encode, out) -- V12.63 (relecture) : une donnée non encodable ne laisse jamais la requête sans réponse
                if not okE then text = '{"ok":false,"text":"Erreur du serveur."}' end
                sent = true
                res.writeHead(200, { ['Content-Type'] = 'application/json', ['Cache-Control'] = 'no-store' })
                res.send(text)
            end, direct)
            if not okH and not sent then
                sent = true
                print(('^1[gs_admin] appli staff : %s^0'):format(tostring(err)))
                res.writeHead(200, { ['Content-Type'] = 'application/json' })
                res.send(json.encode({ ok = false, text = 'Erreur du serveur.' }))
            end
        end)
        return
    end
    if path == '/manifest.webmanifest' then res.writeHead(200, { ['Content-Type'] = 'application/manifest+json' }) return res.send(MANIFEST) end
    if path == '/sw.js' then
        res.writeHead(200, { ['Content-Type'] = 'text/javascript', ['Cache-Control'] = 'no-cache', ['Service-Worker-Allowed'] = './' })
        return res.send(SW)
    end
    if PWA_ICONS[path] then return file(res, 'web/pwa' .. path, 'image/png', 'max-age=86400') end
    if path == '/carte-ls.webp' then return file(res, 'web/dist/carte-ls.webp', 'image/webp', 'max-age=86400') end
    local asset = path:match('^/assets/([%w%-_%.]+)$')
    if asset and not asset:find('%.%.') then
        local ext = asset:match('%.(%w+)$')
        return file(res, 'web/dist/assets/' .. asset, MIME[ext] or 'application/octet-stream', 'max-age=31536000, immutable')
    end
    if path == '/' or path == '' or path == '/index.html' then
        if not Web.enabled() then
            res.writeHead(404, { ['Content-Type'] = 'text/html; charset=utf-8' })
            return res.send('Appli staff fermée : aucun mot de passe. Sur le PC : GERER-OVH.bat → « Appli staff : mot de passe ».')
        end
        return file(res, 'web/dist/staff.html', 'text/html; charset=utf-8')
    end
    res.writeHead(404, { ['Content-Type'] = 'text/plain; charset=utf-8' })
    res.send('Introuvable.')
end)

-- V12.63 (relecture) : ménage — sessions expirées, échecs anciens, visionnages
CreateThread(function()
    while true do
        Wait(600000)
        local now = os.time()
        for k, s in pairs(Web.sessions) do if s.exp < now then Web.sessions[k] = nil end end
        for ip, f in pairs(Web.fails) do if (f.untilAt or 0) < now and now - (f.at or 0) > 900 then Web.fails[ip] = nil end end
        local n = 0
        for _ in pairs(Web.seen) do n = n + 1 end
        if n > 2000 then Web.seen = {} end
    end
end)

AdminWeb = Web
