#!/bin/bash

LOGFILE="/home/ykkang/fabric-samples/test-network-k8s/pidstat.log"

pidstat -u 1  >> $LOGFILE

