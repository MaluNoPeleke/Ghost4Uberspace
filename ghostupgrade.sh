#!/bin/bash
#set -v
GHOSTDIR=~/ghost
PACKAGE_VERSION_OLD=$(sed -nE 's/^\s*"version": "(.*?)",$/\1/p' $GHOSTDIR/current/package.json)
CURRENT_GHOST=$(curl -s https://api.github.com/repos/TryGhost/Ghost/releases | grep tag_name | head -n 1 | cut -d '"' -f 4)
CURRENT_GHOST_DOWNLOAD=$(curl -s https://api.github.com/repos/TryGhost/Ghost/releases/latest | grep browser_download_url | cut -d '"' -f 4)
CURRENT_GHOST_FILE=$(echo $CURRENT_GHOST_DOWNLOAD | sed 's:.*/::')
echo "Installierte Version von Ghost: $PACKAGE_VERSION_OLD"
echo " Verfuegbare Version von Ghost: $CURRENT_GHOST"
cd $GHOSTDIR
if [[ $CURRENT_GHOST > $PACKAGE_VERSION_OLD ]]
then
	read -r -p "Soll Ghost jetzt von Version $PACKAGE_VERSION_OLD auf $CURRENT_GHOST aktualisiert werden? [J/n] " response
	if [[ $response =~ ^([jJ][aA]|[jJ]|"")$ ]]
	then
		echo "Pruefe auf Aktualisierung von npm..."
		echo "Node.js version: $( node -v)" && echo "Bisherige npm version: $(npm -v)"
		npm install -g npm
		echo "Neue npm version: $(npm -v)"
		echo "Pruefe auf Aktualisierung von knex-migrator..."
		echo "Bisherige knex-migrator version: $(knex-migrator -v)"
		npm install -g knex-migrator
		echo "Neue knex-migrator version: $(knex-migrator -v)"
		echo "Pruefe auf Aktualisierung von yarn..."
		echo "Bisherige yarn version: $(yarn --version)"
		#curl --compressed -o- -L https://yarnpkg.com/install.sh | bash
		yarn set version latest
		echo "Neue yarn version: $(yarn --version)"
		echo "Ghost $CURRENT_GHOST wird heruntergeladen und entpackt..."
		cd $GHOSTDIR/versions/
		curl -LOk $CURRENT_GHOST_DOWNLOAD
		unzip $GHOSTDIR/versions/$CURRENT_GHOST_FILE -d $CURRENT_GHOST
		rm $GHOSTDIR/versions/$CURRENT_GHOST_FILE
		echo "Ghost wird jetzt aktualisiert..."
		cd $GHOSTDIR/versions/$CURRENT_GHOST
		yarn install --production
		echo "Die Datenbank von Ghost wird auf die neue Version migriert..."
		cd $GHOSTDIR
		NODE_ENV=production knex-migrator migrate --mgpath $GHOSTDIR/versions/$CURRENT_GHOST
		ln -sfn $GHOSTDIR/versions/$CURRENT_GHOST $GHOSTDIR/current
		PACKAGE_VERSION=$(sed -nE 's/^\s*"version": "(.*?)",$/\1/p' $GHOSTDIR/current/package.json)
		echo "Ghost wurde von Version $PACKAGE_VERSION_OLD auf Version $PACKAGE_VERSION aktualisiert und wird neu gestartet. Dies kann ein paar Sekunden dauern..."
		supervisorctl restart ghost
		supervisorctl status
		echo "Bei Fehlern Logfile ueberpruefen: 'supervisorctl tail ghost'"
		echo "Zum Zuruecksetzen auf Ghost $PACKAGE_VERSION_OLD folgenden Befehl ausfuehren: 'ln -sfn $GHOSTDIR/versions/$PACKAGE_VERSION_OLD $GHOSTDIR/current' und dann per 'supervisorctl restart ghost' neustarten"
	else
		echo "-> Ghost wird nicht aktualisiert"
	fi
else
	echo "-> Ghost ist bereits auf dem aktuellen Stand, keine Aktualisierung notwendig"
fi
