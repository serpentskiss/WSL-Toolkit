#!/usr/bin/env bash

# +-----------------------------------------------------------------------------------------+
# | UBUNTU DEVELOPMENT WEB SERVER UNDER WINDOWS SUBSYSTEM FOR LINUX TOOLS                   |
# +-----------------------------------------------------------------------------------------+
# | Version : 1.000                                                                         |
# | Date    : 26/NOV/2021                                                                   |
# | Author  : Jon Thompson                                                                  |
# | License : Public Domain                                                                 |
# +-----------------------------------------------------------------------------------------+
# | Creates a new database and gives the new user full access to it                         |
# +-----------------------------------------------------------------------------------------+



# +-----------------------------------------------------------------------------------------+
# | NEEDS TO BE RUN AS ROOT, AS WE ARE USING THE MYSQL ROOT USER                            |
# +-----------------------------------------------------------------------------------------+
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi


# +-----------------------------------------------------------------------------------------+
# | CHECK FOR REQUIRED CLI PARAMETERS                                                       |
# +-----------------------------------------------------------------------------------------+
while getopts d:u:p: flag
do
    case "${flag}" in
        d) DATABASE=${OPTARG};;
        u) USERNAME=${OPTARG};;
        p) PASSWORD=${OPTARG};;
    esac
done

if [[ ! "$DATABASE" =~ ^[a-zA-Z0-9_-]{6,20}$ ]]; then
    echo "Missing database - Usage: $0 -d DATABASE -u USERNAME -p PASSWORD"
    exit
fi

if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_-]{6,20}$ ]]; then
    echo "Missing username - Usage: $0 -d DATABASE -u USERNAME -p PASSWORD"
    exit
fi

if [[ ! "$PASSWORD" =~ ^[a-zA-Z0-9_-]{6,}$ ]]; then
    echo "Missing password - Usage: $0 -d DATABASE -u USERNAME -p PASSWORD"
    exit
fi



# +-----------------------------------------------------------------------------------------+
# | RUN THE MYSQL COMMANDS TO CREATE THE DATABASE AND USER                                  |
# +-----------------------------------------------------------------------------------------+
mysql --defaults-extra-file=./.wsl.root_mysql.cnf --user=root <<_EOF_
    CREATE DATABASE ${DATABASE};
    GRANT ALL PRIVILEGES ON ${DATABASE}.* TO '${USERNAME}'@'localhost' IDENTIFIED BY '${PASSWORD}';
    GRANT ALL PRIVILEGES ON ${DATABASE}.* TO '${USERNAME}'@'192.168.%' IDENTIFIED BY '${PASSWORD}';
    FLUSH PRIVILEGES;
_EOF_
