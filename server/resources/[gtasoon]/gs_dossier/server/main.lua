-- gs_dossier (serveur) · V10.2 « Le dossier du citoyen ». Une seule fiche par personnage, assemblée à la demande à
-- partir des tables existantes (lecture seule, aucune écriture) ; chaque rôle n'en voit que sa partie :
--   police : tout (casier, mandats, affaires, véhicules, gang, réputation, presse) ;
--   juge   : casier, mandats, affaires, métiers, presse ;
--   presse : ce qui est public (verdicts rendus, métiers, notoriété, articles).
-- Toute consultation est journalisée (qui a regardé quel dossier).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Dossier = {}

--- Requête protégée : une table absente (ressource jamais lancée) ne casse pas la fiche
local function q(sql, args)
    local ok, rows = pcall(function() return MySQL.query.await(sql, args) end)
    return ok and rows or {}
end
Dossier.query = q

--- Rôle du demandeur (premier rôle dont il occupe un des métiers en service)
function Dossier.role(src)
    if GetResourceState('gs_jobs') ~= 'started' then return nil end
    for id, r in pairs(Config.Roles) do
        for _, job in ipairs(r.jobs) do
            if exports.gs_jobs:IsOnDutyAs(src, job) == true then return id, r end
        end
    end
    return nil
end

