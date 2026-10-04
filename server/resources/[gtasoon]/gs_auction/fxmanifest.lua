fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_auction'
description 'V10.1 · Enchères de la fourrière : chaque samedi soir, la police vend aux enchères ses saisies et les véhicules abandonnés envoyés à la fourrière. Mises bloquées en banque (remboursées si dépassé), recette à la caisse de la police.'
version '0.1.0'

dependencies { 'ox_lib', 'gs_bridge', 'gs_security' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
