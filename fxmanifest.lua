fx_version "adamant"
games { "rdr3" }
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'
author 'Jannings'



client_scripts {
	'client/client.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/server.lua',

}

shared_script {
	'shared/config.lua',
	'shared/locale.lua',
	'shared/en.lua'
}



dependencies {
	'vorp_core',
	'vorp_inventory',
	'vorp_utils',
	'bcc-utils'
}

version '1.2.4'
