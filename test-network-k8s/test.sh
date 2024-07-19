#!/bin/bash

random_number=$RANDOM
sudo mv build build_${random_number}
sudo rm $HOME/.kube/config

#### k8s init ####
sudo kubeadm reset --cri-socket unix://var/run/crio/crio.sock
sudo systemctl restart crio
sudo systemctl restart kubelet
sudo kubeadm init --cri-socket unix://var/run/crio/crio.sock --pod-network-cidr=10.244.0.0/16

### Create k8s config file ###
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

### Taint nodes ###
sudo -E kubectl taint nodes --all node-role.kubernetes.io/control-plane-
sudo -E kubectl taint nodes --all node-role.kubernetes.io/master:NoSchedule-

### Apply calico ###
sudo -E kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

### Create runtimeClassName ###
sudo -E kubectl apply -f runtime.yaml

### Test ###
sudo -E kubectl apply -f nginx-kata.yaml

sleep 2
sudo kubectl get pods -A

### Apply fabric_crd & nginx_ingress_controller ###
### Run script/cluster.sh ###
./network cluster init

### Setting ingress controller ###
kubectl label nodes yun-fabric ingress-ready=true
kubectl patch deployments ingress-nginx-controller -n ingress-nginx --patch '{"spec":{"template":{"spec":{"hostNetwork":true}}}}'

sleep 2

### Make pv for peer, orederer, ca ###
source make_pv.sh

### Check pv ###
kubectl get pv

### Apply fabric (ca, peer, orderer) ###
### Run script/test_network.sh ###
sleep 30
./network up
kubectl get pods -A

./network channel create
