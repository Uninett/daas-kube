#! /bin/bash
set -e
set -o pipefail

if [ $# -ne 2 ]; then
	echo "Usage: $0 namespace nvidia_version"
	echo "Example: $0 test 375.66"
	exit 1
fi

NAMESPACE=$1
NVIDIA_VERSION=$2

echo "Creating GPU Volume, PVC and PodPreset for namespace: $NAMESPACE"
kubectl --kubeconfig=../ansible/kubeconfig apply --record --filename=- <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $NAMESPACE-nvidia-driver-$NVIDIA_VERSION
spec:
  capacity:
    storage: 42Gi
  accessModes:
    - ReadOnlyMany
  hostPath:
    path: /usr/local/lib/nvidia/volumes/nvidia_driver/$NVIDIA_VERSION
  claimRef:
    namespace: $NAMESPACE
    name: nvidia-driver-$NVIDIA_VERSION

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $NAMESPACE-libcuda-so-$NVIDIA_VERSION
spec:
  capacity:
    storage: 42Gi
  accessModes:
    - ReadOnlyMany
  hostPath:
    path: /usr/lib/x86_64-linux-gnu/libcuda.so.$NVIDIA_VERSION
  claimRef:
    namespace: $NAMESPACE
    name: libcuda-so-$NVIDIA_VERSION


---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nvidia-driver-$NVIDIA_VERSION
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadOnlyMany
  volumeName: $NAMESPACE-nvidia-driver-$NVIDIA_VERSION
  resources:
    requests:
      storage: 42Gi

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: libcuda-so-$NVIDIA_VERSION
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadOnlyMany
  volumeName: $NAMESPACE-libcuda-so-$NVIDIA_VERSION
  resources:
    requests:
      storage: 42Gi

---
kind: PodPreset
apiVersion: settings.k8s.io/v1alpha1
metadata:
  name: nvidia-gpu-driver
  namespace: $NAMESPACE
spec:
  selector:
    matchLabels:
      driver: nvidia-gpu
  volumeMounts:
  - name: nvidia-driver
    mountPath: /usr/local/nvidia
    readOnly: true
  - name: libcuda-so
    mountPath: /usr/lib/x86_64-linux-gnu/libcuda.so
    readOnly: true
  volumes:
  - name: nvidia-driver
    persistentVolumeClaim:
      claimName: nvidia-driver-$NVIDIA_VERSION
  - name: libcuda-so
    persistentVolumeClaim:
      claimName: libcuda-so-$NVIDIA_VERSION
EOF

echo "Successfully created PV, PVC and PodPreset for namespace: $NAMESPACE"