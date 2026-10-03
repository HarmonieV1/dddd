fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_market'
description 'Bourse de la ville : indices (prix, carburant, immobilier, matières premières, richesse) relevés chaque heure, affichés dans Vibe avec leur évolution.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
