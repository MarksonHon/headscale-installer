#!/usr/bin/env sh

# set -x

[ -f /usr/local/bin/headscale ] && rm -rf /usr/local/bin/headscale
[ -f /etc/systemd/system/headscale.service ] && rm -rf /etc/systemd/system/headscale.service
[ -f /etc/init.d/headscale ] && rm -rf /etc/init.d/headscale
userdel headscale || busybox deluser headscale
groupdel headscale || busybox delgroup headscale
echo "headscale has been uninstalled, remove /etc/headscale manually if you want to."