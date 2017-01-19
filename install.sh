#!/usr/bin/env bash
TZKD_VERSION=0.2.0

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

curl -o /tmp/tzk.toml https://raw.githubusercontent.com/NebTex/tzk/master/kubernetes.sh

# install tzk daemon
RUN wget https://github.com/NebTex/tzk-daemon/releases/download/v${TZKD_VERSION}/tzkd_linux_amd64 && \
    mv tzkd_linux_amd64 /usr/local/bin/tzkd && \
    chmod +x /usr/local/bin/tzkd && \
# install sigil
curl -fsSL https://github.com/gliderlabs/sigil/releases/download/v0.4.0/sigil_0.4.0_Linux_x86_64.tgz | tar -zxC /usr/local/bin

curl -o /tmp/tzk.toml https://raw.githubusercontent.com/NebTex/tzk/master/tzk.toml

# install tzk daemon
wget https://github.com/NebTex/tzk-daemon/releases/download/v${TZKD_VERSION}/tzkd_linux_amd64 && \
    mv tzkd_linux_amd64 /usr/local/bin/tzkd && \
    chmod +x /usr/local/bin/tzkd && \
    mkdir -p /etc/tzk.d
       
if [ "${master:-false}" == "true" ];then
    export ACLToken=$(uuidgen)
    mkdir -p /consul
    mkdir -p /caddy
    chmod 755 -R /consul
    chmod 755 -R /caddy
fi
 
 sigil -p -i "$(cat /tmp/tzk.toml)" \
    VPNName=${VPNName:-tzk} ACLToken=${ACLToken:?} master=${master:-false} \
    Subnet=${Subnet:-10.187.0.0/16} ConsulHost=${ConsulHost:?} \
    NodeIP=${NodeIP:-} \
    ClusterCIDR=${ClusterCIDR:-10.32.0.0/12}\
    PodSubnet=${PodSubnet:-}\
    > /etc/tzk.d/tzk.toml
    
if [ "${master:-false}" != "true" ];then
  # set docker new subnet
  curl -sS https://raw.githubusercontent.com/NebTex/tzk/master/configure_docker0.sh | sudo bash -s - `tzkd get podSubnet`    
fi

docker run -d \
    --env ACLToken=${ACLToken:?} \
    --env ConsulHost=${ConsulHost:?} \
    --env master=${master:-false} \
    --net=host \
    --restart=always
    --device=/dev/net/tun \
    --cap-add NET_ADMIN \
    --volume /consul-tinc:/consul \
    --volume /etc/tinc/tzk:/etc/tinc/tzk \
    --volume /etc/tzk.d/:/etc/tzk.d/ \
    --volume /caddy:/root/.caddy \
    --volume /etc/hosts:/etc/hosts --name tzk nebtex/tzk

# print welcome
sleep 5

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
ip = `tzkd get ip`
podSubnet = `tzkd get podSubnet`
master = master1.${VPNName:-tzk}.local
logs = tzkd get logs

Enjoy !!!

"

