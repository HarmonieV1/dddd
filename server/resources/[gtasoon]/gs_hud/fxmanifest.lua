fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_hud'
description 'HUD néon : santé, armure, faim, soif, voix, argent, job, recherche, heure/météo, compteur véhicule'
version '0.1.0'

dependencies { 'ox_lib', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
client_scripts { 'client/main.lua' }

ui_page 'web/dist/index.html'
files { 'web/dist/index.html', 'web/dist/assets/*' }
