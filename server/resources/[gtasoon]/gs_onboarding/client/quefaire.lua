-- gs_onboarding (client) · V10 « Que faire ? » : ce qui se passe maintenant + tout ce qu'on peut faire, en boutons
-- (GPS ou action) au lieu de commandes à retenir. Utilisé par l'appli du téléphone (export GuideData / GuideAction)
-- et par /quefaire (menu, pour qui n'a pas de téléphone).
local function find(point) -- position à jour (le staff a pu déplacer le point)
    if not point then return nil end
    local ok, c = pcall(function() return exports.gs_bridge:FindPoint(point) end)
    return ok and c or nil
end

local SERVICES = { police = 'Police', ambulance = 'EMS', mechanic = 'Mécanos', taxi = 'Taxis' }

--- Lignes « En ce moment » (public, jamais d'adresse secrète)
local function liveLines(d)
    local l = {}
    if d.event then l[#l + 1] = { icon = 'champagne-glasses', color = '#f2c230', label = d.event.label, desc = d.event.desc } end
    if d.next then l[#l + 1] = { icon = 'calendar-check', color = '#b048ff', label = ('Prochain rendez-vous : %s'):format(d.next.label), desc = d.next.when, cmd = 'rdv' } end
    if d.ring then l[#l + 1] = { icon = 'hand-fist', color = '#ff2340', label = 'Un ring clandestin est ouvert', desc = 'Son adresse circule dans les rumeurs.', cmd = 'rumeurs' } end
    local fug = #(GlobalState.gsFugitives or {})
    if fug > 0 then l[#l + 1] = { icon = 'person-running', color = '#ff2340', label = ('%d fugitif(s) en cavale'):format(fug), desc = 'Une prime pour qui le livre à la police.', cmd = 'legendes' } end
    for _, h in ipairs(d.hot or {}) do l[#l + 1] = { icon = 'fire', color = '#ff5a5a', label = ('%s : quartier sous tension'):format(h), desc = 'Rues désertes, police nombreuse.' } end
    if d.cases and d.cases > 0 then l[#l + 1] = { icon = 'magnifying-glass', color = '#4fd8ff', label = ('%d fait(s) divers à traiter'):format(d.cases), desc = 'Signalés au central (F4 → Faits divers).' } end
    local s = {}
    for job, label in pairs(SERVICES) do s[#s + 1] = ('%s %d'):format(label, d.services[job] or 0) end
    table.sort(s)
    l[#l + 1] = { icon = 'users', color = '#5aff8c', label = 'En service : ' .. table.concat(s, ' · '),
        desc = (d.services.mechanic or 0) == 0 and 'Aucun mécano en ville : le métier t\'attend !' or ((d.services.police or 0) == 0 and 'Pas de police joueur : la police IA patrouille.' or nil) }
    if (d.heat or 0) > 0 then l[#l + 1] = { icon = 'star', color = '#ff8a3d', label = 'Tu es recherché', desc = 'Change de tenue, fais-toi oublier… ou tente la cavale.', cmd = 'cavale' } end
    if not d.job or d.job.name == 'unemployed' then l[#l + 1] = { icon = 'building', color = '#4fd8ff', label = 'Tu n\'as pas encore de métier', desc = 'Le Pôle emploi t\'attend.', point = 'gs_jobs:Config.JobCenter.coords' } end
    return l
end

local function allowed(item, d)
    if item.only == 'gang' then return d.gang ~= nil end
    if item.only == 'nogang' then return d.gang == nil end
    if item.only == 'police' then return d.job and d.job.name == 'police' end
    return true
end

--- Données du guide : { live = { lignes }, sections = { { id, label, icon, color, items } } }
local function guideData()
    local d = lib.callback.await('gs_onboarding:quefaire', false)
    if not d then return nil end
    local sections = {}
    for _, s in ipairs(Guide) do
        local items = {}
        for i, it in ipairs(s.items) do
            if allowed(it, d) then
                items[#items + 1] = { ref = s.id .. ':' .. i, label = it.label, desc = it.desc, icon = it.icon, gps = it.point ~= nil }
            end
        end
        sections[#sections + 1] = { id = s.id, label = s.label, icon = s.icon, color = s.color, items = items }
    end
    local live = liveLines(d)
    for i, l in ipairs(live) do l.ref = 'live:' .. i end
    return { live = live, sections = sections }, live
end

local lastLive = {}
local function resolve(ref)
    local sid, i = tostring(ref):match('^([%w_]+):(%d+)$')
    i = tonumber(i)
    if sid == 'live' then return lastLive[i] end
    for _, s in ipairs(Guide) do if s.id == sid then return s.items[i] end end
end

--- Lance l'action d'une ligne. Retourne true si le téléphone doit se ranger (menu d'une autre ressource).
local function act(ref)
    local it = resolve(ref)
    if not it then return false end
    if it.report then
        local r = lib.inputDialog('Appeler le staff', { { type = 'textarea', label = 'Ton problème', required = true, max = 200 } })
        if r and r[1] then ExecuteCommand('report ' .. r[1]:gsub('[\r\n]', ' ')) end
        return true
    end
    if it.cmd then ExecuteCommand(it.cmd) return true end
    local c = find(it.point)
    if c then
        SetNewWaypoint(c.x, c.y)
        lib.notify({ title = it.label, description = 'GPS réglé.', type = 'success', icon = 'location-dot' })
    end
    return false
end

exports('GuideData', function()
    local data, live = guideData()
    lastLive = live or {}
    return data
end)
exports('GuideAction', act)

-- /quefaire : même contenu en menu
RegisterCommand('quefaire', function()
    local data, live = guideData()
    if not data then return end
    lastLive = live
    local o = {}
    for _, l in ipairs(data.live) do
        o[#o + 1] = { title = l.label, description = l.desc, icon = l.icon, iconColor = l.color, readOnly = not (l.cmd or l.point),
            onSelect = (l.cmd or l.point) and function() act(l.ref) end or nil }
    end
    for _, s in ipairs(data.sections) do
        o[#o + 1] = { title = s.label, icon = s.icon, iconColor = s.color, arrow = true, onSelect = function()
            local sub = {}
            for _, it in ipairs(s.items) do
                sub[#sub + 1] = { title = it.label, description = it.desc, icon = it.icon, onSelect = function() act(it.ref) end,
                    metadata = it.gps and { { label = 'Action', value = 'GPS' } } or nil }
            end
            lib.registerContext({ id = 'gs_quefaire_' .. s.id, title = s.label, menu = 'gs_quefaire', options = sub })
            lib.showContext('gs_quefaire_' .. s.id)
        end }
    end
    lib.registerContext({ id = 'gs_quefaire', title = 'Que faire ?', options = o })
    lib.showContext('gs_quefaire')
end, false)
