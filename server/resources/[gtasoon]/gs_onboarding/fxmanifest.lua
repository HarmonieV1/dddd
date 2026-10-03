fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_onboarding'
description 'Arrivée des joueurs : règlement à accepter (/regles), liste blanche (candidature Discord), accueil « ton premier jour ».'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua', 'shared/commands.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua', 'server/commands.lua' }
client_scripts { 'client/main.lua', 'client/keys.lua', 'client/commands.lua' }
