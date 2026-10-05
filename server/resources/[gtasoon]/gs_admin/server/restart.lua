-- gs_admin (serveur) · V11 « Redémarrage quotidien annoncé ». L'heure est posée sur le VPS par
-- « roadline redemarrage-auto HH:MM » (GERER-OVH), qui écrit setr gs_restart dans secrets.cfg. Absent ou « off » : rien.
-- Les joueurs sont prévenus 15, 5 puis 1 minute avant (le redémarrage lui-même est fait par le VPS).
local WARN = { 15, 5, 1 }
local said = {} -- [jour:minutes] = true, une seule annonce par palier

function Admin.restartWarning(now, at)
    local h, m = tostring(at or ''):match('^(%d%d):(%d%d)$')
    if not h then return nil end
    local left = (tonumber(h) * 60 + tonumber(m) - (now.hour * 60 + now.min)) % 1440
    for _, w in ipairs(WARN) do
        if left == w then return w end
    end
    return nil
end

CreateThread(function()
    while true do
        Wait(20000)
        local now = os.date('*t')
        local w = Admin.restartWarning(now, GetConvar('gs_restart', 'off'))
        local key = w and ('%d-%d:%d'):format(now.yday, now.hour * 60 + now.min, w)
        if w and not said[key] then
            said[key] = true
            TriggerClientEvent('gs_admin:client:announce', -1,
                ('Redémarrage de la ville dans %d min : range ton véhicule et mets-toi en sécurité.'):format(w))
        end
    end
end)
