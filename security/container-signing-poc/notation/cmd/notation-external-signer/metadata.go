package main

import (
	"github.com/notaryproject/notation-go/plugin/proto"
)

var (
	Version       = "v0.1.0"
	BuildMetadata = "unreleased"
)

func getVersion() string {
	if BuildMetadata == "" {
		return Version
	}
	return Version + "+" + BuildMetadata
}

func runGetMetadata() *proto.GetMetadataResponse {
	return &proto.GetMetadataResponse{
		Name:                      "external-signer",
		Description:               "Sign artifacts with any external signer",
		Version:                   getVersion(),
		URL:                       "https://github.com/Nordix/notation-external-signer",
		SupportedContractVersions: []string{proto.ContractVersion},
		Capabilities:              []proto.Capability{proto.CapabilitySignatureGenerator},
	}
}
