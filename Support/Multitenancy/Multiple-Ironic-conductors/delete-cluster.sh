#!/bin/bash

source ./config.sh

cluster_number=$1

kubectl delete -f /tmp/test${cluster_number}-cluster.yaml
