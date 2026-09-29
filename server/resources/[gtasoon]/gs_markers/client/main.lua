-- gs_markers (client) : tous les marqueurs GTA SOON dessinés par UN seul fil, avec le même style néon.
-- Les autres ressources déclarent leurs points : exports.gs_markers:Add(id, { coords, style, label?, icon?, distance?, height? })
-- Coût : un tri par distance toutes les 500 ms ; dessin à chaque frame seulement s'il y a un point à < 40 m.

local STYLES = {
    -- cercle au sol + icône flottante
    rental = { ring = { 255, 46, 136 }, icon = 38, iconColor = { 40, 224, 255 } },   -- vélo / voiture de location
    quest  = { ring = { 90, 255, 140 }, plumbob = { 90, 255, 140 } },              -- losange vert au-dessus des PNJ de quête
    entry  = { ring = { 40, 224, 255 }, icon = 20, iconColor = { 40, 224, 255 } },    -- entrée de bâtiment / interaction
    shop   = { ring = { 255, 196, 0 }, icon = 29, iconColor = { 255, 196, 0 } },      -- commerce ($)
    job    = { ring = { 160, 110, 255 }, icon = 21, iconColor = { 160, 110, 255 } },  -- point de métier
    objective = { ring = { 255, 196, 0 }, icon = 0, iconColor = { 255, 196, 0 } },    -- objectif de quête (cône)
}

local points = {}      -- [id] = { coords, style, label, drawDist }
local nearby = {}      -- liste des points proches (recalculée toutes les 500 ms)

local function add(id, def)
    if type(id) ~= 'string' or type(def) ~= 'table' or not def.coords then return false end
    points[id] = {
        coords = vec3(def.coords.x, def.coords.y, def.coords.z),
        style = STYLES[def.style] or STYLES.entry,
        label = def.label,
        drawDist = def.distance or 35.0,
        ring = def.ring ~= false,
        height = def.height or 1.0,
        icon = def.icon,   -- remplace l'icône du style (ex : 36 voiture, 38 vélo)
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
    SetTextFont(4) SetTextScale(0.0, 0.36) SetTextCentre(true) SetTextOutline()
    SetTextColour(255, 255, 255, 235)
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
            for _, n in ipairs(nearby) do
                local p, c, s = n.p, n.p.coords, n.p.style
                if p.ring then
                    DrawMarker(25, c.x, c.y, c.z - 0.97, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.6, 1.6, 1.0,
                        s.ring[1], s.ring[2], s.ring[3], 170, false, false, 2, false, nil, nil, false)
                end
                if s.plumbob then -- losange façon Sims : deux cônes pointe à pointe qui tournent
                    local z = c.z + p.height
                    DrawMarker(0, c.x, c.y, z + 0.18, 0.0, 0.0, 0.0, 0.0, 0.0, spin, 0.22, 0.22, 0.28,
                        s.plumbob[1], s.plumbob[2], s.plumbob[3], 220, false, false, 2, false, nil, nil, false)
                    DrawMarker(0, c.x, c.y, z + 0.46, 180.0, 0.0, 0.0, 0.0, 0.0, spin, 0.22, 0.22, 0.28,
                        s.plumbob[1], s.plumbob[2], s.plumbob[3], 220, false, false, 2, false, nil, nil, false)
                elseif p.icon or s.icon then
                    DrawMarker(p.icon or s.icon, c.x, c.y, c.z + 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.55, 0.55, 0.55,
                        s.iconColor[1], s.iconColor[2], s.iconColor[3], 210, true, true, 2, false, nil, nil, false)
                end
                if p.label and n.d < 8.0 then text3d(vec3(c.x, c.y, c.z + (s.plumbob and p.height + 0.8 or 0.9)), p.label) end
            end
            Wait(0)
        end
    end
end)
