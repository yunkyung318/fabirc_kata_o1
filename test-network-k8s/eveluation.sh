#!/bin/bash

fabric_home="/home/ykkang/fabric-samples/test-network-k8s"
caliper_home="/home/ykkang/caliper-benchmarks"
kata_config="/opt/kata/share/defaults/kata-containers/configuration.toml"
iteration_count=10
namespace="test-network"
caliper_user="ykkang"
caliper_host="10.138.0.26" 
caliper_key="project.d" 
caliper_password="1"

function update_kata_config {
    local vcpu_count=$1
    sudo sed -i "s/^default_vcpus = .*/default_vcpus = ${vcpu_count}/" $kata_config
    echo "Updated Kata default vCPU to ${vcpu_count}"
}

function update_yaml_files {
    local mode=$1
    local vcpu_count=$2

    for yaml_file in $fabric_home/kube/org0/org0-orderer1.yaml \
                     $fabric_home/kube/org0/org0-ca.yaml \
                     $fabric_home/kube/org1/org1-ca.yaml \
                     $fabric_home/kube/org1/org1-peer1.yaml \
                     $fabric_home/kube/org1/org1-peer2.yaml \
                     $fabric_home/kube/org1/org1-cc-template.yaml; do
        if [[ $mode == "container" ]]; then
            sed -i '/runtimeClassName: kata/s/^/#/' "$yaml_file"
            
            sed -i '/resources:/,/limits:/ { /^[^#]/s/^/#/ }' "$yaml_file"
            sed -i '/limits:/,/cpu:/ { /^[^#]/s/^/#/ }' "$yaml_file"

        elif [[ $mode == "kata" ]]; then
            sed -i '/runtimeClassName: kata/s/^#//' "$yaml_file"

            if [[ $vcpu_count -gt 1 ]]; then
                sed -i '/resources:/,/limits:/ { /^#/s/^#// }' "$yaml_file"
                sed -i '/limits:/,/cpu:/ { /^#/s/^#// }' "$yaml_file"
                sed -i "/cpu:/s/: \"[0-9]*\"/: \"${vcpu_count}\"/" "$yaml_file"
            else
                sed -i '/resources:/,/limits:/ { /^[^#]/s/^/#/ }' "$yaml_file"
                sed -i '/limits:/,/cpu:/ { /^[^#]/s/^/#/ }' "$yaml_file"
            fi
        fi
    done
    echo "YAML files updated for ${mode} with vCPU=${vcpu_count}"
}


function set_physical_cpus {
    local cpu_count=$1
    local total_cpus=$(nproc --all)
    
    if [[ $cpu_count -lt $total_cpus ]]; then
        echo "Disabling CPUs from $cpu_count to $((total_cpus - 1))"
        for cpu in $(seq $cpu_count $((total_cpus - 1))); do
            sudo chcpu -d $cpu || echo "Failed to disable CPU $cpu"
        done
    fi

    echo "Enabling CPUs from 0 to $((cpu_count - 1))"
    for cpu in $(seq 0 $((cpu_count - 1))); do
        sudo chcpu -e $cpu || echo "Failed to enable CPU $cpu"
    done

    echo "Set physical CPUs to ${cpu_count}"
}

function deploy_fabric_network {
    cd $fabric_home
    bash kata_run.sh
    echo "Deployed Fabric network"


    if [[ $mode == "container" ]]; then
        echo "Container mode detected. Skipping mpstat installation check."
        return
    fi

    for pod in org0-orderer1 org1-peer1 org1-peer2; do
        while true; do
            pod_name=$(kubectl get pods -n $namespace | grep $pod | awk '{print $1}')
            if kubectl exec -n $namespace $pod_name -- which mpstat > /dev/null 2>&1; then
                echo "mpstat is installed on $pod_name"
                break
            else
                echo "mpstat is NOT installed on $pod_name, attempting installation"
            	kubectl exec -n $namespace $pod_name -- bash -c "apt-get update && apt-get install -y sysstat procps"
	    fi
        done
    done
}


