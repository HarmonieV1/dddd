-- gs_furniture (client) · V12.42 Mobilier utilisable : Alt sur un banc, une chaise, un lit, un matelas, un fauteuil roulant…
-- (objets posés au F11 → Mapping ET objets de la ville, mêmes modèles) : s'asseoir, s'allonger, rouler en fauteuil.
--  - assis / allongé : personnage figé à la place (animation en boucle), X pour se lever ; place occupée = refusée ;
--  - fauteuil roulant : le fauteuil de la ville est caché (chez tout le monde, via le state bag gsWheel) et remplacé par un
--    fauteuil réseau auquel le personnage est accroché ; Z / S avancer / reculer, Q / D tourner, Maj plus vite, bloqué
--    par les murs et les marches (> 35 cm) ; X pour se lever : le fauteuil retourne à sa place ;
--  - PgUp / PgDn (hauteur) et flèches gauche / droite (rotation) pendant la pose : la ligne à recopier dans
--    Config.Furniture s'affiche en F8 (pour caler un modèle une fois pour toutes).
local F = Config.Furniture
local using -- { kind, ent, model, cfg, pos, heading, adj = { z, h }, chair, hidden }
local hidden = {} -- [serverId] = objet de la ville caché pendant qu'un joueur roule avec

local function notify(msg, ok) lib.notify({ description = msg, type = ok and 'success' or 'error' }) end

local function rot(x, y, h)
    local r = math.rad(h)
    return x * math.cos(r) - y * math.sin(r), x * math.sin(r) + y * math.cos(r)
end

--- Place (monde) d'un siège : décalage local (x de la place, y, z) tourné selon l'objet.
local function seatPos(ent, cfg, sx)
    local c, h = GetEntityCoords(ent), GetEntityHeading(ent)
    local dx, dy = rot(sx or 0.0, cfg.y or 0.0, h)
    return vec3(c.x + dx, c.y + dy, c.z + (cfg.z or 0.5)), (h + (cfg.h or 0.0)) % 360.0
end

local function occupied(pos)
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= cache.ped and #(GetEntityCoords(ped) - pos) < 0.45 then return true end
    end
    return false
end

local function playLoop(ped, a)
    if not pcall(lib.requestAnimDict, a.dict, 3000) then return false end
    TaskPlayAnim(ped, a.dict, a.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    RemoveAnimDict(a.dict)
    return true
end

local function printLine()
    if not using then return end
    local c = using.cfg
    print(('[gs_furniture] Mobilier · %s = { kind = \'%s\', z = %.2f, y = %.2f, h = %.1f },'):format(using.model, c.kind,
        (c.z or 0.5) + using.adj.z, c.y or 0.0, ((c.h or 0.0) + using.adj.h) % 360.0))
end

local function standUp()
    if not using then return end
    local u = using
    using = nil
    lib.hideTextUI()
    local ped = cache.ped
    if u.chair and DoesEntityExist(u.chair) then
        DetachEntity(ped, true, false)
        DeleteEntity(u.chair)
    end
    if u.kind == 'wheel' then LocalPlayer.state:set('gsWheel', nil, true) end
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    -- un pas devant la place, posé au sol
    local p, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local fx, fy = rot(0.0, 0.7, h)
    local ok, gz = GetGroundZFor_3dCoord(p.x + fx, p.y + fy, p.z + 1.0, false)
    SetEntityCoords(ped, p.x + fx, p.y + fy, ok and gz or p.z, false, false, false, false)
end

-- Assis / allongé ------------------------------------------------------------------------------------------------
local function pose(ent, model, cfg)
    local best, bestD
    local me = GetEntityCoords(cache.ped)
    for _, sx in ipairs(cfg.seats or { 0.0 }) do
        local pos = seatPos(ent, cfg, sx)
        if not occupied(pos) and (not bestD or #(pos - me) < bestD) then best, bestD = sx, #(pos - me) end
    end
    if not best then return notify('Place occupée.', false) end
    using = { kind = cfg.kind, ent = ent, model = model, cfg = cfg, seat = best, adj = { z = 0.0, h = 0.0 } }
    local ped = cache.ped
    local function apply()
        local pos, h = seatPos(ent, cfg, using.seat)
        SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z + using.adj.z, false, false, false)
        SetEntityHeading(ped, (h + using.adj.h) % 360.0)
    end
    ClearPedTasksImmediately(ped)
    apply()
    FreezeEntityPosition(ped, true)
    if not playLoop(ped, F.anims[cfg.kind]) then return standUp() end
    lib.showTextUI('[X] Se lever · PgUp / PgDn : hauteur · ← → : tourner', { icon = cfg.kind == 'lie' and 'bed' or 'chair' })
    CreateThread(function()
        local anim = F.anims[cfg.kind]
        while using and using.ent == ent do
            local ped2 = cache.ped
            if IsEntityDead(ped2) or IsPedRagdoll(ped2) or IsControlJustPressed(0, F.keyUp) then break end
            local changed = false
            if IsControlJustPressed(0, 10) then using.adj.z = using.adj.z + 0.02 changed = true end
            if IsControlJustPressed(0, 11) then using.adj.z = using.adj.z - 0.02 changed = true end
            if IsControlJustPressed(0, 174) then using.adj.h = using.adj.h + 5.0 changed = true end
            if IsControlJustPressed(0, 175) then using.adj.h = using.adj.h - 5.0 changed = true end
            if changed then apply() printLine() end
            if not IsEntityPlayingAnim(ped2, anim.dict, anim.clip, 3) then playLoop(ped2, anim) end
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) -- pas de tir assis
            Wait(0)
        end
        if using and using.ent == ent then standUp() end
    end)
