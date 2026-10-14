-- gs_gangs (client) : territoires sur la carte (GlobalState), planque (ox_target), menu /gang (F9). 0 boucle.
local Bridge = exports.gs_bridge
local membership
local blips = {}
--- V12.40 · gang du joueur (lu par client/population.lua)
function GSGangMine() return membership and membership.gang or nil end
local stashZone

-- Carte des territoires · V12.40 : visible SEULEMENT des membres d'un gang (les autres joueurs n'ont rien sur leur carte).
-- Style épuré : quartier tenu = couleur du gang, discrète (le sien un peu plus marqué), au rayon effectif (il grandit avec
-- le niveau) ; quartier libre = pas de zone, juste un petit repère gris. Plus de grands disques blancs.
local lastState
local function drawTerritories(state)
    lastState = state
    for _, b in pairs(blips) do for _, a in ipairs(b.areas or {}) do RemoveBlip(a) end RemoveBlip(b.label) end
    blips = {}
    if not membership then return end
    for id, t in pairs(Config.Territories) do
        local s = state and state[id] or {}
        local mine = s.ownerId and s.ownerId == membership.gang
        local areas = {}
        if s.owner then -- V12.56 : pâtés de maisons alignés sur les rues (plus de disque qui déborde)
            local angle, cell = s.angle or t.angle or 0.0, s.cell or t.cell or Config.Territory.cell or 90.0
            for _, c in ipairs(Blocks.cells(t.center, s.radius or t.radius, angle, cell)) do
                local area = AddBlipForArea(c.x, c.y, c.z, cell, cell)
                SetBlipRotation(area, math.floor(angle + 0.5))
                SetBlipColour(area, s.color or 4)
                SetBlipAlpha(area, mine and 95 or math.min(85, 45 + (s.heat or 0) * 6))
                SetBlipAsShortRange(area, true)
                SetBlipDisplay(area, 3)
                areas[#areas + 1] = area
            end
        end
        local label = AddBlipForCoord(t.center.x, t.center.y, t.center.z)
        SetBlipSprite(label, 437)
        SetBlipColour(label, s.owner and s.color or 39)
        SetBlipAlpha(label, s.owner and 255 or 150)
        SetBlipScale(label, s.owner and 0.6 or 0.45)
        SetBlipAsShortRange(label, true)
        SetBlipCategory(label, 10)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(s.owner and ('%s · %s%s'):format(t.label, s.owner, (s.level or 0) > 0 and (' · niv. %d'):format(s.level) or '')
            or ('%s · libre'):format(t.label))
        EndTextCommandSetBlipName(label)
        blips[id] = { areas = areas, label = label }
    end
end

AddStateBagChangeHandler('gsTerritories', 'global', function(_, _, value) drawTerritories(value) end)
CreateThread(function() drawTerritories(GlobalState.gsTerritories) end)

-- Appartenance + planque ------------------------------------------------------------------------------
local qgBlip

AddEventHandler('gs_gangs:client:openStash', function()
    if membership then TriggerServerEvent('gs_gangs:server:stashVisit') Bridge:OpenStash('gs_gang_' .. membership.gang) end
end)

local function applyMembership(m)
    membership = m
    drawTerritories(lastState or GlobalState.gsTerritories) -- V12.40 : carte des quartiers seulement pour les membres
    if stashZone then exports.ox_target:removeZone(stashZone) stashZone = nil end
    if qgBlip then RemoveBlip(qgBlip) qgBlip = nil end
    exports.gs_markers:Remove('gs_gangs:qg')
    if m and m.stash then
        qgBlip = AddBlipForCoord(m.stash.x, m.stash.y, m.stash.z)
        SetBlipSprite(qgBlip, 437)
        SetBlipColour(qgBlip, m.color or 1)
        SetBlipScale(qgBlip, 0.85)
        SetBlipAsShortRange(qgBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('QG ' .. m.label)
        EndTextCommandSetBlipName(qgBlip)
        -- V12.37 · un PNJ posé par le staff et relié au gang ('gang:ballas') garde la planque : les membres lui parlent pour
        -- l'ouvrir ([E] reste), les autres le voient en PNJ d'ambiance (gs_markers). Lu dans GlobalState.gsStaffPeds (GsPoints).
        exports.gs_markers:Add('gs_gangs:qg', { coords = m.stash, style = 'entry', label = 'Planque ' .. m.label,
            event = 'gs_gangs:client:openStash', prompt = 'Ouvrir la planque', ped = GsPoints.pointPed(nil, 'gang:' .. m.gang) })
        stashZone = exports.ox_target:addSphereZone({
            coords = m.stash, radius = 1.5,
            options = { {
                name = 'gs_gang_stash', icon = 'fa-solid fa-box', label = 'Planque ' .. m.label,
                onSelect = function() TriggerServerEvent('gs_gangs:server:stashVisit') Bridge:OpenStash('gs_gang_' .. m.gang) end,
            } },
        })
    end
end
RegisterNetEvent('gs_gangs:client:membership', applyMembership)
-- V12.37 · PNJ du staff posé ou retiré : le PNJ de la planque est recalculé
AddStateBagChangeHandler('gsStaffPeds', 'global', function() if membership then applyMembership(membership) end end)

RegisterNetEvent('gs_gangs:client:invite', function(label)
    local answer = lib.alertDialog({
        header = 'Proposition', content = ('On te propose de rejoindre **%s**. Tu acceptes ?'):format(label),
        centered = true, cancel = true, labels = { confirm = 'Rejoindre', cancel = 'Refuser' },
    })
    TriggerServerEvent('gs_gangs:server:answer', answer == 'confirm')
end)

-- Menu ---------------------------------------------------------------------------------------------------
local function result(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function openMenu()
    local info = lib.callback.await('gs_gangs:info', false)
    if info == false then return lib.notify({ description = 'Tu n\'es dans aucun gang.', type = 'error' }) end
    if not info then return end
    local options = {
        { title = info.label, description = ('Caisse : %s $'):format(info.money), icon = 'skull', readOnly = true },
        { title = 'Déposer dans la caisse', icon = 'arrow-down', onSelect = function()
            local i = lib.inputDialog('Dépôt', { { type = 'number', label = 'Montant', min = 1, required = true } })
            if i then result(lib.callback.await('gs_gangs:bank', false, 'deposit', i[1])) end
        end },
    }
    if info.canBank then
        options[#options + 1] = { title = 'Retirer de la caisse', icon = 'arrow-up', onSelect = function()
            local i = lib.inputDialog('Retrait', { { type = 'number', label = 'Montant', min = 1, required = true } })
            if i then result(lib.callback.await('gs_gangs:bank', false, 'withdraw', i[1])) end
        end }
    end
    options[#options + 1] = { title = 'Atelier : munitions artisanales', icon = 'hammer', description = 'À la planque : ferraille + cuivre', arrow = true, onSelect = function()
        local o = {}
        for item, r in pairs(Config.AmmoCraft.recipes) do
            o[#o + 1] = { title = r.label, description = ('%d ferraille · %d cuivre · grade %d'):format(r.scrapmetal, r.copper, r.minGrade), icon = 'box', onSelect = function()
                local ok, ms = lib.callback.await('gs_gangs:craftBegin', false, item)
                if not ok then return result(false, ms) end
                local done = lib.progressBar({ duration = ms, label = 'Fabrication : ' .. r.label, canCancel = true,
                    disable = { move = true, car = true, combat = true }, anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 } })
                if not done then return TriggerServerEvent('gs_gangs:server:craftCancel') end
                result(lib.callback.await('gs_gangs:craftFinish', false))
            end }
        end
        lib.registerContext({ id = 'gs_gangs_craft', title = 'Atelier', menu = 'gs_gang', options = o })
        lib.showContext('gs_gangs_craft')
    end }
    if info.grade == 3 then
        options[#options + 1] = { title = 'Flotte du gang (chef)', icon = 'car-side', description = ('Jusqu\'à %d modèles + 1 véhicule personnalisé'):format(Config.GangFleet.max), arrow = true, onSelect = function()
            local choices = {}
            for _, mdl in ipairs(Config.GangFleet.choices) do choices[#choices + 1] = { value = mdl, label = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(mdl))) .. ' (' .. mdl .. ')' } end
            lib.registerContext({ id = 'gs_gang_fleet', title = 'Flotte du gang', menu = 'gs_gang', options = {
                { title = 'Choisir les véhicules du garage', icon = 'list-check', onSelect = function()
                    local r = lib.inputDialog('Flotte', { { type = 'multi-select', label = ('Jusqu\'à %d modèles'):format(Config.GangFleet.max), options = choices, required = true, searchable = true } })
                    if r then result(lib.callback.await('gs_gangs:setFleet', false, r[1])) end
                end },
                { title = 'Véhicule personnalisé', icon = 'palette', description = 'Modèle + 2 couleurs (0-159)', onSelect = function()
                    local r = lib.inputDialog('Véhicule personnalisé', {
                        { type = 'select', label = 'Modèle', options = choices, required = true, searchable = true },
                        { type = 'number', label = 'Couleur principale (0-159)', min = 0, max = 159, default = 0, required = true },
                        { type = 'number', label = 'Couleur secondaire (0-159)', min = 0, max = 159, default = 0, required = true } })
                    if r then result(lib.callback.await('gs_gangs:setCustom', false, r[1], r[2], r[3])) end
                end },
            } })
            lib.showContext('gs_gang_fleet')
        end }
    end
    if info.canManage then
        options[#options + 1] = { title = 'Recruter le joueur le plus proche', icon = 'user-plus', onSelect = function()
            local target = lib.getClosestPlayer(GetEntityCoords(cache.ped), Config.InviteRange, false)
            if not target then return result(false, 'Personne à proximité.') end
            result(lib.callback.await('gs_gangs:invite', false, GetPlayerServerId(target)))
        end }
    end
    local members = {}
    for _, m in ipairs(info.members) do
        members[#members + 1] = {
            title = (m.name ~= '' and m.name or m.citizenid), description = m.gradeLabel .. (m.online and ' · en ligne' or ''),
            icon = m.online and 'circle' or 'circle-dot', disabled = not info.canManage or m.citizenid == info.myCid or m.grade >= info.grade,
            onSelect = function()
                local grades = {}
                for lvl, g in pairs(Config.Grades) do if lvl < info.grade then grades[#grades + 1] = { value = tostring(lvl), label = g.label } end end
                table.sort(grades, function(a, b) return a.value < b.value end)
                local i = lib.inputDialog(m.name, {
                    { type = 'select', label = 'Action', required = true, options = { { value = 'grade', label = 'Changer le grade' }, { value = 'kick', label = 'Exclure' } } },
                    { type = 'select', label = 'Grade', options = grades },
                })
                if i then result(lib.callback.await('gs_gangs:manage', false, i[1], m.citizenid, tonumber(i[2]))) end
            end,
        }
    end
    lib.registerContext({ id = 'gs_gang_members', title = 'Membres', menu = 'gs_gang', options = members })
    options[#options + 1] = { title = ('Membres (%d)'):format(#info.members), icon = 'users', menu = 'gs_gang_members' }
    local terr = {}
    for _, t in ipairs(info.territories) do
        terr[#terr + 1] = { title = t.label, description = ('Influence %d %% · %s'):format(t.influence, t.mine and 'À VOUS' or (t.owner or 'libre')),
            progress = t.influence, colorScheme = t.mine and 'green' or 'pink', readOnly = true }
    end
    lib.registerContext({ id = 'gs_gang_terr', title = 'Territoires', menu = 'gs_gang', options = terr })
    options[#options + 1] = { title = 'Territoires', icon = 'map', menu = 'gs_gang_terr' }
    options[#options + 1] = { title = 'Guerres de territoire', icon = 'skull-crossbones', iconColor = '#ff4d6d', arrow = true, onSelect = function()
        local w = lib.callback.await('gs_gangs:wars', false)
        if not w then return result(false, 'Indisponible.') end
        local opts = {}
        local now = GetCloudTimeAsInt()
        for id, war in pairs(w.wars) do
            local left = math.max(0, (war.started and war.endsAt or war.startsAt) - now)
            opts[#opts + 1] = { title = ('%s contre %s'):format(war.attacker, war.defender), icon = 'fire', iconColor = '#ff4d6d', readOnly = true, progress = nil,
                description = ('%s · %d – %d · %s dans %d min'):format(Config.Territories[id].label, war.a, war.d, war.started and 'fin' or 'début', math.ceil(left / 60)) }
        end
        if w.canDeclare then
            for _, t in ipairs(w.targets) do
                opts[#opts + 1] = { title = ('Déclarer la guerre : %s'):format(t.label), description = ('Tenu par %s · frais %s $ (caisse)%s'):format(t.owner, w.cost,
                    w.cooldown > 0 and (' · repos ' .. math.ceil(w.cooldown / 60) .. ' min') or ''), icon = 'crosshairs', disabled = t.war,
                    onSelect = function()
                        if lib.alertDialog({ header = 'Guerre pour ' .. t.label, content = ('Préavis de 10 min, puis 20 min de combat. Frais : %s $.'):format(w.cost), centered = true, cancel = true }) == 'confirm' then
                            result(lib.callback.await('gs_gangs:declareWar', false, t.id))
                        end
                    end }
            end
        end
        if #opts == 0 then opts[1] = { title = 'Aucune guerre. Aucun quartier ennemi à attaquer pour l\'instant.', icon = 'dove', readOnly = true } end
        lib.registerContext({ id = 'gs_gang_wars', title = 'Guerres de territoire', menu = 'gs_gang', options = opts })
        lib.showContext('gs_gang_wars')
    end }
    -- V12 · Opérations (guerre de l'information), payées par la caisse
    if info.grade >= 2 then
        options[#options + 1] = { title = 'Opérations', icon = 'satellite-dish', iconColor = '#ffb347', arrow = true, description = 'Brouiller les caméras, pirater le scanner police', onSelect = function()
            local o = {}
            for kind, def in pairs(Config.Ops) do
                o[#o + 1] = { title = def.label, icon = def.icon, description = ('%d $ (caisse) · %d min · grade %d · la police peut remonter la source'):format(def.cost, def.minutes, def.minGrade),
                    onSelect = function()
                        if lib.alertDialog({ header = def.label, content = def.help, centered = true, cancel = true }) == 'confirm' then
                            result(lib.callback.await('gs_gangs:op', false, kind))
                        end
                    end }
            end
            table.sort(o, function(a, b) return a.title < b.title end)
            lib.registerContext({ id = 'gs_gang_ops', title = 'Opérations', menu = 'gs_gang', options = o })
            lib.showContext('gs_gang_ops')
        end }
    end
    options[#options + 1] = { title = 'Quitter le gang', icon = 'door-open', iconColor = '#ff2e88', onSelect = function()
        if lib.alertDialog({ header = 'Quitter le gang', content = 'Sûr ?', centered = true, cancel = true }) == 'confirm' then
            TriggerServerEvent('gs_gangs:server:leave')
        end
    end }
    lib.registerContext({ id = 'gs_gang', title = 'Gang', options = options })
    lib.showContext('gs_gang')
end

RegisterCommand('gang', function()
    if lib.getOpenContextMenu() then return lib.hideContext() end -- même touche = fermer
    if IsNuiFocused() then return end -- V11.5 : jamais pendant une saisie ou une autre interface
    openMenu()
end, false)
RegisterKeyMapping('gang', 'Menu gang', 'keyboard', Config.Key)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in pairs(blips) do RemoveBlip(b.area) RemoveBlip(b.label) end
end)
