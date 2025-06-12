NUM_BMH ?= 3

.PHONY: cluster
cluster: bmhs
	kubectl apply -k ClusterResourceSets
	kubectl apply -k setup-scripts
	kubectl apply -k Metal3/cluster

.PHONY: pivot
pivot: cluster
	./Metal3/pivot.sh

.PHONY: kamaji
kamaji:
	KUBECONFIG=kubeconfig.yaml ./kamaji.sh

.PHONY: bmhs
bmhs:
	NUM_BMH=$(NUM_BMH) ./Metal3/create-bmhs.sh

.PHONY: setup
setup: prereq
	./Metal3/setup.sh

.PHONY: prereq
prereq: images credentials ClusterResourceSets

.PHONY: ClusterResourceSets
ClusterResourceSets: ClusterResourceSets/calico.yaml

.PHONY: credentials
credentials:
	./Metal3/generate-credentials.sh

.PHONY: images
images: Metal3/images/ubuntu-2404.raw

Metal3/images/ubuntu-2404.img:
	mkdir -p Metal3/images
	wget -O Metal3/images/ubuntu-2404.img https://cloud-images.ubuntu.com/releases/noble/release-20250610/ubuntu-24.04-server-cloudimg-amd64.img

Metal3/images/ubuntu-2404.raw: Metal3/images/ubuntu-2404.img
	qemu-img convert -f qcow2 -O raw Metal3/images/ubuntu-2404.img Metal3/images/ubuntu-2404.raw

ClusterResourceSets/calico.yaml:
	kustomize build ClusterResourceSets/calico > ClusterResourceSets/calico.yaml

.PHONY: teardown
teardown:
	./Metal3/clean.sh

.PHONY: clean
clean: teardown
	rm -rf Metal3/images
	rm -rf Metal3/tmp
