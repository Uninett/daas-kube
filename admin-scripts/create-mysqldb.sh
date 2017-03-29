#! /bin/bash
set -e
set -o pipefail

if [ $# -ne 3 ]; then
	echo "Usage: $0 application-namespace application-name persistent-volume-claim-name"
	exit 1
fi

if [ -z "$CPU" ]; then
	CPU="256m"
fi

if [ -z "$MEMORY" ]; then
	MEMORY="512Mi"
fi

if [ -z "$IMAGE" ]; then
	IMAGE="gurvin/mysql:5.7.16"
fi

if [ -z "$MYSQL_UID" ]; then
	MYSQL_UID="999"
fi

if [ -z "$MYSQL_GID" ]; then
	MYSQL_GID="999"
fi

NAMESPACE=$1
APPNAME=$2
PVCNAME=$3

if [ ! -f  "/proc/sys/kernel/random/uuid" ]; then
  SECRET=$(uuidgen | tr -d '\n' | base64)
else
  SECRET=$(cat /proc/sys/kernel/random/uuid | base64)
fi

kubectl apply --record --filename=- <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $NAMESPACE-$APPNAME
  namespace: mysql
type: Opaque
data:
  MYSQL_ROOT_PASSWORD: $SECRET

---

apiVersion: v1
kind: Service
metadata:
  name: $NAMESPACE-$APPNAME
  namespace: mysql
  labels:
    app: $NAMESPACE-$APPNAME
spec:
  ports:
  - port: 3306
    name: mysql
  selector:
    app: $NAMESPACE-$APPNAME

---

apiVersion: v1
kind: ConfigMap
metadata:
  name: $NAMESPACE-$APPNAME
  namespace: mysql
data:
  mysql.cnf:  |-
    [isamchk]
    key_buffer_size = 16M
    [mysqld]
    expire_logs_days = 10
    tmpdir = /tmp
    skip-name-resolve
    innodb_buffer_pool_size = 1073741824
    innodb_log_file_size = 128M
    innodb_fast_shutdown = 0
    expire_logs_days = 10
    key_buffer_size = 16M
    log-error = /var/log/mysql/error.log
    max_allowed_packet = 32M
    max_connect_errors = 50
    max_connections = 256
    thread_cache_size = 8
    thread_stack = 256K
    innodb_io_capacity = 150

---

apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: $NAMESPACE-$APPNAME
  namespace: mysql
  labels:
    app: $NAMESPACE-$APPNAME
spec:
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: $NAMESPACE-$APPNAME
    spec:
      containers:
      - name: mysql
        image: $IMAGE
        imagePullPolicy: Always
        env:
        - name: UID
          value: "$MYSQL_UID"
        - name: GID
          value: "$MYSQL_GID"
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: $NAMESPACE-$APPNAME
              key: MYSQL_ROOT_PASSWORD
        - name: SERVICE_NAME
          value: $NAMESPACE-$APPNAME
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        lifecycle:
          preStop:
            exec:
              command: ["/bin/bash","/usr/local/bin/shutdown_db.sh"]
        ports:
        - containerPort: 3306
          protocol: TCP
          name: mysql
        livenessProbe:
          exec:
            command: ["/usr/bin/mysqladmin","--defaults-extra-file=/etc/mysql/client.cnf","status"]
          initialDelaySeconds: 90
          timeoutSeconds: 5
        readinessProbe:
          exec:
            command: ["/usr/bin/mysqladmin","--defaults-extra-file=/etc/mysql/client.cnf","status"]
          initialDelaySeconds: 15
          timeoutSeconds: 5
          failureThreshold: 10
        resources:
          requests:
            cpu: $CPU
            memory: $MEMORY
          limits:
            cpu: $CPU
            memory: $MEMORY
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        - name: mysql-config
          mountPath: /etc/mysql/conf.d
      terminationGracePeriodSeconds: 300
      volumes:
        - name: mysql-data
          persistentVolumeClaim:
            claimName: $PVCNAME
        - name: mysql-config
          configMap:
            name: $NAMESPACE-$APPNAME
            items:
            - key: mysql.cnf
              path: mysql.cnf
---

apiVersion: extensions/v1beta1
kind: NetworkPolicy
metadata:
  namespace: mysql
  name: $NAMESPACE-$APPNAME
spec:
  podSelector:
    matchLabels:
      app: $NAMESPACE-$APPNAME
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: $NAMESPACE
      ports:
        - protocol: tcp
          port: 3306
EOF

echo "Waiting for Mysql Database for $NAMESPACE-$APPNAME to come up"
kubectl  -n mysql rollout status -w deployment/$NAMESPACE-$APPNAME
POD=$(kubectl -n mysql get po -l app=$NAMESPACE-$APPNAME -o=jsonpath='{.items[*].metadata.name}')
kubectl -n mysql exec $POD /usr/local/bin/create_db.sh $NAMESPACE $APPNAME
