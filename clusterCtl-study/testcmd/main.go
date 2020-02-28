package main

import (
	"fmt"
	"os"

	"sigs.k8s.io/cluster-api/cmd/clusterctl/client"
)

func main() {
	setup()
}

//func localRepositoryFactory(configClient config.Client) func(providerConfig config.Provider) (repository.Client, error) {
//	return func(providerConfig config.Provider) (repository.Client, error) {
//		return repository.New(providerConfig, configClient.Variables())
//	}
//}
func setup() {
	fmt.Println("Starting Setup")
	//configClient, _ := config.New(os.Args[1])
	//repoFactory := localRepositoryFactory(configClient)
	//opt := client.InjectRepositoryFactory(repoFactory)
	//opt1 := client.InjectConfig(configClient)
	c, err := client.New(os.Args[1])

	if err != nil {
		fmt.Println("Error occured %v", err)
	}
	var bt []string
	var it []string
	options := client.InitOptions{
		Kubeconfig:              os.Args[2],             //"/home/kashif/.kube/config",
		CoreProvider:            os.Args[3],             //"cluster-api:v0.3.0",
		BootstrapProviders:      append(bt, os.Args[4]), // "kubeadm:v0.3.0"),
		ControlPlaneProviders:   append(bt, os.Args[5]), //"kubeadm:v0.3.0"),
		InfrastructureProviders: append(it, os.Args[6]), //"baremetal:v0.3.0"),
		TargetNamespace:         os.Args[7],
		WatchingNamespace:       os.Args[8],
		LogUsageInstructions:    true,
	}

	if _, err := c.Init(options); err != nil {
		fmt.Println("Error occured %v", err)

	}
	fmt.Println("Successs")
}
