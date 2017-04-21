#! /bin/bash
set -e
set -o pipefail

if [ $# -ne 3 ]; then
	echo "Usage: $0 namespace-name role-name subject-name"
	echo "For info about RBAC, visit: https://kubernetes.io/docs/admin/authorization/rbac/"
	exit 1
fi

NAMESPACE=$1
ROLENAME=$2
SUBJECTNAME=$3

echo "\"$ROLENAME\" is of which role type:"
echo "1. ClusterRole (these roles are available **cluster wide across namespaces**)"
echo "2. Role (these roles are available on in the **given namespace**)"
echo -n "Specify Role type (1 or 2): "
read ROLETYPE

if [ $ROLETYPE -eq 1 ]; then
	ROLETYPE="ClusterRole"
elif [ $ROLETYPE -eq 2 ]; then
	ROLETYPE="Role"
else
	echo "Unknown Role type"
	exit 1
fi

echo "\"$SUBJECTNAME\" is of which subject type:"
echo "1. User (A user name)"
echo "2. Group (A group name)"
echo "3. ServiceAccount (A service account name)"
echo -n "Specify Subject type (1,2 or 3): "
read SUBJECTTYPE

if [ $SUBJECTTYPE -eq 1 ]; then
	SUBJECTTYPE="User"
elif [ $SUBJECTTYPE -eq 2 ]; then
	SUBJECTTYPE="Group"
elif [ $SUBJECTTYPE -eq 3 ]; then
	SUBJECTTYPE="ServiceAccount"
else
	echo "Unknown Subject type"
	exit 1
fi

BINDNAME="$NAMESPACE-$ROLENAME-"$(echo -n $ROLETYPE | tr A-Z a-z)

echo "\"$BINDNAME\" is of which binding type:"
echo "1. ClusterRoleBinding (it binds the given subject to given role in **whole cluster across namespaces**)"
echo "2. RoleBinding (it binds the given subject to given role in **given namespaces only**)"
echo -n "Specify Binding type (1 or 2): "
read BINDTYPE

if [ $BINDTYPE -eq 1 ]; then
	BINDTYPE="ClusterRoleBinding"
elif [ $BINDTYPE -eq 2 ]; then
	BINDTYPE="RoleBinding"
else
	echo "Unknown Binding type"
	exit 1
fi

if [[ ("$SUBJECTTYPE" == "User" || "$SUBJECTTYPE" == "Group") && "$BINDTYPE" == "ClusterRoleBinding" ]]; then
	cat > binding.yaml <<EOF
kind: $BINDTYPE
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $BINDNAME
subjects:
- kind: $SUBJECTTYPE
  name: $SUBJECTNAME
roleRef:
  kind: $ROLETYPE
  name: $ROLENAME
  apiGroup: rbac.authorization.k8s.io
EOF

elif [[ ("$SUBJECTTYPE" == "User" || "$SUBJECTTYPE" == "Group") && "$BINDTYPE" == "RoleBinding" ]]; then
	cat > binding.yaml <<EOF
kind: $BINDTYPE
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $BINDNAME
  namespace: $NAMESPACE
subjects:
- kind: $SUBJECTTYPE
  name: $SUBJECTNAME
roleRef:
  kind: $ROLETYPE
  name: $ROLENAME
  apiGroup: rbac.authorization.k8s.io
EOF
elif [[ "$SUBJECTTYPE" == "ServiceAccount" && "$BINDTYPE" == "ClusterRoleBinding" ]]; then
	cat > binding.yaml <<EOF
kind: $BINDTYPE
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $BINDNAME
subjects:
- kind: $SUBJECTTYPE
  name: $SUBJECTNAME
  namespace: $NAMESPACE
roleRef:
  kind: $ROLETYPE
  name: $ROLENAME
  apiGroup: rbac.authorization.k8s.io
EOF
elif [[ "$SUBJECTTYPE" == "ServiceAccount" && "$BINDTYPE" == "RoleBinding" ]]; then
	cat > binding.yaml <<EOF
kind: $BINDTYPE
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $BINDNAME
  namespace: $NAMESPACE
subjects:
- kind: $SUBJECTTYPE
  name: $SUBJECTNAME
  namespace: $NAMESPACE
roleRef:
  kind: $ROLETYPE
  name: $ROLENAME
  apiGroup: rbac.authorization.k8s.io
EOF
fi

echo "This binding will be applied, please review:"
echo "==========================================="
cat binding.yaml
echo "==========================================="
echo -n "Do you accept (yes or no): "
read input

if [[ "$input" == "yes" ]]; then
	kubectl --kubeconfig=../ansible/kubeconfig apply -f binding.yaml
	rm -f binding.yaml
else
	echo "Binding has not be created, canceled by user"
fi
