fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_furniture'
description 'Mobilier utilisable (V12.42) : s\'asseoir, s\'allonger, rouler en fauteuil roulant (objets du mapping F11 et de la ville)'
version '0.1.0'

dependencies { 'ox_lib', 'ox_target' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
client_scripts { 'client/main.lua' }
