-- gs_tuning (serveur) : néons et plaque. Le joueur doit être conducteur d'un véhicule QUI LUI APPARTIENT, dans un salon.
-- Le serveur lit la plaque de l'entité, retrouve le véhicule en base, contrôle la plaque demandée, prélève, écrit.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Tuning = {}

local function inShop(src)
    for _, s in ipairs(Config.Shops) do
        if Security:InRange(src, s.coords, Config.Range + 2.0) then return true end
    end
    return false
end

--- Véhicule au volant → entité, plaque, id en base (nil si pas à lui) ; ou nil + message.
local function myVehicle(src)
    local ped = GetPlayerPed(src)
    local veh = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return nil, 'Il faut être au volant du véhicule.' end
    local plate = GetVehicleNumberPlateText(veh)
    local cid = Bridge:GetIdentifier(src)
    local id = cid and plate and Store.ownedByPlate(cid, plate)
    if not id then return nil, 'Ce véhicule n\'est pas dans ton garage (location, volé ou de service).' end
    return { veh = veh, plate = plate, id = id, cid = cid }
end

--- Plaque demandée : majuscules, 2 à 8 caractères A-Z 0-9 (espaces internes autorisés), pas de préfixe réservé ni de mot interdit.
function Tuning.validPlate(text)
    if type(text) ~= 'string' then return nil, 'Plaque invalide.' end
    local plate = text:upper():gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s%s+', ' ')
    if #plate < Config.PlateMin or #plate > Config.PlateMax then return nil, ('Plaque : %d à %d caractères.'):format(Config.PlateMin, Config.PlateMax) end
    if not plate:match('^[A-Z0-9 ]+$') then return nil, 'Seulement des lettres A-Z, des chiffres et des espaces.' end
    local flat = plate:gsub('%s', '')
    for _, p in ipairs(Config.ReservedPrefixes) do
        if flat:sub(1, #p) == p then return nil, 'Ce début de plaque est réservé.' end
    end
    for _, w in ipairs(Config.BannedWords) do
        if flat:find(w, 1, true) then return nil, 'Cette plaque n\'est pas autorisée.' end
    end
    return plate
end

lib.callback.register('gs_tuning:info', function(src)
    if not Security:RateLimit(src, 'gs_tuning:info', 6, 10000) then return nil end
    if not inShop(src) then return nil end
    local v, err = myVehicle(src)
    return { ok = v ~= nil, message = err, plate = v and v.plate, neonPrice = Config.NeonPrice, platePrice = Config.PlatePrice }
end)

local function pay(src, price, reason)
    return Bridge:RemoveMoney(src, 'bank', price, reason) or Bridge:RemoveMoney(src, 'cash', price, reason)
end

--- index 1..#Config.Neon = couleur ; 0 = éteindre (gratuit)
lib.callback.register('gs_tuning:neon', function(src, index)
    if not Security:RateLimit(src, 'gs_tuning:neon', 3, 10000) then return false, 'Doucement.' end
    if not inShop(src) then return false, 'Présente-toi dans un salon.' end
    index = math.floor(tonumber(index) or -1)
    local color = Config.Neon[index]
    if index ~= 0 and not color then return false, 'Couleur inconnue.' end
    local v, err = myVehicle(src)
    if not v then return false, err end
    if color and not pay(src, Config.NeonPrice, 'néons') then return false, ('Néons : %d $ (banque ou liquide).'):format(Config.NeonPrice) end
    if not Store.setNeon(v.id, v.cid, color and color.rgb or nil) then
        if color then Bridge:AddMoney(src, 'bank', Config.NeonPrice, 'remboursement néons') end
        return false, 'Erreur, rien n\'a été débité.'
    end
    return true, color and ('Néons %s posés (%d $).'):format(color.label:lower(), Config.NeonPrice) or 'Néons éteints.', color and color.rgb or nil
end)

lib.callback.register('gs_tuning:plate', function(src, text)
    if not Security:RateLimit(src, 'gs_tuning:plate', 2, 15000) then return false, 'Doucement.' end
    if not inShop(src) then return false, 'Présente-toi dans un salon.' end
    local plate, why = Tuning.validPlate(text)
    if not plate then return false, why end
    local v, err = myVehicle(src)
    if not v then return false, err end
    if plate == v.plate:gsub('^%s+', ''):gsub('%s+$', '') then return false, 'C\'est déjà ta plaque.' end
    if Store.plateTaken(plate) then return false, 'Cette plaque existe déjà.' end
    if not pay(src, Config.PlatePrice, 'plaque personnalisée') then return false, ('Plaque : %d $ (banque ou liquide).'):format(Config.PlatePrice) end
    if not Store.setPlate(v.id, v.cid, plate) then
        Bridge:AddMoney(src, 'bank', Config.PlatePrice, 'remboursement plaque')
        return false, 'Erreur, rien n\'a été débité.'
    end
    SetVehicleNumberPlateText(v.veh, plate)
    Bridge:GiveVehicleKeys(src, v.veh) -- la clé suit le véhicule : on la redonne pour la nouvelle plaque
    Security:LogStaff(('[Plaque] %s : %s → %s'):format(GetPlayerName(src) or src, v.plate, plate))
    return true, ('Nouvelle plaque : %s (%d $).'):format(plate, Config.PlatePrice), plate
end)
