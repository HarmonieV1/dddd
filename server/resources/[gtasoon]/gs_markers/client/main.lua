-- gs_markers (client) : tous les marqueurs GTA SOON dessinés par UN seul fil, même style discret.
-- Les autres ressources déclarent leurs points : exports.gs_markers:Add(id, { coords, style, label?, icon?, distance?, height?,
--   event?, args?, prompt?, reach?, snap?, ped? }) : avec `event`, la touche [E] à moins de `reach` m déclenche l'event local (en plus d'ox_target).
-- Coût : un tri par distance toutes les 500 ms ; dessin à chaque frame seulement s'il y a un point à < 40 m.
--
-- V12.36 · `ped = { model, heading, scenario?, distance?, label?, icon?, options? }` : un PNJ sur le point (vendeur, agent d'accueil,
-- contremaître…), invincible et figé, créé à l'approche (≤ 60 m) et retiré au loin (> 80 m) par UNE boucle lente commune à toutes
-- les ressources. Il se tient `distance` m (1,2 par défaut) « derrière » le point dans la direction `heading` et regarde vers le point.
-- Il porte l'interaction (ox_target) : `options` = options ox_target fournies par la ressource, sinon une option « [label] » qui
-- déclenche le même `event` que la touche [E]. Le point reste déplaçable par le staff : le PNJ suit la position du point.
--
-- V12.37 · PNJ et objets posés par le staff (F11 → Monde et lieux → « PNJ et objets », GlobalState.gsStaffPeds, gs_bridge) :
-- `ped.at = { x, y, z, heading }` = position absolue (le PNJ ne se déduit plus du point) et `ped.staffId` = entrée staff reprise
-- par ce point (gs_bridge/shared/points.lua `GsPoints.pointPed`). Les entrées que personne ne reprend sont créées ici en PNJ
-- d'ambiance (sans interaction) ou en objets, par la même boucle lente. Export `Place` : placement libre avec aperçu (menu staff).

-- V7 : style discret pour le RP. Plus de flèches ni d'icônes flottantes : un petit cercle au sol, peu opaque, visible
-- seulement de près (15 m max), texte à moins de 4 m. Seuls les repères de quête gardent un symbole (losange, cône).
local STYLES = {
    rental = { ring = { 255, 46, 136 } },          -- location
    quest  = { plumbob = { 90, 255, 140 } },       -- losange vert au-dessus des PNJ de quête (sans cercle)
    entry  = { ring = { 40, 224, 255 } },          -- entrée de bâtiment / interaction
    shop   = { ring = { 255, 196, 0 } },           -- commerce
    job    = { ring = { 235, 240, 255 } },         -- point de métier
    objective = { ring = { 255, 196, 0 }, icon = 0, iconColor = { 255, 196, 0 } },    -- objectif de quête (cône)
    hidden = {},                                   -- rien de dessiné : juste [E]
}
local RING_ALPHA, RING_SIZE, MAX_DIST, LABEL_DIST = 70, 0.85, 15.0, 4.0

local points = {}      -- [id] = { coords, style, label, drawDist }
local nearby = {}      -- liste des points proches (recalculée toutes les 500 ms)

local owners = {}      -- V12.5 · [id] = ressource qui a posé le point (nettoyé à son arrêt, voir plus bas)

-- PNJ des points (V12.36) -----------------------------------------------------------------------------------------
local PED_RANGE, PED_FORGET = 60.0, 80.0   -- créé en dessous, retiré au-dessus (marge pour ne pas clignoter à la limite)
local peds = {}        -- [id] = { ent, grounded, target }

--- Charge un modèle (sans ox_lib ici) ; false si le modèle n'existe pas ou met plus de 5 s.
local function loadModel(hash)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

--- Ancrage d'un PNJ de point (pur, sans sol) : `distance` m derrière le point dans la direction `heading` (il regarde donc vers
--- le point) ; ou, V12.37, sa position absolue `at` quand le staff l'a posé lui-même. Retourne x, y, zIndicatif, cap, absolu. [API]
local function pedAnchor(d, c)
    if type(d.at) == 'table' then return d.at.x + 0.0, d.at.y + 0.0, d.at.z + 0.0, (d.at.heading or 0.0) + 0.0, true end
    local h = math.rad(d.heading or 0.0)
    local dist = d.distance or 1.2
    return c.x + math.sin(h) * dist, c.y - math.cos(h) * dist, c.z - 1.0, (d.heading or 0.0) + 0.0, false
