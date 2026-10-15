-- screenshot-basic (ressource officielle Cfx.re, licence MIT : voir LICENSE), V12.60 · livrée DÉJÀ COMPILÉE par RoadLine
-- (github.com/citizenfx/screenshot-basic, compilée avec son webpack d'origine) : plus besoin de yarn / webpack au démarrage
-- ni de l'installer à la main. Sert aux Lives staff (gs_lives), aux photos Vibe et à la bodycam (gs_social, gs_police).
fx_version 'cerulean'
game 'common'
lua54 'yes'

client_script 'dist/client.js'
server_script 'dist/server.js'

files { 'dist/ui.html' }
ui_page 'dist/ui.html'
