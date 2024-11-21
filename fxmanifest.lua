fx_version "adamant"
games { "rdr3" }
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'
author 'BCC-Team @Jannings'


shared_script {
	'config/config.lua',
	'locale.lua',
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
	'bcc-utils'
}

version '1.3.6'
