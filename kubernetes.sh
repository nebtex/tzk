#!/usr/bin/env bash

# install kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl kubernetes-cni

{{ if eq "${master:-false}" "true" }}
# setup kubernetes token
export KubeToken=\$(kubeadm token generate)

# save KubeToken on consul
curl -s -X PUT -d "\$KubeToken" 'https://${ConsulHost:?}/v1/kv/${VPNName:-tzk}/KubeToken?cas=0&token=${ACLToken:?}'

{{ end }}
# get kube token
export KubeToken="\$(curl -X GET 'https://${ConsulHost:?}/v1/kv/${VPNName:-tzk}/KubeToken?token=${ACLToken:?}&raw')"

if [ "x$KubeToken" == "x" ]; then echo "No kubernetes token found, maybe you have not enough permissions"; exit 1; fi

kubeadm reset
{{ if eq "${master:-false}" "true" }}
# get master address
export MasterAddress="\$(curl -X GET 'https://${ConsulHost:?}/v1/kv/${VPNName:-tzk}/Hosts/master1/VpnAddress?token=${ACLToken:?}&raw')"

#init kubernetes
kubeadm init --api-advertise-addresses=\$MasterAddress --api-external-dns-names=master1.${VPNName:-tzk}.local --token=\$KubeToken

# set dedicated master label
kubectl label nodes master1 dedicated=master

# install weave network
kubectl apply -f https://git.io/weave-kube
{{ else }}
kubeadm join --token=\$KubeToken master1.${VPNName:-tzk}.local
{{ end }}
