fx_version 'cerulean'
game 'gta5'
name "old_ghostHunter"
description "ghost hunter"
author "OldMoney"
version "1.0.0"

shared_scripts {
	'shared/*.lua'
}

client_scripts {
	'client/*.lua'
}

server_scripts {
	'server/*.lua'
}

ui_page 'ui/dist/index.html'

files {
	'ui/dist/index.html',
	'ui/dist/**/*',
	'ui/dist/assets/*.mp3'
}
