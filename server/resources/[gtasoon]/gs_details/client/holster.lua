-- gs_details (client) · V11.5 « Armes dans le dos ». Les armes longues de l'inventaire (fusils, pompes, mitraillettes,
-- précision) qui ne sont pas en main sont visibles dans le dos du personnage, pour tout le monde : chaque client dessine
-- les objets (locaux, sans réseau) des joueurs proches d'après leur state bag `gsBack`. Pistolets et armes blanches : rien.
--
-- V12.37 (13/10, fondateur : « la fonction des armes lourdes (dans le dos) reste bloquée dans le vide ») :
--   · cause : un objet n'était gardé que s'il existait encore (sync) ; quand le ped du joueur est recréé (réapparition,
--     changement de modèle, re-streaming) l'objet accroché à l'ancien ped restait libre dans l'air. Désormais un objet
--     n'est gardé que s'il est attaché au ped ACTUEL ; attache ratée ou modèle d'arme absent = objet supprimé tout de suite ;
--   · état publié vide dès que je suis mort / à terre, recalculé à la réapparition et au changement de ped (lib.onCache) ;
--   · voisins mis à jour immédiatement quand `gsBack` change (AddStateBagChangeHandler), la boucle sert de filet ;
--   · une seule boucle : Config.Back.refresh.busy (400 ms) seulement si quelqu'un autour (moi compris) porte une arme dans
--     le dos, sinon idle (2 s) ; balayage des objets orphelins toutes les ~5 s (joueur parti du réseau, objet détaché) ;
--   · ordre stable des armes (tri par emplacement d'inventaire) : plus de republication inutile ;
--   · /dosreglage (staff) : réglage en direct des décalages / rotations, bloc Config.Back prêt à coller (F8 + presse-papier).
-- Aucune boucle par image. Logique pure dans la table `Holster` (tests hors jeu : tests/test_gs_holster.lua).
local B = Config.Back
local R = B.refresh or { busy = 400, idle = 2000, sweep = 5000 }
local T = B.tune or { pos = 0.01, rot = 2.0 }
Holster = {}            -- V12.37 : fonctions pures + tick/sweep appelables par les tests
local mine = {}         -- hash des armes que je montre, publiés dans le state bag gsBack
local objects = {}      -- [serverId] = { [slot] = { hash = hash, obj = handle } }
local created = {}      -- V12.37 : [handle] = true pour tout objet créé ici (balayage des orphelins)
local currentWeapon     -- V12.37 : { slot, hash } de l'arme en main (ox_inventory) ou nil
local wasDead = false   -- V12.37 : dernier état mort / vivant connu (republication au changement)

local names = {}        -- [hash] = 'WEAPON_…' (libellés du menu de réglage)
for name in pairs(B.weapons) do names[joaat(name)] = name end

local function round(v, places) local m = 10 ^ places local r = math.floor(v * m + 0.5) / m if r == 0 then return 0.0 end return r end

-- Logique pure --------------------------------------------------------------------------------------------------------

--- Les armes à montrer dans le dos : armes longues (Config.Back.weapons) de l'inventaire ox_inventory, sans l'arme en main
--- (exclue par son emplacement, sinon une seule occurrence de son hash), triées par emplacement (ordre stable), `max` au plus.
--- `inHand` = { slot, hash } ou nil.
function Holster.pick(items, inHand, max)
    local list = {}
    if type(items) ~= 'table' then return list end
    local found = {}
    for slot, it in pairs(items) do
        if type(it) == 'table' and type(it.name) == 'string' and B.weapons[it.name:upper()] == true then
            found[#found + 1] = { slot = tonumber(slot) or math.huge, hash = joaat(it.name:upper()) }
        end
    end
    table.sort(found, function(a, b) return a.slot < b.slot end)
    local skipSlot, skipHash = inHand and tonumber(inHand.slot), inHand and inHand.hash
    for _, f in ipairs(found) do
        if skipSlot and f.slot == skipSlot then skipSlot = nil
        elseif not skipSlot and skipHash and f.hash == skipHash then skipHash = nil
        else list[#list + 1] = f.hash end
        if #list >= (max or B.max) then break end
    end
    return list
end

--- Deux listes d'armes identiques (même ordre) ?
function Holster.same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

local POS, ROT = { x = true, y = true, z = true }, { rx = true, ry = true, rz = true }
--- Applique un pas à un réglage d'emplacement (positions arrondies au cm et bornées à ±1 m, angles au dixième dans
--- [0, 360[). Renvoie la nouvelle valeur, nil si l'emplacement ou la clé n'existe pas.
function Holster.nudge(slot, key, delta)
    local s = B.slots[slot]
    if not s or (not POS[key] and not ROT[key]) or type(delta) ~= 'number' then return nil end
    local v = (s[key] or 0.0) + delta
    if POS[key] then
        v = round(v, 2)
        if v > 1.0 then v = 1.0 elseif v < -1.0 then v = -1.0 end
    else
        v = round(v % 360.0, 1)
        if v >= 360.0 then v = 0.0 end
    end
    s[key] = v
    return v
end

--- Bloc Lua prêt à coller dans Config.Back (shared/config.lua) à la place des lignes `bone` et `slots`.
function Holster.block(slots, bone)
    local out = { ('    bone = %d,'):format(bone or B.bone), '    slots = { -- réglé en jeu avec /dosreglage' }
    for i, s in ipairs(slots) do
        out[#out + 1] = ('        { x = %.2f, y = %.2f, z = %.2f, rx = %.1f, ry = %.1f, rz = %.1f },%s'):format(
            round(s.x, 2), round(s.y, 2), round(s.z, 2), round(s.rx, 1), round(s.ry, 1), round(s.rz, 1),
            i == 1 and ' -- 1re arme (droite)' or i == 2 and ' -- 2e arme (gauche)' or '')
    end
    out[#out + 1] = '    },'
    return table.concat(out, '\n')
end

--- Libellé court d'une arme pour le menu (« PUMPSHOTGUN »), ou le hash.
function Holster.label(hash) local n = names[hash] return n and (n:gsub('^WEAPON_', '')) or tostring(hash) end

-- Mon état (state bag gsBack) ------------------------------------------------------------------------------------------
local function dead(ped, sid)
    if IsEntityDead(ped) then return true end
    local st = sid and Player(sid).state or LocalPlayer.state
    return st['qbx_medical:deathState'] == 3 -- [API] qbx_medical : 3 = mort (à terre en attente des secours)
end

--- Ce que je porte dans le dos : rien si je suis mort / à terre, sinon d'après mon inventaire (arme en main exclue).
local function compute()
    if dead(cache.ped) then return {} end -- V12.37
    local ok, items = pcall(function() return exports.ox_inventory:GetPlayerItems() end) -- [API] ox_inventory
    if not ok then return {} end
    return Holster.pick(items, currentWeapon, B.max)
end

local pending = false
local function publish()
    if pending then return end
    pending = true
    SetTimeout(400, function() -- plusieurs changements d'inventaire d'un coup → une seule publication
        pending = false
        local list = compute()
        if Holster.same(list, mine) then return end
        mine = list
        LocalPlayer.state:set('gsBack', #list > 0 and list or nil, true)
    end)
end

AddEventHandler('ox_inventory:updateInventory', publish)               -- [API] ox_inventory
AddEventHandler('ox_inventory:itemCount', publish)                     -- [API] ox_inventory · V12.37 : arme donnée / perdue
AddEventHandler('ox_inventory:currentWeapon', function(w)              -- [API] ox_inventory
    currentWeapon = w and w.hash and { slot = w.slot, hash = w.hash } or nil -- V12.37 : l'emplacement exact est exclu
    publish()
end)
AddEventHandler('gs_bridge:client:playerLoaded', function() SetTimeout(3000, publish) end)
if LocalPlayer.state.isLoggedIn then SetTimeout(3000, publish) end -- V12.37 : redémarrage à chaud, joueur déjà en jeu

-- Objets (pour moi et les voisins) ------------------------------------------------------------------------------------
local function destroy(obj)
    if obj and DoesEntityExist(obj) then
        SetEntityAsMissionEntity(obj, true, true)
        DeleteEntity(obj)
    end
    if obj then created[obj] = nil end
end

local function removeAll(sid)
    for _, e in pairs(objects[sid] or {}) do destroy(e.obj) end
    objects[sid] = nil
end

--- Objet d'arme local (sans réseau), modèle chargé d'abord ; nil si le modèle ne vient pas (2 s) ou si la création rate.
local function weaponObject(hash, at)
    if not HasWeaponAssetLoaded(hash) then
        RequestWeaponAsset(hash, 31, 0)
        for _ = 1, 80 do -- V12.37 : 2 s au plus, par pas de 25 ms
            if HasWeaponAssetLoaded(hash) then break end
            Wait(25)
        end
        if not HasWeaponAssetLoaded(hash) then return nil end
    end
    local obj = CreateWeaponObject(hash, 1, at.x, at.y, at.z, true, 1.0, 0)
    if not obj or obj == 0 or not DoesEntityExist(obj) then return nil end
    return obj
end

--- Accroche (ou ré-accroche) l'objet sur l'os du dos avec les réglages de l'emplacement. true si l'objet est bien attaché.
local function place(obj, ped, slot)
    local o = B.slots[slot]
    if not o or not DoesEntityExist(ped) then return false end
    local bone = GetPedBoneIndex(ped, B.bone)
    if bone == -1 then return false end
    AttachEntityToEntity(obj, ped, bone, o.x, o.y, o.z, o.rx, o.ry, o.rz, true, true, false, true, 1, true)
    if IsEntityAttachedToEntity(obj, ped) then return true end
    Wait(0) -- une image de tolérance si le jeu applique l'attache au cycle suivant
    return IsEntityAttachedToEntity(obj, ped)
end

local function attach(ped, hash, slot)
    if not B.slots[slot] then return nil end
    local obj = weaponObject(hash, GetEntityCoords(ped))
    if not obj then return nil end
    created[obj] = true
    if not place(obj, ped, slot) then destroy(obj) return nil end -- V12.37 : attache ratée = supprimé, jamais laissé libre
    SetEntityCollision(obj, false, false)
    return obj
end

--- Fait coller les objets du joueur `sid` à sa liste `list`, sur son ped ACTUEL.
local function sync(sid, ped, list)
    local cur = objects[sid] or {}
    local want = {}
    for slot = 1, math.min(#list, #B.slots) do want[slot] = list[slot] end
    for slot, e in pairs(cur) do
        -- V12.37 : l'objet doit exister ET être accroché à ce ped (sinon il flotte : on le refait)
        if want[slot] ~= e.hash or not DoesEntityExist(e.obj) or not IsEntityAttachedToEntity(e.obj, ped) then
            destroy(e.obj)
            cur[slot] = nil
        end
    end
    for slot, hash in pairs(want) do
        if not cur[slot] then
            local obj = attach(ped, hash, slot)
            if obj then cur[slot] = { hash = hash, obj = obj } end
        end
    end
    objects[sid] = next(cur) and cur or nil
end

--- Un passage : moi (mort / vivant → republication) puis les voisins à portée. Renvoie true si quelqu'un porte une arme.
function Holster.tick()
    local isDead = dead(cache.ped)
    if isDead ~= wasDead then wasDead = isDead publish() end -- V12.37 : mort → rien dans le dos ; réapparition → recalcul
    local busy = #mine > 0
    local seen = {}
    local me = GetEntityCoords(cache.ped)
    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        local sid = GetPlayerServerId(pid)
        if ped ~= 0 and DoesEntityExist(ped) and #(GetEntityCoords(ped) - me) < B.range then
            seen[sid] = true
            local list = Player(sid).state.gsBack
            if type(list) == 'table' and #list > 0 then
                busy = true
                if dead(ped, sid) then removeAll(sid) else sync(sid, ped, list) end
            else
                removeAll(sid)
            end
        end
    end
    for sid in pairs(objects) do if not seen[sid] then removeAll(sid) end end
    return busy
end

--- V12.37 · Balayage des orphelins : joueur parti du réseau, objet détaché (ped supprimé) ou plus référencé.
function Holster.sweep()
    local referenced = {}
    for sid, slots in pairs(objects) do
        if GetPlayerFromServerId(sid) == -1 then removeAll(sid)
        else for _, e in pairs(slots) do referenced[e.obj] = true end end
    end
    for obj in pairs(created) do
        if not DoesEntityExist(obj) then created[obj] = nil
        elseif not referenced[obj] or not IsEntityAttached(obj) then destroy(obj) end
    end
end

--- Nombre d'objets vivants créés par ce fichier (diagnostic et tests).
function Holster.count() local n = 0 for obj in pairs(created) do if DoesEntityExist(obj) then n = n + 1 end end return n end

-- V12.37 : réaction immédiate au state bag (le mien compris), la boucle reste le filet de sécurité
AddStateBagChangeHandler('gsBack', nil, function(bagName, _, value)
    local sid = tonumber(bagName:match('^player:(%d+)$'))
    if not sid then return end
    if type(value) ~= 'table' or #value == 0 then return removeAll(sid) end -- plus rien dans le dos : retiré tout de suite
    SetTimeout(0, function() -- hors du handler : le chargement du modèle d'arme peut attendre
        local pid = GetPlayerFromServerId(sid)
        local ped = pid ~= -1 and GetPlayerPed(pid) or 0
        if ped == 0 or not DoesEntityExist(ped) or dead(ped, sid) then return removeAll(sid) end
        if #(GetEntityCoords(ped) - GetEntityCoords(cache.ped)) < B.range then sync(sid, ped, value) end
    end)
end)

-- V12.37 : nouveau ped (réapparition, changement de modèle) : les anciens objets ne suivent plus → on les refait
lib.onCache('ped', function()
    removeAll(GetPlayerServerId(PlayerId()))
    publish()
end)

CreateThread(function()
    local lastSweep = 0
    while true do
        local busy = Holster.tick()
        local now = GetGameTimer()
        if now - lastSweep >= R.sweep then lastSweep = now Holster.sweep() end
        Wait(busy and R.busy or R.idle) -- V12.37 : rapide seulement si quelqu'un autour porte une arme dans le dos
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for sid in pairs(objects) do removeAll(sid) end
    for obj in pairs(created) do destroy(obj) end -- V12.37 : rien ne survit à l'arrêt
    LocalPlayer.state:set('gsBack', nil, true)
end)

-- V12.37 · /dosreglage (staff) : régler en direct les décalages / rotations de l'arme dans le dos ------------------------
local defaults = {}
for i, s in ipairs(B.slots) do defaults[i] = { x = s.x, y = s.y, z = s.z, rx = s.rx, ry = s.ry, rz = s.rz } end
local tune = { slot = 1 }
local AXES = {
    { key = 'x',  step = T.pos, fmt = '%.2f m', label = 'Décalage X' },
    { key = 'y',  step = T.pos, fmt = '%.2f m', label = 'Décalage Y' },
    { key = 'z',  step = T.pos, fmt = '%.2f m', label = 'Décalage Z' },
    { key = 'rx', step = T.rot, fmt = '%.1f°',  label = 'Rotation X' },
    { key = 'ry', step = T.rot, fmt = '%.1f°',  label = 'Rotation Y' },
    { key = 'rz', step = T.rot, fmt = '%.1f°',  label = 'Rotation Z' },
}

--- Mes objets ré-accrochés avec les réglages courants (l'objet qui refuse est supprimé, la boucle le refera).
local function reattachMine()
    local sid = GetPlayerServerId(PlayerId())
    local cur = objects[sid]
    if not cur then return end
    for slot, e in pairs(cur) do
        if not DoesEntityExist(e.obj) or not place(e.obj, cache.ped, slot) then destroy(e.obj) cur[slot] = nil end
    end
    if not next(cur) then objects[sid] = nil end
end

--- Bascule l'os de tout le dos (24818 SKEL_Spine3 ↔ 24816 SKEL_Spine2) et ré-accroche.
function Holster.setBone(bone)
    B.bone = bone
    reattachMine()
end

function Holster.reset(slot)
    local d = defaults[slot]
    if not d then return end
    for k, v in pairs(d) do B.slots[slot][k] = v end
end

local function copyBlock()
    local text = Holster.block(B.slots, B.bone)
    print(('[gs_details] /dosreglage · à coller dans shared/config.lua, Config.Back (remplace `bone` et `slots`) :\n%s'):format(text))
    pcall(function() lib.setClipboard(text) end) -- [API] ox_lib
    lib.notify({ description = 'Bloc Config.Back copié dans le presse-papier et affiché dans la console F8.', type = 'success' })
end

local function tuneMenu()
    local n = #B.slots
    if tune.slot > n then tune.slot = 1 end
    local s = B.slots[tune.slot]
    local hash = mine[tune.slot]
    local options = {
        { title = ('Emplacement %d / %d · %s'):format(tune.slot, n, hash and Holster.label(hash) or 'aucune arme dans le dos'),
          description = ('{ x = %.2f, y = %.2f, z = %.2f, rx = %.1f, ry = %.1f, rz = %.1f } · clic : autre emplacement'):format(s.x, s.y, s.z, s.rx, s.ry, s.rz),
          icon = 'arrows-rotate', onSelect = function() tune.slot = tune.slot % n + 1 tuneMenu() end },
        { title = ('Os : %d (%s)'):format(B.bone, B.bone == 24818 and 'SKEL_Spine3' or B.bone == 24816 and 'SKEL_Spine2' or 'autre'),
          description = 'Clic : basculer 24818 ↔ 24816 (toutes les armes se ré-accrochent)', icon = 'bone',
          onSelect = function() Holster.setBone(B.bone == 24818 and 24816 or 24818) tuneMenu() end },
    }
    for _, a in ipairs(AXES) do
        local shown = a.fmt:format(s[a.key])
        local step = a.step < 1 and ('%d cm'):format(math.floor(a.step * 100 + 0.5)) or ('%d°'):format(math.floor(a.step + 0.5))
        for _, sign in ipairs({ 1, -1 }) do
            options[#options + 1] = {
                title = ('%s = %s  →  %s%s'):format(a.label, shown, sign > 0 and '+' or '−', step),
                icon = sign > 0 and 'plus' or 'minus', iconColor = sign > 0 and '#4ade80' or '#f87171',
                onSelect = function() Holster.nudge(tune.slot, a.key, sign * a.step) reattachMine() tuneMenu() end,
            }
        end
    end
    options[#options + 1] = { title = 'Saisir les valeurs exactes', icon = 'keyboard', onSelect = function()
        local fields = {}
        for i, a in ipairs(AXES) do
            fields[i] = { type = 'number', label = a.label .. (a.step < 1 and ' (m)' or ' (°)'), default = s[a.key], step = a.step, precision = a.step < 1 and 2 or 1 }
        end
        local r = lib.inputDialog(('Emplacement %d · valeurs exactes'):format(tune.slot), fields)
        if r then
            for i, a in ipairs(AXES) do
                if tonumber(r[i]) then Holster.nudge(tune.slot, a.key, tonumber(r[i]) - s[a.key]) end
            end
            reattachMine()
        end
        tuneMenu()
    end }
    options[#options + 1] = { title = 'Copier le bloc Config.Back', description = 'Presse-papier + console F8 : à coller dans shared/config.lua',
        icon = 'copy', iconColor = '#60a5fa', onSelect = function() copyBlock() tuneMenu() end }
    options[#options + 1] = { title = 'Revenir aux valeurs du fichier', description = ('Emplacement %d seulement'):format(tune.slot), icon = 'rotate-left',
        onSelect = function() Holster.reset(tune.slot) reattachMine() tuneMenu() end }
    lib.registerContext({ id = 'gs_details_dos', title = 'Armes dans le dos · réglage (staff)', options = options })
    lib.showContext('gs_details_dos')
end

RegisterCommand('dosreglage', function()
    if IsNuiFocused() then return end -- jamais pendant une saisie ou une autre interface
    if lib.getOpenContextMenu() == 'gs_details_dos' then return lib.hideContext() end -- même commande = fermer
    if LocalPlayer.state.gsStaff ~= true then -- posé par gs_onboarding (serveur) d'après exports.gs_admin:GetStaffLevel
        return lib.notify({ description = 'Réservé au staff.', type = 'error' })
    end
    tuneMenu()
end, false)
TriggerEvent('chat:addSuggestion', '/dosreglage', 'Staff : régler en direct la position des armes dans le dos')
