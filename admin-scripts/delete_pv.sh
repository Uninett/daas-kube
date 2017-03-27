#! /bin/bash
set -e
set -o pipefail

if [ $# -ne 1 ]; then
	echo "Usage: $0 Volume-name"
	exit 1
fi

kubectl delete pv $1
