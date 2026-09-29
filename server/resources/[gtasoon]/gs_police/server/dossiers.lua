-- gs_police (serveur) : base de données de la police. Recherche d'un citoyen par nom (résultats numérotés : le client ne voit
-- jamais de citizenid), mandats (délivrés / clos selon le grade), rapports (lecture pour tous les agents, suppression par
-- l'auteur ou un grade élevé). Tout passe par Police.run : service obligatoire, rate-limit, journal.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local Actions, need, label = Police.Actions, Police.need, Police.label
local D = Config.Dossiers

Police.lastSearch = {} -- [src] = { { cid, name, birthdate } } : dernière recherche de l'agent

local function grade(src)
    local j = Bridge:GetJob(src)
    return j and j.grade or 0
end

Actions.dossier_search = { job = 'police', run = function(src, _, data)
    local term = need(Security:Sanitize(data.term, 40), 'Tape un nom.')
    term = term:gsub('[%%_\\]', '')
    need(#term >= 2, 'Au moins 2 lettres.')
    local found, out = Store.searchCitizens(term), {}
    Police.lastSearch[src] = {}
    for i, r in ipairs(found) do
        local name = ('%s %s'):format(r.firstname or '?', r.lastname or '?')
        Police.lastSearch[src][i] = { cid = r.citizenid, name = name, birthdate = r.birthdate }
        out[i] = { index = i, name = name, birthdate = r.birthdate }
    end
    return out
end }

local function picked(src, index)
    local p = Police.lastSearch[src] and Police.lastSearch[src][tonumber(index) or 0]
    return need(p, 'Refais la recherche.')
end

Actions.dossier_open = { job = 'police', run = function(src, _, data)
    local p = picked(src, data.index)
    local licences = {}
    local online = Bridge:GetSourceByIdentifier(p.cid)
    if online then licences = Bridge:GetLicences(online) or {} end
    return { name = p.name, birthdate = p.birthdate, records = Store.records(p.cid), warrants = Store.warrantsOf(p.cid),
             online = online ~= nil, weapon = licences.weapon == true, driver = licences.driver == true }
end }

Actions.warrant_add = { job = 'police', run = function(src, _, data)
    need(grade(src) >= D.warrantGrade, 'Grade insuffisant pour un mandat.')
    local p = picked(src, data.index)
    local reason = need(Security:Sanitize(data.reason, D.reasonMax), 'Motif obligatoire.')
    local me = Bridge:GetIdentifier(src)
    need(Store.countOfficerWarrants(me) < D.maxWarrantsPerOfficer, ('Maximum %d mandats actifs par agent.'):format(D.maxWarrantsPerOfficer))
    need(me ~= p.cid, 'Pas de mandat contre toi-même.')
    Store.addWarrant(p.cid, p.name, reason, label(src), me)
    return 'Mandat délivré contre ' .. p.name
end }

Actions.warrants_list = { job = 'police', run = function() return Store.activeWarrants() end }

Actions.warrant_close = { job = 'police', run = function(src, _, data)
    need(grade(src) >= D.closeGrade, 'Grade insuffisant pour clore un mandat.')
    need(Store.closeWarrant(tonumber(data.id) or 0), 'Mandat introuvable ou déjà clos.')
    return 'Mandat clos'
end }

Actions.report_add = { job = 'police', run = function(src, _, data)
    local title = need(Security:Sanitize(data.title, 100), 'Titre obligatoire.')
    local body = need(Security:Sanitize(data.body, D.bodyMax), 'Rapport vide.')
    local image = data.image and Security:ValidImageUrl(data.image) or nil -- capture bodycam (hébergeur autorisé seulement)
    Store.addReport(title, body, label(src), Bridge:GetIdentifier(src), image)
    return image and 'Rapport enregistré avec la capture bodycam' or 'Rapport enregistré'
end }

Actions.reports_list = { job = 'police', run = function() return Store.reports() end }

Actions.report_read = { job = 'police', run = function(src, _, data)
    local r = need(Store.report(tonumber(data.id) or 0), 'Rapport introuvable.')
    r.mine = r.officer_cid == Bridge:GetIdentifier(src)
    r.officer_cid = nil
    return r
end }

Actions.report_delete = { job = 'police', run = function(src, _, data)
    local r = need(Store.report(tonumber(data.id) or 0), 'Rapport introuvable.')
    need(r.officer_cid == Bridge:GetIdentifier(src) or grade(src) >= D.reportDeleteGrade, 'Seul l\'auteur ou un gradé peut le supprimer.')
    Store.deleteReport(r.id)
    return 'Rapport supprimé'
end }

--- Preuves vidéo : crimes filmés par les caméras de surveillance (gs_wanted), du plus récent au plus ancien.
Actions.evidence_list = { job = 'police', run = function()
    return GetResourceState('gs_wanted') == 'started' and exports.gs_wanted:GetEvidence() or {}
end }

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Police.lastSearch[src] = nil end)
