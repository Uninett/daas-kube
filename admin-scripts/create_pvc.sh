#! /bin/bash
set -e
set -o pipefail

if [ $# -ne 4 ]; then
	echo "Usage: $0 Volume-name Volume-Path namespace rwmode"
	echo "Example: $0 test /data/test test ReadWriteOnce"
	echo "Possible values for rwmode: ReadOnlyMany,ReadWriteOnce.ReadWriteMany"
	exit 1
fi

VOLUMENAME=$1
VOLUMEPATH=$2
NAMEPSACE=$3
RWMODE=$4

if [ ! -f  "/proc/sys/kernel/random/uuid" ]; then
	PVCNAME=$(uuidgen | tr A-Z a-z )
else
	PVCNAME=$(cat /proc/sys/kernel/random/uuid | tr A-Z a-z )
fi

echo "Making sure container can access the volume with SELinux enabled by running this command on storage server"
echo "chcon -Rt svirt_sandbox_file_t $VOLUMEPATH"

echo "Creating Volume: $VOLUMENAME with Path: $VOLUMEPATH to be accessible in Namespace: $NAMEPSACE using Volume Claim: $PVCNAME"
kubectl --kubeconfig=../ansible/kubeconfig apply --record --filename=- <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $VOLUMENAME
spec:
  capacity:
    storage: 42Gi
  accessModes:
    - $RWMODE
  hostPath:
    path: $VOLUMEPATH
  claimRef:
    namespace: $NAMEPSACE
    name: $PVCNAME

---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: $PVCNAME
  namespace: $NAMEPSACE
spec:
  accessModes:
    - $RWMODE
  volumeName: $VOLUMENAME
  resources:
    requests:
      storage: 42Gi
EOF