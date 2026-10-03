fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_bridge'
description "Couche d'adaptation framework : seule ressource autorisée à appeler qbx_core / ox_inventory / qbx_vehiclekeys"
version '0.2.0'

dependencies { 'oxmysql', 'qbx_core', 'ox_inventory' }

server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua', 'server/points.lua' }
client_scripts { 'client/main.lua', 'client/points.lua' }
files { 'shared/points.lua' } -- inclus par nos autres ressources (@gs_bridge/shared/points.lua)
