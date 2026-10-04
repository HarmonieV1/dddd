-- gs_insurance (client) : guichet Mors Mutual, liste des véhicules avec prime et jours restants.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

AddEventHandler('gs_insurance:client:open', function()
    local data = lib.callback.await('gs_insurance:list', false)
    if not data then return notify(false, 'Guichet indisponible.') end
    local options = {}
    for _, v in ipairs(data.vehicles) do
        options[#options + 1] = { title = ('%s · %s'):format(v.model, v.plate), icon = v.daysLeft > 0 and 'shield-halved' or 'car-burst',
            iconColor = v.daysLeft > 0 and '#5aff8c' or '#ff8a3d',
            description = ('%s · prime %d $ / %d jours (fourrière à %d %%)'):format(v.daysLeft > 0 and ('assuré encore %d j'):format(v.daysLeft) or 'non assuré',
                v.premium, data.days, math.floor(data.factor * 100)),
            onSelect = function()
                notify(lib.callback.await('gs_insurance:buy', false, v.id))
                TriggerEvent('gs_insurance:client:open')
            end }
        if v.claim then -- V9 : dossier de vol en cours
            options[#options + 1] = { title = ('   ↳ Dossier de vol : %s'):format(({ pending = 'enquête de l\'expert', paid = 'indemnisé', fraud = 'fraude constatée' })[v.claim] or v.claim),
                icon = 'file-shield', readOnly = true }
        elseif v.daysLeft > 0 then
            options[#options + 1] = { title = '   ↳ Déclarer ce véhicule volé', icon = 'user-secret', iconColor = '#ff5470',
                description = 'L\'expert recoupe avec le carnet du véhicule. Fausse déclaration = casier + remboursement majoré.',
                onSelect = function()
                    local yes = lib.alertDialog({ header = 'Déclaration de vol', content = ('Déclarer %s (%s) volé ?'):format(v.model, v.plate), centered = true, cancel = true })
                    if yes ~= 'confirm' then return end
                    notify(lib.callback.await('gs_insurance:claim', false, v.id))
                end }
        end
    end
    if #options == 0 then options[1] = { title = 'Aucun véhicule à ton nom', icon = 'car', readOnly = true } end
    lib.registerContext({ id = 'gs_insurance_menu', title = 'Assurance auto', options = options })
    lib.showContext('gs_insurance_menu')
end)

CreateThread(function()
    local c = Config.Counter
    exports.gs_markers:Add('gs_insurance:counter', { coords = c.coords, style = 'shop', label = c.label, event = 'gs_insurance:client:open',
        prompt = 'Assurance auto', distance = 20.0 })
    local b = AddBlipForCoord(c.coords.x, c.coords.y, c.coords.z)
    SetBlipSprite(b, 525) SetBlipColour(b, 3) SetBlipScale(b, 0.7) SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(c.label) EndTextCommandSetBlipName(b)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then exports.gs_markers:RemovePrefix('gs_insurance:') end
end)
