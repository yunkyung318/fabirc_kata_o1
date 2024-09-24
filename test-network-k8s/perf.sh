#!/bin/bash

# 랜덤한 정수 생성 (0-100)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# perf 데이터 수집
nohup sudo perf record -F 99 -a -g --output=/home/ykkang/fabric-samples/test-network-k8s/perf_${TIMESTAMP}.data &
