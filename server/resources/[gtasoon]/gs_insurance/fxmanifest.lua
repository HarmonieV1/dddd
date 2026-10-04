fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_insurance'
description 'Assurance auto : une semaine de couverture par véhicule, la fourrière ne coûte plus que 25 % (patch qbx_garages posé par METTRE-A-JOUR).'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua', 'server/claims.lua' }
client_scripts { 'client/main.lua' }
