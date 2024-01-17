# Go.mod and go.sum

This investigatio clarifies the relation between `go.mod` and `go.sum` files and
their respective usages.

## Some basic definitions

First, let's do some research what the files are supposed to be doing.

### Go.mod

- "Each Go module is defined by a go.mod file that describes the module’s
   properties, including its dependencies on other modules and on versions of
   Go." - [go.dev](https://go.dev/doc/modules/gomod-ref),
   [go.dev](https://go.dev/ref/mod)

- "The go.mod file lists the specific versions of the dependencies that your
   project uses." -
   [FreeCodeCamp](https://www.freecodecamp.org/news/golang-environment-gopath-vs-go-mod/#:~:text=sum%20file.-,The%20go.,all%20projects%20on%20your%20system.)

- "No, go.sum is not a lock file. The go.mod files in a build provide
   enough information for 100% reproducible builds." -
   [go.dev/wiki](https://go.dev/wiki/Modules#is-gosum-a-lock-file-why-does-gosum-include-information-for-module-versions-i-am-no-longer-using)

There is basically no misconceptions about `go.mod`. It lists direct, indirect,
and replaced modules information, alongside with minimum Go version and
toolchain version used by the package. Modules mentioned in `go.mod` are enough
for 100% reproducible builds, and hence only them are needed to download and
license.

### Go.sum

- "The go.sum file may contain hashes for multiple versions of a module.
  The go command may need to load go.mod files from multiple versions of
  a dependency in order to perform minimal version selection. go.sum may
  also contain hashes for module versions that aren’t needed anymore
  (for example, after an upgrade). go mod tidy will add missing hashes
  and will remove unnecessary hashes from go.sum." -
  [go.dev](https://go.dev/ref/mod#go-sum-files)

- "go.sum is the easier one. Many users fall into the initial assumption
  that go.sum is a form of lock file, as it seems to list versions for all
  direct and indirect dependencies. And they might even use modules for
  years without realising that that's not the case.

  And the misunderstanding is reasonable, especially given that many other
  package managers also use two files: one to declare the package and list
  its dependencies, and another to lock their versions. And since go.mod
  declares the module, it's only natural to expect go.sum to be a form of
  lock file." -
  [golang.dev](https://groups.google.com/g/golang-dev/c/wkIlHZL-NNk)

- "No, go.sum is not a lock file. The go.mod files in a build provide
   enough information for 100% reproducible builds.",
   "For validation purposes, go.sum contains the expected cryptographic
   checksums of the content of specific module versions. See the FAQ
   below for more details on go.sum (including why you typically should
   check in go.sum) as well as the “Module downloading and verification”
   section in the tip documentation.",
  [go.dev/wiki](https://go.dev/wiki/Modules#is-gosum-a-lock-file-why-does-gosum-include-information-for-module-versions-i-am-no-longer-using)

`go.sum` information is still more misleading, and even the latest Go 1.21
has changed its implementation what to record in `go.sum`. Most sources
are solid that the `go.sum` is used for checksum verification to prevent
tampering. Some sources call it "transparency log".

This tampering protection means that once you've downloaded a module and
added it to your `go.mod`, if someone moves a Git tag (Git tags define
Go module versions), `go.sum` checksum would no longer match and you'd be
alerted of the package alteration.

## Let's test this in action

Since the above is not 100% cohesive (especially the last quote from
Go Wiki, and even that can be interpreted many ways), let's put it into
a test to see what we actually need.

### Go mod vendor

`go mod vendor` downloads all dependencies required to build the package
into `vendor/` directory. If we do that for example for `baremetal-operator`
repository and try check that directory for a module that is found in
`go.sum` but not in `go.mod`, we don't find it in `vendor` either.

```console
# no tools required directly or indirectly in go.mod
user@host:~/git/baremetal-operator$ ag tools go.mod
# find any tools in vendor directory
user@host:~/git/baremetal-operator$ find vendor -name "*tools*"
vendor/k8s.io/client-go/tools
# find any tools in go.sum
user@host:~/git/baremetal-operator$ ag tools go.sum
174:golang.org/x/tools v0.0.0-20180917221912-90fa682c2a6e/go.mod h1:n7NCudcB/nEzxVGmLbDWY5pfWTLqBcC2KZ6jyYvM4mQ=
175:golang.org/x/tools v0.0.0-20190311212946-11955173bddd/go.mod h1:LCzVGOaR6xXOjkQ3onu1FJEFr0SW1gC7cKk1uF8kGRs=
176:golang.org/x/tools v0.0.0-20191119224855-298f0cb1881e/go.mod h1:b+2E5dAYhXwXZwtnZ6UAqBI28+e2cm9otk0dWdXHAEo=
177:golang.org/x/tools v0.0.0-20200619180055-7c47624df98f/go.mod h1:EkVYQZoAsY45+roYkvgYkIh4xh/qjgUK9TdY2XT94GE=
178:golang.org/x/tools v0.0.0-20210106214847-113979e3529a/go.mod h1:emZCQorbCU4vsT4fOWvOPXz4eW1wZW4PmDk9uLelYpA=
179:golang.org/x/tools v0.1.5/go.mod h1:o0xws9oXOQQZyjljx8fwUC0k7L1pTE6eaCbjGeHmOkk=
180:golang.org/x/tools v0.12.0 h1:YW6HUoUmYBpwSgyaGaZq1fHjrBjX1rlpZ54T6mu2kss=
```

There is plenty of `golang.org/x/tools` packages in `go.sum` but they're not
actually needed for building. If we do analysis on the `vendor` contents, we find
it is nearly 100% identical with the `go.mod` list. There are few lines of
difference, but those seem to be result of URL redirections.

### $GOPATH/pkg

Similar conclusion can be drawn by actually building the package. By emptying
systems's `$GOPATH/pkg` and doing a `go build ...` for a package, you can see
that the packages downloaded in the `$GOPATH/pkg` are exactly the same as in
`vendor` directory. In fact, if you have `vendor` directory, Go doesn't download
anything, but uses the vendored packages!

```console
user@host:~/git/baremetal-operator$ go build -o bin/test main.go
go: downloading github.com/pkg/errors v0.9.1
go: downloading k8s.io/apimachinery v0.28.5
go: downloading go.uber.org/zap v1.26.0
...
go: downloading github.com/josharian/intern v1.0.0
```

The list of downloaded packages also match exactly what the `go.mod` lists.

## Conclusion

`go.mod` is the source of truth when it comes to what software is actually
needed to build a package. `go.sum` includes additional entries, mostly used
for Minimum Version Selection algorithm and as transparency log for tamper
protection.

Packages listed in `go.sum` thus are not used for vulnerability scanning,
or need to be licensed. Only packages in `go.mod` (and in practise, those
you would download via `go mod vendor`) need to be licensed.
