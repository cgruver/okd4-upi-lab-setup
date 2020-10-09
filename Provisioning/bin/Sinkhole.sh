#!/bin/bash

for i in "$@"
do
case $i in
    -d|--disconnect)
    ssh root@${LAB_NAMESERVER} 'sed -i "s|;sinkhole-openshift|registry.svc.ci.openshift.org|g" /etc/named/zones/db.sinkhole && sed -i "s|;sinkhole-quay|quay.io|g" /etc/named/zones/db.sinkhole && sed -i "s|;sinkhole-dockerhub|docker.io|g" /etc/named/zones/db.sinkhole && sed -i "s|;sinkhole-github|github.com|g" /etc/named/zones/db.sinkhole && systemctl restart named'
    shift
    ;;
    -c|--connect)
    ssh root@${LAB_NAMESERVER} 'sed -i "s|registry.svc.ci.openshift.org|;sinkhole-openshift|g" /etc/named/zones/db.sinkhole && sed -i "s|quay.io|;sinkhole-quay|g" /etc/named/zones/db.sinkhole && sed -i "s|docker.io|;sinkhole-dockerhub|g" /etc/named/zones/db.sinkhole && sed -i "s|github.com|;sinkhole-github|g" /etc/named/zones/db.sinkhole && systemctl restart named'
    shift
    ;;
    *)
    echo "Usage: Sinkhole.sh -d to disconnect DNS from registry.svc.ci.openshift.org, quay.io, and docker.io"
    echo "Usage: Sinkhole.sh -c to connect DNS to registry.svc.ci.openshift.org, quay.io, and docker.io"
    ;;
esac
done

