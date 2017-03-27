#! /bin/bash
# set -e
# set -o pipefail

if [ $# -ne 1 ]; then
	echo "Usage: $0 application-name"
	exit 1
fi

APPNAME=$1

echo "Delete Mysql Database for $APPNAME"

POD=$(kubectl -n mysql get po -l app=$APPNAME -o=jsonpath='{.items[*].metadata.name}')
#kubectl -n mysql exec -ti $POD /usr/local/bin/delete_db.sh $APPNAME
kubectl -n mysql delete secret $APPNAME
kubectl -n mysql delete service $APPNAME
kubectl -n mysql delete configmap $APPNAME
kubectl -n mysql delete deployment $APPNAME
kubectl -n mysql delete networkpolicy $APPNAME

