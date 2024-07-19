#!/bin/bash

kubectl_output=$(kubectl get svc -A)

org1_ca_ip=$(echo "$kubectl_output" | grep "org1-ca" | awk '{print $4}')
org1_ca_port=$(echo "$kubectl_output" | grep "org1-ca" | awk '{print $6}' | cut -d':' -f2 | cut -d'/' -f1)

org1_peer1_ip=$(echo "$kubectl_output" | grep "org1-peer1 " | awk '{print $4}')
org1_peer1_port=$(echo "$kubectl_output" | grep "org1-peer1 " | awk '{print $6}' | cut -d':' -f2 | cut -d'/' -f1)

org2_ca_ip=$(echo "$kubectl_output" | grep "org2-ca" | awk '{print $4}')
org2_ca_port=$(echo "$kubectl_output" | grep "org2-ca" | awk '{print $6}' | cut -d':' -f2 | cut -d'/' -f1)

org2_peer1_ip=$(echo "$kubectl_output" | grep "org2-peer1" | awk '{print $4}')
org2_peer1_port=$(echo "$kubectl_output" | grep "org2-peer1" | awk '{print $6}' | cut -d':' -f2 | cut -d'/' -f1)

sudo sed -i '/org1-ca/d' /etc/hosts
sudo sed -i '/org1-peer1/d' /etc/hosts
sudo sed -i '/org2-ca/d' /etc/hosts
sudo sed -i '/org2-peer1/d' /etc/hosts

echo "$org1_ca_ip org1-ca" | sudo tee -a /etc/hosts
echo "$org1_peer1_ip org1-peer1" | sudo tee -a /etc/hosts
echo "$org2_ca_ip org2-ca" | sudo tee -a /etc/hosts
echo "$org2_peer1_ip org2-peer1" | sudo tee -a /etc/hosts

jq --arg ip "$org1_peer1_ip" --arg port "$org1_peer1_port" --arg ca_ip "$org1_ca_ip" --arg ca_port "$org1_ca_port" \
  '.peers["org1-peers"].url = "grpcs://\($ip):\($port)" |
   .peers["org1-peers"].grpcOptions["ssl-target-name-override"] = $ip |
   .peers["org1-peers"].grpcOptions["hostnameOverride"] = $ip |
   .certificateAuthorities["org1-ca"].url = "https://\($ca_ip):\($ca_port)"' \
  build/fabric-rest-sample-config/HLF_CONNECTION_PROFILE_ORG1 > build/fabric-rest-sample-config/temp1.json && mv build/fabric-rest-sample-config/temp1.json build/fabric-rest-sample-config/HLF_CONNECTION_PROFILE_ORG1

jq --arg ip "$org2_peer1_ip" --arg port "$org2_peer1_port" --arg ca_ip "$org2_ca_ip" --arg ca_port "$org2_ca_port" \
  '.peers["org2-peers"].url = "grpcs://\($ip):\($port)" |
   .peers["org2-peers"].grpcOptions["ssl-target-name-override"] = $ip |
   .peers["org2-peers"].grpcOptions["hostnameOverride"] = $ip |
   .certificateAuthorities["org2-ca"].url = "https://\($ca_ip):\($ca_port)"' \
  build/fabric-rest-sample-config/HLF_CONNECTION_PROFILE_ORG2 > build/fabric-rest-sample-config/temp2.json && mv build/fabric-rest-sample-config/temp2.json build/fabric-rest-sample-config/HLF_CONNECTION_PROFILE_ORG2