end

--- Position du PNJ, pieds au sol. Les points sont relevés à hauteur de joueur (≈ 1 m au-dessus du sol) : repli à c.z - 1 si le
--- sol n'est pas encore chargé. Un PNJ posé par le staff (`at`) garde exactement sa hauteur (déjà calée à l'aperçu).
local function pedPlace(p)
    local d, c = p.ped, p.coords
    local x, y, z, _, absolute = pedAnchor(d, c)
    if absolute then return x, y, z, true end
    local found, gz = GetGroundZFor_3dCoord(x, y, c.z + 1.0, false)
    if found and math.abs((gz + 1.0) - c.z) < 6.0 then return x, y, gz, true end
    return x, y, z, false
end

local function despawnPed(id)
    local e = peds[id]
    if not e then return end
    if e.target then exports.ox_target:removeLocalEntity(e.ent) end
    if DoesEntityExist(e.ent) then DeletePed(e.ent) end
    peds[id] = nil
end

local function spawnPed(id, p)
    local d = p.ped
    local hash = GetHashKey(d.model)
    if not loadModel(hash) then
        print(('[gs_markers] PNJ du point %s : modèle « %s » introuvable, ignoré'):format(id, tostring(d.model)))
        p.pedFailed = true -- on n'essaie plus (sinon une tentative toutes les 2,5 s)
        return
    end
    local x, y, z, grounded = pedPlace(p)
    local _, _, _, heading = pedAnchor(d, p.coords) -- V12.37 : cap absolu si le PNJ a été posé par le staff
    local ped = CreatePed(4, hash, x, y, z, heading, false, true)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return end
    SetEntityHeading(ped, heading)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedDiesWhenInjured(ped, false)
    if d.scenario then TaskStartScenarioInPlace(ped, d.scenario, 0, true) end
    -- Le PNJ porte l'interaction : options ox_target de la ressource, sinon la même action que la touche [E]
    local options = type(d.options) == 'table' and d.options or nil
    if not options and p.event then
        options = { {
            name = 'gs_markers:ped:' .. id, icon = d.icon or 'fa-solid fa-comments', distance = 2.5,
            label = d.label or p.prompt or p.label or 'Parler',
            onSelect = function() TriggerEvent(p.event, table.unpack(p.args)) end,
        } }
    end
    if options then exports.ox_target:addLocalEntity(ped, options) end
    peds[id] = { ent = ped, grounded = grounded, target = options ~= nil }
end

local function add(id, def)
    if type(id) ~= 'string' or type(def) ~= 'table' or not def.coords then return false end
    owners[id] = GetInvokingResource()
    local ped = def.ped
    if type(ped) ~= 'table' or type(ped.model) ~= 'string' or ped.model == '' then ped = nil end
    points[id] = {
        coords = vec3(def.coords.x, def.coords.y, def.coords.z),
        style = STYLES[def.style] or STYLES.entry,
        label = def.label,
        drawDist = def.style == 'objective' and (def.distance or 35.0) or math.min(def.distance or MAX_DIST, MAX_DIST),
        ring = def.ring ~= false,
        height = def.height or 1.0,
        icon = def.style == 'objective' and def.icon or nil, -- icônes flottantes : seulement les objectifs (V7)
        event = def.event, -- [E] à proximité : TriggerEvent(event, table.unpack(args)) (évent local de la ressource)
        args = def.args or {},
        prompt = def.prompt or def.label,
        reach = def.reach or 1.8,
        snap = def.snap == true, -- hauteur recalée sur le sol à l'approche (points dehors à la hauteur approximative)
        ped = ped, -- V12.36 : PNJ du point (voir en-tête)
    }
    despawnPed(id) -- V12.36 : point redéclaré (ressource relancée, point déplacé) → le PNJ est recréé à la nouvelle position
    return true
end

local function remove(id) points[id] = nil owners[id] = nil despawnPed(id) end

