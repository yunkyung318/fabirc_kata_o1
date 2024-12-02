#!/bin/bash
iteration=$1
# Namespace where the pods are running
namespace="test-network"

# Get the list of pod names, excluding fabric-rest-sample and chaincode-related pods
pods=$(kubectl get pods -n $namespace --no-headers -o custom-columns=":metadata.name" | grep -v -e "fabric-rest-sample" -e "ccaas" -e "ca")

# Loop through each pod and stop mpstat by killing the process
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

    # Attempt to kill the mpstat process inside the pod
    kubectl exec -n $namespace $pod -- pkill mpstat

    echo "Stopped mpstat on pod $pod"
done
#/home/ykkang/fabric-samples/test-network-k8s/fetch_pod_mpstat.sh $iteration
echo "All mpstat processes have been stopped."

