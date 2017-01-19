#!/bin/sh -e
#
# You can run this script directly from github as root like this:
#   curl -sS https://gist.githubusercontent.com/kamermans/94b1c41086de0204750b/raw/configure_docker0.sh | sudo bash -s - 192.168.254.1/24
#
# * Make sure you replace "192.168.254.0/24" with the network that you want to use
#
# NOTE: This script is intended for Debian / Ubuntu only!
# taken from https://gist.github.com/kamermans/94b1c41086de0204750b

if [ $# -lt 1 ]; then
    echo "Usage: sudo ./configure_docker0.sh <ip/CIDR>"
    echo "   examples: "
    echo "    ./configure_docker0.sh 10.200.0.57/16"
    echo "    ./configure_docker0.sh 172.31.0.21/16"
    echo "    ./configure_docker0.sh 192.168.254.1/24"
    echo " "
    echo " NOTE: You should stop Docker before running this script."
    echo "       When you restart it, Docker will use the new IP."
    exit 2
fi

INIT_SYSTEM="sysv"
if ps -o comm -1 | grep -q systemd; then
    INIT_SYSTEM="systemd"
fi

NEW_IP="$1"
DOCKER_INIT="/etc/default/docker"

if [ ! -f "$DOCKER_INIT" ]; then
    cat << EOF > $DOCKER_INIT
# Docker Upstart and SysVinit configuration file

# Customize location of Docker binary (especially for development testing).
#DOCKER="/usr/local/bin/docker"

# Use DOCKER_OPTS to modify the daemon startup options.
#DOCKER_OPTS="--dns 8.8.8.8 --dns 8.8.4.4"
DOCKER_OPTS="--bip=$NEW_IP"

# If you need Docker to use an HTTP proxy, it can also be specified here.
#export http_proxy="http://127.0.0.1:3128/"

# This is also a handy place to tweak where Docker's temporary files go.
#export TMPDIR="/mnt/bigdrive/docker-tmp"
EOF

    echo "Created a new Docker default file at $DOCKER_INIT"
    exit 0;
fi

echo "Removing old docker0 network(s)"
NETWORKS=$(ip addr list docker0 | grep "inet " | cut -d" " -f6)
for NET in $NETWORKS; do
    echo "  $NET"
    ip addr del $NET dev docker0
done

echo "Adding new docker0 network"
ip addr add $NEW_IP dev docker0

echo "Removing old iptables rules"
iptables -t nat -F POSTROUTING
iptables -F DOCKER

CURRENT_OPTS=$(cat $DOCKER_INIT | grep "^ *DOCKER_OPTS" | sed 's/^/    /g')
NEW_OPTS=DOCKER_OPTS=\"--bip=$NEW_IP\"

echo " "

if [ "$CURRENT_OPTS" != "" ]; then
    TEMP_FILE="/tmp/docker_config.tmp"
    grep -v "^ *DOCKER_OPTS" $DOCKER_INIT > $TEMP_FILE
    echo " " >> $TEMP_FILE
    echo DOCKER_OPTS=\"--bip=$NEW_IP\" >> $TEMP_FILE
    cat $TEMP_FILE > $DOCKER_INIT
    rm -f $TEMP_FILE

    echo "WARNING: The existing DOCKER_OPTS were overwritten in $DOCKER_INIT:"
    echo "Old:"
    echo "$CURRENT_OPTS"
    echo "New:"
    echo "    $NEW_OPTS"
else
    echo " " >> $DOCKER_INIT
    echo DOCKER_OPTS=\"--bip=$NEW_IP\" >> $DOCKER_INIT
    echo "Success: $DOCKER_INIT has been modified."
fi

SYSTEMD_DOCKER_DIR="/etc/systemd/system/docker.service.d"
if [ "$INIT_SYSTEM" = "systemd" ]; then
    echo "Configuring systemd to use /etc/default/docker"
    if [ ! -d $SYSTEMD_DOCKER_DIR ]; then
        mkdir -p $SYSTEMD_DOCKER_DIR
    fi

    OPTS='$DOCKER_OPTS'
    cat << EOF > $SYSTEMD_DOCKER_DIR/debian-style-config.conf
# Enable /etc/default/docker configuration files with Systemd
[Service]
EnvironmentFile=-/etc/default/docker
ExecStart=
ExecStart=/usr/bin/docker daemon -H fd:// $OPTS

EOF
fi

echo ""
echo "Restarting Docker"
case $INIT_SYSTEM in
    sysv)
        service docker restart
        ;;
    systemd)
        systemctl daemon-reload
        systemctl restart docker.service
        sleep 1
        ;;
esac

echo "done."
