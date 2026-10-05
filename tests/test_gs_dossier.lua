-- Tests gs_dossier (V10.2) : rôle selon le métier en service, chaque rôle ne voit que ses rubriques, presse = public
-- seulement (pas de casier ni de mandats), table absente sans plantage, journalisation.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local duty = {}
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end })
local function rows(sql)
    if sql:find('FROM players WHERE citizenid') then return { { citizenid = 'CID9', firstname = 'Tony', lastname = 'Vercetti', birthdate = '1990-01-01', job = 'Mécano' } } end
    if sql:find('FROM players WHERE CONCAT') then return { { citizenid = 'CID9', firstname = 'Tony', lastname = 'Vercetti' } } end
    if sql:find('gs_police_records') then return { { charge = 'Excès de vitesse', fine = 300, jail = 0, date = '01/10/2026' } } end
    if sql:find('gs_police_warrants') then return { { reason = 'Braquage', officer = 'Agent X' } } end
    if sql:find('gs_justice_cases') then return { { charge = 'Vol', status = 'guilty', verdict = 'Coupable', date = '02/10/2026' } } end
    if sql:find('gs_gang_members') then error('table absente') end
    if sql:find('gs_news') then return { { title = 'Vercetti relaxé', author = 'Weazel' } } end
    return {}
end
MySQL = { query = { await = function(sql) return rows(sql) end } }
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_dossier', { R .. 'gs_dossier/shared/config.lua', R .. 'gs_dossier/server/main.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function titles(d) local t = {} for _, s in ipairs(d.sections) do t[s.title] = s.lines end return t end
join(1, 'C1', 'Agent', vec3(0.0, 0.0, 0.0)) duty[1] = 'police'
join(2, 'C2', 'Journaliste', vec3(0.0, 0.0, 0.0)) duty[2] = 'weazel'
join(3, 'C3', 'Civil', vec3(0.0, 0.0, 0.0))
local ok = cb('gs_dossier:search', 3, 'Vercetti') advance(11000)
check('civil : refusé', not ok)
local _, list = cb('gs_dossier:search', 1, 'Verc') advance(11000)
check('police : recherche', #list == 1 and list[1].citizenid == 'CID9')
local _, d = cb('gs_dossier:open', 1, 'CID9') advance(11000)
local t = titles(d)
check('police : casier, mandats, véhicules, gang', t['Casier judiciaire'] and t['Mandats actifs'] and t['Véhicules enregistrés'] and t['Gang (renseignements)'])
check('table absente : rubrique quand même (sans planter)', t['Gang (renseignements)'][1] == 'Aucun lien connu')
local _, dp = cb('gs_dossier:open', 2, 'CID9') advance(11000)
local tp = titles(dp)
check('presse : pas de casier ni de mandats', not tp['Casier judiciaire'] and not tp['Mandats actifs'] and not tp['Gang (renseignements)'])
check('presse : verdicts publics, articles, notoriété', tp['Verdicts rendus (public)'] and tp['Dans la presse'][1]:find('relaxé', 1, true) and tp['Notoriété'])
ok = cb('gs_dossier:open', 1, "CID9'; DROP") advance(11000)
check('identifiant invalide refusé', not ok)
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
