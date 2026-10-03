-- gs_onboarding (serveur) : liste blanche à la connexion (deferrals), règlement à accepter (version), accueil des nouveaux.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Onboarding = { pendingRules = {} } -- pendingRules[src] = true tant que le règlement n'est pas accepté

local function license(src)
    return GetPlayerIdentifierByType(src, 'license2') or GetPlayerIdentifierByType(src, 'license')
end

local function discord() return GetConvar('gs_discord_invite', Config.DiscordInvite) end

function Onboarding.whitelistOn() return GetConvar('gs_whitelist', 'false') == 'true' end

--- Contrôle de connexion : true | false, message
function Onboarding.check(src)
    if not Onboarding.whitelistOn() then return true end
    if IsPlayerAceAllowed(src, Config.WhitelistBypassAce) then return true end
    local lic = license(src)
    if not lic then return false, 'Licence Rockstar introuvable : relance FiveM.' end
    if Store.isWhitelisted(lic) then return true end
    return false, ('Serveur sur liste blanche. Candidature sur notre Discord : %s'):format(discord())
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('Vérification de ton accès…')
    local ok, msg = Onboarding.check(src)
    if ok then deferrals.done() else deferrals.done(msg) end
end)

--- Règlement : à la connexion du personnage, s'il n'a pas accepté la version courante → le client l'affiche.
AddEventHandler('gs_bridge:server:playerLoaded', function(src)
    local lic = license(src)
    if lic and Store.rulesVersion(lic) < Config.RulesVersion then
        Onboarding.pendingRules[src] = true
        TriggerClientEvent('gs_onboarding:client:rules', src, true)
    end
    if GetResourceState('gs_quests') == 'started' and not exports.gs_quests:HasDone(src, 'welcome') then
        TriggerClientEvent('gs_onboarding:client:welcome', src)
    end
end)

lib.callback.register('gs_onboarding:accept', function(src, accepted)
    if not Security:RateLimit(src, 'gs_onboarding:accept', 3, 10000) then return false end
    if not Onboarding.pendingRules[src] then return true end
    if accepted ~= true then
        DropPlayer(src, 'Il faut accepter le règlement pour jouer. À bientôt !')
        return false
    end
    local lic = license(src)
    if not lic then return false end
    Store.acceptRules(lic, Config.RulesVersion)
    Onboarding.pendingRules[src] = nil
    return true
end)

AddEventHandler('playerDropped', function() Onboarding.pendingRules[source] = nil end)

--- /whitelist add|remove <id serveur | license:xxx> [note]
function Onboarding.command(src, args)
    local action, who = args[1], args[2]
    if action ~= 'add' and action ~= 'remove' then return false, 'Usage : /whitelist add|remove <id | license:...> [note]' end
    local lic = who and who:match('^license2?:%x+$') and who or (tonumber(who) and GetPlayerName(tonumber(who)) and license(tonumber(who)))
    if not lic then return false, 'Joueur ou licence introuvable.' end
    local by = src == 0 and 'console' or (GetPlayerName(src) or tostring(src))
    if action == 'add' then
        Store.addWhitelist(lic, by, table.concat(args, ' ', 3):sub(1, 100))
    elseif not Store.removeWhitelist(lic) then
        return false, 'Pas dans la liste blanche.'
    end
    Security:LogStaff(('[Liste blanche] %s : %s %s'):format(by, action == 'add' and 'ajout' or 'retrait', lic))
    return true, action == 'add' and 'Ajouté à la liste blanche.' or 'Retiré de la liste blanche.'
end

RegisterCommand('whitelist', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.ManageAce) then return end
    if src ~= 0 and not Security:RateLimit(src, 'gs_onboarding:wl', 5, 10000) then return end
    local ok, msg = Onboarding.command(src, args)
    if src == 0 then print(msg) else Bridge:Notify(src, msg, ok and 'success' or 'error') end
end, false)

-- Retouche du personnage : visage, cheveux, maquillage, vêtements, UNE fois par personnage (création pas finie, bug…).
-- Le droit n'est consommé qu'à l'enregistrement : annuler garde la retouche. Staff : /gsretouche <id> la rend.
lib.callback.register('gs_onboarding:retouche:check', function(src)
    if not Security:RateLimit(src, 'gs_onboarding:retouche', 4, 10000) then return false, 'Doucement.' end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return false, 'Personnage introuvable.' end
    if Store.retoucheUsed(cid) then return false, 'Retouche déjà utilisée pour ce personnage (le staff peut la rendre : /report).' end
    return true
end)

lib.callback.register('gs_onboarding:retouche:done', function(src)
    if not Security:RateLimit(src, 'gs_onboarding:retouche', 4, 10000) then return false end
    local cid = Bridge:GetIdentifier(src)
    if not cid or Store.retoucheUsed(cid) then return false end
    Store.useRetouche(cid)
    Security:LogStaff(('[Retouche] %s (%s) a retouché son personnage'):format(GetPlayerName(src) or src, cid))
    return true
end)

RegisterCommand('gsretouche', function(src, args)
    local target = tonumber(args[1])
    local cid = target and Bridge:GetIdentifier(target)
    local function reply(msg) if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { description = msg }) end end
    if not cid then return reply('Usage : /gsretouche <id du joueur en ligne>') end
    Store.resetRetouche(cid)
    TriggerClientEvent('ox_lib:notify', target, { description = 'Le staff t\'a rendu une retouche de personnage : /retoucheperso', type = 'success' })
    reply(('Retouche rendue à %s.'):format(GetPlayerName(target) or target))
end, true) -- ACE command.gsretouche (group.admin a déjà « command »)

CreateThread(function() Store.init() end)
