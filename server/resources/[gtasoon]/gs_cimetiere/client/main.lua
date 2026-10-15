-- gs_cimetiere (client) · V12.60. Pierres tombales créées à l'approche (objets locaux), Alt : lire l'épitaphe, déposer des
-- fleurs ; fleurs et bougie visibles 72 h après un dépôt ; nom et épitaphe écrits discrètement, de près seulement.
local spawned = {} -- [id] = { stone, flower… }
local near = {}    -- tombes à moins de Config.TextRange (texte)
local stoneModel

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function pickStone()
    if stoneModel then return stoneModel end
    for _, m in ipairs(Config.Stones) do if IsModelInCdimage(GetHashKey(m)) then stoneModel = m return m end end
end

local function prop(model, x, y, z, h)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 3000) then return nil end
    local o = CreateObject(hash, x, y, z, false, false, false)
    SetEntityHeading(o, h or 0.0) PlaceObjectOnGroundProperly(o) FreezeEntityPosition(o, true)
    SetModelAsNoLongerNeeded(hash)
    return o
end

local function clear(id)
    for _, e in ipairs(spawned[id] or {}) do
        if e and DoesEntityExist(e) then exports.ox_target:removeLocalEntity(e) DeleteEntity(e) end
    end
    spawned[id] = nil
end

