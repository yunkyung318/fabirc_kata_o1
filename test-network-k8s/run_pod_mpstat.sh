#!/bin/bash

iteration=$1
# Namespace where the pods are running
namespace="test-network"

# Get the list of pod names, excluding fabric-rest-sample and chaincode-related pods
pods=$(kubectl get pods -n $namespace --no-headers -o custom-columns=":metadata.name" | grep -v -e "fabric-rest-sample" -e "ccaas" -e "ca")

# Loop through each pod and run mpstat simultaneously
for pod in $pods; do
    echo "=======$pod======"
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

    # Define the output log file path
    output_file="/tmp/mpstat_vcpu3_kata_${role}_${iteration}.log"

    # Execute mpstat inside the pod simultaneously, saving the output to the log file
    kubectl exec -n $namespace $pod -- bash -c "mpstat -P ALL 1 > $output_file" &

    echo "Started mpstat on pod $pod, output will be saved to $output_file"
done

# Wait for all background processes to finish
wait

echo "All mpstat processes have been started."

