-- gs_details (client) · V8 « Mode cinéma » : pour tourner des clips (TikTok, YouTube). /cinema change de style
-- (bandes noires → néon → noir et blanc → arrêt), /ralenti pendant le tournage. Tout est local : rien n'est envoyé.
local STYLES = {
    { label = 'Cinéma', filter = 'cinema' },
    { label = 'Néon', filter = 'NG_filmic11' },
    { label = 'Noir et blanc', filter = 'NG_filmnoir_BW01' },
}
local style, slow = 0, false
local BAR = 0.11

local function stop()
    style, slow = 0, false
    ClearTimecycleModifier()
    SetTimeScale(1.0)
    DisplayRadar(true)
    TriggerEvent('gs_hud:client:cinema', false)
end

RegisterCommand('cinema', function()
    style = style + 1
    if style > #STYLES then stop() return lib.notify({ description = 'Mode cinéma arrêté.', type = 'inform' }) end
    SetTimecycleModifier(STYLES[style].filter)
    SetTimecycleModifierStrength(0.85)
    TriggerEvent('gs_hud:client:cinema', true)
    if style > 1 then return end
    lib.notify({ title = 'Mode cinéma', description = '/cinema : style suivant · /ralenti : ralenti · /cinema jusqu\'à l\'arrêt', type = 'inform', duration = 6000 })
    CreateThread(function()
        while style > 0 do
            HideHudAndRadarThisFrame()
            DisplayRadar(false)
            DrawRect(0.5, BAR / 2, 1.0, BAR, 0, 0, 0, 255)
            DrawRect(0.5, 1.0 - BAR / 2, 1.0, BAR, 0, 0, 0, 255)
            Wait(0)
        end
    end)
end, false)

RegisterCommand('ralenti', function()
    if style == 0 then return lib.notify({ description = 'Lance d\'abord /cinema.', type = 'error' }) end
    slow = not slow
    SetTimeScale(slow and 0.4 or 1.0)
end, false)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and style > 0 then stop() end end)
