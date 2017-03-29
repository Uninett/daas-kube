#! /bin/bash
set -e
set -o pipefail

if [ $# -ne 2 ]; then
	echo "Usage: $0 namespace application-name"
	exit 1
fi

NAMESPACE=$1
APPNAME=$2

echo "Delete Mysql Database for $NAMESPACE-$APPNAME"

POD=$(kubectl -n mysql get po -l app=$NAMESPACE-$APPNAME -o=jsonpath='{.items[*].metadata.name}')
kubectl -n mysql exec -ti $POD /usr/local/bin/delete_db.sh $APPNAME
kubectl -n mysql delete secret $NAMESPACE-$APPNAME
kubectl -n mysql delete service $NAMESPACE-$APPNAME
kubectl -n mysql delete configmap $NAMESPACE-$APPNAME
kubectl -n mysql delete deployment $NAMESPACE-$APPNAME
kubectl -n mysql delete networkpolicy $NAMESPACE-$APPNAME