--- Supprime tous les points dont l'id commence par `prefix` (ex : 'gs_rental:').
local function removePrefix(prefix)
    for id in pairs(points) do if id:sub(1, #prefix) == prefix then points[id] = nil owners[id] = nil despawnPed(id) end end
end

-- V12.5 · Une ressource qui s'arrête (ou redémarre après « Déplacer un point ») perd TOUS ses points, même si elle oublie
-- de les retirer. Avant : magasins, fourrière, justice… gardaient leur ancien point actif à l'ancien endroit.
AddEventHandler('onClientResourceStop', function(res)
    for id, owner in pairs(owners) do
        if owner == res then points[id] = nil owners[id] = nil despawnPed(id) end -- V12.36 : son PNJ part avec le point
    end
    nearby = {} -- pas d'attente des 500 ms : plus aucun [E] sur un point retiré
end)

exports('Add', add)
exports('Remove', remove)
exports('RemovePrefix', removePrefix)
exports('PedAnchor', pedAnchor)

-- PNJ et objets posés par le staff (V12.37) -------------------------------------------------------------------------------
-- Copie locale de GlobalState.gsStaffPeds. Une entrée reprise par un point (points[*].ped.staffId) est créée par ce point, avec
-- son interaction ; les autres sont créées ici : PNJ d'ambiance (`staff:<id>` dans `peds`) ou objet figé (`props`).
local staffList = {}   -- { id, kind, model, scenario, x, y, z, heading, p = pseudo-point pour spawnPed }
local props = {}       -- ['staff:<id>'] = objet créé à proximité

local function despawnProp(id)
    local ent = props[id]
    if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
    props[id] = nil
end

local function spawnProp(id, e)
    local hash = GetHashKey(e.model)
    if not loadModel(hash) then
        print(('[gs_markers] objet du staff #%s : modèle « %s » introuvable, ignoré'):format(e.id, tostring(e.model)))
        e.failed = true
        return
    end
    local ent = CreateObjectNoOffset(hash, e.x, e.y, e.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ent or ent == 0 then return end
    SetEntityHeading(ent, e.heading or 0.0)
    FreezeEntityPosition(ent, true)
    props[id] = ent
end

--- Recharge la liste du staff : tout ce qui a été créé ici est retiré, la boucle lente recrée ce qui est encore proche.
local function setStaffList(list)
    for id in pairs(props) do despawnProp(id) end
    for id in pairs(peds) do if id:sub(1, 6) == 'staff:' then despawnPed(id) end end
    staffList = {}
    if type(list) ~= 'table' then return end
    for _, e in ipairs(list) do
        if type(e) == 'table' and type(e.model) == 'string' and tonumber(e.id) then
            local x, y, z, h = (e.x or 0.0) + 0.0, (e.y or 0.0) + 0.0, (e.z or 0.0) + 0.0, (e.heading or 0.0) + 0.0
            staffList[#staffList + 1] = { id = e.id, kind = e.kind, model = e.model, scenario = e.scenario, x = x, y = y, z = z, heading = h,
                p = { coords = vec3(x, y, z), ped = { model = e.model, scenario = e.scenario, at = { x = x, y = y, z = z, heading = h }, staffId = e.id } } }
        end
    end
end

setStaffList(GlobalState.gsStaffPeds)
AddStateBagChangeHandler('gsStaffPeds', 'global', function(_, _, value) setStaffList(value) end)

--- Entrée staff (id) dont l'entité `entity` est le PNJ ou l'objet, créé ici ou repris par un point ; nil sinon. [API]
local function staffEntryOf(entity)
    if not entity or entity == 0 then return nil end
    for id, e in pairs(peds) do
        if e.ent == entity then
            local n = id:match('^staff:(%d+)$')
            if n then return tonumber(n) end
            local p = points[id]
            return p and p.ped and p.ped.staffId or nil
        end
    end
    for id, ent in pairs(props) do
        if ent == entity then return tonumber(id:match('^staff:(%d+)$')) end
    end
    return nil
end
exports('StaffEntryOf', staffEntryOf)

--- Entrées staff à créer ici : celles qu'aucun point déclaré ne reprend (pur). Retourne la liste et l'ensemble des id repris.
local function unclaimedStaff(list, pts)
    local claimed, out = {}, {}
    for _, p in pairs(pts) do if p.ped and p.ped.staffId then claimed[p.ped.staffId] = true end end
    for _, e in ipairs(list) do if not claimed[e.id] then out[#out + 1] = e end end
    return out, claimed
end
exports('UnclaimedStaff', function(list, pts) return unclaimedStaff(list or staffList, pts or points) end)

local function text3d(c, label)
    local onScreen, x, y = GetScreenCoordFromWorldCoord(c.x, c.y, c.z)
    if not onScreen then return end
    SetTextFont(4) SetTextScale(0.0, 0.30) SetTextCentre(true) SetTextOutline()
    SetTextColour(255, 255, 255, 190)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandDisplayText(x, y)
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local list = {}
        for _, p in pairs(points) do
            local d = #(me - p.coords)
            if p.snap and not p.snapped and d < 40.0 then
                local c = p.coords
                for _, from in ipairs({ 1.0, 8.0 }) do
                    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + from, false)
                    if found and math.abs(gz + 1.0 - c.z) < 8.0 then p.coords, p.snapped = vec3(c.x, c.y, gz + 1.0), true break end
                end
                d = #(me - p.coords)
            end
            if d < p.drawDist then list[#list + 1] = { p = p, d = d } end
        end
        nearby = list
        Wait(500)
    end
end)

-- V12.36 · PNJ des points : UNE boucle lente pour toutes les ressources (jamais par image). Création à ≤ 60 m, retrait à > 80 m ;
-- un PNJ posé avant que le sol soit chargé est recréé une fois, de près, à la bonne hauteur.
CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        for id, p in pairs(points) do
            if p.ped and not p.pedFailed then
                local d = #(me - p.coords)
                local e = peds[id]
                if not e then
                    if d < PED_RANGE then spawnPed(id, p) end
                elseif d > PED_FORGET then
                    despawnPed(id)
                elseif not e.grounded and d < 30.0 then
                    local _, _, _, ok = pedPlace(p)
                    if ok then despawnPed(id) spawnPed(id, p) end
                end
            end
        end
        -- V12.37 · entrées du staff que personne ne reprend : PNJ d'ambiance ou objets, mêmes distances
        local free, claimed = unclaimedStaff(staffList, points)
        for _, e in ipairs(free) do
            local id = 'staff:' .. e.id
            local d = #(me - e.p.coords)
            if e.kind == 'prop' then
                if not props[id] then
                    if d < PED_RANGE and not e.failed then spawnProp(id, e) end
                elseif d > PED_FORGET then despawnProp(id) end
            elseif not peds[id] then
                if d < PED_RANGE and not e.p.pedFailed then spawnPed(id, e.p) end
            elseif d > PED_FORGET then despawnPed(id) end
        end
        for id in pairs(peds) do
            local n = id:match('^staff:(%d+)$')
            if n then
                if claimed[tonumber(n)] then despawnPed(id) end -- repris entre-temps par un point : plus de doublon
            elseif not points[id] then despawnPed(id) end -- point retiré sans passer par Remove
        end
        Wait(2500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(peds) do despawnPed(id) end -- V12.36 : aucun PNJ orphelin quand gs_markers redémarre
    for id in pairs(props) do despawnProp(id) end -- V12.37 : ni objet du staff
end)

CreateThread(function()
    local spin = 0.0
    while true do
        if #nearby == 0 then
            Wait(500)
        else
            spin = (spin + 1.2) % 360.0
            local me = GetEntityCoords(PlayerPedId())
            local best, bestD
            for _, n in ipairs(nearby) do
                if n.p.event then
                    local d = #(me - n.p.coords)
                    if d < n.p.reach and (not bestD or d < bestD) then best, bestD = n.p, d end
                end
            end
            if best and not IsPedInAnyVehicle(PlayerPedId(), false) then
                SetTextFont(4) SetTextScale(0.0, 0.45) SetTextCentre(true) SetTextOutline()
                SetTextColour(40, 224, 255, 240)
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName('[E] ' .. (best.prompt or 'Interagir'))
                EndTextCommandDisplayText(0.5, 0.88)
                if IsControlJustReleased(0, 38) and not IsNuiFocused() then TriggerEvent(best.event, table.unpack(best.args)) end -- V11.5 : pas pendant une saisie
            end
            for _, n in ipairs(nearby) do
                local p, c, s = n.p, n.p.coords, n.p.style
                if p.ring and s.ring then
                    -- léger fondu avec la distance : presque invisible au loin, net à côté
                    local a = math.floor(RING_ALPHA * math.max(0.25, 1.0 - n.d / p.drawDist))
                    DrawMarker(25, c.x, c.y, c.z - 0.97, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, RING_SIZE, RING_SIZE, 1.0,
                        s.ring[1], s.ring[2], s.ring[3], a, false, false, 2, false, nil, nil, false)
                end
                if s.plumbob then -- losange façon Sims : deux cônes pointe à pointe qui tournent
                    local z = c.z + p.height
                    DrawMarker(0, c.x, c.y, z + 0.18, 0.0, 0.0, 0.0, 0.0, 0.0, spin, 0.22, 0.22, 0.28,
                        s.plumbob[1], s.plumbob[2], s.plumbob[3], 170, false, false, 2, false, nil, nil, false)
                    DrawMarker(0, c.x, c.y, z + 0.46, 180.0, 0.0, 0.0, 0.0, 0.0, spin, 0.22, 0.22, 0.28,
                        s.plumbob[1], s.plumbob[2], s.plumbob[3], 170, false, false, 2, false, nil, nil, false)
                elseif (p.icon or s.icon) and s.iconColor then
                    DrawMarker(p.icon or s.icon, c.x, c.y, c.z + 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.55, 0.55, 0.55,
                        s.iconColor[1], s.iconColor[2], s.iconColor[3], 210, true, true, 2, false, nil, nil, false)
                end
                if p.label and n.d < LABEL_DIST and s ~= STYLES.hidden then text3d(vec3(c.x, c.y, c.z + (s.plumbob and p.height + 0.8 or 0.9)), p.label) end
            end
            Wait(0)
        end
    end
end)

-- Placement libre (V12.37) ------------------------------------------------------------------------------------------------
-- Pour le menu staff F11 (gs_admin) : aperçu d'un point (anneau + repère de cap), d'un PNJ ou d'un objet en fantôme devant le
-- joueur, réglé au clavier, puis Entrée / Retour. Les textes d'aide sont affichés par l'appelant (lib.showTextUI : gs_markers ne
-- charge pas ox_lib). Une seule boucle par image, le temps du placement ; un seul placement à la fois.
local STEP_MOVE, STEP_UP, STEP_TURN = 0.10, 0.05, 5.0      -- 10 cm, 5 cm, 5° par pas ; Maj = pas × 5
local PLACE_DISABLED = { 23, 24, 25, 44, 38, 45, 47, 73, 172, 173, 174, 175, 10, 11, 14, 15, 16, 17, 37, 108, 109, 111, 112, 140, 141, 142, 257, 263 }
local placing = false
local held = {} -- [commande] = horodatage du premier appui (répétition quand la touche reste enfoncée)

--- Pure : nouvelle pose après les commandes d'une image. `inp` = { fwd, right, up, turn } en nombre de pas (signés, fractions
--- autorisées pour le maintien), `camHeading` = cap de la caméra en degrés (avancer = s'éloigner de la caméra), `mult` = Maj × 5.
--- Le cap suit la convention du jeu (sens inverse des aiguilles d'une montre) : turn > 0 tourne à gauche. [API]
local function placeStep(pose, inp, camHeading, mult)
    mult = mult or 1.0
    local h = math.rad(camHeading or 0.0)
    local fx, fy = -math.sin(h), math.cos(h)
    local rx, ry = math.cos(h), math.sin(h)
    local fwd, right = (inp.fwd or 0) * STEP_MOVE * mult, (inp.right or 0) * STEP_MOVE * mult
    return {
        x = pose.x + fx * fwd + rx * right,
        y = pose.y + fy * fwd + ry * right,
        z = pose.z + (inp.up or 0) * STEP_UP * mult,
        heading = ((pose.heading or 0.0) + (inp.turn or 0) * STEP_TURN * mult) % 360.0,
    }
end
exports('PlaceStep', placeStep)

--- Un pas au premier appui ; touche maintenue plus de 350 ms : pas continus (≈ 10 pas par seconde).
local function pressed(c, dt)
    if IsDisabledControlJustPressed(0, c) then held[c] = GetGameTimer() return 1.0 end
    if IsDisabledControlPressed(0, c) then
        if held[c] and GetGameTimer() - held[c] > 350 then return dt * 10.0 end
        return 0.0
    end
    held[c] = nil
    return 0.0
end
local function axis(plus, minus, dt) return pressed(plus, dt) - pressed(minus, dt) end

--- Point visé par la caméra (sol et objets, joueur ignoré), à 25 m max ; nil si rien.
local function camAim()
    local cam, rot = GetGameplayCamCoord(), GetGameplayCamRot(2)
    local rz, rx = math.rad(rot.z), math.rad(rot.x)
    local dir = vec3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
    local to = cam + dir * 25.0
    local _, hit, at = GetShapeTestResult(StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, to.x, to.y, to.z, 1 | 16, PlayerPedId(), 4))
    if hit then return at end
    return nil
end

--- V12.63 (backtest : « une touche pour coller au mur, éviter les faux placements ») : surface visée par la caméra (25 m).
--- Mur : l'objet est collé DOS au mur (profondeur du modèle), face à la pièce ; plafond : suspendu dessous ; sol : posé dessus.
--- `back` = distance au mur pour un PNJ ou un point. Retourne la pose, ou nil si rien n'est visé. [API]
local function wallSnap(kind, model, pose, back)
    local cam, rot = GetGameplayCamCoord(), GetGameplayCamRot(2)
    local rz, rx = math.rad(rot.z), math.rad(rot.x)
    local dir = vec3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
    local to = cam + dir * 25.0
    local _, hit, at, normal = GetShapeTestResult(StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, to.x, to.y, to.z, 1 | 16, PlayerPedId(), 4))
    if hit ~= 1 or not normal then return nil end
    local mn, mx = vec3(-0.2, -0.2, 0.0), vec3(0.2, 0.2, 1.0)
    if kind == 'prop' and model then mn, mx = GetModelDimensions(GetHashKey(model)) end
    if normal.z > 0.7 then -- sol
        return { x = at.x, y = at.y, z = at.z + (kind == 'prop' and -mn.z or 0.0) + (kind == 'point' and 1.0 or 0.0), heading = pose.heading }
    elseif normal.z < -0.7 then -- plafond (caméra, lampe…)
        return { x = at.x, y = at.y, z = at.z - (kind == 'prop' and mx.z or 0.3), heading = pose.heading }
    end
    local d = kind == 'prop' and (-mn.y + 0.01) or (back or 0.35)
    local p = at + normal * d
    return { x = p.x, y = p.y, z = kind == 'ped' and (p.z - 1.0) or p.z, heading = GetHeadingFromVector_2d(normal.x, normal.y) % 360.0 }
end
exports('WallSnap', wallSnap)

--- Fantôme : PNJ ou objet semi-transparent, sans collision, figé. Retourne l'entité (0 pour un point), ou nil + message.
local function ghostCreate(kind, model, scenario, pose)
    if kind ~= 'ped' and kind ~= 'prop' then return 0 end
    local hash = GetHashKey(tostring(model or ''))
    if not loadModel(hash) then return nil, 'Modèle inconnu : ' .. tostring(model) end
    local ent
    if kind == 'ped' then ent = CreatePed(4, hash, pose.x, pose.y, pose.z, pose.heading, false, false)
    else ent = CreateObjectNoOffset(hash, pose.x, pose.y, pose.z, false, false, false) end
    SetModelAsNoLongerNeeded(hash)
    if not ent or ent == 0 then return nil, 'Création impossible.' end
    SetEntityAlpha(ent, 170, false)
    SetEntityCollision(ent, false, false)
    SetEntityInvincible(ent, true)
    FreezeEntityPosition(ent, true)
    if kind == 'ped' then
        SetBlockingOfNonTemporaryEvents(ent, true)
        if scenario then TaskStartScenarioInPlace(ent, scenario, 0, true) end
    end
    return ent
end

local function ghostMove(kind, ent, pose)
    if not ent or ent == 0 then return end
    if kind == 'ped' then SetEntityCoords(ent, pose.x, pose.y, pose.z, false, false, false, false) -- avec décalage : z = sol, comme CreatePed
    else SetEntityCoordsNoOffset(ent, pose.x, pose.y, pose.z, false, false, false) end
    SetEntityHeading(ent, pose.heading)
end

--- Au sol : point = 1 m au-dessus (convention des points, hauteur de joueur), PNJ = pieds au sol, objet = posé par le jeu.
local function placeGround(kind, pose, ghost)
    if kind == 'prop' and ghost and ghost ~= 0 then
        PlaceObjectOnGroundProperly(ghost)
        local c = GetEntityCoords(ghost)
        return { x = c.x, y = c.y, z = c.z, heading = pose.heading }
    end
    local found, gz = GetGroundZFor_3dCoord(pose.x, pose.y, pose.z + 1.0, false)
    if not found then found, gz = GetGroundZFor_3dCoord(pose.x, pose.y, pose.z + 10.0, false) end
    if not found then return pose end
    return { x = pose.x, y = pose.y, z = gz + (kind == 'point' and 1.0 or 0.0), heading = pose.heading }
end

--- Aperçu d'un point : anneau au sol, bille au point, bille plus petite vers l'avant (sens du cap).
local function drawPointPreview(pose)
    local h = math.rad(pose.heading)
    DrawMarker(25, pose.x, pose.y, pose.z - 0.97, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.3, 1.3, 1.0, 40, 224, 255, 150, false, false, 2, false, nil, nil, false)
    DrawMarker(28, pose.x, pose.y, pose.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.14, 0.14, 0.14, 40, 224, 255, 210, false, false, 2, false, nil, nil, false)
    DrawMarker(28, pose.x - math.sin(h) * 0.8, pose.y + math.cos(h) * 0.8, pose.z - 0.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.09, 0.09, 0.09, 255, 196, 0, 220, false, false, 2, false, nil, nil, false)
end

--- Placement libre. opts = { kind = 'point' | 'ped' | 'prop', model?, scenario?, x?, y?, z?, heading? } (sans x : 2,5 m devant le
--- joueur, au sol). Touches : flèches ou pavé 8/5/4/6 = 10 cm, PgUp/PgDn = 5 cm, Q/E = 5°, Maj = pas × 5, G = au sol, F = coller au mur visé, Tab = viser à
--- la souris, Entrée = valider, Retour = annuler. Retourne { x, y, z, heading }, nil si annulé, nil + message si impossible. [API]
local function place(opts)
    if placing then return nil, 'Un placement est déjà en cours.' end
    if type(opts) ~= 'table' then return nil, 'Options invalides.' end
    local kind = opts.kind == 'ped' and 'ped' or opts.kind == 'prop' and 'prop' or 'point'
    local me = PlayerPedId()
    local heading = (tonumber(opts.heading) or GetEntityHeading(me)) + 0.0
    local pose
    if tonumber(opts.x) and tonumber(opts.y) and tonumber(opts.z) then
        pose = { x = opts.x + 0.0, y = opts.y + 0.0, z = opts.z + 0.0, heading = heading }
    else
        local c = GetOffsetFromEntityInWorldCoords(me, 0.0, 2.5, 0.0)
        pose = placeGround(kind, { x = c.x, y = c.y, z = c.z - (kind == 'point' and 0.0 or 1.0), heading = heading }, nil)
    end
    local ghost, err = ghostCreate(kind, opts.model, opts.scenario, pose)
    if ghost == nil then return nil, err end
    placing, held = true, {}
    local aim, result = false, nil
    -- par frame : seulement pendant un placement libre du staff (sortie avec Entrée / Retour)
    while true do
        for _, c in ipairs(PLACE_DISABLED) do DisableControlAction(0, c, true) end
        local dt = GetFrameTime()
        local mult = IsControlPressed(0, 21) and 5.0 or 1.0 -- Maj
        if IsDisabledControlJustPressed(0, 37) then aim = not aim end -- Tab : viser à la souris / réglage fin
        if aim then
            local at = camAim()
            if at then pose = { x = at.x, y = at.y, z = at.z + (kind == 'point' and 1.0 or 0.0), heading = pose.heading } end
        end
        local inp = { fwd = axis(172, 173, dt) + axis(111, 112, dt), right = axis(175, 174, dt) + axis(109, 108, dt),
            up = axis(10, 11, dt), turn = axis(44, 38, dt) } -- Q : à gauche, E : à droite
        if inp.fwd ~= 0 or inp.right ~= 0 or inp.up ~= 0 or inp.turn ~= 0 then
            pose = placeStep(pose, inp, GetGameplayCamRot(2).z, mult)
            if inp.fwd ~= 0 or inp.right ~= 0 or inp.up ~= 0 then aim = false end
        end
        if IsDisabledControlJustPressed(0, 47) then pose, aim = placeGround(kind, pose, ghost), false end -- G : au sol
        if IsDisabledControlJustPressed(0, 23) then -- F : coller au mur / plafond / sol visé (V12.63)
            local snap = wallSnap(kind, opts.model, pose, kind == 'point' and 0.25 or 0.35)
            if snap then pose, aim = snap, false end
        end
        if kind == 'point' then drawPointPreview(pose) else ghostMove(kind, ghost, pose) end
        if IsControlJustPressed(0, 191) then result = pose break end -- Entrée
        if IsControlJustPressed(0, 194) then break end -- Retour
        Wait(0)
    end
    if ghost ~= 0 and DoesEntityExist(ghost) then DeleteEntity(ghost) end
    placing = false
    return result
end
exports('Place', place)
