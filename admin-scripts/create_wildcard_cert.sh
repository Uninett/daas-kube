#! /bin/bash
set -e
set -o pipefail

if [ $# -ne 2 ]; then
	echo "Usage: $0 namespace-name project-name"
	exit 1
fi

NAMESPACE=$1
PROJECT=$2

kubectl --kubeconfig=../ansible/kubeconfig apply --record --filename=- <<EOF
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: wildcard-tls
  namespace: $NAMESPACE
spec:
  secretName: wildcard-tls
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-dns-prod
  commonName: '*.$PROJECT.ioudaas.no'
  dnsNames:
  - $PROJECT.ioudaas.no
  acme:
    config:
    - dns01:
        provider: aws
      domains:
      - '*.$PROJECT.ioudaas.no'
      - $PROJECT.ioudaas.no

EOF

echo "Created 'wildcard-tls' secret object for certificate in $NAMESPACE with DNS names '*.$PROJECT.ioudaas.no' and '$PROJECT.ioudaas.no'"