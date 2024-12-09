fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

game 'rdr3'
lua54 'yes'
author 'BCC-Team @Jannings'

shared_scripts {
	'config/config.lua',
	'shared/locale.lua',
	'languages/*.lua',
}

client_scripts {
	'client/client.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/dbUpdater.lua',
	'server/server.lua',
}

dependencies {
	'vorp_core',
	'vorp_inventory',
	'vorp_character',
	'bcc-utils',
	'bcc-crypt'
}

version '1.3.7'