end

-- Fauteuil roulant ---------------------------------------------------------------------------------------------------
local ALLOWED = { 1, 2, 0, 26, 245, 249, 288, 289, 170, 166, 167, 168 } -- caméra, regard, chat, micro, F1 F2 F3 F5 F6 F7

local function roll(ent, model, cfg)
    local origin = GetEntityCoords(ent)
    for _, o in pairs(hidden) do
        if o == ent then return notify('Quelqu\'un roule déjà avec ce fauteuil.', false) end
    end
    local hash = GetEntityModel(ent)
    local ped = cache.ped
    local chair = CreateObject(hash, origin.x, origin.y, origin.z, true, true, false)
    if not chair or chair == 0 then return notify('Fauteuil indisponible.', false) end
    SetEntityHeading(chair, GetEntityHeading(ent))
    FreezeEntityPosition(chair, true)
    SetEntityCollision(chair, false, false)
    LocalPlayer.state:set('gsWheel', { x = origin.x, y = origin.y, z = origin.z, model = hash }, true) -- cache le fauteuil d'origine chez tous
    using = { kind = 'wheel', ent = ent, model = model, cfg = cfg, chair = chair, adj = { z = 0.0, h = 0.0 } }
    local function attach()
        AttachEntityToEntity(ped, chair, 0, 0.0, cfg.y or 0.0, (cfg.z or 0.55) + using.adj.z, 0.0, 0.0, (cfg.h or 180.0) + using.adj.h,
            false, false, false, true, 2, true)
    end
    ClearPedTasksImmediately(ped)
    attach()
    playLoop(ped, F.anims.wheel)
    lib.showTextUI('[Z/S] Rouler · [Q/D] Tourner · [Maj] Plus vite · [X] Se lever', { icon = 'wheelchair' })
    CreateThread(function()
        local pos, heading = GetEntityCoords(chair), GetEntityHeading(chair)
        while using and using.chair == chair and DoesEntityExist(chair) do
            local p = cache.ped
            if IsEntityDead(p) or IsPedRagdoll(p) or IsEntityInWater(chair) then break end
            DisableAllControlActions(0)
            for _, c in ipairs(ALLOWED) do EnableControlAction(0, c, true) end
            if IsDisabledControlJustPressed(0, F.keyUp) then break end
            local dt = GetFrameTime()
            local turn = (IsDisabledControlPressed(0, 34) and 1 or 0) - (IsDisabledControlPressed(0, 35) and 1 or 0)
            local dir = (IsDisabledControlPressed(0, 32) and 1 or 0) - (IsDisabledControlPressed(0, 33) and 0.6 or 0)
            if turn ~= 0 then heading = (heading + turn * F.turnSpeed * dt) % 360.0 SetEntityHeading(chair, heading) end
            if dir ~= 0 then
                local speed = F.rollSpeed * (IsDisabledControlPressed(0, 21) and 1.8 or 1.0) * dir * dt
                local fx, fy = rot(0.0, 1.0, heading)
                local nx, ny = pos.x + fx * speed, pos.y + fy * speed
                -- mur / objet devant (à hauteur de genou), en regardant 40 cm plus loin
                local probe = StartExpensiveSynchronousShapeTestLosProbe(pos.x, pos.y, pos.z + 0.45,
                    nx + fx * 0.4 * (dir > 0 and 1 or -1), ny + fy * 0.4 * (dir > 0 and 1 or -1), pos.z + 0.45, 1 | 16, chair, 4)
                local _, hit = GetShapeTestResult(probe)
                local ok, gz = GetGroundZFor_3dCoord(nx, ny, pos.z + 0.6, false)
                if hit ~= 1 and ok and math.abs(gz - pos.z) < 0.35 then
                    pos = vec3(nx, ny, gz)
                    SetEntityCoordsNoOffset(chair, pos.x, pos.y, pos.z, false, false, false)
                end
            end
            if IsDisabledControlJustPressed(0, 10) then using.adj.z = using.adj.z + 0.02 attach() printLine() end
            if IsDisabledControlJustPressed(0, 11) then using.adj.z = using.adj.z - 0.02 attach() printLine() end
            if not IsEntityPlayingAnim(p, F.anims.wheel.dict, F.anims.wheel.clip, 3) then playLoop(p, F.anims.wheel) end
            Wait(0)
        end
        if using and using.chair == chair then standUp() end
    end)
