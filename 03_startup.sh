#!/usr/bin/env bash
# +-----------------------------------------------------------------------------------------+
# | NEEDS TO BE RUN AS ROOT, AS WE ARE INSTALLING PACKAGES                                  |
# +-----------------------------------------------------------------------------------------+
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi


service apache2 start
service mariadb start

