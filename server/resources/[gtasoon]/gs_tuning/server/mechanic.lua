-- gs_tuning (serveur) : personnalisation par le mécano en service. Contrôles : métier + service, à côté du véhicule,
-- véhicule possédé par un joueur (sinon : rien à enregistrer), réglages de forme raisonnable. La plaque n'est jamais
-- modifiable ici (salon : gs_tuning:plate).
local Security = exports.gs_security
local JobsApi  = exports.gs_jobs

local function vehicleFromNet(src, netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil, 'Véhicule introuvable.' end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > 8.0 then return nil, 'Trop loin du véhicule.' end
    return veh
end

local function check(src, netId)
    if not JobsApi:IsOnDutyAs(src, 'mechanic') then return nil, 'Réservé aux mécanos en service.' end
    local veh, err = vehicleFromNet(src, netId)
    if not veh then return nil, err end
    local id, plate = Store.byPlate(GetVehicleNumberPlateText(veh))
    if not id then return nil, 'Ce véhicule n\'appartient à personne (location, service, volé).' end
    return veh, id, plate
end

lib.callback.register('gs_tuning:mechanicCheck', function(src, netId)
    if not Security:RateLimit(src, 'gs_tuning:mechanicCheck', 5, 10000) then return false, 'Doucement.' end
    local veh, err = check(src, netId)
    return veh ~= nil, err
end)

lib.callback.register('gs_tuning:mechanicSave', function(src, netId, props)
    if not Security:RateLimit(src, 'gs_tuning:mechanicSave', 3, 10000) then return false, 'Doucement.' end
    local veh, id, plate = check(src, netId)
    if not veh then return false, id end
    if type(props) ~= 'table' then return false, 'Réglages invalides.' end
    props.plate = plate -- jamais changée ici
    local encoded = json.encode(props)
    if #encoded > 16000 then return false, 'Réglages invalides.' end
    if not Store.setProps(id, encoded) then return false, 'Erreur d\'enregistrement.' end
    Security:LogStaff(('[Mécano] %s a personnalisé %s'):format(GetPlayerName(src) or src, plate), 'jobs')
    return true, ('Personnalisation enregistrée sur %s. Pense à la facture (F6).'):format(plate)
end)
