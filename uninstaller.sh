#!/usr/bin/env sh

set -e

[ -f /usr/local/share/headscale ] && rm -rf /usr/local/share/headscale
[ -f /etc/systemd/system/headscale.service ] && rm -rf /etc/systemd/system/headscale.service
[ -f /etc/init.d/headscale ] && rm -rf /etc/init.d/headscale
userdel headscale
groupdel headscale
echo "headscale has been uninstalled, remove /etc/headscale manually if you want to."