local function build(g)
    local ents = {}
    local m = pickStone()
    local stone = m and prop(m, g.x, g.y, g.z, g.h)
    if stone then
        ents[#ents + 1] = stone
        exports.ox_target:addLocalEntity(stone, {
            { name = 'gs_cimetiere_read', icon = 'fas fa-cross', label = 'Lire l\'épitaphe', distance = 2.5,
              onSelect = function()
                  lib.alertDialog({ header = g.name, centered = true, labels = { confirm = 'Fermer' },
                      content = ('*Parti(e) le %s*\n\n%s'):format(g.died or '?', g.epitaph ~= '' and ('« ' .. g.epitaph .. ' »') or '') })
              end },
            { name = 'gs_cimetiere_flowers', icon = 'fas fa-seedling', label = ('Déposer des fleurs (%d $)'):format(Config.FlowerPrice), distance = 2.5,
              onSelect = function()
                  if not lib.progressBar({ duration = 4000, label = 'Tu déposes des fleurs…', canCancel = true,
                      anim = { dict = 'anim@heists@narcotics@trash', clip = 'drop_front' }, disable = { move = true, car = true, combat = true } }) then return end
                  notify(lib.callback.await('gs_cimetiere:flowers', false, g.id))
              end },
        })
    end
    if g.flowers then -- fleurs et bougie devant la pierre (72 h après le dernier dépôt)
        local h = math.rad(g.h or 0.0)
        local fx, fy = -math.sin(h), math.cos(h)
        for i, fm in ipairs(Config.Flowers) do
            local side = (i == 1) and -0.35 or 0.35
            ents[#ents + 1] = prop(fm, g.x + fx * 0.8 + fy * side, g.y + fy * 0.8 - fx * side, g.z, g.h)
        end
    end
    return ents
end

-- Tombes à l'approche (toutes les 2 s) ; un changement (fleurs, nouvelle tombe) refait la tombe concernée
local last = {}
CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        local alive, close = {}, {}
        for _, g in ipairs(GlobalState.gsGraves or {}) do
            alive[g.id] = true
            local d = #(me - vec3(g.x, g.y, g.z))
            local sig = ('%s|%s|%s'):format(g.name, g.flowers and 1 or 0, g.x)
            if spawned[g.id] and last[g.id] ~= sig then clear(g.id) end
            if d < 70.0 and not spawned[g.id] then spawned[g.id] = build(g) last[g.id] = sig
            elseif d > 100.0 and spawned[g.id] then clear(g.id) end
            if d < Config.TextRange then close[#close + 1] = g end
        end
        for id in pairs(spawned) do if not alive[id] then clear(id) end end
        near = close
        Wait(2000)
    end
end)

-- Nom et épitaphe : petits, de près seulement (dessinés par frame uniquement quand une tombe est à moins de 4 m)
CreateThread(function()
    while true do
        if #near == 0 then Wait(1000) else
            for _, g in ipairs(near) do
                local on, x, y = GetScreenCoordFromWorldCoord(g.x, g.y, g.z + 1.15)
                if on then
                    SetTextFont(4) SetTextScale(0.0, 0.32) SetTextCentre(true) SetTextColour(235, 225, 200, 190) SetTextDropshadow(1, 0, 0, 0, 160)
                    BeginTextCommandDisplayText('STRING')
                    AddTextComponentSubstringPlayerName(('%s · %s'):format(g.name, g.died or ''))
                    EndTextCommandDisplayText(x, y)
                end
            end
            Wait(0) -- par frame : seulement quand une tombe est à moins de 4 m (texte affiché)
        end
    end
end)

-- Menu staff (F11 → Monde et lieux → Cimetière ; F11 → Joueurs → le joueur → Mort RP) -----------------------------------------
local staffMenu
staffMenu = function()
    local ok, list = lib.callback.await('gs_cimetiere:staff', false, 'list')
    if not ok then return notify(false, list) end
    local o = {
        { title = 'Nouvelle tombe (carré du cimetière)', icon = 'cross', description = 'Nom, épitaphe : posée au prochain emplacement libre, avis de décès publié',
          onSelect = function()
              local r = lib.inputDialog('Nouvelle tombe', { { type = 'input', label = 'Nom (personnage)', required = true, max = Config.Max.name },
                  { type = 'input', label = 'Épitaphe', max = Config.Max.epitaph } })
              if r then notify(lib.callback.await('gs_cimetiere:staff', false, 'bury', { name = r[1], epitaph = r[2] })) end
              staffMenu()
          end },
        { title = 'Nouvelle tombe ICI (à mes pieds)', icon = 'location-dot', description = 'Même chose, posée là où tu es',
          onSelect = function()
              local r = lib.inputDialog('Nouvelle tombe ici', { { type = 'input', label = 'Nom (personnage)', required = true, max = Config.Max.name },
                  { type = 'input', label = 'Épitaphe', max = Config.Max.epitaph } })
              if r then notify(lib.callback.await('gs_cimetiere:staff', false, 'bury', { name = r[1], epitaph = r[2], here = true })) end
              staffMenu()
          end },
    }
    for _, g in ipairs(list) do
        o[#o + 1] = { title = g.name, icon = 'cross', arrow = true, description = ('%s · %s'):format(g.died or '?', g.flowers and 'fleuri' or 'sans fleurs'),
            onSelect = function()
                lib.registerContext({ id = 'gs_cimetiere_grave', title = g.name, menu = 'gs_cimetiere_staff', options = {
                    { title = 'Y aller', icon = 'location-arrow', onSelect = function() SetEntityCoords(cache.ped, g.x + 1.5, g.y, g.z + 0.5, false, false, false, false) end },
                    { title = 'Retirer la tombe', icon = 'trash', iconColor = '#ff6b6b', onSelect = function()
                        if lib.alertDialog({ header = 'Retirer la tombe de ' .. g.name .. ' ?', centered = true, cancel = true, content = 'Elle disparaît pour tout le monde.' }) == 'confirm' then
                            notify(lib.callback.await('gs_cimetiere:staff', false, 'remove', { id = g.id }))
                        end
                        staffMenu()
                    end },
                } })
                lib.showContext('gs_cimetiere_grave')
            end }
    end
    lib.registerContext({ id = 'gs_cimetiere_staff', title = ('Cimetière (%d tombe%s)'):format(#list, #list > 1 and 's' or ''), options = o })
    lib.showContext('gs_cimetiere_staff')
end
exports('OpenStaffMenu', function() staffMenu() end)

--- Mort RP d'un joueur (appelé depuis la fiche joueur du menu staff)
exports('PlayerDeath', function(target, name)
    local r = lib.inputDialog('Mort RP de ' .. (name or '?'), { { type = 'input', label = 'Épitaphe (facultative)', max = Config.Max.epitaph } })
    if not r then return end
    if lib.alertDialog({ header = 'Confirmer la mort RP', centered = true, cancel = true,
        content = 'Une tombe est posée au cimetière et l\'avis de décès est publié (Weazel, Gazette). Le personnage n\'est PAS supprimé.' }) ~= 'confirm' then return end
    notify(lib.callback.await('gs_cimetiere:staff', false, 'player', { target = target, epitaph = r[1] }))
end)

-- Blip du cimetière
CreateThread(function()
    local o = Config.Origin
    local b = AddBlipForCoord(o.x, o.y, o.z)
    SetBlipSprite(b, 305) SetBlipColour(b, 0) SetBlipScale(b, 0.7) SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Cimetière') EndTextCommandSetBlipName(b)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(spawned) do clear(id) end
end)
