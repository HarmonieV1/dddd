-- gs_driving (client) : accueil de l'auto-école, QCM (ox_lib), examen (point suivant + GPS), menu moniteur (/moniteur).
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 7000 }) end end
local exam  -- { cp }
local blip
local snapped = {}

--- Point d'examen recollé à la route la plus proche (nœud de circulation GTA), pour qu'il ne tombe jamais sur un
--- trottoir ou une pelouse. Calculé une fois par point.
local function routePoint(i)
    local p = Config.Practical.route[i]
    if not p then return nil end
    if snapped[i] then return snapped[i] end
    local found, node = GetClosestVehicleNode(p.x, p.y, p.z, 0, 3.0, 0)
    snapped[i] = (found and node and #(node - p) <= (Config.Practical.snapMax or 0)) and vec3(node.x, node.y, node.z) or p
    return snapped[i]
end

local function nextPoint()
    if blip then RemoveBlip(blip) blip = nil end
    if not exam then return end
    local p = routePoint(exam.cp + 1)
    if not p then return end
    blip = AddBlipForCoord(p.x, p.y, p.z)
    SetBlipSprite(blip, 1) SetBlipColour(blip, 5) SetBlipRoute(blip, true)
end

local function runExam()
    CreateThread(function()
        while exam do
            local p = routePoint(exam.cp + 1)
            if p then
                DrawMarker(1, p.x, p.y, p.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 6.0, 6.0, 2.0, 40, 224, 255, 110, false, false, 2, false, nil, nil, false)
                if cache.vehicle and #(GetEntityCoords(cache.vehicle) - p) <= Config.Practical.checkpointRadius then
                    local ok, cp = lib.callback.await('gs_driving:checkpoint', false)
                    if ok and cp and exam then exam.cp = cp nextPoint() PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true) end
                    Wait(400)
                end
            end
            Wait(0)
        end
    end)
end

local function quiz()
    local ok, questions = lib.callback.await('gs_driving:theoryStart', false)
    if not ok then return notify(false, questions) end
    local answers = {}
    for i, q in ipairs(questions) do
        local opts = {}
        for j, o in ipairs(q.options) do opts[j] = { value = tostring(j), label = o } end
        local r = lib.inputDialog(('Code %d / %d'):format(i, #questions), { { type = 'select', label = q.q, options = opts, required = true } })
        answers[i] = r and tonumber(r[1]) or 0
    end
    notify(lib.callback.await('gs_driving:theoryAnswer', false, answers))
end

AddEventHandler('gs_driving:client:desk', function()
    local info = lib.callback.await('gs_driving:info', false)
    if not info then return notify(false, 'Accueil indisponible.') end
    local labels = { [0] = 'Aucun : commence par le code', [1] = 'Code obtenu : il reste la conduite', [2] = 'Permis obtenu' }
    lib.registerContext({ id = 'gs_driving', title = 'Auto-école', options = {
        { title = labels[info.status], icon = 'id-card', readOnly = true },
        { title = ('Passer le code (%d $)'):format(info.theoryPrice), icon = 'book', disabled = info.status >= 1, onSelect = quiz },
        { title = ('Examen de conduite (%d $)'):format(info.practicalPrice), icon = 'car', disabled = info.status ~= 1, onSelect = function()
            local ok, res = lib.callback.await('gs_driving:practicalStart', false)
            if not ok then return notify(false, res) end
            exam = { cp = 0 }
            nextPoint()
            runExam()
            notify(true, 'Suis les points, respecte les 80 km/h et ne casse rien. Bonne chance !')
        end },
    } })
    lib.showContext('gs_driving')
end)

RegisterNetEvent('gs_driving:client:fault', function(what, n, max)
    lib.notify({ title = 'Faute : ' .. what, description = ('%d / %d fautes autorisées'):format(n, max), type = 'warning' })
end)

RegisterNetEvent('gs_driving:client:end', function(passed, why)
    exam = nil
    if blip then RemoveBlip(blip) blip = nil end
    if why then lib.notify({ title = 'Examen de conduite', description = why, type = passed and 'success' or 'error', duration = 10000 }) end
end)

RegisterCommand('moniteur', function()
    local target = lib.getClosestPlayer(GetEntityCoords(cache.ped), 5.0, false)
    if not target then return notify(false, 'Aucun candidat à côté de toi.') end
    if lib.alertDialog({ header = 'Délivrer le permis ?', content = 'Le candidat a réussi l\'examen encadré.', centered = true, cancel = true }) == 'confirm' then
        notify(lib.callback.await('gs_driving:grant', false, GetPlayerServerId(target)))
    end
end, false)

CreateThread(function()
    exports.gs_markers:Add('gs_driving:desk', { coords = Config.Desk, style = 'job', label = 'Auto-école', event = 'gs_driving:client:desk',
        prompt = 'Auto-école (code, examen)', distance = 20.0 })
    local b = AddBlipForCoord(Config.Desk.x, Config.Desk.y, Config.Desk.z)
    SetBlipSprite(b, 545) SetBlipColour(b, 3) SetBlipScale(b, 0.75) SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Auto-école') EndTextCommandSetBlipName(b)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    exports.gs_markers:RemovePrefix('gs_driving:')
end)

-- V8 · Permis à points : /permis
RegisterCommand('permis', function()
    local pts, max = lib.callback.await('gs_driving:points', false)
    if not pts then return notify(false, 'Pas de permis de conduire valide. Direction l\'auto-école !') end
    lib.notify({ title = 'Permis de conduire', description = ('Solde : %d / %d points'):format(pts, max), type = pts > 6 and 'success' or 'warning',
        icon = 'id-card', duration = 7000 })
end, false)
