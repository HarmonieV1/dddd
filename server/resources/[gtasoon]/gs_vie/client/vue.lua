-- gs_vie (client) · V12.59 « Vue d'ensemble » (backtest du 15/10 : « une vue d'ensemble sur son perso pour le RP, pas un
-- vol libre »). Caméra qui tourne AUTOUR de son propre personnage : souris pour tourner, molette pour s'éloigner (1,5 à
-- 8 m), jamais à travers un mur (la caméra s'arrête devant l'obstacle), jamais loin du perso : ce n'est pas un vol libre.
-- Le perso ne bouge pas pendant la vue (pas de tir ni de déplacement) ; les emotes (/e) restent possibles.
-- /vue, touche C (V12.63, modifiable : Paramètres → Raccourcis → FiveM → « Vue d'ensemble »), menu radial (W) → Moi → Vue d'ensemble.
-- Sortie : même commande / touche, Retour arrière ou Échap. Coupée d'office si on meurt, monte en véhicule ou est menotté.
local MIN, MAX, STEP = 1.5, 8.0, 0.5
local active = false

local function blocked()
    local st = LocalPlayer.state
    return IsEntityDead(cache.ped) or (st['qbx_medical:deathState'] or 1) >= 2 or st.isCuffed or st.cuffed or cache.vehicle -- [API] qbx_medical
end

local function stop(cam)
    active = false
    RenderScriptCams(false, true, 400, true, false)
    if cam and DoesCamExist(cam) then DestroyCam(cam, false) end
end

local function start()
    if active then active = false return end -- même commande = sortir (la boucle détruit la caméra)
    if IsNuiFocused() or cache.vehicle then return end -- V12.63 : C en voiture = regarder derrière (rien à signaler)
    if blocked() then return lib.notify({ description = 'Vue d\'ensemble impossible maintenant.', type = 'error' }) end
    active = true
    local ped = cache.ped
    local heading = GetEntityHeading(ped) + 180.0
    local pitch, dist = 15.0, 4.0
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 55.0)
    RenderScriptCams(true, true, 400, true, false)
    lib.showTextUI('Vue d\'ensemble · souris : tourner · molette : distance · Retour arrière : quitter', { position = 'bottom-center' })
    CreateThread(function()
        -- par frame : uniquement pendant la vue (caméra placée et commandes coupées à chaque image), s'arrête à la sortie
        while active do
            Wait(0)
            ped = cache.ped
            if blocked() or IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then break end -- Retour arrière / Échap (touches coupées : lues « désactivées »)
            DisableAllControlActions(0)
            for _, c in ipairs({ 1, 2, 241, 242, 245, 249 }) do EnableControlAction(0, c, true) end -- souris, molette, chat, voix
            heading = heading - GetDisabledControlNormal(0, 1) * 6.0
            pitch = math.max(-30.0, math.min(70.0, pitch + GetDisabledControlNormal(0, 2) * 4.0))
            if IsControlJustPressed(0, 241) then dist = math.max(MIN, dist - STEP) end -- molette haut : plus près
            if IsControlJustPressed(0, 242) then dist = math.min(MAX, dist + STEP) end -- molette bas : plus loin
            local target = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0) - vec3(0.0, 0.0, 0.25) -- un peu sous la tête
            local h, p = math.rad(heading), math.rad(pitch)
            local dir = vec3(math.sin(h) * math.cos(p), -math.cos(h) * math.cos(p), math.sin(p))
            local wanted = target + dir * dist
            -- Mur entre le perso et la caméra : on s'arrête 20 cm devant
            local ray = StartExpensiveSynchronousShapeTestLosProbe(target.x, target.y, target.z, wanted.x, wanted.y, wanted.z, 1 | 16, ped, 4)
            local _, hit, pos = GetShapeTestResult(ray)
            local at = (hit == 1 and #(pos - target) > 0.3) and (pos - dir * 0.2) or wanted
            SetCamCoord(cam, at.x, at.y, at.z)
            PointCamAtCoord(cam, target.x, target.y, target.z)
        end
        lib.hideTextUI()
        stop(cam)
    end)
end

RegisterCommand('vue', start, false)
-- V12.63 (backtest : « F6 = caméra mais le perso en vol libre ») : F6 reste le menu des métiers ; le vol libre sur F6 venait du
-- raccourci « NoClip » de txAdmin posé sur F6 dans les réglages FiveM du compte. La vue d'ensemble (perso immobile) a sa touche : C.
RegisterKeyMapping('vue', 'Vue d\'ensemble (caméra autour de son perso)', 'keyboard', 'C')
TriggerEvent('chat:addSuggestion', '/vue', 'Caméra autour de ton perso (molette : distance), rappuie pour quitter')
exports('ToggleView', start)
