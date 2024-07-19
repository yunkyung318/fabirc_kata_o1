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
sudo -E kubectl taint nodes yun-fabric node-role.kubernetes.io/master:NoSchedule-

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
kubectl wait --for=condition=Ready pod --all --all-namespaces --timeout=600s
./network up
kubectl get pods -A

### Channel Create ###
./network channel create

### Chaincode Deploy ###
./network chaincode deploy asset-transfer-basic ../asset-transfer-basic/chaincode-java

echo "Not END."
sleep 30

### Chaincode invoke & query ###
./network chaincode invoke asset-transfer-basic '{"Args":["InitLedger"]}'
./network chaincode query  asset-transfer-basic '{"Args":["ReadAsset","asset1"]}'

sleep 2
kubectl get pods -A

### Make Certificate ###
### externally accessible ###
./network rest-easy

### Get IP & PORT ###
kubectl_output=$(kubectl get svc -A)

org1_ca_ip=$(echo "$kubectl_output" | grep "org1-ca" | awk '{print $4}')
org1_ca_port=$(echo "$kubectl_output" | grep "org1-ca" | awk '{print $6}' | cut -d':' -f2 | cut -d'/' -f1)

org1_peer1_ip=$(echo "$kubectl_output" | grep "org1-peer1 " | awk '{print $4}')
org1_peer1_port=$(echo "$kubectl_output" | grep "org1-peer1 " | awk '{print $6}' | cut -d':' -f2 | cut -d'/' -f1)

### Modify /etc/hosts ###
sudo sed -i '/org1-ca/d' /etc/hosts
sudo sed -i '/org1-peer1/d' /etc/hosts

echo "$org1_ca_ip org1-ca" | sudo tee -a /etc/hosts
echo "$org1_peer1_ip org1-peer1" | sudo tee -a /etc/hosts

### Modifying IP & PORT of a Connection file ###
jq --arg ip "$org1_peer1_ip" --arg port "$org1_peer1_port" --arg ca_ip "$org1_ca_ip" --arg ca_port "$org1_ca_port" \
  '.peers["org1-peers"].url = "grpcs://\($ip):\($port)" |
   .certificateAuthorities["org1-ca"].url = "https://\($ca_ip):\($ca_port)"' \
  build/fabric-rest-sample-config/HLF_CONNECTION_PROFILE_ORG1 > build/fabric-rest-sample-config/temp1.json && mv build/fabric-rest-sample-config/temp1.json build/fabric-rest-sample-config/HLF_CONNECTION_PROFILE_ORG1

### Send Certificates to Caliper Server ###
./send_cert.sh

echo "################END################"
