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

--- Position du PNJ : `distance` m derrière le point dans la direction `heading` (il regarde donc vers le point), pieds au sol.
--- Les points sont relevés à hauteur de joueur (≈ 1 m au-dessus du sol) : repli à c.z - 1 si le sol n'est pas encore chargé.
local function pedPlace(p)
    local d, c = p.ped, p.coords
    local h = math.rad(d.heading or 0.0)
    local dist = d.distance or 1.2
    local x, y = c.x + math.sin(h) * dist, c.y - math.cos(h) * dist
    local found, gz = GetGroundZFor_3dCoord(x, y, c.z + 1.0, false)
    if found and math.abs((gz + 1.0) - c.z) < 6.0 then return x, y, gz, true end
    return x, y, c.z - 1.0, false
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
    local ped = CreatePed(4, hash, x, y, z, d.heading or 0.0, false, true)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return end
    SetEntityHeading(ped, d.heading or 0.0)
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
        for id in pairs(peds) do if not points[id] then despawnPed(id) end end -- point retiré sans passer par Remove
        Wait(2500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(peds) do despawnPed(id) end -- V12.36 : aucun PNJ orphelin quand gs_markers redémarre
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
