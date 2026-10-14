fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_furniture'
description 'Mobilier utilisable (V12.42) : s\'asseoir, s\'allonger, rouler en fauteuil roulant (objets du mapping F11 et de la ville)'
version '0.1.0'

dependencies { 'ox_lib', 'ox_target', 'gs_security' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' } -- V12.58 : réglages par modèle enregistrés par le staff (/meubleregle)
