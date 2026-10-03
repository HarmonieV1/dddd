fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_duo'
description 'Duo criminel lié : lien persistant, partenaire sur la carte, contrats à deux, niveau de lien, chaleur partagée'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_wanted' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
