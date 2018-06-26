#! /bin/bash
set -e
set -o pipefail

if [ $# -ne 4 ]; then
	echo "Usage: $0 namespace-name project-name cpu-quota(in cores) memory-quota(in Gi e.g. 2Gi)"
	exit 1
fi

NAMESPACE=$1
PROJECT=$2
CPU=$3
MEMORY=$4
LIMIT_CPU="$((2 * $CPU))"

kubectl --kubeconfig=../ansible/kubeconfig apply --record --filename=- <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  annotations:
    appstore.uninett.no/domains: $PROJECT.ioudaas.no
  labels:
    name: $NAMESPACE
    project: $PROJECT

---
apiVersion: extensions/v1beta1
kind: NetworkPolicy
metadata:
    name: default-deny
    namespace: $NAMESPACE
spec:
    podSelector:
      matchLabels: {}
    egress:
    - to:
      - ipBlock:
          cidr: "0.0.0.0/0"
          except:
          - "158.38.100.0/24"
    - to:
      - ipBlock:
          cidr: "158.38.100.0/24"
      ports:
      - port: 53
        protocol: TCP
      - port: 53
        protocol: UDP
      - port: 8443
        protocol: TCP
    policyTypes:
    - Ingress
    - Egress


---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cert-manager-solver
  namespace: $NAMESPACE
spec:
  podSelector:
    matchExpressions:
    - key: certmanager.k8s.io/acme-http-domain
      operator: Exists
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: kube-ingress
      ports:
        - protocol: TCP
          port: 8089


---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: quota
  namespace: $NAMESPACE
spec:
  hard:
    requests.cpu: "$CPU"
    requests.memory: $MEMORY
    limits.cpu: "$LIMIT_CPU"
    limits.memory: $MEMORY
    configmaps: "100"
    services: "100"
    secrets: "100"


---
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: $NAMESPACE
spec:
  limits:
  - defaultRequest:
      cpu: 50m
      memory: 50Mi
    default:
      cpu: 150m
      memory: 100Mi
    maxLimitRequestRatio:
      cpu: "3"
      memory: "2"
    type: Container

EOF

echo "Please create a CNAME record in your cluster DNS zone as: _acme-challenge.$PROJECT.ioudaas.no CNAME $PROJECT.ioudaas.no.acme-dns.uninett.no."
echo "This will be used to create the wildcard certificate using Lets encrypt DNS01 Challenge"

