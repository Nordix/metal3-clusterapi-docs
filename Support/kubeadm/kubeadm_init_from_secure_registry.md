# `kubeadm init` from a private secure registry

**Key objectives**:
A description of steps to follow in order to initialize a k8s cluster using kubeadm from a secure private registry

Jira Issues:

- [Kubeadm init with registry with authentication](https://jira.nordix.org/browse/KB-461)

## Summary

While a Kubernetes cluster uses the Secret of `kubernetes.io/dockerconfigjson` type to authenticate with a container registry to pull a private image as described in [1], `kubeadm init` cannot create secrets because the cluster services (e.g. ETCD) will not be available at the initialization time. In addition, note that `kubeadm` will trigger error if manifests folder is not empty refer to [`kubeadm init` workflow](#kubeadm-init-workflow-7). Nevertheless, `kubeadm init` can work with a secure registry (with authentication) by specifying the registry as an option `--image-repository` or in the `kubeadm` configuration file as detialed in [2] and delegate the authentication to Docker using `docker login -u <user> -p <password> <registry>` for details check [4].

## Setup private registry with authentication [4]

In order to setup a registry with authentication we must first generate ssl certificate because `Docker login` requires `https`

### Setup certificate [5]

```bash
foo@bar:~$mkdir -p docker_reg_certs
foo@bar:~$sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout docker_reg_certs/domain.key -x509 -days 365 -out docker_reg_certs/domain.crt -addext 'subjectAltName = IP:<ip_address>'
```

Install the certificates both in the server (running registry) and the client (will run kubeadm):

```bash
foo@bar:~$sudo mkdir -p /etc/docker/certs.d/<ip_address>:5000
foo@bar:~$sudo cp docker_reg_certs/domain.crt /etc/docker/certs.d/<ip_address>:5000/ca.crt
foo@bar:~$sudo cp docker_reg_certs/domain.crt /usr/local/share/ca-certificates/ca.crt
foo@bar:~$sudo update-ca-certificates
```

Create basic authentication:

```bash
foo@bar:~$mkdir auth
foo@bar:~$docker run --entrypoint htpasswd httpd:2 -Bbn testuser testpassword > auth/htpasswd
```

Run registry with certificate and authentication:

```bash
foo@bar:~$sudo docker run -d -p 5000:5000 --restart=always --name registry -v "$(pwd)"/auth:/auth -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v $PWD/docker_reg_certs:/certs -v /reg:/var/lib/registry -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key registry:2
```

### Copy an image from default registry `k8s.gcr.io` to your private one [6]

Print the images that `kubeadm` will pull to `init` the cluster:

```bash
foo@bar:~$sudo kubeadm config images list
```

Pull all images:

```bash
foo@bar:~$sudo kubeadm config images pull
```

Tag and push images to your private registry:

```bash
foo@bar:~$sudo docker image tag k8s.gcr.io/kube-apiserver:v1.21.1 <ip_address>:5000/kube-apiserver:v1.21.1
foo@bar:~$sudo docker image push <ip_address>:5000/kube-apiserver:v1.21.1
```

>**NOTE:** Repeat the tag and push steps for all the images needed by `kubeadm`

## kubeadm init from private registry

> requirements : [Install `kubeadm`](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)

Test `kubeadm init` before docker login:

```bash
foo@bar:~$sudo kubeadm init --image-repository <ip_address>:5000
```

> ![Kubeadm init before login](img/kubeadm_init_before_login.png?raw=true)

Authenticate to the registry using `docker login` [3]

```bash
foo@bar:~$sudo docker login <ip_address>:5000
```

> ![docker_login](img/docker_login.png?raw=true)

Test `kubeadm init` after docker login:

```bash
foo@bar:~$sudo kubeadm init --image-repository <ip_address>:5000
```

> ![Kubeadm init after login](img/kubeadm_init_after_login.png?raw=true)

## `kubeadm init` workflow [7]

The static manifests are located in `/etc/kubernetes` directory:

`/etc/kubernetes/manifests` as the path where kubelet should look for static Pod manifests. Names of static Pod manifests are:

- `etcd.yaml`
- `kube-apiserver.yaml`
- `kube-controller-manager.yaml`
- `kube-scheduler.yaml`

However kubeadm has the following Preflight check:

```text
[Error] if `/etc/kubernetes/manifest` folder already exists and it is not empty
```

[1]: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/

[2]: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/

[3]: https://docs.docker.com/engine/reference/commandline/login/

[4]: https://docs.docker.com/registry/deploying/

[5]: https://medium.com/@ifeanyiigili/how-to-setup-a-private-docker-registry-with-a-self-sign-certificate-43a7407a1613

[6]: https://computingforgeeks.com/manually-pull-container-images-used-by-kubernetes-kubeadm/

[7]: https://kubernetes.io/docs/reference/setup-tools/kubeadm/implementation-details/
