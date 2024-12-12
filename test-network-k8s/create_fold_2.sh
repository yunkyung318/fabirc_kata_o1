#!/bin/bash

# 설정 변수
fabric_home="/home/ykkang/fabric-samples/test-network-k8s/Data"
caliper_home="/home/ykkang/caliper-benchmarks/Data"

# 디렉토리 생성 함수
function create_directories {
    local base_dir=$1
    local sub_dir=$2

    for physical_cpu in 2 4 6 8; do
        case $physical_cpu in
            2)
                mkdir -p ${base_dir}/physical2/{physical2_container,physical2_all_vcpu1}/{1..10}/${sub_dir}/{1..10}
                ;;
            4)
                mkdir -p ${base_dir}/physical4/{physical4_container,physical4_all_vcpu1,physical4_all_vcpu2,physical4_orderer1_peer2,physical4_orderer2_peer1}/{1..10}/${sub_dir}/{1..10}
                ;;
            6)
                mkdir -p ${base_dir}/physical6/{physical6_container,physical6_all_vcpu1,physical6_all_vcpu2,physical6_all_vcpu3,physical6_orderer1_peer2,physical6_orderer1_peer3,physical6_orderer2_peer1,physical6_orderer3_peer1}/{1..10}/${sub_dir}/{1..10}
                ;;
            8)
                mkdir -p ${base_dir}/physical8/{physical8_container,physical8_all_vcpu4,physical8_orderer1_peer2}/{1..10}/${sub_dir}/{1..10}
                ;;
        esac
    done

    echo "Directories created under ${base_dir} with subdirectory ${sub_dir}"}
}
# Fabric-Server 디렉토리 생성 (pod_mpstat 전용)
create_directories $fabric_home "pod_mpstat"

# Caliper-Server 디렉토리 생성 (tps 전용)
ssh -i project.d ykkang@10.138.0.26 "$(declare -f create_directories); create_directories $caliper_home tps"

echo "All directories created successfully."
