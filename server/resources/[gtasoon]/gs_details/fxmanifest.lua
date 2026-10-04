fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_details'
description 'Petits détails qui changent tout : menu radial véhicule (Z), /me /do, mains en l\'air (X), ceinture (B), kits de réparation et nettoyage utilisables'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua', 'client/vehicle.lua', 'client/health.lua', 'client/outfits.lua', 'client/radial.lua', 'client/cinema.lua', 'client/undershirt.lua' }
