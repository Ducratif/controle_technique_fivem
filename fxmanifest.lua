fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Ducratif (generated package)'
description 'CT + Carte grise RP (ESX Legacy) - ox_lib + ox_inventory'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/main.lua'
}

files {
    'docs/index.html',
    'docs/style.css'
}

dependency 'ox_lib'
dependency 'ox_inventory'
dependency 'oxmysql'
dependency 'es_extended'
