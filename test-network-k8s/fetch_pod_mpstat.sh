#!/bin/bash

# Get the iteration as an argument
iteration=$1

# Namespace where the pods are running
namespace="test-network"

# Directory on the host to store the files, with iteration subdirectory
host_dir="./physical6/physical8_all_vcpu3/${iteration}/pod_mpstat/"

# Get the list of pod names, excluding fabric-rest-sample and chaincode-related pods
pods=$(kubectl get pods -n $namespace --no-headers -o custom-columns=":metadata.name" | grep -v -e "fabric-rest-sample" -e "ccaas" -e "ca")

# Loop through each pod and copy the file from the pod to the host
for pod in $pods; do
    # Extract the base name of the pod (removes the random suffix)
    if [[ $pod == org0-ca* ]]; then
        role="org0_ca"
    elif [[ $pod == org0-orderer* ]]; then
        role="org0_orderer"
    elif [[ $pod == org1-ca* ]]; then
        role="org1_ca"
    elif [[ $pod == org1-peer1* ]]; then
        role="org1_peer1"
    elif [[ $pod == org1-peer2* ]]; then
        role="org1_peer2"
    elif [[ $pod == org1peer1* ]]; then
        role="cc-peer1"
    elif [[ $pod == org1peer2* ]]; then
        role="cc-peer2"
    else
        continue
    fi

    # Define the file path in the pod and the destination on the host with iteration
    pod_file="/tmp/mpstat_vcpu3_kata_${role}_${iteration}.log"
    host_file="${host_dir}/physical_all_vcpu3_${role}_${iteration}.log"

    # Copy the file from the pod to the host
    kubectl cp $namespace/$pod:$pod_file $host_file
    echo "Copied file from pod $pod to $host_file"

done

echo "All files have been copied to $host_dir."

