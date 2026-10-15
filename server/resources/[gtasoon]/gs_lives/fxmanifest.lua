fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_lives'
description 'V12.60 · Lives staff : voir l\'écran d\'un ou plusieurs joueurs dans des fenêtres déplaçables (modération), via screenshot-basic'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge' }

ui_page 'html/index.html'
files { 'html/index.html' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
