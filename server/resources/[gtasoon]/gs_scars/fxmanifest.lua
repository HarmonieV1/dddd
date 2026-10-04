fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_scars'
description 'V9 · Les cicatrices de la ville : bougies et ruban là où quelqu\'un est tombé, vitrines brisées après un braquage (réparées par les ouvriers de la ville), fresques des gangs vainqueurs'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
