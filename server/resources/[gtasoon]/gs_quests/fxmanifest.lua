fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_quests'
description 'Progression GTA SOON : XP et niveaux, quêtes de départ (chaînes homme / femme), personnages récurrents, paquets cachés'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_markers' }

-- V12.5 : quests.lua AVANT points.lua, sinon les personnages (Characters) n'existaient pas encore au recensement des
-- points déplaçables : Max, Big Sal, la cabine de la Voix… ne pouvaient pas être déplacés au F11.
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', 'shared/quests.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
