-- gs_scars (client) : affiche les cicatrices proches (props créés à l'approche, supprimés au loin) ;
-- vitrines brisées : [E] Réparer (ouvrier de la ville) ; fresques : grand texte peint aux couleurs du gang ;
-- V11 plaques (lieux de mémoire) : couronne + bougie, texte doré de près, [E] Lire la plaque.
local spawned = {} -- [id] = { entités }
local COLORS = { [1] = { 224, 50, 50 }, [2] = { 114, 204, 114 }, [3] = { 93, 182, 229 }, [25] = { 114, 204, 114 }, [27] = { 171, 60, 230 },
    [46] = { 240, 200, 80 }, [40] = { 80, 80, 80 } }

local function place(model, c, ox, oy, h)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 3000) then return nil end
    local o = CreateObject(hash, c.x + ox, c.y + oy, c.z, false, false, false)
    SetEntityHeading(o, h or 0.0) PlaceObjectOnGroundProperly(o) FreezeEntityPosition(o, true)
    SetModelAsNoLongerNeeded(hash)
    return o
end

local function build(s)
    local ents = {}
    local c = vec3(s.x, s.y, s.z)
    local list = s.kind == 'memorial' and Config.Memorial.props or (s.kind == 'glass' and Config.Glass.props)
        or (s.kind == 'plaque' and Config.Plaques.props or {})
    for i, m in ipairs(list) do
        local a = (i / #list) * math.pi * 2
        local r = (s.kind == 'memorial' or s.kind == 'plaque') and 0.8 or 2.2
        ents[#ents + 1] = place(m, c, math.cos(a) * r, math.sin(a) * r, math.deg(a))
    end
    if s.kind == 'glass' then
        exports.gs_markers:Add('gs_scars:' .. s.id, { coords = c, style = 'job', label = 'Vitrine brisée', event = 'gs_scars:client:repair',
            args = { s.id }, prompt = 'Réparer la vitrine (ouvrier de la ville)', reach = 3.0, snap = true })
    end
    if s.kind == 'plaque' then -- V11 : lieux de mémoire, un passant raconte
        exports.gs_markers:Add('gs_scars:' .. s.id, { coords = c, style = 'info', label = 'Lieu de mémoire', event = 'gs_scars:client:read',
            args = { s.id }, prompt = 'Lire la plaque', reach = 2.5, snap = true })
    end
    return ents
end

AddEventHandler('gs_scars:client:read', function(id)
    for _, s in ipairs(GlobalState.gsScars or {}) do
        if s.id == id then
            local talk = Config.Plaques.talk[math.random(#Config.Plaques.talk)]
            return lib.notify({ title = s.label, description = 'Un passant : ' .. talk, type = 'inform', duration = 9000 })
        end
    end
end)

local function clear(id)
    for _, e in ipairs(spawned[id] or {}) do if e and DoesEntityExist(e) then DeleteEntity(e) end end
    spawned[id] = nil
    exports.gs_markers:Remove('gs_scars:' .. id)
end

AddEventHandler('gs_scars:client:repair', function(id)
    if not lib.progressBar({ duration = Config.Glass.duration, label = 'Pose d\'une nouvelle vitre…', canCancel = true,
        anim = { scenario = 'WORLD_HUMAN_HAMMERING' }, disable = { move = true, car = true, combat = true } }) then return ClearPedTasks(cache.ped) end
    ClearPedTasks(cache.ped)
    local ok, msg = lib.callback.await('gs_scars:repair', false, id)
    lib.notify({ description = msg, type = ok and 'success' or 'error' })
end)

-- Props à l'approche (toutes les 2 s) ; fresques dessinées chaque image seulement si l'une est proche
local murals = {}
CreateThread(function()
    while true do
        local me, alive = GetEntityCoords(cache.ped), {}
        murals = {}
        for _, s in ipairs(GlobalState.gsScars or {}) do
            alive[s.id] = true
            local d = #(me - vec3(s.x, s.y, s.z))
            if s.kind == 'mural' or s.kind == 'plaque' then -- texte peint (fresques) ou gravé (plaques, de près)
                if d < (s.kind == 'plaque' and 20.0 or Config.Mural.drawDistance) then murals[#murals + 1] = s end
                if s.kind == 'plaque' then
                    if d < 80.0 and not spawned[s.id] then spawned[s.id] = build(s) elseif d > 120.0 and spawned[s.id] then clear(s.id) end
                end
            elseif d < 80.0 and not spawned[s.id] then spawned[s.id] = build(s)
            elseif d > 120.0 and spawned[s.id] then clear(s.id) end
        end
        for id in pairs(spawned) do if not alive[id] then clear(id) end end
        Wait(2000)
    end
end)

CreateThread(function()
    while true do
        if #murals == 0 then Wait(1000) else
            for _, s in ipairs(murals) do
                local plaque = s.kind == 'plaque'
                local onScreen, x, y = GetScreenCoordFromWorldCoord(s.x, s.y, s.z + (plaque and 1.1 or 2.5))
                if onScreen then
                    local col = plaque and { 235, 215, 160 } or COLORS[s.color or 0] or { 255, 46, 154 }
                    SetTextFont(plaque and 4 or 1) SetTextScale(0.0, plaque and 0.42 or 1.2) SetTextCentre(true) SetTextColour(col[1], col[2], col[3], 230) SetTextDropshadow(3, 0, 0, 0, 220)
                    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(s.label) EndTextCommandDisplayText(x, y)
                end
            end
            Wait(0)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(spawned) do clear(id) end
end)