end

-- Fauteuil d'origine caché chez tout le monde pendant qu'un joueur roule avec (et remis ensuite)
AddStateBagChangeHandler('gsWheel', nil, function(bagName, _, value)
    local sid = tonumber(tostring(bagName):match('^player:(%d+)$'))
    if not sid then return end
    local prev = hidden[sid]
    if prev then
        if DoesEntityExist(prev) then SetEntityVisible(prev, true, false) SetEntityCollision(prev, true, true) end
        hidden[sid] = nil
    end
    if type(value) == 'table' and value.x then
        local o = GetClosestObjectOfType(value.x + 0.0, value.y + 0.0, value.z + 0.0, 1.0, value.model or GetHashKey('prop_wheelchair_01'), false, false, false)
        if o and o ~= 0 then
            SetEntityVisible(o, false, false)
            SetEntityCollision(o, false, false)
            hidden[sid] = o
        end
    end
end)

-- Alt sur les modèles ---------------------------------------------------------------------------------------------------
CreateThread(function()
    local byKind = { sit = {}, lie = {}, wheel = {} }
    for model, cfg in pairs(F.models) do byKind[cfg.kind][#byKind[cfg.kind] + 1] = model end
    local function free() return using == nil and not IsPedInAnyVehicle(cache.ped, false) and not IsEntityDead(cache.ped) end
    local function handler(fn)
        return function(data)
            local ent = data.entity
            local model
            for m in pairs(F.models) do if GetEntityModel(ent) == GetHashKey(m) then model = m break end end
            if model then fn(ent, model, F.models[model]) end
        end
    end
    exports.ox_target:addModel(byKind.sit, { -- [API] ox_target
        { name = 'gs_furniture_sit', icon = 'fa-solid fa-chair', label = 'S\'asseoir', distance = 2.0, canInteract = free, onSelect = handler(pose) },
    })
    exports.ox_target:addModel(byKind.lie, {
        { name = 'gs_furniture_lie', icon = 'fa-solid fa-bed', label = 'S\'allonger', distance = 2.0, canInteract = free, onSelect = handler(pose) },
    })
    exports.ox_target:addModel(byKind.wheel, {
        { name = 'gs_furniture_wheel', icon = 'fa-solid fa-wheelchair', label = 'S\'asseoir et rouler', distance = 2.0, canInteract = free, onSelect = handler(roll) },
        { name = 'gs_furniture_wheelsit', icon = 'fa-solid fa-chair', label = 'S\'asseoir', distance = 2.0, canInteract = free,
          onSelect = handler(function(ent, model, cfg) pose(ent, model, { kind = 'sit', z = cfg.z, y = cfg.y, h = cfg.h }) end) },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if using then standUp() end
    for _, o in pairs(hidden) do if DoesEntityExist(o) then SetEntityVisible(o, true, false) SetEntityCollision(o, true, true) end end
end)
