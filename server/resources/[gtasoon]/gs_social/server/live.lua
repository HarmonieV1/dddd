-- gs_social (serveur) · V10.1 « Direct Weazel ». Une grosse poursuite passe en direct : bandeau pour toute la ville
-- (jamais le nom du suspect), hélicoptère de la chaîne pour les joueurs proches, journalistes en service sur place payés
-- à la minute (plafonné), brève de fin selon l'issue, Radio Los Santos.
local Bridge = exports.gs_bridge
local L = Config.Live

Live = { current = nil, last = -L.cooldown }

local function now() return os.time() end
local function started(r) return GetResourceState(r) == 'started' end
local function zone(c)
    if not started('gs_rumors') then return 'Los Santos' end
    local ok, z = pcall(function() return exports.gs_rumors:Zone(c) end)
    return ok and z or 'Los Santos'
end
local function radio(text)
    if started('gs_lsradio') then pcall(function() exports.gs_lsradio:Say(text) end) end
end
local function heat(src)
    if not started('gs_wanted') then return 0 end
    local ok, h = pcall(function() return exports.gs_wanted:GetHeat(src) end)
    return ok and tonumber(h) or 0
end
local function posOf(src) return GetEntityCoords(GetPlayerPed(src)) end

--- Envoie la cible de l'hélicoptère aux joueurs proches du suspect (les autres n'ont que le bandeau)
local function follow(c)
    local here = posOf(c.src)
    for _, s in ipairs(Bridge:GetPlayers() or {}) do
        if not c.seen[s] and #(posOf(s) - here) <= L.range then
            c.seen[s] = true
            TriggerClientEvent('gs_social:client:live', s, c.src)
        end
    end
end

function Live.start(src, coords)
    local c = { src = src, since = now(), zone = zone(coords or posOf(src)), paid = {}, seen = {} }
    Live.current = c
    local text = ('Course-poursuite en cours à %s. Notre hélicoptère est sur place.'):format(c.zone)
    TriggerClientEvent('gs_social:client:weazel', -1, 'EN DIRECT', text, 12000)
    radio(('On me signale une course-poursuite à %s, Weazel News est en direct. Prudence sur la route !'):format(c.zone))
    follow(c)
    return c
end

local ENDINGS = {
    caught = 'Fin de notre direct à %s : le suspect a été interpellé.',
    lost = 'Fin de notre direct à %s : le suspect a semé la police.',
    gone = 'Fin de notre direct à %s : le suspect s\'est volatilisé.',
    timeout = 'Fin de notre direct à %s : la traque continue sans nous.',
}

function Live.stop(outcome)
    local c = Live.current
    if not c then return end
    Live.current, Live.last = nil, now()
    for s in pairs(c.seen) do TriggerClientEvent('gs_social:client:live', s, nil) end
    local text = (ENDINGS[outcome] or ENDINGS.timeout):format(c.zone)
    TriggerClientEvent('gs_social:client:weazel', -1, 'FIN DU DIRECT', text, 10000)
    if Vibe2 and Vibe2.newsroom then pcall(Vibe2.newsroom, 'live_end', text) end
    radio(text)
    for s, n in pairs(c.paid) do
        if n > 0 and Bridge:IsLoaded(s) then Bridge:Notify(s, ('Direct terminé : %d $ pour ta couverture.'):format(n), 'success') end
    end
end

--- Une grosse poursuite démarre (signalement avec beaucoup de chaleur) : direct, si la chaîne n'en sort pas d'un
function Live.consider(src, h, coords)
    if Live.current or now() - Live.last < L.cooldown or (tonumber(h) or 0) < L.minHeat or not Bridge:IsLoaded(src) then return nil end
    return Live.start(src, coords)
end

--- Toutes les 30 s : fin du direct ? journalistes sur place payés, nouveaux spectateurs
function Live.tick()
    local c = Live.current
    if not c then return end
    if not Bridge:IsLoaded(c.src) then return Live.stop('gone') end
    if heat(c.src) <= 0 then return Live.stop('lost') end
    if now() - c.since > L.maxMinutes * 60 then return Live.stop('timeout') end
    local here = posOf(c.src)
    for _, s in ipairs(Bridge:GetPlayers() or {}) do
        if s ~= c.src and started('gs_jobs') and exports.gs_jobs:IsOnDutyAs(s, Config.PressJob) == true and #(posOf(s) - here) <= L.pressRange then
            local n = math.min(math.floor(L.pressPerMinute / 2), L.pressMax - (c.paid[s] or 0))
            if n > 0 and Bridge:AddMoney(s, 'cash', n, 'direct weazel') then c.paid[s] = (c.paid[s] or 0) + n end
        end
    end
    follow(c)
end

AddEventHandler('gs_wanted:server:reported', function(src, _, h, coords) Live.consider(src, h, coords) end)
AddEventHandler('gs_police:server:jailed', function(target)
    if Live.current and Live.current.src == target then Live.stop('caught') end
end)
AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    if Live.current then
        if Live.current.src == src then Live.stop('gone') else Live.current.seen[src], Live.current.paid[src] = nil, nil end
    end
end)

CreateThread(function()
    while true do Wait(30000) Live.tick() end
end)
