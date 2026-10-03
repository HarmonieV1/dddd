fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_places'
description 'Lieux publics placés par le staff en jeu (F11) : parkings publics (qbx_garages) et boutiques de vêtements (illenium-appearance), sauvegardés en BDD.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