function Dossier.search(term)
    term = Security:Sanitize(term, 40)
    if not term or #term < 2 then return {} end
    return Dossier.query([[SELECT citizenid,
        JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname, JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS lastname
        FROM players WHERE CONCAT(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE ?
        LIMIT ?]], { '%' .. term .. '%', Config.Max.search })
end

--- La fiche, réduite aux rubriques du rôle. Retourne nil si le personnage n'existe pas.
function Dossier.build(cid, show)
    local p = Dossier.query([[SELECT citizenid, JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname,
        JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS lastname, JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.birthdate')) AS birthdate,
        JSON_UNQUOTE(JSON_EXTRACT(job, '$.label')) AS job FROM players WHERE citizenid = ? LIMIT 1]], { cid })[1]
    if not p then return nil end
    local name = ('%s %s'):format(p.firstname or '?', p.lastname or '')
    local d = { cid = cid, name = name, sections = {} }
    local function section(title, icon, lines) d.sections[#d.sections + 1] = { title = title, icon = icon, lines = lines } end
    local M = Config.Max

    if show.identity then
        section('Identité', 'id-card', { ('%s · né(e) le %s'):format(name, p.birthdate or '?'), 'Emploi principal : ' .. (p.job or 'aucun') })
    end
    if show.records then
        local l = {}
        for _, r in ipairs(Dossier.query([[SELECT charge, fine, jail, DATE_FORMAT(created_at, '%d/%m/%Y') AS date FROM gs_police_records
            WHERE citizenid = ? ORDER BY id DESC LIMIT ?]], { cid, M.records })) do
            l[#l + 1] = ('%s · %s%s%s'):format(r.date or '', r.charge, (r.fine or 0) > 0 and (' · ' .. r.fine .. ' $') or '', (r.jail or 0) > 0 and (' · ' .. r.jail .. ' min') or '')
        end
        section('Casier judiciaire', 'scale-balanced', #l > 0 and l or { 'Casier vierge' })
    end
    if show.warrants then
        local l = {}
        for _, r in ipairs(Dossier.query('SELECT reason, officer FROM gs_police_warrants WHERE citizenid = ? AND active = 1', { cid })) do
            l[#l + 1] = ('%s (par %s)'):format(r.reason, r.officer)
        end
        section('Mandats actifs', 'triangle-exclamation', #l > 0 and l or { 'Aucun' })
    end
    if show.cases or show.publicCases then
        local l = {}
        local sql = show.cases and [[SELECT charge, status, verdict, DATE_FORMAT(created_at, '%d/%m/%Y') AS date FROM gs_justice_cases
            WHERE defendant = ? ORDER BY id DESC LIMIT ?]] or [[SELECT charge, status, verdict, DATE_FORMAT(created_at, '%d/%m/%Y') AS date
            FROM gs_justice_cases WHERE defendant = ? AND status <> 'open' ORDER BY id DESC LIMIT ?]]
        for _, r in ipairs(Dossier.query(sql, { cid, M.cases })) do
            l[#l + 1] = ('%s · %s · %s'):format(r.date or '', r.charge, r.status == 'open' and 'en cours' or (r.verdict ~= '' and r.verdict or r.status))
        end
        section(show.cases and 'Affaires au tribunal' or 'Verdicts rendus (public)', 'gavel', #l > 0 and l or { 'Aucune' })
    end
    if show.jobs then
        local l = {}
        for _, r in ipairs(Dossier.query('SELECT job, grade FROM gs_job_members WHERE citizenid = ?', { cid })) do
            l[#l + 1] = ('%s (grade %d)'):format(r.job, r.grade or 0)
        end
        section('Métiers et entreprises', 'briefcase', #l > 0 and l or { 'Aucun contrat' })
    end
    if show.gang then
        local g = Dossier.query('SELECT gang, grade FROM gs_gang_members WHERE citizenid = ? LIMIT 1', { cid })[1]
        section('Gang (renseignements)', 'people-group', { g and ('%s (rang %d)'):format(g.gang, g.grade or 0) or 'Aucun lien connu' })
    end
    if show.vehicles then
        local l = {}
        for _, r in ipairs(Dossier.query('SELECT plate, vehicle FROM player_vehicles WHERE citizenid = ? LIMIT ?', { cid, M.vehicles })) do
            l[#l + 1] = ('%s · %s'):format(r.plate or '?', r.vehicle or '?')
        end
        section('Véhicules enregistrés', 'car', #l > 0 and l or { 'Aucun' })
    end
    if show.reputation or show.fame then
        local r = Dossier.query('SELECT street, legal, media FROM gs_reputation WHERE citizenid = ? LIMIT 1', { cid })[1] or {}
        if show.reputation then
            section('Réputation', 'star', { ('Rue %d · Légale %d · Médias %d'):format(r.street or 0, r.legal or 0, r.media or 0) })
        else
            section('Notoriété', 'star', { ('Médias : %d'):format(r.media or 0) })
        end
    end
    if show.press then
        local l = {}
        local last = tostring(p.lastname or '')
        if #last >= 3 then
            for _, r in ipairs(Dossier.query([[SELECT title, author, created FROM gs_news WHERE title LIKE ? OR body LIKE ?
                ORDER BY id DESC LIMIT ?]], { '%' .. last .. '%', '%' .. last .. '%', M.press })) do
                l[#l + 1] = ('« %s » (%s)'):format(r.title, r.author)
            end
        end
        section('Dans la presse', 'newspaper', #l > 0 and l or { 'Aucun article' })
    end
    return d
end

lib.callback.register('gs_dossier:search', function(src, term)
    if not Security:RateLimit(src, 'gs_dossier:search', 4, 10000) then return false, 'Doucement.' end
    if not Dossier.role(src) then return false, 'Réservé à la police, aux juges et à la presse en service.' end
    return true, Dossier.search(term)
end)

lib.callback.register('gs_dossier:open', function(src, cid)
    if not Security:RateLimit(src, 'gs_dossier:open', 6, 10000) then return false, 'Doucement.' end
    local id, role = Dossier.role(src)
    if not id then return false, 'Réservé à la police, aux juges et à la presse en service.' end
    if type(cid) ~= 'string' or not cid:match('^[%w]+$') then return false, 'Dossier introuvable.' end
    local d = Dossier.build(cid, role.show)
    if not d then return false, 'Dossier introuvable.' end
    d.label = role.label
    Security:LogStaff(('[Dossier] %s (%s) a consulté le dossier de %s'):format(Bridge:GetName(src) or src, id, d.name), 'jobs')
    return true, d
end)
