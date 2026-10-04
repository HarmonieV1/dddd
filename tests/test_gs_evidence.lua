-- Tests gs_evidence (V8) : douilles, sang, empreintes (gants), pneus / peinture, fusion, vieillissement (pluie),
-- javel, lampe torche réservée à la police, scellé, labo (fiché / profil inconnu / liens), anti-abus.
dofile('tests/mock.lua')
local kvp, jstore = {}, {}
function SetResourceKvp(k, v) kvp[k] = v end
function GetResourceKvpString(k) return kvp[k] end
json.encode = function(t) local k = 'J' .. (#jstore + 1) jstore[#jstore + 1] = t return k end
json.decode = function(s) if s == 'null' or s == '[]' then return s == '[]' and {} or nil end return jstore[tonumber(s:sub(2))] end
local R = 'server/resources/[gtasoon]/'
local duty, weather = {}, 'CLEAR'
provide('gs_jobs', { IsOnDutyAs = function(src, job) return job == 'police' and duty[src] == true end, GetOnDutyPlayers = function() return {} end })
provide('gs_weather', { GetWeather = function() return weather end })
provide('gs_wanted', { ColorName = function(i) return i == 64 and 'bleu' or nil end, Describe = function(src) return 'Homme, masqué' end })
provide('gs_rumors', { Zone = function() return 'Vespucci' end })
local weapon = { label = 'Pistolet', name = 'WEAPON_PISTOL', metadata = { serial = 'AB123', registered = 'Jean Tireur' } }
provide('ox_inventory', { GetCurrentWeapon = function() return weapon end })
function GetVehicleBodyHealth(veh) return W.entities[veh].body or 1000 end
local filed = {}
Store = { init = function() end, filed = function(cid) return filed[cid] end, file = function(cid, name) filed[cid] = name end }
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_evidence', { R .. 'gs_evidence/shared/config.lua', R .. 'gs_evidence/server/main.lua', R .. 'gs_evidence/server/photo.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function count(kind) local n = 0 for _, t in pairs(Evidence.traces) do if not kind or t.kind == kind then n = n + 1 end end return n end

local scene = vec3(100.0, 100.0, 30.0)
join(1, 'CID1', 'Jean Tireur', scene)
join(2, 'CID2', 'Agent Deux', vec3(102.0, 100.0, 30.0))
duty[2] = true

-- Douilles ------------------------------------------------------------------------------------------------------
net('gs_evidence:server:shot', 1)
check('sans arme : pas de douille', count('casing') == 0)
W.players[1].weapon = joaat('WEAPON_PISTOL')
advance(2000) net('gs_evidence:server:shot', 1)
check('tir : douille au sol avec arme et série', count('casing') == 1)
advance(2000) net('gs_evidence:server:shot', 1)
local c1 for _, t in pairs(Evidence.traces) do if t.kind == 'casing' then c1 = t end end
check('2e tir au même endroit : fusionné (×2)', count('casing') == 1 and c1.n == 2)
net('gs_evidence:server:shot', 1)
check('spam de tirs limité', c1.n == 2)
W.players[2].weapon = joaat('WEAPON_PISTOL')
net('gs_evidence:server:shot', 2)
check('policier en service : pas de douille', count('casing') == 1)

-- Sang -------------------------------------------------------------------------------------------------------------
net('gs_evidence:server:hurt', 1)
check('pas blessé : pas de sang', count('blood') == 0)
W.entities = W.entities or {}
local realHealth = GetEntityHealth
GetEntityHealth = function(ent) if ent == 1001 then return 150 end return realHealth(ent) end
advance(16000) net('gs_evidence:server:hurt', 1)
check('blessé : sang au sol', count('blood') == 1)
GetEntityHealth = realHealth

-- Crime : empreintes (gants), pneus, peinture ---------------------------------------------------------------------
local car = CreateVehicleServerSetter(0, 'automobile', scene.x, scene.y, scene.z)
SetVehicleNumberPlateText(car, 'RL4X2201')
W.entities[car].color, W.entities[car].body = 64, 700
TriggerEvent('gs_wanted:server:crime', 1, 'store_robbery', scene, car)
check('braquage sans gants : empreintes', count('print') == 1)
check('véhicule : pneus et peinture (carrosserie abîmée)', count('tyre') == 1 and count('paint') == 1)
W.players[1].items.gs_gloves = 1
check('gants : enfilés', select(1, cb('gs_evidence:gloves', 1)) == true and W.pstate[1].gsGloves == true)
TriggerEvent('gs_wanted:server:crime', 1, 'store_robbery', vec3(300.0, 300.0, 30.0))
check('avec gants : aucune empreinte', count('print') == 1)
W.players[1].items.gs_gloves = 0
TriggerEvent('gs_wanted:server:crime', 1, 'store_robbery', vec3(300.0, 300.0, 30.0))
check('gants jetés (plus dans l\'inventaire) : empreintes de nouveau', count('print') == 2)
TriggerEvent('gs_wanted:server:crime', 1, 'gunshot', vec3(500.0, 500.0, 30.0))
check('tir seul : pas d\'empreinte', count('print') == 2)

-- Lampe torche : police seulement ---------------------------------------------------------------------------------------
check('civil : rien de visible', #cb('gs_evidence:nearby', 1) == 0)
local seen = cb('gs_evidence:nearby', 2)
check('police : traces visibles autour', #seen >= 5)

-- Scellé -------------------------------------------------------------------------------------------------------------------
local blood for _, t in pairs(Evidence.traces) do if t.kind == 'blood' then blood = t end end
tp(2, vec3(150.0, 100.0, 30.0))
local ok, msg = cb('gs_evidence:collect', 2, blood.id)
check('scellé : refusé de loin', not ok)
tp(2, vec3(101.0, 100.0, 30.0))
check('scellé : refusé aux civils', not cb('gs_evidence:collect', 1, blood.id))
ok, msg = cb('gs_evidence:collect', 2, blood.id)
check('scellé : objet donné, trace retirée', ok and W.players[2].items.evidence_bag == 1 and Evidence.traces[blood.id] == nil)

-- Labo --------------------------------------------------------------------------------------------------------------------
local ok2, d = cb('gs_evidence:lab', 2, 'list')
check('labo : refusé hors du labo', not ok2)
tp(2, Config.Lab.coords)
ok2, d = cb('gs_evidence:lab', 2, 'list')
check('labo : mes scellés listés', ok2 and #d.mine == 1)
local sealId = d.mine[1].id
check('labo : analyse lancée (scellé consommé)', cb('gs_evidence:lab', 2, 'analyze', sealId) == true and W.players[2].items.evidence_bag == 0)
ok2, d = cb('gs_evidence:lab', 2, 'list')
check('analyse en cours', d.results[1].status == 'analyzing')
advance(Config.Lab.seconds * 1000 + 1000)
ok2, d = cb('gs_evidence:lab', 2, 'list')
check('personne non fichée : profil inconnu (pas de nom)', d.results[1].status == 'done' and d.results[1].result:find('Profil inconnu P%-') and not d.results[1].result:find('Jean'))
check('même personne = même profil', Evidence.profile('CID1') == Evidence.profile('CID1') and Evidence.profile('CID1') ~= Evidence.profile('CID2'))

-- Fichage puis nouvelle analyse : nom + lien entre scellés
Evidence.file('CID1', 'Jean Tireur')
local pr for _, t in pairs(Evidence.traces) do if t.kind == 'print' then pr = t break end end
tp(2, pr.coords)
check('2e scellé (empreintes)', cb('gs_evidence:collect', 2, pr.id) == true)
tp(2, Config.Lab.coords)
ok2, d = cb('gs_evidence:lab', 2, 'list')
cb('gs_evidence:lab', 2, 'analyze', d.mine[1].id)
advance(Config.Lab.seconds * 1000 + 1000)
ok2, d = cb('gs_evidence:lab', 2, 'list')
local res = d.results[1].result
check('personne fichée : nommée', res:find('Jean Tireur %(fiché%)'))
check('lien avec le premier scellé', res:find('même origine que les scellés n°' .. sealId))

-- Douille : arme, série, propriétaire
for _, t in pairs(Evidence.traces) do if t.kind == 'casing' then c1 = t end end
tp(2, c1.coords) cb('gs_evidence:collect', 2, c1.id) tp(2, Config.Lab.coords)
ok2, d = cb('gs_evidence:lab', 2, 'list') cb('gs_evidence:lab', 2, 'analyze', d.mine[1].id)
advance(Config.Lab.seconds * 1000 + 1000)
ok2, d = cb('gs_evidence:lab', 2, 'list')
check('douille : arme, série et propriétaire enregistré', d.results[1].result:find('Pistolet') and d.results[1].result:find('AB123') and d.results[1].result:find('Jean Tireur'))
check('analyser le scellé d\'un autre / déjà analysé : refusé', not cb('gs_evidence:lab', 2, 'analyze', sealId))

-- Javel ----------------------------------------------------------------------------------------------------------------------
local before = count()
tp(1, scene)
check('javel : refusée sans objet', not cb('gs_evidence:clean', 1))
W.players[1].items.gs_bleach = 1
advance(13000)
check('javel : traces autour effacées', cb('gs_evidence:clean', 1) == true and count() < before and W.players[1].items.gs_bleach == 0)

-- Vieillissement : plus rapide sous la pluie -----------------------------------------------------------------------------
Evidence.traces, Evidence.count = {}, 0
Evidence.add('blood', scene, { key = 'X', cid = 'X' })
Evidence.add('print', vec3(900.0, 0.0, 0.0), { key = 'X', cid = 'X' })
advance(15 * 60000) Evidence.decay()
check('15 min au sec : le sang reste', count('blood') == 1)
weather = 'RAIN'
Evidence.decay()
check('sous la pluie : le sang est lavé, les empreintes restent', count('blood') == 0 and count('print') == 1)
weather = 'CLEAR'
advance(61 * 60000) Evidence.decay()
check('empreintes effacées avec le temps', count() == 0)

-- V9 · Appareil photo argentique
do
    join(70, 'CID70', 'Photographe', vec3(0.0, 0.0, 0.0))
    join(71, 'CID71', 'Sujet', vec3(-10.0, 0.0, 0.0))   -- devant l'objectif (cap 90° : vers -x)
    join(72, 'CID72', 'Derrière', vec3(10.0, 0.0, 0.0))
    check('photo : appareil requis', not Photo.take(70))
    W.players[70].items.gs_camera = 1
    local ok = Photo.take(70, 'https://img.example/p.jpg')
    check('photo développée (objet)', ok and W.players[70].items.gs_photo == 1)
    local id
    for k, v in pairs(kvp) do if k:match('^gs_photo:') then id = k:sub(10) end end
    local r = Photo.get(id)
    check('seul le joueur devant l\'objectif est sur la photo', r and #r.subjects == 1 and r.subjects[1].cid == 'CID71' and r.place == 'Vespucci')
    -- labo : profil inconnu puis nom une fois fiché
    tp(2, Config.Lab.coords)
    local ok2, out = Photo.analyze(2, id)
    check('labo : description + profil (non fiché)', ok2 and out[1]:find('profil P%-'))
    Evidence.file('CID71', 'Sujet Fiché')
    ok2, out = Photo.analyze(2, id)
    check('labo : nommé une fois fiché', ok2 and out[1]:find('Sujet Fiché'))
    check('labo : réservé à la police', not Photo.analyze(70, id))
    -- accrocher / décrocher
    check('accrochée au mur (texte et image relus côté serveur, pas ceux du client)', Photo.hang(70, { photo = id, label = 'FAUX', description = 'truqué', image = 'https://evil/x.png' }) == true
        and #GlobalState.gsWallPhotos == 1 and W.players[70].items.gs_photo == 0 and GlobalState.gsWallPhotos[1].label ~= 'FAUX' and GlobalState.gsWallPhotos[1].image == nil)
    check('décrocher : seulement l\'auteur', not Photo.unhang(71, 1))
    check('décrochée : rendue', Photo.unhang(70, 1) == true and W.players[70].items.gs_photo == 1 and #GlobalState.gsWallPhotos == 0)
end

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
