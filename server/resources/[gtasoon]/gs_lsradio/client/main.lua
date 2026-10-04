-- gs_lsradio (client) : l'animateur ne parle qu'à ceux qui roulent radio allumée. Sous-titre natif du jeu (aucune
-- interface, aucune boucle) + petit jingle. /radiols pour couper ou rallumer.
local on = GetResourceKvpInt('gs_lsradio_off') ~= 1

RegisterNetEvent('gs_lsradio:client:say', function(host, text)
    if not on or not cache.vehicle or not IsPlayerVehRadioEnable() then return end
    PlaySoundFrontend(-1, 'Radio_Off', 'MP_RADIO_SFX', true)
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(('~p~Radio Los Santos~s~ · %s : « %s »'):format(host, text))
    EndTextCommandPrint(Config.Duration, true)
end)

RegisterCommand('radiols', function()
    on = not on
    SetResourceKvpInt('gs_lsradio_off', on and 0 or 1)
    lib.notify({ description = on and 'Radio Los Santos allumée (en voiture).' or 'Radio Los Santos coupée.', type = 'inform', icon = 'radio' })
end, false)
