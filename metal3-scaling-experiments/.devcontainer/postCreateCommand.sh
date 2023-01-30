#!/bin/bash

cat <<-EOF >> ~/.bashrc
source /usr/share/bash-completion/completions/git
alias k=kubectl
complete -F __start_kubectl k
EOF
