fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_cabines'
description 'V12.60 · Cabines téléphoniques : appel anonyme à la police (central) ou tuyau à la rédaction Weazel, depuis les cabines du jeu'
version '0.1.0'

dependencies { 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
