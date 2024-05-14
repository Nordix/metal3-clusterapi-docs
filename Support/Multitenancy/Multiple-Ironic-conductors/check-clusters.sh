#!/bin/bash

source ./config.sh

START_NUM=${1:-1}

# Run describe for all clusters
for i in $(seq $START_NUM $N_NODES); do
  clusterctl -n "test${i}" describe cluster "test${i}"
done
