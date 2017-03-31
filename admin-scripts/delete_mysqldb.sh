#! /bin/bash
set -e
set -o pipefail

if [ $# -ne 2 ]; then
	echo "Usage: $0 namespace application-name"
	exit 1
fi

NAMESPACE=$1
APPNAME=$2

echo "Delete MySQL Database for $NAMESPACE-$APPNAME"

POD=$(kubectl --kubeconfig=../ansible/kubeconfig -n mysql get po -l app=$NAMESPACE-$APPNAME -o=jsonpath='{.items[*].metadata.name}')
kubectl --kubeconfig=../ansible/kubeconfig -n mysql exec -ti $POD /usr/local/bin/delete_db.sh $APPNAME
kubectl --kubeconfig=../ansible/kubeconfig -n mysql delete secret $NAMESPACE-$APPNAME
kubectl --kubeconfig=../ansible/kubeconfig -n mysql delete service $NAMESPACE-$APPNAME
kubectl --kubeconfig=../ansible/kubeconfig -n mysql delete configmap $NAMESPACE-$APPNAME
kubectl --kubeconfig=../ansible/kubeconfig -n mysql delete deployment $NAMESPACE-$APPNAME
kubectl --kubeconfig=../ansible/kubeconfig -n mysql delete networkpolicy $NAMESPACE-$APPNAME

echo "MySQL Database has been deleted, remember to delete underlying storage folder, PV and PV Claim"
