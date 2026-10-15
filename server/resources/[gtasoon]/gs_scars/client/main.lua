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

local decals = {} -- [id] = { decal, … } (V12.59 : flaques de sang)

local function build(s)
    local ents = {}
    local c = vec3(s.x, s.y, s.z)
    local list = s.kind == 'glass' and Config.Glass.props
        or (s.kind == 'plaque' and not s.auto and Config.Plaques.props) -- V12.59 : plaque automatique = pas de couronne ni de bougie
        or (s.kind == 'memorial' and s.shot and Config.Memorial.shotProps) or {} -- V12.59 : douilles seulement par balle
    for i, m in ipairs(list) do
        local a = (i / #list) * math.pi * 2
        local r = s.kind == 'glass' and 2.2 or (s.kind == 'memorial' and 0.6 or 0.8)
        ents[#ents + 1] = place(m, c, math.cos(a) * r, math.sin(a) * r, math.deg(a))
    end
    if s.kind == 'memorial' then -- V12.59 : une flaque de sang par victime tombée ici (au sol, autour du point)
        local list2 = {}
        for i = 1, math.max(1, math.min(s.n or 1, Config.Memorial.maxBlood)) do
            local a, r = (i * 2.4), (i == 1 and 0.0 or 0.6 + i * 0.35)
            local x, y = c.x + math.cos(a) * r, c.y + math.sin(a) * r
            local found, gz = GetGroundZFor_3dCoord(x, y, c.z + 1.0, false)
            local size = 1.2 + math.random() * 0.8
            -- [native] AddDecal : 1010 = sang (éclaboussure), rouge sombre, ~24 h au plus (recréée à l'approche)
            list2[#list2 + 1] = AddDecal(1010, x, y, (found and gz or c.z) + 0.05, 0.0, 0.0, -1.0, 0.0, 1.0, 0.0,
                size, size, 0.35, 0.02, 0.02, 0.9, 86400.0, false, false, false)
        end
        decals[s.id] = list2
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
    for _, d in ipairs(decals[id] or {}) do if d and d ~= 0 then RemoveDecal(d) end end -- V12.59
    decals[id] = nil
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
                if d < (s.kind == 'plaque' and Config.Plaques.textRange or Config.Mural.drawDistance) then murals[#murals + 1] = s end -- V12.59 : texte lu de près seulement
                if s.kind == 'plaque' then
                    if d < 80.0 and not spawned[s.id] then spawned[s.id] = build(s) elseif d > 120.0 and spawned[s.id] then clear(s.id) end
                end
            elseif spawned[s.id] and s.kind == 'memorial' and (s.n or 1) ~= (#(decals[s.id] or {})) and d < 80.0 then
                clear(s.id) spawned[s.id] = build(s) -- V12.59 : une victime de plus au même endroit → une flaque de plus
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
                local onScreen, x, y = GetScreenCoordFromWorldCoord(s.x, s.y, s.z + (plaque and 0.6 or 2.0))
                if onScreen then
                    local col = plaque and { 235, 215, 160 } or COLORS[s.color or 0] or { 255, 46, 154 }
                    SetTextFont(4) SetTextScale(0.0, plaque and 0.30 or 0.55) SetTextCentre(true) SetTextColour(col[1], col[2], col[3], plaque and 170 or 190) SetTextDropshadow(1, 0, 0, 0, 150) -- V12.59 : plus discret
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
