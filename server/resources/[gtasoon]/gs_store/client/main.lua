-- gs_store (client) : /boutique. Appliquer un skin ou une tenue est purement visuel.
local Bridge = exports.gs_bridge

local function notify(msg, ok) lib.notify({ description = msg, type = ok and 'success' or 'error' }) end

local function applyPed(model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then return notify('Skin indisponible.', false) end
    lib.requestModel(hash, 10000)
    SetPlayerModel(cache.playerId, hash)
    SetPedDefaultComponentVariation(PlayerPedId())
    SetModelAsNoLongerNeeded(hash)
end

local function applyOutfit(outfit)
    local ped = PlayerPedId()
    local female = GetEntityModel(ped) == GetHashKey('mp_f_freemode_01')
    local comps = female and outfit.female or outfit.male
    if not comps then return notify('Tenue non disponible pour ce modèle.', false) end
    for component, v in pairs(comps) do
        SetPedComponentVariation(ped, tonumber(component), v[1], v[2], 0)
    end
end

local function openMenu()
    local data = lib.callback.await('gs_store:data', false)
    if not data then return end
    if not data.enabled then
        return notify('Boutique bientôt disponible. Tes achats éventuels sont bien enregistrés.', true)
    end
    local options = {}
    for _, o in ipairs(data.pending) do
        options[#options + 1] = {
            title = 'À récupérer : ' .. o.label, icon = 'gift', iconColor = '#ff2e88',
            onSelect = function()
                local answer = lib.alertDialog({
                    header = o.label, centered = true, cancel = true,
                    content = 'Ce pack sera attribué à **ce personnage**, définitivement. Continuer ?',
                })
                if answer ~= 'confirm' then return end
                local ok, msg = lib.callback.await('gs_store:claim', false, o.transaction)
                notify(msg, ok)
            end,
        }
    end
    for _, p in ipairs(data.peds) do
        options[#options + 1] = { title = 'Skin : ' .. p.label, icon = 'user-astronaut',
            onSelect = function()
                local model = lib.callback.await('gs_store:applyPed', false, p.id)
                if model then applyPed(model) end
            end }
    end
    if #data.peds > 0 then
        options[#options + 1] = { title = 'Reprendre mon apparence', icon = 'rotate-left',
            onSelect = function()
                if lib.callback.await('gs_store:resetPed', false) then Bridge:RestoreAppearance() end
            end }
    end
    for _, o in ipairs(data.outfits) do
        options[#options + 1] = { title = 'Tenue : ' .. o.label, icon = 'shirt',
            onSelect = function()
                local outfit = lib.callback.await('gs_store:applyOutfit', false, o.id)
                if outfit then applyOutfit(outfit) end
            end }
    end
    if #options == 0 then options[1] = { title = 'Rien pour le moment', readOnly = true } end
    lib.registerContext({ id = 'gs_store', title = 'Boutique', options = options })
    lib.showContext('gs_store')
end

RegisterCommand('boutique', openMenu, false)

-- Skin actif réappliqué après le chargement de l'apparence (délai : l'appearance s'applique d'abord).
RegisterNetEvent('gs_store:client:applyPed', function(model)
    SetTimeout(3000, function() applyPed(model) end)
end)
