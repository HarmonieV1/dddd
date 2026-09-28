fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_security'
description 'Helpers de sécurité serveur : rate-limit, distance, logs staff'
version '0.1.0'

server_scripts { 'server/main.lua' }
server_exports { 'RateLimit', 'InRange', 'LogStaff' }
