fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_markers'
description 'Marqueurs au sol GTA SOON (cercles, icônes, losange de quête façon Sims) + PNJ des points : un seul fil, style unifié, 0 coût loin des points'
version '0.1.0'

dependencies { 'ox_target' } -- V12.36 : le PNJ d'un point porte son interaction (ox_target sur le PNJ)

client_scripts { 'client/main.lua' }
