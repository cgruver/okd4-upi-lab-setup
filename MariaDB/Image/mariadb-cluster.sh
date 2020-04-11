#!/bin/sh

export PATH=$PATH:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
export WSREP_START_POSITION=""
export WSREP_NEW_CLUSTER=""
export NODE_LIST=""
let NODE_COUNT=0

CLUSTER_SERVICE="${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"
let j=0
for i in $(dig ${CLUSTER_SERVICE} +short)
do
   if [[ NODE_COUNT -eq 0 ]]
      then NODE_LIST="$i"
   else
      NODE_LIST="${NODE_LIST},${i}"
   fi
   let NODE_COUNT=${NODE_COUNT}+1
done

# Test to see if the is the initial bootstrap of a new cluster deployment.
# If true, then initialize MariaDB
if [ ! -f /var/lib/mysql/data/node_deployed ]
then
   sudo mkdir -p /var/lib/mysql/data
   sudo chown mysql.0 /var/lib/mysql/data
   sudo /usr/bin/mysql_install_db --datadir=/var/lib/mysql/data --user=mysql
   sudo /usr/sbin/mysqld --user=mysql --datadir=/var/lib/mysql/data --bind-address=127.0.0.1 &
   # Give mariadb time to start
   sleep 10
   sudo /usr/bin/mysql --user=root -e "DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'); DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'; FLUSH PRIVILEGES;"
   sudo /usr/bin/mysqladmin shutdown
   touch /var/lib/mysql/data/node_deployed
fi

cp /tmp/mariadb-config/mariadb-server.cnf /etc/my.cnf.d/server.cnf

# Test to see if we are the first node in the cluster
if [[ NODE_COUNT -eq 0 ]]
then
   export WSREP_NEW_CLUSTER='--wsrep-new-cluster'
   export CLUSTER_ADDRESS="wsrep_cluster_address=gcomm://${POD_IP}"
   sed -i 's/safe_to_bootstrap: 0/safe_to_bootstrap: 1/g' /var/lib/mysql/data/grastate.dat
else
   export CLUSTER_ADDRESS="wsrep_cluster_address=gcomm://${NODE_LIST}"
fi
sed -i "s|%%CLUSTER_ADDRESS%%|${CLUSTER_ADDRESS}|g" "/etc/my.cnf.d/server.cnf"

VAR=`sudo /usr/bin/galera_recovery`; [ $? -eq 0 ] && export WSREP_START_POSITION=${VAR} || exit 1

sudo /usr/sbin/mysqld --user=mysql --datadir=/var/lib/mysql/data $MYSQLD_OPTS ${WSREP_NEW_CLUSTER} $WSREP_START_POSITION

