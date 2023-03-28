#!/usr/bin/env bash

# +-----------------------------------------------------------------------------------------+
# | UBUNTU DEVELOPMENT WEB SERVER UNDER WINDOWS SUBSYSTEM FOR LINUX                         |
# +-----------------------------------------------------------------------------------------+
# | Version        : 1.002                                                                  |
# | Ubuntu Version : 22.0.4 LTS                                                             |
# | Date           : 26/NOV/2021                                                            |
# | Updated        : 28/MAR/2023                                                            |
# | Author         : Jon Thompson                                                           |
# | License        : Public Domain                                                          |
# +-----------------------------------------------------------------------------------------+
# | Installs and configures a basic LAMP stack running under the WSL components             |
# |                                                                                         |
# | v1.01   : 09/MAR/2023                                                                   |
# |           Additions:                                                                    |
# |           - Networking fix added                                                        |
# |                                                                                         |
# | v1.01   : 09/MAR/2023                                                                   |
# |           Additions:                                                                    |
# |           - drive selection for use as DocumentRoot/web site storage                    |
# |           - Composer installation for PHP development                                   |
# |           - WSL metadata mount option (allow CHOWN & CHMOD)                             | 
# |                                                                                         |
# |           Bug Fixes:                                                                    |
# |           - Changed imagick to imagemagick                                              |
# |           - Added check for existing default web site on chosen drive                   |
# |           - Added check for existing default PHP test page                              |
# |           - Enabled Apache's mod_rewrite                                                |
# |           - Added "AllowEncodedSlashes NoDecode" to Apache config                       | 
# |           - Changed MySQL commands to MariaDB (Ubuntu default)                          |
# |           - Changed SQL to use correct syntax instead of writing to tables              |
# |                                                                                         |
# | v1.00   : 26/NOV/2021                                                                   |
# |           Initial release                                                               |
# +-----------------------------------------------------------------------------------------+



# +-----------------------------------------------------------------------------------------+
# | NEEDS TO BE RUN AS ROOT, AS WE ARE INSTALLING PACKAGES                                  |
# +-----------------------------------------------------------------------------------------+
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

UID = $SUDO_UID
GID = $SUDO_GID



# +-----------------------------------------------------------------------------------------+
# | ADD THE NEW PHP REPOSITORY, UPDATE THE SYSTEM, AND INSTALL SOME UTILITIES               |
# +-----------------------------------------------------------------------------------------+
echo "RUNNING REPOSITORY UPDATES"
apt install -y software-properties-common
add-apt-repository ppa:ondrej/php
apt-get update
apt-get -y upgrade
apt-get install -y imagemagick curl zip unzip mcrypt ffmpeg



# +-----------------------------------------------------------------------------------------+
# | GET THE AVAILABLE PHP VERSIONS AND ASK FOR USER INPUT AS TO WHICH ONE TO INSTALL        |
# +-----------------------------------------------------------------------------------------+
mapfile -t PHPVERSIONS < <( apt-cache search --names-only '^php(7|8)\..$' | sort | cut -d ' ' -f 1 )
CT=1

for i in "${PHPVERSIONS[@]}"
do
	echo "${CT} - ${i}"
	CT=$((CT+1))
done

