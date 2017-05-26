#! /bin/bash
set -e
set -o pipefail

if [ $# -ne 5 ]; then
	echo "Usage: $0 namespace-name project-name cpu-quota(in cores) memory-quota(in Gi e.g. 2Gi) gpu-quota(in numbers e.g. 1)"
	exit 1
fi

NAMESPACE=$1
PROJECT=$2
CPU=$3
MEMORY=$4
GPU=$5

kubectl --kubeconfig=../ansible/kubeconfig apply --record --filename=- <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    name: $NAMESPACE
    project: $PROJECT
  annotations:
    net.beta.kubernetes.io/network-policy: |
      {
        "ingress": {
          "isolation": "DefaultDeny"
        }
      }

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
    requests.alpha.kubernetes.io/nvidia-gpu: $GPU
    limits.cpu: "$CPU"
    limits.memory: $MEMORY
    limits.alpha.kubernetes.io/nvidia-gpu: $GPU
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
      cpu: 100m
      memory: 50Mi
    default:
      cpu: 200m
      memory: 100Mi
    maxLimitRequestRatio:
      cpu: "3"
      memory: "2"
    type: Container

EOF