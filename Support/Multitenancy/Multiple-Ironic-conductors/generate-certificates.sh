#!/bin/bash
#

openssl req -x509 -subj "/CN=Kubernetes API" -new -newkey rsa:2048 -nodes -keyout "/tmp/ca.key" -sha256 -days 3650 -out "/tmp/ca.crt"

openssl req -x509 -subj "/CN=ETCD CA" -new -newkey rsa:2048 -nodes -keyout "/tmp/etcd.key" -sha256 -days 3650 -out "/tmp/etcd.crt"
