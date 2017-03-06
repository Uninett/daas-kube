#!/bin/bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -f terraform/local.tfvars ]; then
    echo "You must create terraform/local.tfvars" >&2
    exit 1
fi

if [ ! -f ansible/roles/gpfs/files/Spectrum_Scale_Advanced-4.2.2.1-x86_64-Linux-install ]; then
    echo "You must add Spectrum_Scale_Advanced-4.2.2.1-x86_64-Linux-install to ansible/roles/gpfs/files/" >&2
    exit 1
fi

pushd terraform
terraform apply -var-file ipnett.tfvars -var-file local.tfvars
terraform output inventory >../ansible/inventory
popd

./ansible/apply.sh
