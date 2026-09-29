-- GTA SOON : copie de qbx_garages/server/default-calculate-impound-fee.lua + rabais d'assurance (gs_insurance).
-- Posé automatiquement par INSTALLER.bat / METTRE-A-JOUR.bat.
local logger = require '@qbx_core.modules.logger'

---Calcule la fourrière : 2 % du prix du véhicule, × facteur d'assurance (gs_insurance : 0,25 si assuré).
---@param vehicleId number
---@param modelName string
---@return number
local defaultCalculateImpoundFee = function(vehicleId, modelName)
    local vehicleInfo = VEHICLES[modelName]

    if not vehicleInfo then
        logger.log({
            message = string.format("The model name %s does not exist in the vehicle list. Cannot calculate impound fee.", modelName),
            webhook = Config.logging.webhook.error, event = 'error', color = 'red'
        })
        return 0
    end

    local factor = 1.0
    if GetResourceState('gs_insurance') == 'started' then
        factor = exports.gs_insurance:GetImpoundFactor(vehicleId) or 1.0
    end
    local impoundFee = qbx.math.round(vehicleInfo.price * 0.02 * factor)

    logger.log({
        message = string.format("Calculated impound fee for vehicle model %s (ID: %d) is: %d, based on a price of %d (assurance x%.2f).",
            modelName, vehicleId, impoundFee, vehicleInfo.price, factor),
        webhook = Config.logging.webhook.default, event = 'info', color = 'blue'
    })

    return impoundFee
end

return defaultCalculateImpoundFee
