fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_gigs'
description 'Petits boulots depuis le téléphone (app Boulots) : livraisons légales, passeur illégal. Offres, trajets et paiements côté serveur.'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
