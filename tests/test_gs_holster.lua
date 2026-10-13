-- Tests gs_details · armes dans le dos (V12.37, client simulé) : choix des armes affichées (longues seulement, pistolets
-- et armes blanches exclus, arme en main exclue par emplacement puis par hash, 2 max, ordre stable), comparaison de
-- listes, pas de réglage (±1 cm / ±2°, arrondis, bornes), bloc Config.Back prêt à coller ; puis le comportement complet :
-- state bag publié / vidé (arme en main, arme retirée du sac, mort, réapparition), objets toujours attachés au ped actuel
-- (changement de ped), attache ratée ou modèle absent = aucun objet libre, voisins (state bag immédiat, distance, mort,
-- départ du réseau, balayage des orphelins), arrêt de la ressource, /dosreglage (staff seulement, réglage, copie du bloc).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'

-- Natives client manquantes au mock serveur --------------------------------------------------------------------------
joaat = function(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end return h end
GetHashKey = joaat
cache = { ped = 1001 }
LocalPlayer = Player(1)
function PlayerId() return 1 end
function GetPlayerServerId(pid) return pid end
function GetPlayerFromServerId(sid) if W.players[sid] then return sid end return -1 end
function GetPlayerPed(pid) local p = W.players[pid] if not p then return 0 end return p.ped or (1000 + pid) end
function GetActivePlayers() local l = {} for s in pairs(W.players) do l[#l + 1] = s end table.sort(l) return l end
function IsEntityDead(ent) local e = W.entities[ent] return e ~= nil and e.dead == true end
function GetPedBoneIndex(ped, bone) local e = W.entities[ped] if e and e.nobone then return -1 end return bone end
W.unloaded = {}
function HasWeaponAssetLoaded(hash) return not W.unloaded[hash] end
function RequestWeaponAsset() end
function CreateWeaponObject(hash, _, x, y, z)
    if W.failCreate then return 0 end
    W.nextEntity = W.nextEntity + 1
    W.entities[W.nextEntity] = { type = 3, pos = vec3(x, y, z), model = hash }
    return W.nextEntity
end
function AttachEntityToEntity(obj, ped, bone, x, y, z, rx, ry, rz)
    local e = W.entities[obj]
    if not e or W.failAttach then return end
    e.attached, e.bone, e.off = ped, bone, { x = x, y = y, z = z, rx = rx, ry = ry, rz = rz }
    W.attachCalls = (W.attachCalls or 0) + 1
end
function IsEntityAttachedToEntity(obj, ped) local e = W.entities[obj] return e ~= nil and e.attached == ped and W.entities[ped] ~= nil end
function IsEntityAttached(obj) local e = W.entities[obj] return e ~= nil and e.attached ~= nil and W.entities[e.attached] ~= nil end
function DetachEntity(obj) local e = W.entities[obj] if e then e.attached = nil end end
function SetEntityCollision() end
function SetEntityAsMissionEntity() end
function IsNuiFocused() return false end
W.ui = { notes = {}, contexts = {}, open = nil, clipboard = nil, input = nil }
lib.onCache = function(key, fn) W.onCache = W.onCache or {} W.onCache[key] = fn end
lib.notify = function(d) W.ui.notes[#W.ui.notes + 1] = d end
lib.registerContext = function(c) W.ui.contexts[c.id] = c end
lib.showContext = function(id) W.ui.open = id end
lib.hideContext = function() W.ui.open = nil end
lib.getOpenContextMenu = function() return W.ui.open end
lib.setClipboard = function(t) W.ui.clipboard = t end
lib.inputDialog = function() return W.ui.input end

-- Inventaire ox_inventory simulé : [slot] = { name } ---------------------------------------------------------------------
local inv = {}
provide('ox_inventory', { GetPlayerItems = function() return inv end })

loadResource('gs_details', { R .. 'gs_details/shared/config.lua', R .. 'gs_details/client/holster.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function objs(ped) -- objets d'arme (type 3) existants, filtrés par ped d'attache si donné
    local n, attached = 0, 0
    for _, e in pairs(W.entities) do
        if e.type == 3 then n = n + 1 if ped and e.attached == ped then attached = attached + 1 end end
    end
    return n, attached
end
local function on(ped) return select(2, objs(ped)) end -- objets attachés à ce ped (le mien compris dans objs())
local H = { pump = joaat('WEAPON_PUMPSHOTGUN'), carbine = joaat('WEAPON_CARBINERIFLE'), smg = joaat('WEAPON_SMG'),
    pistol = joaat('WEAPON_PISTOL'), knife = joaat('WEAPON_KNIFE'), sniper = joaat('WEAPON_HEAVYSNIPER') }

-- 1. Choix des armes affichées --------------------------------------------------------------------------------------
local items = { [1] = { name = 'WEAPON_PISTOL' }, [3] = { name = 'WEAPON_CARBINERIFLE' }, [5] = { name = 'bread' },
    [7] = { name = 'WEAPON_KNIFE' }, [9] = { name = 'WEAPON_PUMPSHOTGUN' }, [12] = { name = 'WEAPON_SMG' } }
local list = Holster.pick(items, nil, 2)
check('2 armes longues max, pistolet et couteau exclus', #list == 2 and list[1] == H.carbine and list[2] == H.pump)
check('ordre stable (par emplacement) quel que soit l\'ordre de parcours', Holster.same(Holster.pick(items, nil, 2), list))
check('3 affichables si max = 3', #Holster.pick(items, nil, 3) == 3)
check('arme en main exclue par son emplacement', Holster.same(Holster.pick(items, { slot = 3, hash = H.carbine }, 2), { H.pump, H.smg }))
check('arme en main exclue par hash si emplacement inconnu', Holster.same(Holster.pick(items, { hash = H.pump }, 2), { H.carbine, H.smg }))
check('deux fois la même arme : une seule exclue', #Holster.pick({ { name = 'WEAPON_SMG' }, { name = 'WEAPON_SMG' } }, { hash = H.smg }, 2) == 1)
check('nom en minuscules toléré', Holster.pick({ { name = 'weapon_heavysniper' } }, nil, 2)[1] == H.sniper)
check('inventaire absent ou objets sans nom : rien', #Holster.pick(nil, nil, 2) == 0 and #Holster.pick({ {}, false, 'x' }, nil, 2) == 0)
check('pistolets seuls : rien dans le dos', #Holster.pick({ { name = 'WEAPON_PISTOL' }, { name = 'WEAPON_COMBATPISTOL' }, { name = 'WEAPON_APPISTOL' } }, nil, 2) == 0)
check('same : longueur, contenu, ordre', Holster.same({}, {}) and not Holster.same({ 1 }, {}) and not Holster.same({ 1, 2 }, { 2, 1 }) and Holster.same({ 1, 2 }, { 1, 2 }))

-- 2. Pas de réglage et bloc de config ----------------------------------------------------------------------------------
local S = Config.Back.slots
check('+1 cm sur x', Holster.nudge(1, 'x', 0.01) == 0.11 and S[1].x == 0.11)
check('−1 cm sur x (arrondi propre)', Holster.nudge(1, 'x', -0.01) == 0.10)
check('+2° sur ry', Holster.nudge(1, 'ry', 2.0) == 167.0 and Holster.nudge(1, 'ry', -2.0) == 165.0)
check('angle ramené dans [0, 360[', Holster.nudge(2, 'rz', -2.0) == 358.0 and Holster.nudge(2, 'rz', 2.0) == 0.0)
check('position bornée à ±1 m', Holster.nudge(2, 'z', -5.0) == -1.0 and Holster.nudge(2, 'z', 0.9) == -0.10)
check('clé ou emplacement inconnus : nil', Holster.nudge(1, 'w', 1) == nil and Holster.nudge(9, 'x', 1) == nil and Holster.nudge(1, 'x', 'a') == nil)
local block = Holster.block(S, 24816)
check('bloc : os et ouverture de slots', block:find('bone = 24816,', 1, true) and block:find('slots = {', 1, true) and block:find('\n    },$'))
check('bloc : 1re ligne formatée', block:find('{ x = 0.10, y = -0.15, z = -0.10, rx = 0.0, ry = 165.0, rz = 0.0 }, -- 1re arme (droite)', 1, true) ~= nil)
check('bloc : 2e ligne formatée', block:find('{ x = -0.10, y = -0.15, z = -0.10, rx = 0.0, ry = 195.0, rz = 0.0 }, -- 2e arme (gauche)', 1, true) ~= nil)
check('libellé court d\'une arme', Holster.label(H.pump) == 'PUMPSHOTGUN' and Holster.label(12345) == '12345')
local ok, err = pcall(load, block) -- le bloc est bien du Lua (dans une table)
check('bloc : syntaxe Lua valide', ok and load('return {\n' .. block .. '\n}') ~= nil)

-- 3. Client simulé : moi -----------------------------------------------------------------------------------------------
join(1, 'CID1', 'Moi', vec3(0.0, 0.0, 0.0))
W.entities[1001] = { type = 1, pos = vec3(0.0, 0.0, 0.0) }
inv = { [2] = { name = 'WEAPON_PISTOL' }, [4] = { name = 'WEAPON_CARBINERIFLE' }, [6] = { name = 'WEAPON_PUMPSHOTGUN' } }
TriggerEvent('gs_bridge:client:playerLoaded')
local st = W.pstate[1].gsBack
check('state bag publié : 2 armes longues, pistolet exclu', type(st) == 'table' and #st == 2 and st[1] == H.carbine and st[2] == H.pump)
check('rien dessiné avant le tick', objs() == 0)
check('tick : quelqu\'un porte une arme (boucle rapide)', Holster.tick() == true)
local n, att = objs(1001)
check('2 objets créés, tous attachés à mon ped', n == 2 and att == 2)
local off = W.entities[W.nextEntity].off
check('offsets et rotation du Config appliqués', off and off.ry == 165.0 or off.ry == 195.0)
-- arme prise en main
TriggerEvent('ox_inventory:currentWeapon', { hash = H.carbine, slot = 4, name = 'WEAPON_CARBINERIFLE' })
check('arme en main : plus dans le state bag', #W.pstate[1].gsBack == 1 and W.pstate[1].gsBack[1] == H.pump)
Holster.tick()
n, att = objs(1001)
check('arme en main : son objet du dos supprimé', n == 1 and att == 1)
TriggerEvent('ox_inventory:currentWeapon', nil)
Holster.tick()
check('arme rangée : objet de retour', objs(1001) == 2)
-- arme retirée du sac (donnée, perdue, vendue)
inv[4] = nil
TriggerEvent('ox_inventory:updateInventory', {})
check('arme retirée du sac : state bag à 1', #W.pstate[1].gsBack == 1)
Holster.tick()
check('arme retirée du sac : objet supprimé', objs(1001) == 1)
inv = {}
TriggerEvent('ox_inventory:itemCount', 'WEAPON_PUMPSHOTGUN', 0)
check('plus d\'arme longue : state bag retiré', W.pstate[1].gsBack == nil)
check('plus d\'arme longue : boucle lente, aucun objet', Holster.tick() == false and objs() == 0)
-- mort puis réapparition
inv = { [1] = { name = 'WEAPON_SMG' } }
TriggerEvent('ox_inventory:updateInventory', {})
Holster.tick()
check('SMG dans le dos', objs(1001) == 1 and #W.pstate[1].gsBack == 1)
W.entities[1001].dead = true
Holster.tick()
check('mort : state bag vidé et objet supprimé', W.pstate[1].gsBack == nil and objs() == 0)
W.entities[1001].dead = false
Holster.tick()
check('réapparition : state bag et objet de retour', #W.pstate[1].gsBack == 1 and objs(1001) == 1)
-- à terre (qbx_medical deathState 3) sans ped mort
W.pstate[1]['qbx_medical:deathState'] = 3
Holster.tick()
check('à terre (qbx_medical) : rien dans le dos', W.pstate[1].gsBack == nil and objs() == 0)
W.pstate[1]['qbx_medical:deathState'] = 1
Holster.tick()
check('relevé : de retour', objs(1001) == 1)
-- changement de ped (nouveau modèle) : l'ancien objet ne doit pas rester en l'air
W.players[1].ped = 2001
W.entities[2001] = { type = 1, pos = vec3(0.0, 0.0, 0.0) }
W.entities[1001] = nil -- l'ancien ped disparaît : l'objet attaché devient orphelin
cache.ped = 2001
Holster.tick()
local total, onNew = objs(2001)
check('nouveau ped : objet refait sur le ped actuel, aucun orphelin', total == 1 and onNew == 1)
W.onCache.ped(2001, 1001)
check('lib.onCache ped : mes objets retirés immédiatement', objs() == 0)
Holster.tick()
check('puis refaits au tick suivant', objs(2001) == 1)
-- attache ratée / modèle absent : jamais d'objet libre
W.players[1].ped = nil W.entities[1001] = { type = 1, pos = vec3(0.0, 0.0, 0.0) } W.entities[2001] = nil cache.ped = 1001
Holster.tick() -- objets refaits sur 1001
check('retour sur le ped 1001', objs(1001) == 1)
for id, e in pairs(W.entities) do if e.type == 3 then W.entities[id] = nil end end -- objets perdus par le jeu
W.failAttach = true
Holster.tick()
check('attache ratée : objet supprimé, rien de libre', objs() == 0)
W.failAttach = nil
W.unloaded[H.smg] = true
Holster.tick()
check('modèle d\'arme jamais chargé : aucun objet', objs() == 0)
W.unloaded[H.smg] = nil
W.entities[1001].nobone = true
Holster.tick()
check('os absent sur ce modèle : aucun objet', objs() == 0)
W.entities[1001].nobone = nil
W.failCreate = true
Holster.tick()
check('création ratée : aucun objet', objs() == 0)
W.failCreate = nil
Holster.tick()
check('retour à la normale', objs(1001) == 1)

-- 4. Voisins --------------------------------------------------------------------------------------------------------------
join(2, 'CID2', 'Voisin', vec3(5.0, 0.0, 0.0))
W.entities[1002] = { type = 1, pos = vec3(5.0, 0.0, 0.0) }
Player(2).state:set('gsBack', { H.pump, H.carbine }, true)
Holster.tick()
check('voisin : 2 objets attachés à son ped (plus le mien)', on(1002) == 2 and objs() == 3)
local function remote(sid, v) Player(sid).state:set('gsBack', v, true) W.sbh.gsBack('player:' .. sid, 'gsBack', v) end -- comme en jeu : valeur + handler
remote(2, nil)
check('state bag vidé : objets du voisin retirés sans attendre la boucle', on(1002) == 0 and on(1001) == 1)
remote(2, { H.pump })
check('state bag rempli : objet créé sans attendre la boucle', on(1002) == 1)
W.sbh.gsBack('player:9', 'gsBack', { H.pump })
W.sbh.gsBack('global', 'gsBack', { H.pump })
check('state bag d\'un joueur inconnu ou global : ignoré', objs() == 2)
W.entities[1002].dead = true
Holster.tick()
check('voisin mort : objets retirés', on(1002) == 0 and on(1001) == 1)
W.entities[1002].dead = false
Holster.tick()
check('voisin relevé : objet refait', on(1002) == 1)
W.players[2].pos = vec3(500.0, 0.0, 0.0) W.entities[1002].pos = W.players[2].pos
Holster.tick()
check('voisin hors de portée : objets retirés', on(1002) == 0 and objs() == 1)
W.players[2].pos = vec3(5.0, 0.0, 0.0) W.entities[1002].pos = W.players[2].pos
Holster.tick()
check('voisin revenu : objet refait', on(1002) == 1)
-- le ped du voisin est recréé par le streaming
W.players[2].ped = 2002 W.entities[2002] = { type = 1, pos = vec3(5.0, 0.0, 0.0) } W.entities[1002] = nil
Holster.tick()
check('ped du voisin recréé : objet refait sur le nouveau ped, aucun orphelin', objs() == 2 and on(2002) == 1 and on(1001) == 1)
-- déconnexion du voisin : balayage des orphelins
W.players[2] = nil W.entities[2002] = nil
Holster.sweep()
check('voisin parti du réseau : ses objets supprimés par le balayage', objs() == 1 and Holster.count() == 1)
-- objet détaché par le jeu (ped supprimé) ou objet perdu de vue
local stray = CreateWeaponObject(H.pump, 1, 0.0, 0.0, 0.0)
W.entities[stray].attached = 1001
for id, e in pairs(W.entities) do if e.type == 3 and id ~= stray then e.attached = nil end end
Holster.sweep()
check('balayage : objet détaché supprimé, objet non référencé laissé au jeu', W.entities[stray] ~= nil and objs() == 1)
W.entities[stray] = nil
Holster.tick()
check('tick : mon objet détaché refait', objs(1001) == 1 and Holster.count() == 1)

-- 5. /dosreglage ----------------------------------------------------------------------------------------------------------
W.commands.dosreglage()
check('non staff : refusé, pas de menu', W.ui.notes[#W.ui.notes].description == 'Réservé au staff.' and W.ui.open == nil)
W.pstate[1].gsStaff = true
W.commands.dosreglage()
local menu = W.ui.contexts.gs_details_dos
check('staff : menu ouvert', W.ui.open == 'gs_details_dos' and menu and #menu.options >= 16)
check('menu : arme du dos et valeurs affichées', menu.options[1].title:find('SMG', 1, true) and menu.options[1].description:find('x = 0.10', 1, true))
local function option(pattern) for _, o in ipairs(W.ui.contexts.gs_details_dos.options) do if o.title:find(pattern, 1, true) then return o end end end
local calls = W.attachCalls
option('Décalage X = 0.10 m  →  +1 cm').onSelect()
check('+1 cm : valeur changée, objet ré-accroché, menu rouvert', S[1].x == 0.11 and W.attachCalls == calls + 1 and W.ui.open == 'gs_details_dos')
check('offset appliqué à l\'objet', select(2, next((function() local t = {} for _, e in pairs(W.entities) do if e.type == 3 then t[1] = e end end return t end)())).off.x == 0.11)
option('Rotation Y = 165.0°  →  −2°').onSelect()
check('−2° : valeur changée', S[1].ry == 163.0)
option('Os : 24818').onSelect()
check('bascule d\'os : 24816 et menu à jour', Config.Back.bone == 24816 and option('Os : 24816') ~= nil)
option('Os : 24816').onSelect()
W.ui.input = { 0.2, -0.1, 0.0, 10, 170, 0 }
option('Saisir les valeurs exactes').onSelect()
check('saisie exacte appliquée', S[1].x == 0.2 and S[1].y == -0.1 and S[1].rx == 10.0 and S[1].ry == 170.0)
option('Copier le bloc').onSelect()
check('bloc copié dans le presse-papier', W.ui.clipboard and W.ui.clipboard:find('x = 0.20, y = -0.10', 1, true) ~= nil)
check('bloc affiché dans la console F8', W.logs[#W.logs]:find('slots = {', 1, true) ~= nil and W.logs[#W.logs]:find('bone = 24818,', 1, true) ~= nil)
check('notification de copie', W.ui.notes[#W.ui.notes].type == 'success')
option('Revenir aux valeurs du fichier').onSelect()
check('retour aux valeurs du fichier', S[1].x == 0.10 and S[1].ry == 165.0 and S[1].rx == 0.0)
option('Emplacement 1 / 2').onSelect()
check('passage au 2e emplacement', option('Emplacement 2 / 2') ~= nil)
W.commands.dosreglage()
check('même commande : ferme le menu', W.ui.open == nil)

-- 6. Arrêt de la ressource --------------------------------------------------------------------------------------------
TriggerEvent('onResourceStop', GetCurrentResourceName())
check('arrêt : tous les objets supprimés, state bag retiré', objs() == 0 and Holster.count() == 0 and W.pstate[1].gsBack == nil)

io.write(('armes dans le dos : %d réussis, %d échoués\n'):format(passed, failed))
if failed > 0 then os.exit(1) end
