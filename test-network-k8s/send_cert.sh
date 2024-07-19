#!/usr/bin/expect

set passphrase "1"

set user "ykkang"
set host "10.138.0.26"
set identity_file "project.d"
set remote_dir "/home/ykkang/caliper-benchmarks/fabric-rest-sample-config"
set local_dir "build/fabric-rest-sample-config/"

set timeout -1
spawn ssh -o StrictHostKeyChecking=no -i $identity_file $user@$host "rm -rf $remote_dir"

expect "Enter passphrase for key '$identity_file':"
send "$passphrase\r"

set timeout -1
spawn scp -o StrictHostKeyChecking=no -i $identity_file -r $local_dir $user@$host:/home/ykkang/caliper-benchmarks

expect "Enter passphrase for key '$identity_file':"
send "$passphrase\r"

interact

