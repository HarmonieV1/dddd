fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_economy'
description 'Économie dynamique : supérettes, cavistes, quincailleries (prix offre / demande / événements), reventes, alcool et tabac'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua', 'shared/pricing.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/regulars.lua', 'server/main.lua' }
client_scripts { 'client/main.lua', 'client/vices.lua', 'client/clerks.lua' }
