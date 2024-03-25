package main

import (
	"context"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"

	"github.com/notaryproject/notation-go/plugin/proto"
)

func runSign(ctx context.Context, input io.Reader) (*proto.GenerateSignatureResponse, error) {
	var req proto.GenerateSignatureRequest
	if err := json.NewDecoder(input).Decode(&req); err != nil {
		return nil, &proto.RequestError{
			Code: proto.ErrorCodeValidation,
			Err:  fmt.Errorf("failed to unmarshal request input: %w", err),
		}
	}

	return sign(ctx, &req)
}

func sign(ctx context.Context, req *proto.GenerateSignatureRequest) (*proto.GenerateSignatureResponse, error) {
	// validate request
	if req == nil || req.KeyID == "" || req.KeySpec == "" || req.Hash == "" {
		return nil, &proto.RequestError{
			Code: proto.ErrorCodeValidation,
			Err:  errors.New("invalid request input"),
		}
	}

	// get keySpec
	keySpec, err := proto.DecodeKeySpec(req.KeySpec)
	if err != nil {
		return nil, &proto.RequestError{
			Code: proto.ErrorCodeValidation,
			Err:  fmt.Errorf("failed to get keySpec, %v", err),
		}
	}

	external_cmd := os.Getenv("EXTERNAL_SIGNER")
	sigBytes, err := runCommand(external_cmd, string(req.Payload))
	if err != nil {
		return nil, &proto.RequestError{
			Code: proto.ErrorCodeGeneric,
			Err:  fmt.Errorf("signing with EXTERNAL_SIGNER=%q failed, %v", external_cmd, err),
		}
	}

	// read certificate chain from a file
	rawCertChain, err := getCertificateChain(ctx)
	if err != nil {
		return nil, &proto.RequestError{
			Code: proto.ErrorCodeGeneric,
			Err:  fmt.Errorf("failed to get certificate chain, %v", err),
		}
	}

	signatureAlgorithmString, err := proto.EncodeSigningAlgorithm(keySpec.SignatureAlgorithm())
	if err != nil {
		return nil, &proto.RequestError{
			Code: proto.ErrorCodeGeneric,
			Err:  fmt.Errorf("failed to encode signing algorithm, %v", err),
		}
	}

	return &proto.GenerateSignatureResponse{
		KeyID:            req.KeyID,
		Signature:        sigBytes,
		SigningAlgorithm: string(signatureAlgorithmString),
		CertificateChain: rawCertChain,
	}, nil
}

func runCommand(external_cmd string, payload string) ([]byte, error) {
	cmd := exec.Command(external_cmd)
	cmd.Stdin = strings.NewReader(payload)

	var out strings.Builder
	cmd.Stdout = &out

	err := cmd.Run()
	if err != nil {
		return nil, err
	}
	return []byte(out.String()), nil
}

func getCertificateChain(ctx context.Context) ([][]byte, error) {
	certs, err := readCertificateChain(ctx)
	if err != nil {
		return nil, err
	}
	// build raw cert chain
	rawCertChain := make([][]byte, 0, len(certs))
	for _, cert := range certs {
		rawCertChain = append(rawCertChain, cert.Raw)
	}
	fmt.Fprintf(os.Stderr, "rawchain: %s\n", rawCertChain[0])
	return rawCertChain, nil
}

func readCertificateChain(ctx context.Context) ([]*x509.Certificate, error) {
	// read a certChain from a file
	certChainFile := os.Getenv("EXTERNAL_CERT_CHAIN")
	certBytes, err := os.ReadFile(certChainFile)
	if err != nil {
		return nil, errors.New("failed to read certificate chain from EXTERNAL_CERT_CHAIN=" + certChainFile)
	}
	return parseCertificates(certBytes)
}

// parseCertificates parses certificates from either PEM or DER data
// returns an empty list if no certificates are found
func parseCertificates(data []byte) ([]*x509.Certificate, error) {
	var certs []*x509.Certificate
	block, rest := pem.Decode(data)
	if block == nil {
		// data may be in DER format
		derCerts, err := x509.ParseCertificates(data)
		if err != nil {
			return nil, err
		}
		certs = append(certs, derCerts...)
	} else {
		// data is in PEM format
		for block != nil {
			cert, err := x509.ParseCertificate(block.Bytes)
			if err != nil {
				return nil, err
			}
			certs = append(certs, cert)
			block, rest = pem.Decode(rest)
		}
	}
	return certs, nil
}
