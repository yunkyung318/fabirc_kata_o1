#!/bin/bash

# 설정 변수
base_dir="/home/ykkang/fabric-samples/test-network-k8s/Data"

# physicalX 디렉토리를 탐색
for physical_dir in "$base_dir"/physical*; do
    # experiment_dir 디렉토리 탐색
    for experiment_dir in "$physical_dir"/*; do
        # iteration 디렉토리 탐색
        for iteration_dir in "$experiment_dir"/{1..10}; do
            pod_mpstat_dir="$iteration_dir/pod_mpstat"

            # pod_mpstat 내부의 하위 디렉토리 삭제
            if [ -d "$pod_mpstat_dir" ]; then
                echo "Removing subdirectories inside: $pod_mpstat_dir"
                find "$pod_mpstat_dir" -mindepth 1 -type d -exec rm -rf {} +
            fi
        done
    done
done

echo "Unnecessary directories inside pod_mpstat removed."

