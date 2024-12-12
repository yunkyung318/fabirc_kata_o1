
#!/bin/bash
peer_vcpu=2
orderer_vcpu=1

adjusted_orderer_vcpu=$((orderer_vcpu - 1))
adjusted_peer_vcpu=$((peer_vcpu - 1))

echo "${adjusted_orderer_vcpu}"
echo "${adjusted_peer_vcpu}"
