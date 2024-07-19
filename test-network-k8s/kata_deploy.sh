mapfile -t deployments < <(kubectl get deployment -n test-network | awk '$1 != "NAME" && $1 != "fabric-operator" {print $1}')

for deployment in "${deployments[@]}"; do
        kubectl patch deployment "$deployment" -n test-network --patch '{
           "spec": {
             "template": {
               "spec": {
                 "runtimeClassName": "kata"
               }
             }
           }
        }'
        kubectl get deployment "$deployment" -n test-network -o jsonpath='{.spec.template.spec.runtimeClassName}'
done
