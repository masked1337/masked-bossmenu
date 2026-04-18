fx_version 'cerulean'
game 'gta5'
author 'masked1337'
description "Free skripte na + https://github.com/masked1337"
lua54 'yes'

ui_page 'html/index.html'

files {
    "html/index.html"
}

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}