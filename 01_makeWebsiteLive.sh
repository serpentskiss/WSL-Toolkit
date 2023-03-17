#!/usr/bin/env bash

# +-----------------------------------------------------------------------------------------+
# | UBUNTU DEVELOPMENT WEB SERVER UNDER WINDOWS SUBSYSTEM FOR LINUX TOOLS                   |
# +-----------------------------------------------------------------------------------------+
# | Version : 1.000                                                                         |
# | Date    : 26/NOV/2021                                                                   |
# | Author  : Jon Thompson                                                                  |
# | License : Public Domain                                                                 |
# +-----------------------------------------------------------------------------------------+
# | Scans the parent web site directories and sets where local;host points                  |
# +-----------------------------------------------------------------------------------------+



# +-----------------------------------------------------------------------------------------+
# | NEEDS TO BE RUN AS ROOT, AS WE ARE MODIFYING AND REBOOTING APACHE                       |
# +-----------------------------------------------------------------------------------------+
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

source ./.wsl.docroot.cnf

echo "The following sites have been found in the hosting directory"
echo ""
echo ""

CURRENTLIVESITE=`readlink -f /var/www`

mapfile -t SITES < <( find /mnt/${DRIVE}/websites/ -mindepth 1 -maxdepth 1 -type d )
CT=1

for i in "${SITES[@]}"
do
    if [[ "${i}" == "${CURRENTLIVESITE}" ]]; then
        echo "${CT} - ${i##*/} (CURRENT)"
    else
        echo "${CT} - ${i##*/}"
    fi
        CT=$((CT+1))
done

echo "Q - Quit with no changes"


MAXVERSIONS=${#SITES[@]}

while :; do
  read -p "Make which site live as localhost? (1-${MAXVERSIONS}) : " SITEINPUT
  [[ ${SITEINPUT} =~ ^([a-zA-Z0-9]+)$ ]] || { echo "Enter a valid number"; continue; }
  if [[ ${SITEINPUT} =~ ^(q|Q)$ ]]; then
    echo ""
    echo "Quitting. No changes made to current localhost"
    echo ""
    exit
  elif  ((SITEINPUT >= 1 && SITEINPUT <= ${MAXVERSIONS})); then
    SITEINPUT=$((SITEINPUT-1))
    SITE=${SITES[${SITEINPUT}]}
    break
  else
    echo "Invalid selection, please try again"
  fi
done

rm -f "/var/www"
ln -s "${SITE}" "/var/www"

echo "localhost now set to ${SITE}"
echo ""
echo ""
