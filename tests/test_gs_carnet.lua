-- Tests gs_carnet (V8) : véhicules de joueurs seulement, kilomètres (anti-téléportation), accident, changement de
-- propriétaire, repeinte, crime (police seulement), consultation civile limitée au véhicule où l'on est.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local duty = {}
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end })
provide('gs_wanted', { ColorName = function(c) return ({ [64] = 'bleu', [27] = 'rouge' })[c] end, CrimeLabel = function() return 'Braquage' end })
function GetVehicleBodyHealth(veh) return W.entities[veh].body or 1000.0 end
local rows, events = {}, {}
Store = { init = function() end, get = function(p) return rows[p] end, save = function(r) rows[r.plate] = r end,
    event = function(p, k, t, pol) events[#events + 1] = { plate = p, kind = k, text = t, police = pol and 1 or 0 } end,
    events = function(p, pol) local l = {} for i = #events, 1, -1 do local e = events[i] if e.plate == p and (pol or e.police == 0) then l[#l + 1] = e end end return l end }
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_carnet', { R .. 'gs_carnet/shared/config.lua', R .. 'gs_carnet/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function kinds(k) local n = 0 for _, e in ipairs(events) do if e.kind == k then n = n + 1 end end return n end

W.owners = { RLCARNET = 'CID1' }
join(1, 'CID1', 'Proprio', vec3(0.0, 0.0, 0.0))
local car = CreateVehicleServerSetter(0, 'automobile', 0.0, 0.0, 0.0)
SetVehicleNumberPlateText(car, 'RLCARNET') W.entities[car].color = 64
local stolen = CreateVehicleServerSetter(0, 'automobile', 0.0, 0.0, 0.0)
SetVehicleNumberPlateText(stolen, 'PNJ00001')
Carnet.sample(stolen)
check('véhicule PNJ : pas de carnet', rows.PNJ00001 == nil)

Carnet.sample(car)
W.entities[car].pos = vec3(1500.0, 0.0, 0.0)
Carnet.sample(car)
check('1,5 km comptés', math.abs(rows.RLCARNET.km - 1.5) < 0.01)
W.entities[car].pos = vec3(9000.0, 0.0, 0.0)
Carnet.sample(car)
check('téléportation : pas comptée', math.abs(rows.RLCARNET.km - 1.5) < 0.01)
W.entities[car].body = 600.0
Carnet.sample(car)
check('accident noté', kinds('accident') == 1)
W.entities[car].color = 27
Carnet.sample(car)
check('repeinte notée (bleu → rouge)', kinds('paint') == 1 and events[#events].text:find('bleu → rouge'))
W.owners.RLCARNET = 'CID2'
Carnet.sample(car)
check('changement de propriétaire (2e main)', kinds('owner') == 1 and rows.RLCARNET.owners == 2)
TriggerEvent('gs_wanted:server:crime', 1, 'robbery', vec3(0.0, 0.0, 0.0), car)
check('crime noté pour la police', kinds('crime') == 1 and events[#events].police == 1)

local pub = Carnet.view('RLCARNET', false)
local pol = Carnet.view('RLCARNET', true)
check('historique public : sans les crimes', #pub.events == 3 and #pol.events == 4)
check('consultation civile : hors véhicule refusée', cb('gs_carnet:view', 1, 'RLCARNET') == nil)
W.players[1].vehicle = car
check('consultation civile : le véhicule où il est', cb('gs_carnet:view', 1, 'AUTRE').plate == 'RLCARNET')
duty[1] = 'police' W.players[1].vehicle = nil
advance(6000)
check('police : n\'importe quelle plaque, crimes compris', #cb('gs_carnet:view', 1, 'RLCARNET').events == 4)

-- V8 · Fausses plaques
do
    duty[1] = nil
    W.players[1].pos = vec3(9000.0, 0.0, 0.0)
    W.entities[car].pos = vec3(9001.0, 0.0, 0.0)
    advance(11000)
    check('fausse plaque : objet requis', not Carnet.fakePlate(1, car))
    W.players[1].items.gs_fakeplate = 1
    local st = SetTimeout SetTimeout = function() end -- (le retour auto de la vraie plaque est différé en jeu)
    local ok = Carnet.fakePlate(1, car)
    SetTimeout = st
    local fake = GetVehicleNumberPlateText(car)
    check('fausse plaque posée (vraie plaque gardée en mémoire)', ok and fake ~= 'RLCARNET' and #fake == 8 and Entity(car).state.gsRealPlate == 'RLCARNET')
    check('fausse plaque : plus de carnet', Carnet.view(fake, true) == nil)
    advance(11000)
    check('retirée : vraie plaque et objet rendus', Carnet.fakePlate(1, car) == true and GetVehicleNumberPlateText(car) == 'RLCARNET'
        and W.players[1].items.gs_fakeplate == 1 and Entity(car).state.gsRealPlate == nil)
    W.players[1].pos = vec3(0.0, 0.0, 0.0)
    advance(11000)
    check('trop loin du véhicule', not Carnet.fakePlate(1, car))
end

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
