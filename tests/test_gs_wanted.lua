-- Tests gs_wanted : témoins, heure, météo, précision, chaleur, anti-abus.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local duty = {}          -- [src] = true si policier en service
local weather = { type = 'CLEAR', hour = 14, blackout = false }
provide('gs_jobs', {
    IsOnDutyAs = function(src, job) return job == 'police' and duty[src] == true end,
    GetOnDutyPlayers = function() local l = {} for s in pairs(duty) do l[#l + 1] = s end return l end,
})
provide('gs_weather', {
    GetGameTime = function() return weather.hour, 0, 0 end,
    GetWeather = function() return weather.type end,
    IsBlackout = function() return weather.blackout end,
})
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_wanted', { R .. 'gs_wanted/shared/config.lua', R .. 'gs_wanted/server/memory.lua', R .. 'gs_wanted/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(21000) end

local street = vec3(200.0, -800.0, 30.0)
join(1, 'CID1', 'Suspect Un', street)
join(2, 'CID2', 'Agent Deux', vec3(5000.0, 5000.0, 0.0))
join(3, 'CID3', 'Passant Trois', vec3(5000.0, 5000.0, 0.0))
duty[2] = true

-- Visibilité -------------------------------------------------------------------------------------
check('jour clair = 1.0', Wanted.visibility() == 1.0)
weather.hour = 23
check('nuit réduit', Wanted.visibility() < 1.0)
weather.type, weather.blackout = 'FOGGY', true
local worst = Wanted.visibility()
check('nuit + brouillard + blackout très faible', worst < 0.25)
weather.hour, weather.type, weather.blackout = 14, 'CLEAR', false

-- Témoins ----------------------------------------------------------------------------------------------
spawnPeds(street, 4)
local n, police = Wanted.witnesses(street, 1)
check('4 PNJ témoins', n == 4 and not police)
tp(3, street)
n = Wanted.witnesses(street, 1)
check('joueur proche = témoin, suspect exclu', n == 5)
tp(3, vec3(5000.0, 5000.0, 0.0))
clearPeds()

-- Probabilités (tirage forcé) -----------------------------------------------------------------------
fixRandom(0.5)
check('sans témoin, vol discret non signalé (15 %)', Wanted.report(1, 'carjack', street) == nil)
spawnPeds(street, 4)
check('4 témoins : signalé (15 % + 48 %)', Wanted.report(1, 'carjack', street) ~= nil)
check('chaleur ajoutée', Wanted.heat[1] == Config.Crimes.carjack.heat)
Wanted.clearHeat(1)
weather.hour, weather.type = 23, 'FOGGY'
check('même scène de nuit dans le brouillard : pas signalé', Wanted.report(1, 'carjack', street) == nil)
weather.hour, weather.type = 14, 'CLEAR'
fixRandom(0.3)
Memory.list = {} -- (même tenue que les crimes précédents = reconnu : on teste ici le silencieux seul)
check('tir silencieux moins signalé', Wanted.report(1, 'gunshot', street, { silenced = true }) == nil)
check('tir normal signalé', Wanted.report(1, 'gunshot', street) ~= nil)
check('crime inconnu ignoré', Wanted.report(1, 'nimporte', street) == nil)

-- Policier témoin : signalement certain et précis ----------------------------------------------------------
fixRandom(0.99)
tp(2, vec3(street.x + 30.0, street.y, street.z))
clearPeds()
local r = Wanted.report(1, 'assault', street)
check('policier à portée : signalé malgré tirage défavorable', r ~= nil and r.witnesses == -1)
check('policier à portée : zone précise, sans délai', r and r.radius == Config.Precision.blurMin and r.delay == 0)
check('dispatch reçu par la police', lastClientEvent('gs_wanted:client:dispatch', 2) ~= nil)
tp(2, vec3(5000.0, 5000.0, 0.0))

-- Précision et plaque -------------------------------------------------------------------------------------
fixRandom(0.0)
local car = CreateVehicleServerSetter(0, 'automobile', street.x, street.y, street.z)
SetVehicleNumberPlateText(car, 'GSOON123')
r = Wanted.report(1, 'carjack', street, { vehicle = car })
check('témoin unique : plaque partielle', r and r.plate and r.plate:find('%*') ~= nil and #r.plate == 8)
check('zone floue sans témoin', r and r.radius > 100)
spawnPeds(street, 8)
r = Wanted.report(1, 'carjack', street, { vehicle = car })
check('beaucoup de témoins : zone plus précise', r and r.radius < 100)
clearPeds()
fixRandom()

-- Zone sûre -------------------------------------------------------------------------------------------------
fixRandom(0.0)
check('stand de tir : jamais signalé', Wanted.report(1, 'gunshot', Config.SafeZones[1].coords) == nil)
fixRandom()

-- Chaleur : plafond, décroissance ----------------------------------------------------------------------------
Wanted.clearHeat(1)
for _ = 1, 20 do Wanted.addHeat(1, 30) end
check('chaleur plafonnée', Wanted.heat[1] == Config.Heat.max)
Wanted.decay()
check('pas de baisse juste après un signalement', Wanted.heat[1] == Config.Heat.max)
advance(Config.Heat.quietMinutes * 60000 + 1000)
Wanted.decay()
check('baisse ensuite', Wanted.heat[1] == Config.Heat.max - Config.Heat.decayPerMinute)
for _ = 1, 60 do Wanted.decay() end
check('retour à zéro', Wanted.heat[1] == nil)
check('étoiles mises à jour côté client', lastClientEvent('gs_wanted:client:heat', 1).args[1] == 0)

-- Events réseau : anti-abus ------------------------------------------------------------------------------------
fixRandom(0.0)
spawnPeds(street, 3)
net('gs_wanted:server:shot', 1, false)
check('tir sans arme en main ignoré', Wanted.heat[1] == nil)
step()
W.players[1].weapon = joaat('WEAPON_PISTOL')
net('gs_wanted:server:shot', 1, false)
check('tir avec arme signalé', (Wanted.heat[1] or 0) > 0)
local h = Wanted.heat[1]
net('gs_wanted:server:shot', 1, false)
check('spam de tirs limité', Wanted.heat[1] == h)
step()
W.players[2].weapon = joaat('WEAPON_PISTOL')
tp(2, street)
net('gs_wanted:server:shot', 2, false)
check('policier en service qui tire : pas signalé', Wanted.heat[2] == nil)
check('historique dispatch pour la police', #cb('gs_wanted:history', 2) > 0)
check('historique refusé aux civils', #cb('gs_wanted:history', 3) == 0)
fixRandom()

-- Police IA : aucun policier joueur en service → étoiles du jeu sur le suspect ------------------------------------
fixRandom(0.0)
local savedDuty = duty
duty = {}
W.clientEvents = {}
Wanted.report(1, 'bank', street, { alarm = true })
local npc = lastClientEvent('gs_wanted:client:npcPolice', 1)
check('sans policier : police IA déclenchée', npc ~= nil and npc.args[1] == 4)
check('étoiles selon la gravité', Wanted.npcStars(8) == 1 and Wanted.npcStars(30) == 2 and Wanted.npcStars(45) == 3)
duty = savedDuty
W.clientEvents = {}
Wanted.report(1, 'bank', street, { alarm = true })
check('policier en service : pas de police IA', lastClientEvent('gs_wanted:client:npcPolice', 1) == nil)
fixRandom()

-- Nettoyage à la déconnexion -------------------------------------------------------------------------------------
TriggerEvent('gs_bridge:server:playerUnloaded', 1)
check('chaleur nettoyée', Wanted.heat[1] == nil)

-- Caméras de surveillance : signalement quasi certain, zone précise, plaque lisible, panne
do
    local cam = Config.Cameras.list[1]
    local at = vec3(cam.coords.x + 5.0, cam.coords.y, cam.coords.z)
    join(7, 'CID7', 'Filmé', at)
    clearPeds()
    Wanted.blind = {}
    fixRandom(0.45) -- sans caméra : 0,15 de base → pas signalé
    check('sans caméra, vol discret non signalé', Wanted.report(7, 'carjack', vec3(3000.0, 3000.0, 30.0)) == nil)
    local car3 = CreateVehicleServerSetter(0, 'automobile', at.x, at.y, at.z)
    SetVehicleNumberPlateText(car3, 'GSOON999')
    local r2 = Wanted.report(7, 'carjack', at, { vehicle = car3 })
    check('sous caméra : signalé, caméra nommée', r2 and r2.camera == cam.label)
    check('sous caméra : plaque presque entière et zone précise', r2 and r2.plate:sub(1, 6) == 'GSOON9' and r2.radius < 100)
    check('preuve vidéo : caméra, plaque, sans identité', Wanted.evidence[1] and Wanted.evidence[1].camera == cam.label and Wanted.evidence[1].plate and Wanted.evidence[1].cid == nil)
    Wanted.blindCameras(at, 60.0, 600)
    check('caméra aveuglée : de nouveau discret', Wanted.report(7, 'carjack', at) == nil)
    Wanted.blind = {}
    fixRandom(nil)
end

-- V8 · La ville se souvient : description brute, mémoire des tenues et véhicules, visage connu ------------------------
do
    local spot = vec3(-500.0, -500.0, 30.0)
    join(8, 'CID8', 'Masque Rouge', spot)
    W.players[8].clothes = { [1] = { 12, 0 }, [11] = { 5, 1 }, [4] = { 3, 0 }, [6] = { 1, 0 }, [5] = { 40, 0 } }
    W.players[8].props = { [0] = 4 }
    W.players[8].weapon = joaat('WEAPON_PISTOL')
    local car8 = CreateVehicleServerSetter(0, 'automobile', spot.x, spot.y, spot.z)
    SetVehicleNumberPlateText(car8, '4XRL8801')
    W.entities[car8].color = 64 -- bleu
    clearPeds() spawnPeds(spot, 8)
    fixRandom(0.0)
    local r8 = Wanted.report(8, 'robbery', spot, { vehicle = car8 })
    local d = r8 and table.concat(r8.desc, ', ') or ''
    check('description brute : sexe, masque, arme, véhicule et couleur', d:find('Homme') and d:find('masqué') and d:find('armé') and d:find('Voiture %(bleu%)'))
    check('jamais le nom d\'un inconnu', r8 and r8.named == nil and not d:find('Masque Rouge'))
    check('mémoire enregistrée', Memory.list['CID8'] and #Memory.list['CID8'] == 1)
    check('premier signalement : pas de lien', r8 and r8.linked == nil)

    -- même tenue → reconnu (lien vers le signalement précédent), même sans véhicule
    clearPeds()
    fixRandom(0.3) -- sans témoin, agression (20 %) : normalement pas signalée
    local r9 = Wanted.report(8, 'assault', spot)
    check('même tenue : reconnu et signalé malgré l\'absence de témoin', r9 and r9.linked == r8.id and r9.linkedBy == 'tenue')

    -- changement de tenue mais même voiture (plaque + couleur) → reconnu par le véhicule
    W.players[8].clothes[11] = { 99, 0 }
    local r10 = Wanted.report(8, 'assault', spot, { vehicle = car8 })
    check('autre tenue, même voiture : reconnu par le véhicule', r10 and r10.linkedBy == 'véhicule')

    -- autre tenue + voiture repeinte → la piste est brouillée
    W.players[8].clothes[4] = { 50, 0 }
    W.entities[car8].color = 27 -- rouge
    check('tenue changée et voiture repeinte : piste brouillée', Wanted.report(8, 'assault', spot, { vehicle = car8 }) == nil)

    -- la ville oublie
    W.players[8].clothes[4] = { 3, 0 } W.players[8].clothes[11] = { 5, 1 }
    advance(Config.Memory.hours * 3600 * 1000 + 1000)
    Memory.forget()
    check('la ville oublie après le délai', Memory.list['CID8'] == nil)

    -- précision faible : peu de détails
    fixRandom(0.0)
    weather.hour, weather.type = 23, 'FOGGY'
    local r11 = Wanted.report(8, 'bank', vec3(4000.0, 4000.0, 30.0), { alarm = true })
    check('alarme de nuit : description présente', r11 and #r11.desc >= 1)
    weather.hour, weather.type = 14, 'CLEAR'
    Wanted.blind = {}

    -- visage connu : célèbre et à visage découvert → nommé ; masqué → jamais
    provide('gs_reputation', { Get = function() return { street = 0, legal = 0, media = 800 } end })
    W.players[8].clothes[1] = { 0, 0 }
    spawnPeds(spot, 8)
    local r12 = Wanted.report(8, 'robbery', spot)
    check('visage connu : un témoin le reconnaît', r12 and r12.named == 'Masque Rouge')
    W.players[8].clothes[1] = { 12, 0 }
    local r13 = Wanted.report(8, 'robbery', spot)
    check('visage connu mais masqué : pas nommé', r13 and r13.named == nil)
    provide('gs_reputation', { Get = function() return { street = 0, legal = 0, media = 0 } end })
    check('couleurs GTA → mots', Memory.colorName(0) == 'noir' and Memory.colorName(64) == 'bleu' and Memory.colorName(111) == 'blanc' and Memory.colorName(999) == nil)
    clearPeds()
    fixRandom(nil)
end

-- V8 · Signes distinctifs (tatouages visibles selon la tenue)
do
    json.decode = function() return { tattoos = { ZONE_HEAD = { { 'x' } }, ZONE_LEFT_ARM = { { 'y' } }, ZONE_TORSO = {} } } end
    local m = Memory.parseTattoos('{}')
    check('tatouages lus : visage et bras (torse vide ignoré)', m.head and m.arms and not m.torso)
    Memory.marks[8] = m
    local spot = vec3(-700.0, -700.0, 30.0)
    W.players[8].pos = spot
    W.players[8].clothes = { [1] = { 0, 0 }, [3] = { 0, 0 }, [11] = { 5, 1 } }
    W.players[8].props = {}
    clearPeds() spawnPeds(spot, 8) fixRandom(0.0) Memory.list = {}
    local r = Wanted.report(8, 'robbery', spot)
    local d = r and table.concat(r.desc, ', ') or ''
    check('bras nus et visage découvert : tatouages décrits', d:find('tatouage au visage') and d:find('bras tatoués'))
    W.players[8].clothes[1] = { 12, 0 } W.players[8].clothes[3] = { 4, 0 }
    r = Wanted.report(8, 'robbery', spot)
    d = r and table.concat(r.desc, ', ') or ''
    check('masque et manches longues : tatouages cachés', not d:find('tatou'))
    clearPeds() fixRandom(nil)
end

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
