fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_memoire'
description 'V12 · La mémoire des lieux : chaque endroit accumule ce qui s y est passé, les passants en parlent, la radio le rappelle, une plaque naît au 10e événement. La nuit, les échos rejouent le passé.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
