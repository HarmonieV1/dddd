-- gs_interiors (serveur) : téléportation par une porte, seulement si le joueur y a droit et est devant la porte.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Interiors = {}

local function door(id) for _, d in ipairs(Config.Doors) do if d.id == id then return d end end end

function Interiors.allowed(src, d)
    local a = d.access or {}
    if a.public then return true end
    if a.gang then
        if GetResourceState('gs_gangs') ~= 'started' then return false end
        return exports.gs_gangs:GetGang(src) == a.gang
    end
    if a.job then
        local job = Bridge:GetJob(src)
        return job ~= nil and job.name == a.job
    end
    return false
end

lib.callback.register('gs_interiors:use', function(src, id, side)
    if not Security:RateLimit(src, 'gs_interiors:use', 4, 10000) then return false, 'Doucement.' end
    local d = door(id)
    if not d or (side ~= 'outside' and side ~= 'inside') then return false, 'Porte inconnue.' end
    local from = d[side]
    if not Security:InRange(src, vec3(from.x, from.y, from.z), Config.Range + 2.0) then return false, 'Trop loin de la porte.' end
    if side == 'outside' and not Interiors.allowed(src, d) then return false, 'C\'est fermé. Tu n\'as pas la clé.' end
    local to = side == 'outside' and d.inside or d.outside
    local ped = GetPlayerPed(src)
    SetEntityCoords(ped, to.x, to.y, to.z, false, false, false, false)
    SetEntityHeading(ped, to.w)
    return true, side == 'outside' and d.label or nil
end)

--- Portes que le joueur a le droit d'ouvrir (le client n'affiche que celles-là).
lib.callback.register('gs_interiors:allowed', function(src)
    if not Security:RateLimit(src, 'gs_interiors:allowed', 6, 10000) then return {} end
    local out = {}
    for _, d in ipairs(Config.Doors) do if Interiors.allowed(src, d) then out[#out + 1] = d.id end end
    return out
end)

--- Le joueur est-il dans le labo `lab` de son gang ? (utilisé par gs_drugs pour le bonus de production)
exports('InLab', function(src, lab, radius)
    for _, d in ipairs(Config.Doors) do
        if d.lab == lab and Interiors.allowed(src, d) and Security:InRange(src, vec3(d.inside.x, d.inside.y, d.inside.z), radius or 40.0) then
            return true
        end
    end
    return false
end)
