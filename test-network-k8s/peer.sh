#!/bin/bash

# First perf record command with 10 seconds duration and 99Hz frequency
sudo perf record -p 174865,175039 -o peer.data -F 99 --duration 10 &

# Second perf record command with 10 seconds duration and 99Hz frequency
sudo perf record -p 174482 -o ord.data -F 99 --duration 10 &

# Wait for both commands to finish
wait

echo "Both perf record commands were run for 10 seconds at 99Hz and then stopped."

