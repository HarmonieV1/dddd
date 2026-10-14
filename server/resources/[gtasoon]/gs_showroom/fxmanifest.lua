fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_showroom'
description 'V12.40 · Véhicules d\'exposition posés par le staff (concession Patoche ou autre) : voir, changer de modèle (vendeur), essayer 2 min, acheter'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge', 'gs_jobs' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
