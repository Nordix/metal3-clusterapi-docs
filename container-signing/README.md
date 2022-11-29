# Sign container image using Cosign and OpenSSL

For testing this workflow use any **Docker Hub** pulled image from your personal docker account.

## Generate the signature payload (to sign with OpenSSL)

The `cosign generate` command prints payload in json format to stdout. Write that output to a file.

```bash
cosign generate <image-name> > <payload-file>
```

## Generate signature with openssl

**Note**: Make sure you have OpenSSL public and private keys generated.

You can use the following commands to generate the signature of a file and convert it to Base64 format:

```bash
openssl dgst -sha256 -sign <private-key> -out /tmp/sign.sha256 <payload-file>
openssl base64 -in /tmp/sign.sha256 -out <signature>
```

Where `private-key` is the file containing the private key, `payload-file` is the file to sign and `signature` is the file name for the digital signature in Base64 format. Use the temporary folder (`/tmp`) to store the binary format of the digital signature. Remember, when you sign a file using the private key, OpenSSL will ask for the passphrase.

The `signature` file can now be shared over internet without encoding issue.

## Upload OpenSSL generated signature to image registry with cosign

Cosign will default to storing signatures in the same repo with the image. The signature is passed via the `-signature` flag. Use OpenSSL generated `signature` file:

```bash
cosign attach signature -signature <signature> <image-name>
```

To specify a different repo for signatures [see these instructions](https://github.com/sigstore/cosign#registry-details).

## Download the signature from registry with cosign

Signature is printed to stdout in a json format. Save `Base64Signature` part from json output to a file.

```bash
cosign download signature <image-name> | jq -r '.Base64Signature' > <downloaded-signature>
```

## Verify payload with OpenSSL

To verify the signature, you need to convert the signature to binary and after apply the verification process of OpenSSL. You can achieve this using the following commands:

```bash
openssl base64 -d -in <downloaded-signature> -out /tmp/sign.sha256
openssl dgst -sha256 -verify <pub-key> -signature /tmp/sign.sha256 <payload-file>
```

## More reading

[Cosign GitHub](https://github.com/sigstore/cosign)

[Cosign Usage](https://github.com/sigstore/cosign/blob/main/USAGE.md)