function run_caliper {
    local experiment_dir=$1
    local physical_cpu=$2
    for i in $(seq 1 $iteration_count); do
        echo "========================== Iteration ${i} =========================="
	
	expect <<- EOF
        spawn ssh -o StrictHostKeyChecking=no -i $caliper_key $caliper_user@$caliper_host "rm -f $caliper_home/transaction_times.log"
        expect "password:"
        send "$caliper_password\r"
        expect eof
EOF

        bash $fabric_home/run_mpstat.sh &
        bash $fabric_home/run_pod_mpstat.sh ${i} &

        expect <<- EOF
        spawn ssh -o StrictHostKeyChecking=no -i $caliper_key $caliper_user@$caliper_host "cd $caliper_home && npx caliper launch manager --caliper-workspace . --caliper-networkconfig networks/fabric/test-network-org1.yaml --caliper-benchconfig assetbenchmark_300.yaml"
        expect "password:"
        send "$caliper_password\r"
        set timeout -1
        expect {
            "info  \[caliper\] \[caliper-engine\]        Benchmark finished" {
                send_user "Caliper benchmark completed\n";
            }
            eof {
                send_user "Caliper process ended\n";
            }
            timeout {
                send_user "Caliper benchmark timed out\n"; exit 1;
            }
        }
        expect eof
EOF

        pkill -f mpstat
        bash $fabric_home/stop_pod_mpstat.sh

        local log_prefix="kata"
        if [[ $experiment_dir == *"container"* ]]; then
            log_prefix="container"
        fi
        local mpstat_log="${fabric_home}/Data/physical${physical_cpu}/physical${physical_cpu}_${experiment_dir}/${i}/${log_prefix}_physical${physical_cpu}_${experiment_dir}_${i}.log"
        mv $fabric_home/mpstat_output.log ${mpstat_log}

        expect <<- EOF
        spawn ssh -o StrictHostKeyChecking=no -i $caliper_key $caliper_user@$caliper_host "cd $caliper_home && sudo mv report.html ${caliper_home}/Data/physical${physical_cpu}/physical${physical_cpu}_${experiment_dir}/${i}/tps/${log_prefix}_physical${physical_cpu}_${experiment_dir}_${i}.html"
        expect "password:"
        send "$caliper_password\r"
        expect eof
EOF

        expect <<- EOF
        spawn ssh -o StrictHostKeyChecking=no -i $caliper_key $caliper_user@$caliper_host "cd $caliper_home && python3 time.py && python3 delete_date.py && sudo mv processed_time.log ${caliper_home}/Data/physical${physical_cpu}/physical${physical_cpu}_${experiment_dir}/${i}/processed_physical_${experiment_dir}_${i}.log"
        expect "password:"
        send "$caliper_password\r"
        expect eof
EOF

        echo "Iteration ${i} results saved"
    done
}

function fetch_pod_results {
    local experiment_dir=$1
    local physical_cpu=$2

    for i in $(seq 1 $iteration_count); do
        local host_dir="${fabric_home}/Data/physical${physical_cpu}/physical${physical_cpu}_${experiment_dir}/${i}/pod_mpstat"

        local pods=$(kubectl get pods -n $namespace --no-headers -o custom-columns=":metadata.name" | grep -v -e "fabric-rest-sample" -e "ccaas" -e "ca")

        for pod in $pods; do
            local role=""
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

            local pod_file="/tmp/mpstat_vcpu3_kata_${role}_${i}.log"
            local host_file="${host_dir}/physical${physical_cpu}_${experiment_dir}_${role}_${i}.log"

            kubectl cp $namespace/$pod:$pod_file $host_file
            echo "Copied file from pod $pod to $host_file"
        done

        echo "All files have been copied to $host_dir."
    done
}

