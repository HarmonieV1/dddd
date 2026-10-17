-- gs_admin (serveur) · V12.63 · Modération avancée, réservée à admin / super-admin / fondateur (F11, F10 et appli staff) :
--   · Surveillance : un compte marqué (avec motif) → le staff en service est prévenu à chacune de ses arrivées ; 👁 dans les
--     listes de joueurs. Rien n'est visible du joueur.
--   · Fermer les arrivées : pendant un raid de trolls ou une attaque, plus personne n'entre sauf le staff ; durée limitée
--     (rouvre toute seule), et un message clair pour ceux qui tentent d'entrer.
--   · Contournement de ban : à chaque bannissement, les empreintes du PC (jetons FiveM) et les comptes liés (Discord, FiveM,
--     Xbox…) sont notés (jamais l'adresse IP : une box est partagée par une famille). Un autre compte qui arrive avec l'une
--     d'elles → alerte au staff (Config.Moderation.evasion = 'block' : arrivée refusée).
--   · Partis récemment : les dernières déconnexions (celui qui quitte juste après un RDM) → bannir hors ligne.
-- Tout est revérifié ici (rang, motif, durée) et journalisé comme les autres actions staff.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local M = Config.Moderation or {}

Moderation = { watch = {}, departed = {}, locked = nil, remote = {} }

local function license(src) return GetPlayerIdentifierByType(src, 'license') end
local function online(src) return type(src) == 'number' and GetPlayerName(src) ~= nil end
local function label(src) return ('%s [%s]'):format(GetPlayerName(src) or '?', tostring(src)) end
local function need(v, msg) if not v then error({ msg = msg }, 0) end return v end
local function clean(s) return (tostring(s or ''):gsub('[|\n\r]', '/')) end -- séparateurs des valeurs gardées (KVP)
local function spanOf(days) return days == 0 and 'définitif' or (days .. ' jour(s)') end
local function staffOnDuty(msg) for s in pairs(Admin.onDuty or {}) do Bridge:Notify(s, msg, 'warning') end end

-- Surveillance --------------------------------------------------------------------------------------------------------
local function saveWatchIndex()
    local l = {}
    for lic in pairs(Moderation.watch) do l[#l + 1] = lic end
    table.sort(l)
    SetResourceKvp('gs_admin:watchlist', table.concat(l, ','))
end

function Moderation.load()
    Moderation.watch = {}
    for lic in (GetResourceKvpString('gs_admin:watchlist') or ''):gmatch('[^,]+') do
        local at, staff, name, reason = (GetResourceKvpString('gs_admin:watch:' .. lic) or ''):match('^(%d+)|([^|]*)|([^|]*)|(.*)$')
        if at then Moderation.watch[lic] = { at = tonumber(at), staff = staff, name = name, reason = reason } end
    end
end

function Moderation.setWatch(lic, name, reason, staff)
    if not lic then return false end
    local w = { at = os.time(), staff = clean(staff):sub(1, 60), name = clean(name):sub(1, 60), reason = clean(reason):sub(1, 200) }
    Moderation.watch[lic] = w
    SetResourceKvp('gs_admin:watch:' .. lic, ('%d|%s|%s|%s'):format(w.at, w.staff, w.name, w.reason))
    saveWatchIndex()
    return true
end

function Moderation.clearWatch(lic)
    if not lic or not Moderation.watch[lic] then return false end
    Moderation.watch[lic] = nil
    DeleteResourceKvp('gs_admin:watch:' .. lic)
    saveWatchIndex()
    return true
end

function Moderation.watched(src) local lic = license(src) return lic and Moderation.watch[lic] or nil end

--- Liste pour l'appli et F11 : { license, name, reason, staff, at, online (id ou nil) }
function Moderation.watchList()
    local here = {}
    for _, id in ipairs(GetPlayers()) do local l = license(tonumber(id)) if l then here[l] = tonumber(id) end end
    local out = {}
    for lic, w in pairs(Moderation.watch) do
        out[#out + 1] = { license = lic, name = w.name, reason = w.reason, staff = w.staff, at = w.at, online = here[lic] }
    end
    table.sort(out, function(a, b) return a.at > b.at end)
    return out
end

-- Fermer les arrivées ---------------------------------------------------------------------------------------------------
function Moderation.lockInfo()
    local l = Moderation.locked
    if l and os.time() >= l.untilAt then
        Moderation.locked = nil
        Security:LogStaff('[Arrivées] rouvertes automatiquement (fin de la fermeture).', 'staff')
        return nil
    end
    return l
end

function Moderation.lock(minutes, reason, staff)
    if minutes == 0 then
        local was = Moderation.locked ~= nil
        Moderation.locked = nil
        return was
    end
    Moderation.locked = { untilAt = os.time() + minutes * 60, reason = clean(reason):sub(1, 120), staff = staff }
    return true
end

--- Message de refus pour un joueur qui se connecte, ou nil (le staff passe toujours)
function Moderation.lockRefusal(src)
    local l = Moderation.lockInfo()
    if not l then return nil end
    for _, ace in ipairs(Config.Aces) do if IsPlayerAceAllowed(src, ace) then return nil end end
    return ('Arrivées fermées quelques minutes par le staff (%s). Réessaie après %s.'):format(l.reason, os.date('%H:%M', l.untilAt))
end

-- Contournement de ban ----------------------------------------------------------------------------------------------------
--- Empreintes d'un joueur : jetons FiveM du PC + comptes liés, sans IP ni licence Rockstar (la licence est déjà la clé du ban)
function Moderation.fingerprints(src)
    local out, seen = {}, {}
    local function add(v)
        if type(v) == 'string' and v ~= '' and #v <= 120 and not seen[v] and not v:find(',', 1, true) then seen[v] = true out[#out + 1] = v end
    end
    if GetNumPlayerTokens and GetPlayerToken then
        for i = 0, (tonumber(GetNumPlayerTokens(src)) or 0) - 1 do add(GetPlayerToken(src, i)) end
    end
    if GetNumPlayerIdentifiers and GetPlayerIdentifier then
        for i = 0, (tonumber(GetNumPlayerIdentifiers(src)) or 0) - 1 do
            local id = GetPlayerIdentifier(src, i)
            if type(id) == 'string' and not id:find('^ip:') and not id:find('^license2?:') then add(id) end
        end
    end
    return out
end

--- Note les empreintes d'un banni. `fp` (facultatif) : empreintes déjà relevées (joueur parti, ban hors ligne).
function Moderation.rememberBan(src, lic, fp)
    if not lic then return 0 end
    fp = fp or (src and Moderation.fingerprints(src)) or {}
    if #fp == 0 then return 0 end
    for _, f in ipairs(fp) do SetResourceKvp('gs_admin:tokban:' .. f, lic) end
    SetResourceKvp('gs_admin:bantok:' .. lic, table.concat(fp, ','))
    return #fp
end

function Moderation.forgetBan(lic)
    if not lic then return end
    for f in (GetResourceKvpString('gs_admin:bantok:' .. lic) or ''):gmatch('[^,]+') do
        if GetResourceKvpString('gs_admin:tokban:' .. f) == lic then DeleteResourceKvp('gs_admin:tokban:' .. f) end
    end
    DeleteResourceKvp('gs_admin:bantok:' .. lic)
end

--- Compte banni qui partage une empreinte avec ce joueur : licence, ban, empreinte ; ou nil. Un ban écoulé est oublié.
function Moderation.evasion(src)
    local own = license(src)
    for _, f in ipairs(Moderation.fingerprints(src)) do
        local lic = GetResourceKvpString('gs_admin:tokban:' .. f)
        if lic and lic ~= '' and lic ~= own then
            local b = Store.ban(lic)
            if b then return lic, b, f end
            Moderation.forgetBan(lic)
        end
    end
    return nil
end

--- Contrôle à la connexion (appelé par gs_onboarding) : message de refus, ou nil
function Moderation.arrivalCheck(src)
    local refusal = Moderation.lockRefusal(src)
    if refusal then return refusal end
    local ok, lic, b, f = pcall(Moderation.evasion, src)
    if ok and lic then
        local kind = tostring(f):match('^(%a+):') or 'PC'
        local msg = ('[Contournement de ban ?] %s arrive avec une empreinte (%s) du compte banni « %s » (%s).')
            :format(GetPlayerName(src) or '?', kind, b.name or '?', b.reason or '—')
        Security:LogStaff(msg, 'staff')
        staffOnDuty('⚠ ' .. msg)
        pcall(Store.log, 'Anti-contournement', 'evasion', GetPlayerName(src) or '?', ('compte banni : %s'):format(b.name or lic))
        if M.evasion == 'block' then
            return 'Ce PC ou ce compte est lié à un compte banni de RoadLine RP. Contestation : notre Discord.'
        end
    end
    return nil
end

-- Partis récemment / ban hors ligne -------------------------------------------------------------------------------------
function Moderation.depart(src, reason)
    local lic = license(src)
    if not lic or (Admin.level and Admin.level(src) > 0) then return end -- le staff n'est jamais dans cette liste
    for i = #Moderation.departed, 1, -1 do if Moderation.departed[i].license == lic then table.remove(Moderation.departed, i) end end
    local okN, name = pcall(function() return Bridge:GetName(src) end)
    table.insert(Moderation.departed, 1, { license = lic, account = GetPlayerName(src) or '?', name = okN and name or nil, at = os.time(),
        reason = tostring(reason or ''):sub(1, 80), session = os.time() - ((Admin.joinedAt or {})[src] or os.time()), fp = Moderation.fingerprints(src) })
    while #Moderation.departed > (M.departedKeep or 50) do table.remove(Moderation.departed) end
end

--- Liste pour l'appli et F11 (sans les empreintes) : { license, name, account, ago, reason, session, banned }
function Moderation.departedList()
    local out, now = {}, os.time()
    for i, d in ipairs(Moderation.departed) do
        out[i] = { license = d.license, name = d.name or d.account, account = d.account, ago = now - d.at, reason = d.reason,
            session = d.session, banned = Store.ban(d.license) ~= nil }
    end
    return out
end

function Moderation.offlineBan(lic, days, reason, staff, level)
    local d
    for _, e in ipairs(Moderation.departed) do if e.license == lic then d = e break end end
    if not d then return false, 'Ce joueur n\'est pas (ou plus) dans les départs récents.' end
    for _, id in ipairs(GetPlayers()) do
        if license(tonumber(id)) == lic then return false, 'Il est revenu en ville : utilise le bannissement normal sur sa fiche.' end
    end
    if Store.ban(lic) then return false, 'Déjà banni.' end
    local name = d.name or d.account
    local span = spanOf(days)
    local untilTs = days == 0 and 0 or (os.time() + days * 86400)
    local held = days == 0 and BanReview and BanReview.needed(level) -- V12.65 : 2e admin pour un définitif
    if held then untilTs, span = BanReview.hold(lic, name, reason, staff, staff) end
    Store.banSet(lic, name, untilTs, reason, staff)
    Store.addNote(lic, 'warn', ('Bannissement hors ligne (%s) : %s'):format(span, reason), staff)
    Moderation.rememberBan(nil, lic, d.fp)
    if not held then Admin.publishSanction('Bannissement', name, reason, span) end
    return true, ('%s banni hors ligne (%s).'):format(name, span)
end

-- Contrôles communs ---------------------------------------------------------------------------------------------------
local function daysOf(v)
    local days = math.tointeger(tonumber(v))
    return need(days and days >= 0 and days <= 3650 and days, 'Durée : 0 (définitif) à 3650 jours (nombre entier).')
end
local function minutesOf(v)
    local m = math.tointeger(tonumber(v))
    return need(m and m >= 0 and m <= (M.lockMaxMinutes or 60) and m, ('Durée : 1 à %d min (0 = rouvrir).'):format(M.lockMaxMinutes or 60))
end
local function reason(v) return need(Security:Sanitize(v, 200), 'Motif obligatoire.') end

-- Actions F10 / F11 (Admin.run : rang, mode staff et journal) ----------------------------------------------------------
local Actions = Admin.actions -- la table d'actions de main.lua (F10 / F11)
local L = M.levels or {}

Actions.watch = { level = L.watch or 3, target = true, sanction = true, run = function(src, target, data)
    local r = reason(data.reason)
    local lic = need(license(target), 'Licence introuvable.')
    Moderation.setWatch(lic, Bridge:GetName(target) or GetPlayerName(target), r, label(src))
    return 'Sous surveillance : le staff sera prévenu à chacune de ses arrivées'
end }

Actions.unwatch = { level = L.watch or 3, run = function(_, target, data)
    local lic = (target and online(tonumber(target)) and license(tonumber(target))) or Security:Sanitize(data.license, 64)
    need(Moderation.clearWatch(need(lic, 'Joueur ou licence manquant.')), 'Ce joueur n\'est pas surveillé.')
    return 'Surveillance levée'
end }

Actions.lockdown = { level = L.lockdown or 4, run = function(src, _, data)
    local minutes = minutesOf(data.minutes)
    if minutes == 0 then
        need(Moderation.lock(0), 'Les arrivées sont déjà ouvertes.')
        Security:LogStaff(('[Arrivées] rouvertes par %s'):format(label(src)), 'staff')
        return 'Arrivées rouvertes'
    end
    local r = reason(data.reason)
    Moderation.lock(minutes, r, label(src))
    Security:LogStaff(('[Arrivées] FERMÉES %d min par %s : %s'):format(minutes, label(src), r), 'staff')
    staffOnDuty(('Arrivées fermées %d min (%s) : seul le staff peut entrer.'):format(minutes, r))
    return ('Arrivées fermées %d min (le staff passe toujours)'):format(minutes)
end }

Actions.offlineban = { level = L.offlineban or 4, run = function(src, _, data)
    local lic = need(Security:Sanitize(data.license, 64), 'Licence manquante.')
    local ok, msg = Moderation.offlineBan(lic, daysOf(data.days), reason(data.reason), label(src), Admin.level(src))
    return need(ok and msg, msg)
end }

-- Appli staff (Admin.remote : rang de la session, journal « Web · pseudo ») ---------------------------------------------
local R = Moderation.remote

R.watch = function(target, text, staff)
    target = tonumber(target)
    if not online(target) then return false, 'Aucun joueur avec cet identifiant en ville.' end
    if Admin.level(target) > 0 then return false, 'Le staff ne se met pas sous surveillance.' end
    local r = Security:Sanitize(text, 200)
    if not r or r == '' then return false, 'Motif obligatoire.' end
    local lic = license(target)
    if not lic then return false, 'Licence introuvable.' end
    Moderation.setWatch(lic, Bridge:GetName(target) or GetPlayerName(target), r, staff)
    Admin.logRemote(staff, 'watch', label(target), r)
    return true, label(target) .. ' sous surveillance.'
end

R.unwatch = function(target, text, staff)
    target = tonumber(target)
    local lic = (target and online(target) and license(target)) or Security:Sanitize(text, 64)
    if not lic or not Moderation.clearWatch(lic) then return false, 'Ce joueur n\'est pas surveillé.' end
    Admin.logRemote(staff, 'unwatch', target and online(target) and label(target) or lic)
    return true, 'Surveillance levée.'
end

R.lockdown = function(_, text, staff, extra)
    local m = math.tointeger(tonumber(extra))
    if not m or m < 0 or m > (M.lockMaxMinutes or 60) then return false, ('Durée : 1 à %d min (0 = rouvrir).'):format(M.lockMaxMinutes or 60) end
    if m == 0 then
        if not Moderation.lock(0) then return false, 'Les arrivées sont déjà ouvertes.' end
        Admin.logRemote(staff, 'lockdown', nil, 'rouvertes')
        return true, 'Arrivées rouvertes.'
    end
    local r = Security:Sanitize(text, 120)
    if not r or r == '' then return false, 'Motif obligatoire.' end
    Moderation.lock(m, r, staff)
    Admin.logRemote(staff, 'lockdown', nil, ('%d min · %s'):format(m, r))
    staffOnDuty(('Arrivées fermées %d min (%s) : seul le staff peut entrer.'):format(m, r))
    return true, ('Arrivées fermées %d min.'):format(m)
end

R.offlineban = function(_, text, staff, extra, actorLevel)
    local e = type(extra) == 'table' and extra or {}
    local lic = Security:Sanitize(e.license, 64)
    if not lic then return false, 'Licence manquante.' end
    local days = math.tointeger(tonumber(e.days))
    if not days or days < 0 or days > 3650 then return false, 'Durée : 0 (définitif) à 3650 jours (nombre entier).' end
    local r = Security:Sanitize(text, 200)
    if not r or r == '' then return false, 'Motif obligatoire.' end
    local ok, msg = Moderation.offlineBan(lic, days, r, staff, actorLevel)
    if ok then Admin.logRemote(staff, 'offlineban', lic, ('%s · %s'):format(spanOf(days), r)) end
    return ok, msg
end

--- État pour les interfaces : fermeture des arrivées, surveillés, départs récents (selon le rang)
function Moderation.state(lvl)
    local l = Moderation.lockInfo()
    return {
        locked = l and { left = l.untilAt - os.time(), reason = l.reason, staff = l.staff } or nil,
        watch = lvl >= (L.watch or 3) and Moderation.watchList() or nil,
        departed = lvl >= (L.departed or 3) and Moderation.departedList() or nil,
        canLock = lvl >= (L.lockdown or 4), canOfflineBan = lvl >= (L.offlineban or 4),
    }
end

lib.callback.register('gs_admin:moderation', function(src)
    if not Security:RateLimit(src, 'gs_admin:moderation', 6, 10000) then return nil end
    local lvl = Admin.level(src)
    if lvl < 3 then return nil end
    return Moderation.state(lvl)
end)

-- Cycle de vie ----------------------------------------------------------------------------------------------------------
AddEventHandler('gs_bridge:server:playerLoaded', function(src)
    local w = Moderation.watched(src)
    if not w then return end
    local msg = ('👁 Joueur surveillé en ville : %s — %s (par %s)'):format(label(src), w.reason, w.staff)
    staffOnDuty(msg)
    Security:LogStaff('[Surveillance] ' .. msg, 'staff')
end)

AddEventHandler('playerDropped', function(why)
    local src = source
    pcall(Moderation.depart, src, why)
end)

exports('ArrivalCheck', function(src) local ok, r = pcall(Moderation.arrivalCheck, tonumber(src)) return ok and r or nil end)

Moderation.load()
