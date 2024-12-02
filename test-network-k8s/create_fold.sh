#!/bin/bash

# Base directory
base_dir="physical8"

# Folders to create
folders=(
    "physical8_all_vcpu4"
    "physical8_orderer1_peer2"
    "physical8_container"
)

# Loop to create folder structure
for folder in "${folders[@]}"; do
    for i in {1..10}; do
        mkdir -p "$base_dir/$folder/$i/pod_mpstat"
    done
done

echo "Directory structure created successfully under $base_dir"