function run_orderer_peer_experiment {
    local experiment_dir=$1
    local orderer_vcpu=$2
    local peer_vcpu=$3
    local physical_cpu=$4

    local adjusted_orderer_vcpu=$((orderer_vcpu - 1))
    local adjusted_peer_vcpu=$((peer_vcpu - 1))

    if [[ $orderer_vcpu -gt 1 ]]; then
        sed -i '/resources:/,/limits:/ { /^#/s/^#// }' $fabric_home/kube/org0/org0-orderer1.yaml
        sed -i "/requests:/,/limits:/ s/cpu: \".*\"/cpu: \"${adjusted_orderer_vcpu}\"/" $fabric_home/kube/org0/org0-orderer1.yaml
        sed -i "/limits:/,/cpu:/ s/cpu: \".*\"/cpu: \"${adjusted_orderer_vcpu}\"/" $fabric_home/kube/org0/org0-orderer1.yaml
    fi

    if [[ $peer_vcpu -gt 1 ]]; then
        sed -i '/resources:/,/limits:/ { /^#/s/^#// }' $fabric_home/kube/org1/org1-peer1.yaml
        sed -i "/requests:/,/limits:/ s/cpu: \".*\"/cpu: \"${adjusted_peer_vcpu}\"/" $fabric_home/kube/org1/org1-peer1.yaml
        sed -i "/limits:/,/cpu:/ s/cpu: \".*\"/cpu: \"${adjusted_peer_vcpu}\"/" $fabric_home/kube/org1/org1-peer1.yaml

        sed -i '/resources:/,/limits:/ { /^#/s/^#// }' $fabric_home/kube/org1/org1-peer2.yaml
        sed -i "/requests:/,/limits:/ s/cpu: \".*\"/cpu: \"${adjusted_peer_vcpu}\"/" $fabric_home/kube/org1/org1-peer2.yaml
        sed -i "/limits:/,/cpu:/ s/cpu: \".*\"/cpu: \"${adjusted_peer_vcpu}\"/" $fabric_home/kube/org1/org1-peer2.yaml
    fi

    deploy_fabric_network
    run_caliper $experiment_dir $physical_cpu
}


function main {
    for physical_cpu in 4 6 8; do
        set_physical_cpus $physical_cpu

        if [[ $physical_cpu -eq 2 ]]; then
            update_kata_config 1
            update_yaml_files "kata" 1
            deploy_fabric_network
            run_caliper "all_vcpu1" $physical_cpu
            fetch_pod_results "all_vcpu1" $physical_cpu

            update_yaml_files "container" 1
            deploy_fabric_network
            run_caliper "container" $physical_cpu
            fetch_pod_results "container" $physical_cpu

        elif [[ $physical_cpu -eq 4 ]]; then
            for vcpu in 2; do
                update_kata_config $vcpu
                update_yaml_files "kata" $vcpu
                deploy_fabric_network
                run_caliper "all_vcpu${vcpu}" $physical_cpu
                fetch_pod_results "all_vcpu${vcpu}" $physical_cpu
            done

            run_orderer_peer_experiment "orderer1_peer2" 1 2 $physical_cpu
            fetch_pod_results "orderer1_peer2" $physical_cpu

            run_orderer_peer_experiment "orderer2_peer1" 2 1 $physical_cpu
            fetch_pod_results "orderer2_peer1" $physical_cpu

            update_yaml_files "container" 1
            deploy_fabric_network
            run_caliper "container" $physical_cpu
            fetch_pod_results "container" $physical_cpu

        elif [[ $physical_cpu -eq 6 ]]; then
            for vcpu in 1 2 3; do
                update_kata_config $vcpu
                update_yaml_files "kata" $vcpu
                deploy_fabric_network
                run_caliper "all_vcpu${vcpu}" $physical_cpu
                fetch_pod_results "all_vcpu${vcpu}" $physical_cpu
            done

            run_orderer_peer_experiment "orderer1_peer2" 1 2 $physical_cpu
            fetch_pod_results "orderer1_peer2" $physical_cpu

            run_orderer_peer_experiment "orderer1_peer3" 1 3 $physical_cpu
            fetch_pod_results "orderer1_peer3" $physical_cpu

            run_orderer_peer_experiment "orderer2_peer1" 2 1 $physical_cpu
            fetch_pod_results "orderer2_peer1" $physical_cpu

            run_orderer_peer_experiment "orderer3_peer1" 3 1 $physical_cpu
            fetch_pod_results "orderer3_peer1" $physical_cpu

            update_yaml_files "container" 1
            deploy_fabric_network
            run_caliper "container" $physical_cpu
            fetch_pod_results "container" $physical_cpu

        elif [[ $physical_cpu -eq 8 ]]; then
            update_kata_config 4
            update_yaml_files "kata" 4
            deploy_fabric_network
            run_caliper "all_vcpu4" $physical_cpu
            fetch_pod_results "all_vcpu4" $physical_cpu

            run_orderer_peer_experiment "orderer1_peer2" 1 2 $physical_cpu
            fetch_pod_results "orderer1_peer2" $physical_cpu

            update_yaml_files "container" 1
            deploy_fabric_network
            run_caliper "container" $physical_cpu
            fetch_pod_results "container" $physical_cpu
        fi
    done
}


main
