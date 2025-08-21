game 'rdr3'
fx_version 'adamant'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

version '1.2'
author 'phil mcracken'
description 'Mobile Data Terminal (MDT) system using ox_lib for UI'

dependency 'ox_lib'

client_scripts {
    'cl_mdt.lua',
}

shared_scripts {
	'@ox_lib/init.lua',
    'config.lua',
}

files {
    'html/index.html',
    'html/styles.css',
    'html/script.js'
}

server_scripts {
   
	'@oxmysql/lib/MySQL.lua',
    'sv_mdt.lua',
    
}
ui_page 'html/index.html'
lua54 'yes'