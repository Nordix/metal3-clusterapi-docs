# Introduction
The purpose of this document is to document instructions for running capi-dev environment more specifically testing v1alpha2 with Cluster API (CAPI),Cluster API Bootstrap Provider Kubeadm (CABPK) and Cluster API Provider Docker (CAPD)/ Cluster API Provider AWS (CAPA). This environment supports two infrastructure providers: CAPD and CAPA. For the reminder of this document, we assume CAPD as the infrastructure environment. For CAPA related tweaks, you have to go through the readme of the capi-dev itself. 
**Note:** The tiltfile editing steps discussed below are valid for both CAPD and CAPA

## Cloning Git Repo
```
git clone git@github.com:chuckha/capi-dev.git
```
## Initialize Dev Environment
The ```init.sh ``` clones the related git repositories namely:CAPI, CABPK, CAPD and CAPA inside the capi-dev repository. You can comment out CAPA for example if you don't want to use it. Then run the following command:

```
./init.sh
```
## Install tilt
Tilt is a handy tool for local kubernetes development. The good thing about tilt is that it watches files for edits and  automatically builds the container images, and applies any changes to bring the environment up-to-date in real-time. [Tilt](https://docs.tilt.dev/install.html) can be installed using the following command: 

```
curl -fsSL https://raw.githubusercontent.com/windmilleng/tilt/master/scripts/install.sh | bash 
```
You should verify if the installation is correct:
```
tilt version
```
**Note:** 
1. Tilt requires **Docker** to be installed as a non-root user and **kubectl** binary. It is assumed that this is already taken care of in your local environment. 
2. Tilt also requires a working kubernetes cluster to work on. For this, tilt page recommends installing ``` microk8s```. While ``` microk8s``` kubernetes has its own advantages, this particular dev-env has some requirements like spawning privileged containers, which can be tricky to deal with in ``` microk8s```. As such, we should skip installing ``` microk8s``` and we should use ``` kind``` based cluster for which the instructions are given below.

## Tiltfile
The capi-dev repository has a ```Tiltfile``` in the root directory. This ```Tiltfile``` contains all the instructions for running the dev environment. 

1. To start with, do the following changes so that we use CAPD as the infrastructure provider: 

```
infrastructure_provider = DOCKER_PROVIDER
#infrastructure_provider = AWS_PROVIDER
```
2. Next change the following line. Specifically you have to remove the space after **-i** flag:

**Incorrect version**
```
	command = '''sed -i '' -e 's@image: .*@image: '"{}"'@' ./{}/config/default/manager_image_patch.yaml'''.format(provider['image'], provider['name'])
```
**Correct version**
```
	command = '''sed -i'' -e 's@image: .*@image: '"{}"'@' ./{}/config/default/manager_image_patch.yaml'''.format(provider['image'], provider['name'])
```
**Note:** I am not an expert in ```sed``` command. This simple tweak is needed to get the tilt environment working in ubuntu.  

## Kind cluster
There is a config file for kind cluster in devenv directory. Here is the full path:

``` 
devenv/kind/config.yaml 
``` 

Create a kind cluster using the config file. The command is as follows: 
```
kind create cluster --config=devenv/kind/config.yaml
```
## Running the dev-env
Run the dev environment using the following command:

``` 
tilt up 
``` 

This command should build all three containers namely CAPI, CABPK and CAPD. You can explore the logs for each of these repositories or rather docker containers separately in tilt gui which runs as soon as you run the ```tilt up``` command. That's it. Your dev-env should be up and running. As mentioned earlier, tilt watches for any changes in the code on those three repositories and it starts building the containers all over again as soon as you save your changes. 

## Note
In case CAPD fails to provision a machine and you do not see any control-plane container created for the target cluster, possibly it is related to docker version. For now, the test environment is not working with docker version **19.03.0**. Roll back the docker to a previous version to see if the problem persists. An example working docker version is **18.09.8**. In any case, checking CAPD logs and kubelet logs inside the kind cluster will be helpful. 