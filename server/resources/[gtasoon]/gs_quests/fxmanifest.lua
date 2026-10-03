fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_quests'
description 'Progression GTA SOON : XP et niveaux, quêtes de départ (chaînes homme / femme), personnages récurrents, paquets cachés'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua', 'shared/quests.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
