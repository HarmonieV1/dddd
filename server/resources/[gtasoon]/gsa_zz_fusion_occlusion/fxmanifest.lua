-- Fusion automatique des fichiers d'occlusion en conflit entre maps (gs_admin/server/maps.js).
-- Lancée APRÈS les maps (dev.cfg / prod.cfg), donc prioritaire. Contenu régénéré à chaque démarrage si besoin.
fx_version 'cerulean'
game 'gta5'
author 'RoadLine'
lua54 'yes'
this_is_a_map 'yes'
server_script 'server.lua' -- écrit les fusions dans son propre dossier (seul endroit où FXServer l'autorise)
