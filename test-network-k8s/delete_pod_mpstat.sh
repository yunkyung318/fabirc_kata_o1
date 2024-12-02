#!/bin/bash

# Namespace where the pods are running
namespace="test-network"

# Get the list of pod names, excluding fabric-rest-sample and chaincode-related pods
pods=$(kubectl get pods -n $namespace --no-headers -o custom-columns=":metadata.name" | grep -v -e "fabric-rest-sample" -e "ccaas")

# Loop through each pod and delete the file inside the pod
for pod in $pods; do
    # Define the file path in the pod
    pod_file="/tmp/mpstat_host6_vcpu1_kata_${pod}.log"

    # Delete the file inside the pod
    kubectl exec -n $namespace $pod -- bash -c "rm -f $pod_file"

    echo "Deleted file $pod_file from pod $pod"
done

echo "All files have been deleted from the pods."

