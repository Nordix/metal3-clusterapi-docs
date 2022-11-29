# Encrypt data at rest

## Key Objectives

[main page](README.md)|[experiments](experiments/AIR-142_.md)

1. Encrypting data at rest using CABPK cofiguration
2. Providing extra certificates using CABPK

Data at rest can be encrypted using the following steps:

1. Creating the secret key and encryption config file
2. Instruct the kub-apiserver to use encryption by specifying `--encryption-provider-config` flag in **CABPK** configuration
3. Do `kubeadm init` / restart the api server

We elaborate steps 1 and 2 with examples here. Step 3 is self explanatory.

### Creating the secret key and encryption config file

* Generate a 32 byte random key and base64 encode it.
  `head -c 32 /dev/urandom | base64`
  **Example output :** `8bDfNzN1Pj2MEgvJj6euor4RQK/iZXz53dEM+lsDkok=`
* Create a new encryption config file and specify the secret in it. An example configuration file is as follows:

    ```yaml
    apiVersion: apiserver.config.k8s.io/v1
    kind: EncryptionConfiguration
    resources:
      - resources:
        - secrets
        providers:
        - aescbc:
            keys:
            - name: key1
              secret: 8bDfNzN1Pj2MEgvJj6euor4RQK/iZXz53dEM+lsDkok=
        - identity: {}
    ```

### Configuring kube-apiserver using CABPK config

The next step is to place the configuration file in the control plane node and instruct the kube-apiserver to encrypt secrets at rest. Both of these tasks can be done using the CABPK configuration file. A working example CABPK file which have these two inclusions is as follows:

```yaml
apiVersion: bootstrap.cluster.x-k8s.io/v1alpha2
kind: KubeadmConfig
metadata:
  creationTimestamp: null
  name: controlplane-0-config
  namespace: default
spec:
  clusterConfiguration:
    ## encryption-provider-config instructs api server to encrypt secret using the given config file
    apiServer:
      extraArgs:
        encryption-provider-config: "/etc/kubernetes/pki/secrets.conf"
    certificatesDir: ""
    controlPlaneEndpoint: ""
    controllerManager: {}
    dns:
      type: ""
    etcd: {}
    imageRepository: ""
    kubernetesVersion: ""
    networking:
      dnsDomain: ""
      podSubnet: ""
      serviceSubnet: ""
    scheduler: {}
  initConfiguration:
    localAPIEndpoint:
      advertiseAddress: ""
      bindPort: 0
    nodeRegistration: {}
  ## The following file section uploads the content of the encryption config file inside the control plane in desired location
  files:
    - content: "YXBpVmVyc2lvbjogYXBpc2VydmVyLmNvbmZpZy5rOHMuaW8vdjEKa2luZDogRW5jcnlwdGlvbkNvbmZpZ3VyYXRpb24KcmVzb3VyY2VzOgogIC0gcmVzb3VyY2VzOgogICAgLSBzZWNyZXRzCiAgICBwcm92aWRlcnM6CiAgICAtIGFlc2NiYzoKICAgICAgICBrZXlzOgogICAgICAgIC0gbmFtZToga2V5MQogICAgICAgICAgc2VjcmV0OiA4YkRmTnpOMVBqMk1FZ3ZKajZldW9yNFJRSy9pWlh6NTNkRU0rbHNEa29rPQogICAgLSBpZGVudGl0eToge30gICAgICAgICAgICAgICAgICAgICAgICAK"
      encoding: base64
      path: "/etc/kubernetes/pki/secrets.conf"
      permissions: "0640"
status: {}

```

### Testing the encryption

The following command will create a secret:

`kubectl create secret generic secret1 -n default    -from-literal=mykey=mydata`
And then we can read the secret from etcd using the following command:

```bash
ETCDCTL_API=3 etcdctl --endpoints=https://172.17.0.4:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get /registry/secrets/default/secret4 | hexdump -C
```

We shall see that the stored secret is prefixed with `k8s:enc:aescbc:v1:` which indicates the aescbc provider has encrypted the resulting data.

### Note

The example shows that we keep the encryption configuration file `secrets.conf` in `/etc/kubernetes/pki/` directory. This directory volume is already mounted in kube-apiserver container so we do not need to do anything extra here. If you want to keep this file to some other directory then you also have to add the volume  and volumeMount in CABPK configuration. A more detailed description of the encryption process can be found here [Encrypting Secret Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/).

## Use pre-generated certs and user provided CA

We can provide either CA certs only or we can provide the whole list of certificates in `/etc/kubernetes/pki`. The certificates can be put in the file system with the proper path using a shell script.  In case we provide CA cert only, kubeadm will generate the other certificates using the CA cert. In the latter case, kubeadm will take the pre-generated certs and avoid generating new ones. The placement of the certs can be done using a script.

In case of CABPK the following certificates and keys can be specified by the user:

```text
cluster-ca-cert
cluster-ca-key

etcd-ca-cert
etcd-ca-key

front-proxy-ca-cert
front-proxy-ca-key

service-account-private-key
service-account-public-key
```
