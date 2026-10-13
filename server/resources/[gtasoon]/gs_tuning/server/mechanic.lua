-- gs_tuning (serveur) : personnalisation par le mécano en service. Contrôles : métier + service, à côté du véhicule,
-- véhicule possédé par un joueur (sinon : rien à enregistrer), propriétaire en ville à côté de sa voiture (son accord),
-- réglages cosmétiques / performances seulement. La plaque n'est jamais modifiable ici (salon : gs_tuning:plate).
-- V12.36 · Avant, seul le jeu du mécano posait les réglages, et seulement s'il obtenait la main réseau sur l'entité
-- (client au volant = rien, en silence) ; puis le rangement au garage (qbx_garages relit les mods chez le client)
-- effaçait tout : la voiture ressortait d'origine. Désormais le serveur fusionne les réglages dans la carte grise,
-- les enregistre et les fait appliquer par le client PROPRIÉTAIRE RÉSEAU du véhicule (même méthode que qbx_core).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs

Mechanic = {}

-- Clés ox_lib que le mécano ne touche jamais (identité et état du véhicule) : gardées depuis la base, jamais renvoyées au jeu.
Mechanic.locked = { model = true, plate = true, lockState = true, bodyHealth = true, engineHealth = true, tankHealth = true,
    fuelLevel = true, oilLevel = true, dirtLevel = true, windows = true, doors = true, tyres = true }

local function vehicleFromNet(src, netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil, 'Véhicule introuvable.' end
    if not Security:EntityInRange(src, veh, Config.Mechanic.range) then
        return nil, ('Approche-toi du véhicule (moins de %d m).'):format(math.floor(Config.Mechanic.range))
    end
    return veh
end

--- Tout ce qu'il faut vérifier avant de toucher au véhicule : { veh, id, plate, cid } ou nil + message clair pour le mécano.
function Mechanic.check(src, netId)
    if not JobsApi:IsOnDutyAs(src, 'mechanic') then return nil, 'Réservé aux mécanos en service.' end
    local veh, err = vehicleFromNet(src, netId)
    if not veh then return nil, err end
    local id, plate, cid = Store.byPlate(GetVehicleNumberPlateText(veh))
    if not id or not cid then return nil, 'Ce véhicule n\'appartient à personne (location, service, volé ou fausse plaque) : rien à enregistrer.' end
    -- V12.36 · Le client donne son accord en restant à côté : propriétaire en ville, près de sa voiture (ou le mécano lui-même).
    local owner = Bridge:GetSourceByIdentifier(cid)
    if owner ~= src then
        if not owner then return nil, 'Le propriétaire doit être en ville : c\'est lui qui donne son accord.' end
        if not Security:EntityInRange(owner, veh, Config.Mechanic.ownerRange) then
            return nil, ('Le client doit rester à côté de son véhicule (moins de %d m).'):format(math.floor(Config.Mechanic.ownerRange))
        end
    end
    return { veh = veh, id = id, plate = plate, cid = cid }
end

lib.callback.register('gs_tuning:mechanicCheck', function(src, netId)
    if not Security:RateLimit(src, 'gs_tuning:mechanicCheck', 5, 10000) then return false, 'Doucement.' end
    local v, err = Mechanic.check(src, netId)
    return v ~= nil, err
end)

--- V12.36 · Fusionne les réglages du mécano dans ceux de la base : seules les clés cosmétiques / performances changent,
--- la carte grise garde identité et état (plaque, modèle, carburant, santé, portes, vitres, pneus).
function Mechanic.merge(current, props, model, plate)
    local merged = {}
    for k, v in pairs(current) do merged[k] = v end
    for k, v in pairs(props) do
        if type(k) == 'string' and not Mechanic.locked[k] then merged[k] = v end
    end
    merged.plate, merged.model = plate, current.model or model
    return merged
end

--- Ce que le jeu du propriétaire doit appliquer : les réglages fusionnés sans identité ni état (pas de plein ni de
--- réparation gratuits, pas de verrou changé).
function Mechanic.applicable(merged)
    local apply = {}
    for k, v in pairs(merged) do
        if not Mechanic.locked[k] then apply[k] = v end
    end
    return apply
end

lib.callback.register('gs_tuning:mechanicSave', function(src, netId, props)
    if not Security:RateLimit(src, 'gs_tuning:mechanicSave', 3, 10000) then return false, 'Doucement.' end
    local v, err = Mechanic.check(src, netId)
    if not v then return false, err end
    if type(props) ~= 'table' then return false, 'Réglages invalides.' end
    local model = GetEntityModel(v.veh)
    if props.model ~= nil and props.model ~= model then return false, 'Réglages invalides : ils ne viennent pas de ce véhicule.' end
    local current = Store.getProps(v.id)
    if type(current) ~= 'table' then return false, 'Ce véhicule n\'est plus enregistré : rien à enregistrer.' end
    if current.model and current.model ~= model then return false, 'Ce véhicule ne correspond pas à sa carte grise (fausse plaque ?).' end
    local merged = Mechanic.merge(current, props, model, v.plate)
    local encoded = json.encode(merged)
    if #encoded > Config.Mechanic.maxJson then return false, 'Réglages invalides (trop volumineux).' end
    if not Store.setProps(v.id, encoded) then return false, 'Erreur d\'enregistrement : rien n\'a été modifié, réessaie.' end
    -- V12.36 · Appliqué par le propriétaire réseau de l'entité (sinon rien ne se synchronise) : la voiture dans la rue
    -- correspond à la base, et le rangement au garage (qbx_garages relit les mods chez le client) garde la personnalisation.
    local owner = NetworkGetEntityOwner(v.veh)
    TriggerClientEvent('gs_tuning:client:applyProps', (owner and owner > 0) and owner or src,
        NetworkGetNetworkIdFromEntity(v.veh), Mechanic.applicable(merged))
    Security:LogStaff(('[Mécano] %s a personnalisé %s'):format(GetPlayerName(src) or src, v.plate), 'jobs')
    return true, ('Personnalisation enregistrée sur %s. Pense à la facture (F6).'):format(v.plate)
end)
