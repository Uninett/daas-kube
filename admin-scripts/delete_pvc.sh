#! /bin/bash
set -e
set -o pipefail

if [ $# -ne 2 ]; then
	echo "Usage: $0 namespace claim-name"
	exit 1
fi

kubectl delete pvc $2 -n $1
