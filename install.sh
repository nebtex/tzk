#!/usr/bin/env bash

if echo "${VPNName:-tzk}" | grep -Eq  ^[a-z0-9]+$; then
    echo "${VPNName:-tzk} [VPNName matched]"
else
    echo "${VPNName:-tzk} is invalid name,  use only these characters a-z 0-9" && exit 100
fi

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

if command_exists docker;then
    echo "Docker is installed already"
else
    curl -sSL https://get.docker.com/ | sh
fi

apt-get update -y && apt-get install curl wget apt-transport-https -y 
# install sigil
curl -fsSL https://github.com/gliderlabs/sigil/releases/download/v0.4.0/sigil_0.4.0_Linux_x86_64.tgz | tar -zxC /usr/local/bin

if [ "${master:-false}" == "true" ];then
    hostnamectl set-hostname master1
    export ACLToken=$(uuidgen)
    mkdir -p /consul
    mkdit -p /caddy
    chmod 755 -R /consul
    chmod 755 -R /caddy
    
    docker run -d --env ACLToken=${ACLToken:?} --env ConsulHost=${ConsulHost:?} \
    --env master=true --net=host --device=/dev/net/tun --cap-add NET_ADMIN \
    --volume /consul:/consul --volume /caddy:/root/.caddy \
    --volume /etc/hosts:/etc/hosts --name tzk tzk
else
    docker run -d --env ACLToken=${ACLToken:?} --env ConsulHost=${ConsulHost:?} \
    --net=host --device=/dev/net/tun --volume /etc/hosts:/etc/hosts --cap-add NET_ADMIN \
    --name tzk tzk
fi

if [ "${master:-false}" == "true" ];then
    # install kubernetes
    sigil -p -i "$(curl -fsSL https://raw.githubusercontent.com/NebTex/tzk/master/kubernetes.sh)" \
        VPNName=${VPNName:-tzk} master=${master:-false} ConsulHost=127.0.0.1 \
        ACLToken=${ACLToken:?} | bash
else
    # install kubernetes
    sigil -p -i "$(curl -fsSL https://raw.githubusercontent.com/NebTex/tzk/master/kubernetes.sh)" \
        VPNName=${VPNName:-tzk} master=${master:-false} ConsulHost=${ConsulHost:?} \
        ACLToken=${ACLToken:?} | bash
fi

# print welcome
sleep 10

# create
BLUE='\e[34m'
RED='\e[31m'
MAGENTA='\e[35m'
CYAN='\e[36m'
NC='\e[39m' # No Color


echo -e "
★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
$BLUE

         █     █░▓█████  ██▓     ▄████▄   ▒█████   ███▄ ▄███▓▓█████
        ▓█░ █ ░█░▓█   ▀ ▓██▒    ▒██▀ ▀█  ▒██▒  ██▒▓██▒▀█▀ ██▒▓█   ▀
        ▒█░ █ ░█ ▒███   ▒██░    ▒▓█    ▄ ▒██░  ██▒▓██    ▓██░▒███
        ░█░ █ ░█ ▒▓█  ▄ ▒██░    ▒▓▓▄ ▄██▒▒██   ██░▒██    ▒██ ▒▓█  ▄
        ░░██▒██▓ ░▒████▒░██████▒▒ ▓███▀ ░░ ████▓▒░▒██▒   ░██▒░▒████▒
        ░ ▓░▒ ▒  ░░ ▒░ ░░ ▒░▓  ░░ ░▒ ▒  ░░ ▒░▒░▒░ ░ ▒░   ░  ░░░ ▒░ ░
          ▒ ░ ░   ░ ░  ░░ ░ ▒  ░  ░  ▒     ░ ▒ ▒░ ░  ░      ░ ░ ░  ░
          ░   ░     ░     ░ ░   ░        ░ ░ ░ ▒  ░      ░      ░
            ░       ░  ░    ░  ░░ ░          ░ ░         ░      ░  ░
                        ░

How can I add new node?:
========================

ConsulHost=${ConsulHost:?} ACLToken=${ACLToken:?} bash -c \"\$(curl -fsSL https://git.io/v1b4Q)\"

$NC
★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

vpn = ${VPNName:-tzk}
hostname = `hostname -s`.${VPNName:-tzk}.local
master = master1.${VPNName:-tzk}.local
logs = docker logs tzk

Enjoy !!!

`docker logs tzk`
"
