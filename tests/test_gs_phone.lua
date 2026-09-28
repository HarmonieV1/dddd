-- Tests gs_phone : numéros uniques, SMS, contacts, appels (pma-voice), virements, urgences, anti-abus.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local timers = {}
function SetTimeout(_, fn) timers[#timers + 1] = fn end -- sonnerie : déclenchée à la main
local voice = {}
provide('pma-voice', { setPlayerCall = function(src, channel) voice[src] = channel end })
local onDuty = { police = {} }
provide('gs_jobs', { GetOnDutyPlayers = function(job) return onDuty[job] or {} end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_phone', { R .. 'gs_phone/shared/config.lua' })
local numbers, contacts, messages, nextMsg = {}, {}, {}, 0
Store = {
    init = function() end,
    getNumber = function(cid) return numbers[cid] end,
    createNumber = function(cid, n) for _, v in pairs(numbers) do if v == n then return false end end numbers[cid] = n return true end,
    contacts = function(o) local l = {} for _, c in ipairs(contacts) do if c.owner == o then l[#l + 1] = c end end return l end,
    countContacts = function(o) local n = 0 for _, c in ipairs(contacts) do if c.owner == o then n = n + 1 end end return n end,
    addContact = function(o, name, number) contacts[#contacts + 1] = { id = #contacts + 1, owner = o, name = name, number = number } return #contacts end,
    deleteContact = function(o, id) for i, c in ipairs(contacts) do if c.id == id and c.owner == o then table.remove(contacts, i) return true end end return false end,
    addMessage = function(s, r, c) nextMsg = nextMsg + 1 messages[nextMsg] = { id = nextMsg, sender = s, receiver = r, content = c, is_read = 0 } return nextMsg end,
    conversations = function() return {} end,
    messageById = function(id) return messages[id] end,
    thread = function(me, peer) local l = {} for _, m in pairs(messages) do if (m.sender == me and m.receiver == peer) or (m.sender == peer and m.receiver == me) then l[#l + 1] = { id = m.id, sender = m.sender, content = m.content } end end return l end,
    markRead = function(me, peer) for _, m in pairs(messages) do if m.receiver == me and m.sender == peer then m.is_read = 1 end end end,
}
loadResource('gs_phone', { R .. 'gs_phone/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(31000) end
local here = vec3(0.0, 0.0, 0.0)

join(1, 'CID1', 'Jason Neon', here); W.players[1].items.phone = 1
join(2, 'CID2', 'Vice Lucia', here); W.players[2].items.phone = 1
join(3, 'CID3', 'Sans Tel', here)
join(4, 'CID4', 'Agent LSPD', here); W.players[4].items.phone = 1
local n1, n2, n3 = Phone.numbers[1], Phone.numbers[2], Phone.numbers[3]

-- Numéros --------------------------------------------------------------------------------------------
check('numéro attribué au format 555-XXXX', Phone.validNumber(n1) and n1:sub(1, 4) == '555-')
check('numéros uniques', n1 ~= n2 and n2 ~= n3)
TriggerEvent('gs_bridge:server:playerUnloaded', 1)
join(1, 'CID1', 'Jason Neon', here); W.players[1].items.phone = 1
check('même numéro à la reconnexion', Phone.numbers[1] == n1)
for _, bad in ipairs({ '5551234', '555-12345', 'abc-defg', 42, '555-12a4' }) do
    check('numéro invalide : ' .. tostring(bad), not Phone.validNumber(bad))
end

-- Ouverture : téléphone requis ------------------------------------------------------------------------
check('sans item : pas de téléphone', cb('gs_phone:open', 3) == false)
local data = cb('gs_phone:open', 1)
check('ouverture', data and data.number == n1 and data.money ~= nil)

-- SMS -------------------------------------------------------------------------------------------------
W.clientEvents = {}
local ok, res = cb('gs_phone:send', 1, n2, 'Yo, dispo ce soir ?')
check('SMS envoyé', ok and res.content == 'Yo, dispo ce soir ?')
check('SMS reçu en direct', lastClientEvent('gs_phone:client:message', 2).args[1].from == n1)
ok = cb('gs_phone:send', 1, n1, 'moi')
check('pas de SMS à soi-même', not ok)
ok, res = cb('gs_phone:send', 1, n2, 'go https://arnaque.io <script>')
check('liens et balises nettoyés', ok and not res.content:find('https') and not res.content:find('[<>]'))
ok = cb('gs_phone:send', 1, n2, '   ')
check('SMS vide refusé', not ok)
local sent = 0
for _ = 1, 10 do if cb('gs_phone:send', 1, n2, 'spam') then sent = sent + 1 end end
check('rate-limit SMS', sent < 10)
step()
local thread = cb('gs_phone:thread', 2, n1)
check('fil de discussion + lu', #thread >= 2 and thread[1].sender == nil and messages[1].is_read == 1)
ok = cb('gs_phone:send', 3, n1, 'test')
check('sans téléphone : pas de SMS', not ok)
step()

-- Contacts ---------------------------------------------------------------------------------------------
ok, res = cb('gs_phone:addContact', 1, 'Lucia', n2)
check('contact ajouté', ok and #res == 1)
ok = cb('gs_phone:addContact', 1, 'Nul', '12')
check('contact numéro invalide refusé', not ok)
ok, res = cb('gs_phone:deleteContact', 1, res[1].id)
check('contact supprimé', ok and #res == 0)
step()

-- Appels -----------------------------------------------------------------------------------------------
ok = cb('gs_phone:call', 1, n3)
check('appel vers un joueur sans téléphone : injoignable', not ok)
ok, res = cb('gs_phone:call', 1, n2)
local id = res
check('appel lancé', ok and Phone.inCall[1] == id and Phone.inCall[2] == id)
check('sonnerie chez le destinataire', lastClientEvent('gs_phone:client:incoming', 2).args[1].number == n1)
ok = cb('gs_phone:call', 4, n2)
check('ligne occupée', not ok)
ok = cb('gs_phone:answer', 1, id)
check('l\'appelant ne peut pas « décrocher » à la place du destinataire', not ok)
ok = cb('gs_phone:answer', 2, id)
check('décroché : voix connectée des deux côtés', ok and voice[1] == voice[2] and voice[1] > 0)
net('gs_phone:server:hangup', 2)
check('raccroché : voix coupée', voice[1] == 0 and voice[2] == 0 and not Phone.inCall[1])
step()
ok, id = cb('gs_phone:call', 1, n2)
timers[#timers]()
check('pas de réponse après la sonnerie', not Phone.inCall[1] and lastClientEvent('gs_phone:client:callEnded', 1).args[1] == 'Pas de réponse')
step()
ok, id = cb('gs_phone:call', 1, n2)
cb('gs_phone:answer', 2, id)
TriggerEvent('gs_bridge:server:playerUnloaded', 2)
check('déconnexion : appel coupé', not Phone.inCall[1] and voice[1] == 0)
join(2, 'CID2', 'Vice Lucia', here); W.players[2].items.phone = 1
step()

-- Virements ---------------------------------------------------------------------------------------------
W.players[1].money.bank, W.players[2].money.bank = 1000, 0
ok = cb('gs_phone:transfer', 1, n2, 5000)
check('virement sans fonds refusé', not ok and W.players[1].money.bank == 1000)
step()
for _, bad in ipairs({ 0, -10, 1.5, 1e9 }) do
    ok = cb('gs_phone:transfer', 1, n2, bad); step()
    check('montant invalide refusé : ' .. bad, not ok)
end
ok = cb('gs_phone:transfer', 1, n2, 400)
check('virement', ok and W.players[1].money.bank == 600 and W.players[2].money.bank == 400)
step()
ok = cb('gs_phone:transfer', 1, n1, 10)
check('pas de virement à soi-même', not ok)
step()
ok = cb('gs_phone:transfer', 1, '555-0000', 10)
check('destinataire inconnu refusé', not ok and W.players[1].money.bank == 600)
step()

-- Urgences ----------------------------------------------------------------------------------------------
ok, res = cb('gs_phone:emergency', 2, 'police', 'Braquage en cours à la supérette')
check('aucune unité : appel enregistré quand même', ok and res:find('Aucune unité'))
advance(61000)
onDuty.police = { 4 }
ok, res = cb('gs_phone:emergency', 2, 'police', 'Braquage en cours à la supérette')
check('police en service alertée avec position', ok and lastClientEvent('gs_phone:client:emergency', 4).args[1].coords ~= nil)
cb('gs_phone:emergency', 2, 'ems', 'et un blessé')
ok = cb('gs_phone:emergency', 2, 'police', 'spam')
check('spam d\'urgences limité (2 / min)', not ok)
advance(61000)
ok = cb('gs_phone:emergency', 2, 'pompiers', 'x')
check('service inconnu refusé', not ok)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
