fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_economy'
description 'Économie dynamique : prix selon offre / demande / événements, commerces et reventes'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', 'shared/pricing.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
