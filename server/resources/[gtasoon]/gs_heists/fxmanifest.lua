fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_heists'
description 'Braquages (supérettes, bijouterie, banque) branchés sur la recherche, la météo, le duo et les territoires'
version '0.1.0'

dependencies { 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge', 'gs_jobs', 'gs_wanted', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua', 'server/duo.lua' }
client_scripts { 'client/main.lua', 'client/duo.lua' }
