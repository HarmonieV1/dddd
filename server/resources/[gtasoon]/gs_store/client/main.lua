-- gs_store (client) : /boutique. V12.41 : vitrine en jeu aux couleurs du site (web/boutique.html) : catalogue par catégorie
-- (VIP, véhicules, personnalisation, skins d'armes), « Acheter » ouvre la boutique Tebex dans le navigateur, « Mes achats »
-- pour récupérer un pack sur ce personnage, appliquer un skin ou une tenue ; RoadCoins (solde du compte, payer en jeu). Appliquer un skin ou une tenue est purement visuel.
local Bridge = exports.gs_bridge
local open, nuiReady = false, false

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

local function close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function refresh()
    local data = lib.callback.await('gs_store:data', false)
    if data and open then SendNUIMessage({ action = 'data', data = data }) end
    return data
end

local function openMenu()
    if open or IsNuiFocused() then return end
    local data = lib.callback.await('gs_store:data', false)
    if not data then return notify('Boutique indisponible pour le moment.', false) end
    open, nuiReady = true, false
    SendNUIMessage({ action = 'open', data = data })
    SetNuiFocus(true, true)
    -- V12.33 (même leçon que la garde-robe) : si l'interface ne confirme pas, on rend la main au joueur
    SetTimeout(2500, function() if open and not nuiReady then close() notify('La boutique n\'a pas pu s\'ouvrir : réessaie.', false) end end)
end

RegisterCommand('boutique', openMenu, false)
RegisterKeyMapping('boutique', 'Boutique RoadLine', 'keyboard', '') -- touche au choix du joueur (Paramètres → Raccourcis → FiveM)

RegisterNUICallback('ready', function(_, cb) nuiReady = true cb(1) end)
RegisterNUICallback('close', function(_, cb) close() cb(1) end)

RegisterNUICallback('claim', function(d, cb)
    local ok, msg = lib.callback.await('gs_store:claim', false, d and d.transaction)
    notify(msg, ok)
    cb({ ok = ok, msg = msg })
    refresh()
end)

RegisterNUICallback('buyCoins', function(d, cb) -- V12.41 : payer un article en RoadCoins (le serveur vérifie tout)
    local ok, msg = lib.callback.await('gs_store:buyCoins', false, d and d.package)
    notify(msg, ok)
    cb({ ok = ok, msg = msg })
    refresh()
end)

RegisterNUICallback('applyPed', function(d, cb)
    local model = lib.callback.await('gs_store:applyPed', false, d and d.id)
    if model then applyPed(model) end
    cb(model and 1 or 0)
end)

RegisterNUICallback('resetPed', function(_, cb)
    if lib.callback.await('gs_store:resetPed', false) then Bridge:RestoreAppearance() end
    cb(1)
end)

RegisterNUICallback('applyOutfit', function(d, cb)
    local outfit = lib.callback.await('gs_store:applyOutfit', false, d and d.id)
    if outfit then applyOutfit(outfit) end
    cb(outfit and 1 or 0)
end)

-- Skin actif réappliqué après le chargement de l'apparence (délai : l'appearance s'applique d'abord).
RegisterNetEvent('gs_store:client:applyPed', function(model)
    SetTimeout(3000, function() applyPed(model) end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
