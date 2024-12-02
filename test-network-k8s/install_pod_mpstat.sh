#!/bin/bash

# Namespace where the pods are running
namespace="test-network"

# Get the list of pod names, excluding fabric-rest-sample and chaincode-related pods
pods=$(kubectl get pods -n $namespace --no-headers -o custom-columns=":metadata.name" | grep -v -e "fabric-rest-sample" -e "ccaas" -e "ca")

# Loop through each pod and install mpstat and pkill
for pod in $pods; do
    echo "Installing mpstat (sysstat) and pkill (procps) on pod $pod..."

    # Detect package manager and install sysstat and procps in the pod
    kubectl exec -n $namespace $pod -- bash -c "
    if command -v apt-get > /dev/null; then
        apt-get update && apt-get install -y sysstat procps
    elif command -v yum > /dev/null; then
        yum install -y sysstat procps
    else
        echo 'Unsupported package manager. Install manually.'
    fi" &

    echo "Installation started on pod $pod."
done

# Wait for all background installation processes to finish
wait

echo "All installations have been completed."

