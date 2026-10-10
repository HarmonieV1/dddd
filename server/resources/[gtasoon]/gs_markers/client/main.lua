-- gs_markers (client) : tous les marqueurs GTA SOON dessinés par UN seul fil, même style discret.
-- Les autres ressources déclarent leurs points : exports.gs_markers:Add(id, { coords, style, label?, icon?, distance?, height?,
--   event?, args?, prompt?, reach?, snap? }) : avec `event`, la touche [E] à moins de `reach` m déclenche l'event local (en plus d'ox_target).
-- Coût : un tri par distance toutes les 500 ms ; dessin à chaque frame seulement s'il y a un point à < 40 m.

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

local function add(id, def)
    if type(id) ~= 'string' or type(def) ~= 'table' or not def.coords then return false end
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
    }
    return true
end

local function remove(id) points[id] = nil end

--- Supprime tous les points dont l'id commence par `prefix` (ex : 'gs_rental:').
local function removePrefix(prefix)
    for id in pairs(points) do if id:sub(1, #prefix) == prefix then points[id] = nil end end
end

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
