# kuberos/kubelogin poc

<!-- markdownlint-disable MD013 -->

## Kubelogin, or kubectl-oidc_login

Docs:

- <https://github.com/int128/kubelogin>
- <https://github.com/int128/kubelogin/blob/master/docs/usage.md>

### Kubelogin installation

Get the binary from
[releases](https://github.com/int128/kubelogin/releases/tag/v1.28.0), and
install as `kubectl-oidc_login` in `/usr/local/bin` or elsewhere in `$PATH`.

## Grant types

Kubelogin and Dex support following grant types:

- auto (automatic selection)
- authcode (token passthru via web browser callback)
- authcode-keyboard (generates code you need to paste yourself)
- device-code (like authcode, but for a device of certain code)
- password (supply username and password on the command line, not enabled by default)

Grant type is specified with `--grant-type=<type>` on command line during setup.

### Authcode

Authcode is the default mode, where it brings up the browser and then after
successful login it calls the callback to pass the token to kubelogin.

Triggering it on a headless machine is problematic. You can workaround it by
creating SSH forwarding from your desktop machine and that way circumvent the
headless limitation.

```console
$ ssh -L 8000:127.0.0.1:8000 <host>
...
$ kubectl oidc-login setup \
    --oidc-issuer-url=http://127.0.0.1:5556/dex \
    --oidc-client-id=kubelogin-test \
    --oidc-client-secret=kubelogin-test-secret

authentication in progress...
error: could not open the browser: exec: "xdg-open,x-www-browser,www-browser": executable file not found in $PATH

Please visit the following URL in your browser manually: http://localhost:8000
```

### Authocde-Keyboard

```console
$ kubectl oidc-login setup --oidc-issuer-url=http://127.0.0.1:5556/dex \
    --oidc-client-id=kubelogin-test --oidc-client-secret=kubelogin-test-secret \
    --grant-type=authcode-keyboard
authentication in progress...
Please visit the following URL in your browser: http://127.0.0.1:5556/dex/auth?access_type=offline&client_id=kubelogin-test&code_challenge=86dPTBNva5aIaXvewKOSyw7P-URcw3Ap8SHtTnhBviA&code_challenge_method=S256&nonce=-Fep0vXzWv48P_u6Jk6BsuQhguRNMzCGByQnCpZ6JnQ&redirect_uri=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob&response_type=code&scope=openid&state=IRBxjcXHgcTz-IA8ws_045ktOSozc4s1ixj-ykNWyJ0
Enter code:
```

Then you access that URL, and you get code like `b2ifzli5rdb3lsahxaqxxtklr`,
which you can enter into the prompt. Requires browser.

### Device-code

Device code seems to be the same as AuthCode, except you need to enter the
device-code for the device you're identifying for. Requires browser.

### Password

Password flow is enabled only, if Dex config is set to allow it by setting one
of the connectors as `passwordConnector`:

```yaml
oauth2:
  passwordConnector: ldap
```

If this config is not present, password grant type is rejected as
`not supported`. Most of the connectors do not support username/password.
`local` and `ldap` do.

## Putting it all together

Now that we know we can do `kubelogin` -> `Dex` -> `openLDAP`, we need to
setup the final chain, where Dex is integrated with k8s apiserver, and it
actually authenticates `kubectl` commands via Dex.

### Kind setup

Setup Kind cluster with additional config in [kind.conf](k8s/kind.conf).

Run: `kind create cluster --config=kind.conf`

Make note of the `extraArgs` as they define fields how users and groups are
identified and they need to match ClusterRoles created, otherwise the logged in
users won't have any rights.

For Kind setup, we also need to mount a directory holding a Dex generated CA
cert, so apiserver will trust the Dex when connecting. Using [Dex's certificate
generation script](https://github.com/dexidp/dex/blob/master/examples/k8s/gencert.sh),
you get a CA cert, which should be mounted via directory
`/etc/ssl/certs/dex-test` in the apiserver.

### Dex setup

We setup Dex to run in nodeport `32000` so it is reachable by the apiserver and
the user's kubectl client. Alternatively, Dex could be configued with service
andpoint, and apiserver could be configured to connect to `dex.dex` for example.
OIDC provider is often external to the cluster, and hence the nodeport simulates
reality better than in-cluster service.

For Dex, we also add LDAP connector configuration and set `passwordConnector` to
`ldap`.

You also need to input key and certificate from `gencert.sh` into
`dex.example.com.tls` Secret for this test setup. These certs must be same as
the generated CA certificate in previous step. Using expired or non-trusted
certificates causes apiserver not trust Dex, and login attempts will fail even
if the Dex token kubectl gained is valid.

See [dex.yaml](k8s/dex.yaml).

We also need to add a line to `/etc/hosts` to create fake Dex domain:
`127.0.0.1       dex.example.com` or simply change all occurences of
`dex.example.com` with `127.0.0.1`. Here we use the `dex.example.com` in order
to make a difference between Dex host and other services.

### OpenLDAP k8s setup

We need to set up OpenLDAP so it is reachable by Dex. In this setup, we run it
via service `openldap.openldap`, but also expose it via nodeport `31389` for
debugging purposes.

See [openldap.yaml](k8s/openldap.yaml).

For reference, see [contents](k8s/openldap.txt) of openLDAP test database.

### Setup kubectl

Now we have technically everything in place, so let's advise kubectl
to log us in.

We then set login credentials for user alias `oidc`. Here we have
`--insecure-skip-tls-verify` since it is a test setup and no proper TLS certs
are configured on the test host.

```console
    kubectl config set-credentials oidc \
      --exec-api-version=client.authentication.k8s.io/v1beta1 \
      --exec-command=kubectl \
      --exec-arg=oidc-login \
      --exec-arg=get-token \
      --exec-arg=--oidc-issuer-url=https://dex.example.com:32000 \
      --exec-arg=--oidc-client-id=kubelogin-test \
      --exec-arg=--oidc-client-secret=kubelogin-test-secret \
      --exec-arg=--oidc-extra-scope=email \
      --exec-arg=--oidc-extra-scope=profile \
      --exec-arg=--oidc-extra-scope=groups \
      --exec-arg=--grant-type=password \
      --exec-arg=--insecure-skip-tls-verify
```

and kubeconfig ends up looking like [this](k8s/kubeconfig).

#### Cluster roles

Cluster role needs to be assigned based on the username or the groups passed via
the `groups` scope. These roles need to be configured by the pre-existing
cluster admin, otherwise users logging in via Dex won't have any permissions.

```yaml
kubectl create clusterrolebinding oidc-cluster-admin \
  --clusterrole=cluster-admin \  # whatever the role should be
  --user='Bar1'  # whatever the username-claim=email field defines username field is
```

or better, you should configure group claim so each individual user does not
need separate role configured:

```yaml
kubectl create clusterrolebinding oidc-cluster-admin-group \
  --clusterrole=cluster-admin \  # whatever the role should be
  --group='readers'  # whatever the group-claim=groups field defines groups field is
```

LDAP configuration would be different per organization regardless.

Some references:

- <https://dexidp.io/docs/connectors/oidc/>
- <https://openid.net/specs/openid-connect-core-1_0.html#Claims>
- <https://dexidp.io/docs/custom-scopes-claims-clients/>
