-- gs_gangs (partagé) · V12.56 Quartiers « en pâtés de maisons » au lieu de cercles. GTA ne dessine pas de forme libre sur la
-- carte, seulement des rectangles orientés (AddBlipForArea + SetBlipRotation) : un quartier = des cases carrées de `cell` m,
-- tournées de `angle` degrés pour suivre le sens des rues, dont le centre tombe dans le rayon du quartier. La carte (client)
-- et l'appartenance d'un point au quartier (serveur) utilisent exactement le même découpage.
Blocks = {}

local function rot(x, y, a)
    local c, s = math.cos(a), math.sin(a)
    return x * c - y * s, x * s + y * c
end

--- Centres des cases du quartier (vec3 à l'altitude du centre).
function Blocks.cells(center, radius, angle, cell)
    local a, out = math.rad(angle or 0.0), {}
    local n = math.ceil(radius / cell)
    for i = -n, n do
        for j = -n, n do
            local lx, ly = i * cell, j * cell
            if lx * lx + ly * ly <= radius * radius then
                local x, y = rot(lx, ly, a)
                out[#out + 1] = vec3(center.x + x, center.y + y, center.z)
            end
        end
    end
    return out
end

--- Le point `p` est-il dans une des cases du quartier ?
function Blocks.contains(center, radius, angle, cell, p)
    local x, y = rot(p.x - center.x, p.y - center.y, -math.rad(angle or 0.0))
    local lx, ly = math.floor(x / cell + 0.5) * cell, math.floor(y / cell + 0.5) * cell
    return lx * lx + ly * ly <= radius * radius
end
