-- Outils serveur partagés par tous les modules de gs_jobs.
Bridge   = exports.gs_bridge
Security = exports.gs_security

GSJ = {}

function GSJ.log(fmt, ...)
    Security:LogStaff(fmt:format(...), 'jobs')
end

function GSJ.notify(src, msg, ntype)
    if src and src > 0 then Bridge:Notify(src, msg, ntype) else print('[gs_jobs] ' .. msg) end
end

function GSJ.isInt(n, min, max)
    return type(n) == 'number' and n == math.floor(n) and n >= (min or -math.huge) and n <= (max or math.huge)
end

--- Contrôle d'entrée standard de tout event/callback : rate-limit + personnage chargé.
function GSJ.guard(src, key, max, windowMs)
    if not Security:RateLimit(src, 'gs_jobs:' .. key, max or 5, windowMs or 10000) then return false end
    return Bridge:IsLoaded(src)
end

--- Job actif + sa définition + son grade.
function GSJ.activeJob(src)
    local job = Bridge:GetJob(src)
    if not job then return nil end
    local def = Jobs[job.name]
    return job, def, def and def.grades[job.grade]
end

--- Le joueur est-il proche d'un des points (vec3 ou { coords = vec3 }) ?
function GSJ.nearAny(src, list, radius)
    if not list then return false end
    for i = 1, #list do
        local c = list[i].coords or list[i]
        if Security:InRange(src, c, (radius or Config.ZoneRadius) + Config.ServerTolerance) then return true, i end
    end
    return false
end

function GSJ.jobLabel(name)
    if name == Config.UnemployedJob then return L('unemployed') end
    return Jobs[name] and Jobs[name].label or name
end

function GSJ.gradeLabel(job, grade)
    local g = Jobs[job] and Jobs[job].grades[grade]
    return g and g.label or ('#' .. tostring(grade))
end
