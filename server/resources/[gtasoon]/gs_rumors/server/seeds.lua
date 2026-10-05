-- gs_rumors (serveur) · V10.2 « Les rumeurs qui deviennent vraies ». Bruits lancés par les joueurs chez les barmans ;
-- assez de voix différentes = le staff valide (ou la ville tranche seule) et l'événement se produit pour de vrai.
-- Rien n'est créé de toutes pièces : chaque bruit déclenche un système existant (tempête de gs_weather, fait divers de
-- gs_faitsdivers) ou un sac de billets à trouver (une seule prise, vérifiée ici).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local S = Config.Seeds

Seeds = { votes = {}, ready = {}, last = {}, stash = nil }
-- votes[id] = { [cid] = at } ; ready[id] = { at } ; last[id] = dernière réalisation

local function now() return os.time() end
local function started(r) return GetResourceState(r) == 'started' end
local function seed(id) for _, s in ipairs(S.list) do if s.id == id then return s end end end
local function staffLevel(src)
    if not started('gs_admin') then return IsPlayerAceAllowed(tostring(src), 'command') and 5 or 0 end
    local ok, l = pcall(function() return exports.gs_admin:GetStaffLevel(src) end)
    return ok and (tonumber(l) or 0) or 0
end
local function announce(text)
    if started('gs_social') then pcall(function() exports.gs_social:Newsroom('rumeur', text) end) end
    if started('gs_lsradio') then pcall(function() exports.gs_lsradio:Say(text) end) end
end

local function count(id)
    local n, t = 0, now()
    for cid, at in pairs(Seeds.votes[id] or {}) do
        if t - at <= S.window then n = n + 1 else Seeds.votes[id][cid] = nil end
    end
    return n
end

--- Un joueur fait courir un bruit (au comptoir d'un barman)
function Seeds.spread(src, id, teller)
    local s = seed(id)
    if not s then return false, 'Je ne vois pas de quoi tu parles.' end
    local t = Config.Tellers[tonumber(teller) or 0]
    if not t or not Security:InRange(src, vec3(t.coords.x, t.coords.y, t.coords.z), 4.0) then return false, 'Approche-toi du comptoir.' end
    if Seeds.ready[id] or (Seeds.last[id] and now() - Seeds.last[id] < S.cooldown) then return false, '« Tout le monde en parle déjà. »' end
    local cid = Bridge:GetIdentifier(src)
    Seeds.votes[id] = Seeds.votes[id] or {}
    if Seeds.votes[id][cid] then return false, '« Tu me l\'as déjà dit. »' end
    if not (Bridge:RemoveMoney(src, 'cash', S.price, 'rumeur') or Bridge:RemoveMoney(src, 'bank', S.price, 'rumeur')) then
        return false, '« Un verre d\'abord. »'
    end
    Seeds.votes[id][cid] = now()
    Rumors.add('il paraît que ' .. s.label:sub(1, 1):lower() .. s.label:sub(2), s.label, t.coords)
    if count(id) >= S.threshold then
        Seeds.ready[id] = { at = now() }
        local msg = ('Rumeur prête à devenir vraie : « %s ». /rumeurvraie %s ou /rumeurfausse %s (sinon la ville tranche dans %d min)')
            :format(s.label, id, id, S.autoAfter // 60)
        if started('gs_admin') then pcall(function() exports.gs_admin:NotifyStaff(msg) end) end
        Security:LogStaff('[Rumeurs] ' .. msg)
    end
    return true, '« Je ferai passer le mot. »'
end

local function zoneOf(c) return Rumors.zone and Rumors.zone(c) or 'Los Santos' end

--- La rumeur se réalise
function Seeds.realize(id, by)
    local s = seed(id)
    if not s then return false end
    Seeds.ready[id], Seeds.votes[id], Seeds.last[id] = nil, {}, now()
    if id == 'storm' and started('gs_weather') then
        pcall(function() exports.gs_weather:StartEvent('storm') end)
        announce(s.fact)
    elseif id == 'crime' and started('gs_faitsdivers') then
        pcall(function() exports.gs_faitsdivers:Create() end)
        announce(s.fact)
    elseif id == 'stash' then
        local spot = S.stash.spots[math.random(#S.stash.spots)]
        Seeds.stash = { coords = spot, untilAt = now() + S.stash.minutes * 60 }
        GlobalState.gsRumorStash = { x = spot.x, y = spot.y, z = spot.z }
        announce(s.fact:format(zoneOf(spot)))
    end
    Security:LogStaff(('[Rumeurs] « %s » est devenue vraie (%s)'):format(s.label, by or 'la ville'))
    return true
end

--- Le sac de billets : un seul gagnant, sur place
function Seeds.take(src)
    local st = Seeds.stash
    if not st or now() > st.untilAt then return false, 'Il n\'y a plus rien.' end
    if not Security:InRangeFlat(src, st.coords, 3.0, 8.0) then return false, 'Trop loin.' end
    Seeds.stash = nil
    GlobalState.gsRumorStash = nil
    local amount = math.random(S.stash.reward[1], S.stash.reward[2])
    if S.stash.dirty then Bridge:AddItem(src, 'black_money', amount) else Bridge:AddMoney(src, 'cash', amount, 'rumeur') end
    announce('Le sac de billets de la rumeur a été trouvé. Quelqu\'un a eu de la chance…')
    return true, ('Tu as trouvé le sac : %d $.'):format(amount)
end

function Seeds.tick()
    for id, r in pairs(Seeds.ready) do
        if now() - r.at >= S.autoAfter then Seeds.realize(id, 'la ville') end
    end
    if Seeds.stash and now() > Seeds.stash.untilAt then Seeds.stash = nil GlobalState.gsRumorStash = nil end
end

lib.callback.register('gs_rumors:seed', function(src, id, teller)
    if not Security:RateLimit(src, 'gs_rumors:seed', 3, 10000) then return false, 'Doucement.' end
    return Seeds.spread(src, tostring(id or ''), teller)
end)
lib.callback.register('gs_rumors:stash', function(src)
    if not Security:RateLimit(src, 'gs_rumors:stash', 3, 5000) then return false, 'Doucement.' end
    return Seeds.take(src)
end)
lib.callback.register('gs_rumors:seeds', function(src)
    if not Security:RateLimit(src, 'gs_rumors:seeds', 4, 10000) then return {} end
    return S.list
end)

local function staffCmd(src, args, ok)
    if src ~= 0 and staffLevel(src) < S.staffLevel then return end
    local id = args[1]
    if not id or not Seeds.ready[id] then
        if src ~= 0 then Bridge:Notify(src, 'Aucune rumeur prête avec ce nom.', 'error') end
        return
    end
    if ok then Seeds.realize(id, src ~= 0 and (Bridge:GetName(src) or 'staff') or 'console')
    else Seeds.ready[id], Seeds.votes[id], Seeds.last[id] = nil, {}, now() end
    if src ~= 0 then Bridge:Notify(src, ok and 'La rumeur devient vraie.' or 'Rumeur étouffée.', 'success') end
end
RegisterCommand('rumeurvraie', function(src, args) staffCmd(src, args, true) end, false)
RegisterCommand('rumeurfausse', function(src, args) staffCmd(src, args, false) end, false)

CreateThread(function()
    GlobalState.gsRumorStash = nil
    while true do Wait(30000) Seeds.tick() end
end)
