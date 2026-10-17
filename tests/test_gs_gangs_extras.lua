-- Tests gs_gangs (extras) : tags (limite, distance, bombe, influence, effacement), garage du gang, receleur.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
function SetVehicleColours(veh, a) W.entities[veh].paint = a end
provide('gs_jobs', { IsOnDutyAs = function() return false end })
local hour = 23
provide('gs_weather', { GetGameTime = function() return hour, 0 end })
local reports = 0
provide('gs_wanted', { ReportCrime = function() reports = reports + 1 return true end })
provide('gs_drugs', { GetSellables = function() return { { id = 'weed', label = 'Cannabis', item = 'weed_bag', price = { 70, 120 } } } end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_gangs', { R .. 'gs_gangs/shared/config.lua', R .. 'gs_gangs/shared/blocks.lua' })
Config.DefaultGangs = {}
local gangs, members = {}, {}
Store = {
    init = function() end, gangs = function() return { { name = 'ballas', label = 'Ballas', color = 27 }, { name = 'vagos', label = 'Vagos', color = 46 } } end,
    territories = function() return {} end, saveTerritories = function() end,
    createGang = function() return true end, setStash = function() end, deleteGang = function() end,
    addMoney = function() return true end, removeMoney = function() return true end, money = function() return 0 end,
    member = function(cid) return members[cid] end, members = function() return {} end, countMembers = function() return 0 end,
    addMember = function(cid, g, grade) members[cid] = { gang = g, grade = grade } return true end,
    setGrade = function() end, removeMember = function(cid) members[cid] = nil return true end,
}
local tagRows, nextTag = {}, 0
TagsStore = {
    init = function() end, all = function() return {} end,
    insert = function(g, c) nextTag = nextTag + 1 tagRows[nextTag] = g return nextTag end,
    insertMemorial = function(g, c, h, text, exp) nextTag = nextTag + 1 tagRows[nextTag] = { g, text, exp } return nextTag end,
    delete = function(id) tagRows[id] = nil end,
}
loadResource('gs_gangs', { R .. 'gs_gangs/server/main.lua', R .. 'gs_gangs/server/extras.lua' })
Gangs.init()
Extras.init()

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local grove = Config.Territories.grove.center
members.CID1 = { gang = 'ballas', grade = 3 }
members.CID2 = { gang = 'vagos', grade = 0 }
join(1, 'CID1', 'Ballas Chef', grove)
join(2, 'CID2', 'Vagos Recrue', grove)
join(3, 'CID3', 'Civil', grove)

-- Tags
local function spot(dx) return { x = grove.x + dx, y = grove.y, z = grove.z } end
local ok, msg = cb('gs_gangs:tag', 3, spot(1)); step()
check('civil : pas de tag', not ok)
ok, msg = cb('gs_gangs:tag', 1, spot(1)); step()
check('bombe requise', not ok and msg:find('bombe'))
W.players[1].items.spraycan = 3
ok = cb('gs_gangs:tag', 1, spot(40)); step()
check('mur trop loin', not ok)
ok = cb('gs_gangs:tag', 1, spot(1)); step()
check('tag posé, bombe utilisée, publié', ok and W.players[1].items.spraycan == 2 and #GlobalState.gsTags == 1 and GlobalState.gsTags[1].label == 'Ballas')
check('influence gagnée', Gangs.territories.grove.influence.ballas == Config.Tags.influence)
tp(1, vec3(grove.x + 10.0, grove.y, grove.z))
ok, msg = cb('gs_gangs:tag', 1, spot(11)); step()
check('trop près d\'un autre tag', not ok and msg:find('côté'))
Config.Tags.maxPerGang = 1
tp(1, vec3(grove.x + 60.0, grove.y, grove.z))
ok = cb('gs_gangs:tag', 1, spot(61)); step()
check('limite par gang', not ok)
Config.Tags.maxPerGang = 15
-- Effacement par un rival
local id = GlobalState.gsTags[1].id
tp(2, vec3(grove.x + 1.0, grove.y, grove.z))
ok = cb('gs_gangs:eraseTag', 2, id); step()
check('tag effacé par un rival, influence retirée', ok and #GlobalState.gsTags == 0 and Gangs.territories.grove.influence.ballas == 0)
check('gang prévenu', W.notes[1] and W.notes[1].msg:find('effacé'))

-- Hommage peint (n° 170)
local money = { ballas = 500 }
Store.removeMoney = function(g, n) if (money[g] or 0) < n then return false end money[g] = money[g] - n return true end
Store.addMoney = function(g, n) money[g] = (money[g] or 0) + n return true end
local function memoAt(dx) tp(1, vec3(grove.x + dx, grove.y, grove.z)) return spot(dx) end
W.players[1].items.spraycan = 3
ok, msg = cb('gs_gangs:tag', 1, memoAt(100), 0.0, { name = ' ' }); step()
check('hommage : nom requis', not ok and msg:find('nom'))
ok, msg = cb('gs_gangs:tag', 1, memoAt(100), 0.0, { name = 'Tony', permanent = true }); step()
check('hommage permanent : caisse insuffisante', not ok and msg:find('caisse') and W.players[1].items.spraycan == 3 and money.ballas == 500)
ok = cb('gs_gangs:tag', 1, memoAt(100), 0.0, { name = 'Tony "Le Roc" Martinez de Grove Street' }); step()
local memo = GlobalState.gsTags[#GlobalState.gsTags]
check('hommage peint 24 h, texte tronqué, bombe utilisée', ok and memo.label == 'R.I.P. Tony "Le Roc" Martinez d' and W.players[1].items.spraycan == 2
    and tagRows[memo.id][3] and tagRows[memo.id][3] > os.time())
check('hommage : ni influence ni compte dans les tags', Gangs.territories.grove.influence.ballas == 0 and Extras.countTags('ballas') == 0)
money.ballas = 1500
ok = cb('gs_gangs:tag', 1, memoAt(140), 0.0, { name = 'Big Mo', permanent = true }); step()
local perm = GlobalState.gsTags[#GlobalState.gsTags]
check('hommage permanent payé par la caisse', ok and money.ballas == 500 and perm.label == 'R.I.P. Big Mo' and tagRows[perm.id][3] == nil)
W.players[1].items.spraycan = 0
money.ballas = 1500
ok, msg = cb('gs_gangs:tag', 1, memoAt(180), 0.0, { name = 'Lil Joe', permanent = true }); step()
check('pas de bombe : caisse remboursée', not ok and money.ballas == 1500)
W.players[1].items.spraycan = 3
Config.Tags.maxMemorials = 2
ok, msg = cb('gs_gangs:tag', 1, memoAt(180), 0.0, { name = 'Lil Joe' }); step()
check('hommage : limite par gang', not ok and msg:find('hommages'))
Config.Tags.maxMemorials = 5
Extras.expireMemorials(os.time() + 25 * 3600)
local left = {}
for _, t in ipairs(GlobalState.gsTags) do left[t.id] = true end
check('hommage 24 h effacé à l\'échéance, permanent conservé', not left[memo.id] and left[perm.id] and tagRows[memo.id] == nil)
tp(2, vec3(grove.x + 140.0, grove.y, grove.z))
W.notes[1] = nil
ok, msg = cb('gs_gangs:eraseTag', 2, perm.id); step()
check('hommage effacé par un rival : gang prévenu, influence intacte', ok and msg:find('Hommage') and W.notes[1] and W.notes[1].msg:find('hommage')
    and Gangs.territories.grove.influence.ballas == 0)
tp(2, grove)

-- Garage
tp(1, grove)
ok = cb('gs_gangs:garage', 1, 1); step()
check('garage : trop loin', not ok)
local g = Config.GangGarages.ballas.garage
tp(1, vec3(g.x, g.y, g.z))
ok = cb('gs_gangs:garage', 1, 1); step()
local veh = Extras.vehicles[1]
check('véhicule du gang sorti aux couleurs', ok and veh and W.entities[veh].paint == Config.GangGarages.ballas.paint)
ok = cb('gs_gangs:garage', 1, 2); step()
check('un seul véhicule à la fois', not ok)
ok = cb('gs_gangs:garageStore', 1); step()
check('véhicule rangé', ok and not W.entities[veh])
ok = cb('gs_gangs:garage', 3, 1); step()
check('civil : pas de garage', not ok)

-- Receleur
local f = Extras.fenceLocation()
tp(2, f)
check('receleur : grade requis', cb('gs_gangs:fenceInfo', 2) == nil)
tp(1, f)
local info = cb('gs_gangs:fenceInfo', 1); step()
check('receleur : lieu donné au chef', info and info.open)
W.players[1].items.weed_bag = 5
ok, msg = cb('gs_gangs:fenceSell', 1, 'weed'); step()
check('quantité minimum', not ok and msg:find('au moins'))
W.players[1].items.weed_bag = 80
fixRandom(0.0)
ok = cb('gs_gangs:fenceSell', 1, 'weed'); step()
fixRandom()
local unit = math.floor(95 * Config.Fence.bonus)
check('vente en gros plafonnée, argent sale', ok and W.players[1].items.weed_bag == 80 - Config.Fence.maxQty
    and W.players[1].items.black_money == unit * Config.Fence.maxQty and reports == 1)
hour = 14
ok, msg = cb('gs_gangs:fenceSell', 1, 'weed'); step()
check('fermé le jour', not ok and msg:find('nuit'))

-- Atelier de munitions artisanales ----------------------------------------------------------------------------
Gangs.list.ballas.stash = vec3(10.0, 10.0, 30.0)
tp(1, vec3(500.0, 500.0, 30.0))
ok, msg = cb('gs_gangs:craftBegin', 1, 'ammo-9'); step()
check('atelier : à la planque seulement', not ok and msg:find('planque'))
tp(1, Gangs.list.ballas.stash)
ok, msg = cb('gs_gangs:craftBegin', 1, 'ammo-9'); step()
check('atelier : matériaux requis', not ok and msg:find('ferraille'))
W.players[1].items.scrapmetal, W.players[1].items.copper = 20, 5
ok = cb('gs_gangs:craftBegin', 3, 'ammo-9'); step()
check('atelier : civil refusé', not ok)
ok = cb('gs_gangs:craftBegin', 1, 'ammo-9'); step()
ok, msg = cb('gs_gangs:craftFinish', 1); step()
check('atelier : durée réelle vérifiée', not ok)
ok = cb('gs_gangs:craftBegin', 1, 'ammo-9'); advance(15000)
ok, msg = cb('gs_gangs:craftFinish', 1); step()
check('munitions fabriquées', ok and W.players[1].items['ammo-9'] == 20 and W.players[1].items.scrapmetal == 14 and W.players[1].items.copper == 3)
Extras.craft.made.ballas.rounds = Config.AmmoCraft.dailyCap
ok, msg = cb('gs_gangs:craftBegin', 1, 'ammo-9'); step()
check('plafond journalier du gang', not ok and msg:find('assez'))

-- Flotte du gang
Config.GangGarages.ballas = Config.GangGarages.ballas or { garage = vec4(0.0, 0.0, 0.0, 0.0), paint = 145, vehicles = { 'chino' } }
ok, msg = cb('gs_gangs:setFleet', 2, { 'chino' }); step()
check('flotte : réservée au chef', not ok)
ok, msg = cb('gs_gangs:setFleet', 1, { 'adder' }); step()
check('flotte : modèle non autorisé', not ok)
ok, msg = cb('gs_gangs:setFleet', 1, { 'chino', 'chino', 'voodoo' }); step()
check('flotte : doublon refusé', not ok)
ok = cb('gs_gangs:setFleet', 1, { 'voodoo', 'manchez' }); step()
check('flotte appliquée et publiée', ok and GlobalState.gsGangGarages.ballas.vehicles[1] == 'voodoo')
ok, msg = cb('gs_gangs:setCustom', 1, 'faction3', 145, 300); step()
check('perso : couleur invalide', not ok)
ok = cb('gs_gangs:setCustom', 1, 'faction3', 145, 12); step()
check('perso enregistré', ok and GlobalState.gsGangGarages.ballas.custom.model == 'faction3' and Config.GangGarages.ballas.vehicles[2] == 'manchez')

-- V12.65 · Tags qui vivent : la pluie délave (pâlit puis efface), la mairie repeint les vieux tags des quartiers calmes
do
    local weather, level = 'CLEAR', 3
    provide('gs_weather', { GetGameTime = function() return hour, 0 end, GetWeather = function() return weather end })
    provide('gs_city', { GetLevel = function() return level, 'Grove' end })
    Extras.tags, Extras.wear = {}, {}
    Extras.tags[901] = { id = 901, gang = 'ballas', x = grove.x + 60.0, y = grove.y, z = grove.z, heading = 0.0 }
    Extras.tags[902] = { id = 902, gang = 'ballas', x = grove.x - 60.0, y = grove.y, z = grove.z, heading = 0.0, text = 'R.I.P. Tony', expires = os.time() + 9999 }
    Extras.weatherTags(os.time())
    check('tags : beau temps, rien ne bouge', Extras.tags[901] and Extras.wear[901].wear == 100)
    weather = 'RAIN'
    Extras.weatherTags(os.time())
    local a1
    for _, t in ipairs(GlobalState.gsTags) do if t.id == 901 then a1 = t.a end end
    check('tags : la pluie le délave (plus pâle)', Extras.wear[901].wear == 100 - Config.TagLife.rainWear and a1 and a1 < 235)
    for _ = 1, 20 do Extras.weatherTags(os.time()) end
    check('tags : assez de pluie = effacé, hommage intact', Extras.tags[901] == nil and Extras.tags[902] ~= nil)
    weather = 'CLEAR'
    Extras.tags[903] = { id = 903, gang = 'ballas', x = grove.x + 80.0, y = grove.y, z = grove.z, heading = 0.0 }
    Extras.wear[903] = { wear = 100, born = os.time() - Config.TagLife.calmHours * 3600 - 10 }
    fixRandom(0.0)
    Extras.weatherTags(os.time())
    check('tags : quartier tendu, la mairie n\'y touche pas', Extras.tags[903] ~= nil)
    level = 1
    Extras.weatherTags(os.time())
    fixRandom()
    check('tags : quartier calme, vieux tag repeint par la mairie', Extras.tags[903] == nil)
end

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
