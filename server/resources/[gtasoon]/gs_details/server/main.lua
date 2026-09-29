-- gs_details (serveur) : /me et /do, relayés seulement aux joueurs proches (le serveur calcule la portée).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

local function relay(src, kind, text)
    text = Security:Sanitize(text, Config.Me.maxLength)
    if not text or not Bridge:IsLoaded(src) then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local c = GetEntityCoords(ped)
    for _, id in ipairs(GetPlayers()) do
        local t = tonumber(id)
        local tp = GetPlayerPed(t)
        if tp ~= 0 and #(GetEntityCoords(tp) - c) <= Config.Me.range then
            TriggerClientEvent('gs_details:client:me', t, src, kind, text)
        end
    end
end

RegisterNetEvent('gs_details:server:me', function(kind, text)
    if not Security:RateLimit(source, 'gs_details:me', 3, 10000) then return end
    relay(source, kind == 'do' and 'do' or 'me', text)
end)