MAXVERSIONS=${#PHPVERSIONS[@]}

while :; do
  read -p "Install which PHP version? (1-${MAXVERSIONS}) : " VERSINPUT
  [[ ${VERSINPUT} =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  if ((VERSINPUT >= 1 && VERSINPUT <= ${MAXVERSIONS})); then
    VERSINPUT=$((VERSINPUT-1))
	PHPVERSION=${PHPVERSIONS[${VERSINPUT}]}
    break
  else
    echo "Invalid selection, please try again"
  fi
done



# +-----------------------------------------------------------------------------------------+
# | ALLOWS CHMOD/CHOWN UNDER WINDOWS!                                                       |
# | REQUIRES "wsl --shutdown" TO BE ISSUED UNDER A WINDOWS COMMAND PROMPT TO TAKE EFFECT    |
# +-----------------------------------------------------------------------------------------+
cat << _EOF_ >> /etc/wsl.conf
[automount]
options = "metadata"
_EOF_



# +-----------------------------------------------------------------------------------------+
# | NETWORKING FIX                                                                          |
# | REQUIRES "wsl --shutdown" TO BE ISSUED UNDER A WINDOWS COMMAND PROMPT TO TAKE EFFECT    |
# +-----------------------------------------------------------------------------------------+
cat << _EOF_ >> /etc/wsl.conf
[network]
generateResolvConf = false
_EOF_

rm -f /etc/resolv.conf
cat << _EOF_ >> /etc/resolv.conf
nameserver 8.8.8.8
_EOF_

chattr +i /etc/resolv.conf



# +-----------------------------------------------------------------------------------------+
# | INSTALL APACHE                                                                          |
# +-----------------------------------------------------------------------------------------+
apt-get install -y apache2 
a2enmod rewrite



# +-----------------------------------------------------------------------------------------+
# | INSTALL PHP                                                                             |
# +-----------------------------------------------------------------------------------------+
apt-get install -y ${PHPVERSION} ${PHPVERSION}-cli ${PHPVERSION}-common ${PHPVERSION}-curl ${PHPVERSION}-gd ${PHPVERSION}-imagick ${PHPVERSION}-imap ${PHPVERSION}-mailparse ${PHPVERSION}-mbstring ${PHPVERSION}-mcrypt ${PHPVERSION}-mysql ${PHPVERSION}-xdebug ${PHPVERSION}-xml ${PHPVERSION}-zip



# +-----------------------------------------------------------------------------------------+
# | INSTALL COMPOSER                                                                        |
# +-----------------------------------------------------------------------------------------+
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php 
php -r "unlink('composer-setup.php');"
mv composer.phar /usr/local/bin/composer



# +-----------------------------------------------------------------------------------------+
# | INSTALL MARIADB (MYSQL EQUIVALENT)                                                      |
# +-----------------------------------------------------------------------------------------+
apt-get install -y mariadb-client mariadb-server



# +-----------------------------------------------------------------------------------------+
# | CREATE DEFAULT WEB DIRECTORIES                                                          |
# +-----------------------------------------------------------------------------------------+
mapfile -t DRIVES < <( find /mnt -mindepth 1 -maxdepth 1 -regex '\/mnt\/[a-z]' -type d  | cut -d '/' -f 3 | sort )
CT=1

for i in "${DRIVES[@]}"
do
	echo "${CT} - ${i}"
	CT=$((CT+1))
done

MAXDRIVES=${#DRIVES[@]}

while :; do
  read -p "Set the DocumentRoot / store web sites on which drive? (1-${MAXDRIVES}) : " DRIVESINPUT
  [[ ${DRIVESINPUT} =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  if ((DRIVESINPUT >= 1 && DRIVESINPUT <= ${MAXDRIVES})); then
    DRIVESINPUT=$((DRIVESINPUT-1))
	DRIVE=${DRIVES[${DRIVESINPUT}]}
    break
  else
    echo "Invalid selection, please try again"
  fi
done

if [ ! -d "/mnt/${DRIVE}/websites/default/web" ]; then
    mkdir -p /mnt/${DRIVE}/websites/default/web
fi

rm -Rf /var/www
ln -s /mnt/${DRIVE}/websites/default /var/www

cat << _EOF_ > ./.wsl.docroot.cnf
DRIVE="${DRIVE}"
_EOF_

chmod 0600 ./.wsl.docroot.cnf



# +-----------------------------------------------------------------------------------------+
# | SET SOME GLOBAL PHP VALUES                                                              |
# +-----------------------------------------------------------------------------------------+
PHPINI=`php -i | grep 'Loaded Configuration File' | cut -d '>' -f 2 | cut -d ' ' -f 2 | sed 's/cli/apache2/'`
sed -i 's/max_execution_time = 30/max_execution_time = 90/' ${PHPINI}
sed -i 's/post_max_size = 8M/post_max_size = 64M/' ${PHPINI}
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 512M/' ${PHPINI}
sed -i 's/allow_url_fopen = On/allow_url_fopen = Off/' ${PHPINI}
sed -i 's/;date.timezone =/date.timezone = Europe\/London/' ${PHPINI}
sed -i 's/mail.add_x_header = Off/mail.add_x_header = On/' ${PHPINI}



# +-----------------------------------------------------------------------------------------+
# | CREATE DEFAULT WEB HOST VIRTUALHOST                                                     |
# +-----------------------------------------------------------------------------------------+
cat << _EOF_ > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/web
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    AllowEncodedSlashes NoDecode
</VirtualHost>

<Directory /var/www>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
_EOF_



# +-----------------------------------------------------------------------------------------+
# | CREATE EXAMPLE TEST PHP PAGE                                                            |
# +-----------------------------------------------------------------------------------------+
if [ ! -f "/var/www/web/phpinfotestpage.php" ]; then
	cat << _EOF_ > /var/www/web/phpinfotestpage.php
<html>
<head>
<title>Example page</title>
<style>
body {margin: 0; padding: 0;}
h6 {font-size: 2.0em; text-align: center; background-color: #ffa726; padding: 10px;}
</style>
</head>
<body>
<h6>Testing PHP works</h6>
<?php
phpinfo();
?>
</body>
</html>
_EOF_
fi



# +-----------------------------------------------------------------------------------------+
# | START APACHE AND MYSQL                                                                  |
# +-----------------------------------------------------------------------------------------+
service apache2 start
service mariadb start



# +-----------------------------------------------------------------------------------------+
# | RUN THE MYSQL_SECURE_INSTALLATION SCRIPT COMMANDS                                       |
# +-----------------------------------------------------------------------------------------+
# mysql_secure_installation
MYSQLROOTPWD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
mysql --user=root <<_EOF_
  DROP USER IF EXISTS '';
  CREATE OR REPLACE USER 'root'@'localhost' IDENTIFIED BY '${MYSQLROOTPWD}';
  DROP DATABASE IF EXISTS test;
  FLUSH PRIVILEGES;
_EOF_



# +-----------------------------------------------------------------------------------------+
# | SAVE THE MYSQL ROOT PASSWORD IN A CNF FILE FOR USE IN MANAGEMENT SCRIPTS                |
# +-----------------------------------------------------------------------------------------+
cat << _EOF_ > ./.root_mysql.cnf
[client]
password="${MYSQLROOTPWD}"
_EOF_

chmod 0600 ./.root_mysql.cnf



echo "Installation complete. Please open a new Windows command prompt and issue the following command"
echo ""
echo "wsl --shutdown"
echo ""
echo "This is required to allow CHMOD and CHOWN commands to work correctly under Windows Subsystem For Linux. This will terminate this window to apply the setting, and you can then simply restart your Ubuntu instance as normal"
echo ""
echo "A test page has been added at http://localhost/phpinfotestpage.php"
