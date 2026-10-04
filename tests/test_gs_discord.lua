-- Tests gs_discord (V9) : statut édité en place (créé une fois, id retenu, recréé si supprimé), annonces, rôles de métier
-- (PUT pour le métier actuel, DELETE pour les autres, pas de requête en double), webhooks invalides ignorés.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local convars = {}
local HOOK = 'https://discord.com/api/web' .. 'hooks/' -- coupé : pas pris pour un vrai secret par check_cfg
function GetConvar(k, d) return convars[k] or d end
function GetConvarInt(k, d) return tonumber(convars[k]) or d end
local reqs = {}
local reply = { code = 200, body = '{"id":"999"}' }
function PerformHttpRequest(url, cb, method, data, headers) reqs[#reqs + 1] = { url = url, method = method, data = data, headers = headers } if cb then cb(reply.code, reply.body) end end
json.decode = function(s) local id = s:match('"id":"(%d+)"') return { id = id } end
local idents = {}
function GetPlayerIdentifiers(src) return idents[src] or {} end
provide('gs_jobs', { GetOnDutyPlayers = function(job) return job == 'police' and { 1, 2 } or {} end })
loadResource('gs_discord', { R .. 'gs_discord/shared/config.lua', R .. 'gs_discord/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end

check('sans webhook : rien n\'est envoyé', Discord.status() == false and #reqs == 0)
convars.gs_webhook_status = 'https://evil.example/api/webhooks/1/abc'
check('webhook hors Discord refusé', Discord.status() == false and #reqs == 0)
convars.gs_webhook_status = HOOK .. '123/tok_EN-1'
join(1, 'CID1', 'A', vec3(0.0, 0.0, 0.0), { name = 'police', onduty = true })
check('statut créé une première fois', Discord.status() and reqs[1].method == 'POST' and reqs[1].url:find('wait=true') and GetResourceKvpString('statusMsg') == '999')
Discord.status()
check('ensuite le même message est modifié', reqs[2].method == 'PATCH' and reqs[2].url:find('/messages/999$'))
local e = Discord.statusEmbed()
check('statut : joueurs et police en service', e.fields[1].value:find('1') and e.fields[4].value:find('Police : %*%*2%*%*'))
reply.code = 404
Discord.status()
check('message supprimé dans Discord : oublié puis recréé', GetResourceKvpString('statusMsg') == nil)
reply.code = 200
Discord.status()
check('recréé', reqs[#reqs].method == 'POST' and GetResourceKvpString('statusMsg') == '999')

local n = #reqs
check('annonce sans webhook : ignorée', Discord.announce('T', 'x') == false and #reqs == n)
convars.gs_webhook_annonces = HOOK .. '5/abc'
check('annonce envoyée', Discord.announce('T', 'x') and #reqs == n + 1)

-- Rôles
n = #reqs
check('sans jeton : pas de rôles', Discord.syncRoles(1) == false and #reqs == n)
convars.gs_discord_bot_token, convars.gs_discord_guild = 'SECRET', '42'
Config.Roles = { police = '111', ambulance = '222' }
check('joueur sans Discord lié : rien', Discord.syncRoles(1) == false)
idents[1] = { 'license:abc', 'discord:777' }
Discord.syncRoles(1)
local put, del = 0, 0
for i = n + 1, #reqs do
    if reqs[i].method == 'PUT' and reqs[i].url:find('/members/777/roles/111$') then put = put + 1 end
    if reqs[i].method == 'DELETE' and reqs[i].url:find('/roles/222$') then del = del + 1 end
end
check('rôle du métier donné, les autres retirés', put == 1 and del == 1 and reqs[#reqs].headers.Authorization == 'Bot SECRET')
n = #reqs
Discord.syncRoles(1)
check('pas de requête en double si le métier n\'a pas changé', #reqs == n)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
