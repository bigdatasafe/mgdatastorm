#!/bin/bash

if [ -f './conf.cfg' ]; then
    source ./conf.cfg
else
    echo -e "\n----------------------- Please Crate conf.cfg -----------------------\n"
    curl http://kaifa.hc-yun.com:30027/base/conf.cfg
    echo -e "\n\n\n"
    exit 1
fi

INFO_HOST(){
    clear
    let SER_LEN=${#SERVERS[@]}-1
    cat <<EOF

----------------------------------------- Install Info -----------------------------------------

  IP --> 主机名对应关系
$(for ((i=0;i<=$SER_LEN;i++)); do echo -e "    ${SERVERS[i]} --> ${HOSTS[i]}"; done)

  zookeeper:
      zookeeper: $ZOO_SERVER

  hadoop:
       namenode: $NameNode
       datanode: $DataNode

  fastdfs:
        storage: $STORAGE_SERVER
        tracker: $TRACKER_SERVER

        storage:
              nginx: $STORAGE_SERVER
          keeplived: $STORAGE_SERVER
        keep_master: $KEEP_MASTER
           keep_vip: $KEEP_VIP

  hbase:
         master: $HBASE_MASTER
          slave: $HBASE_SLAVE

  opentsdb:
       opentsdb: $TSDB_SERVER

  kafka:
          kafka: $KAFKA_SERVER

  apache-storm:
         master: $STORM_MASTER
          slave: $STORM_SLAVE

------------------------------------------------------------------------------------------------

EOF
}


INFO_IP(){
    clear
    let SER_LEN=${#SERVERS[@]}-1
    for ((i=0;i<=$SER_LEN;i++)); do
        export ${HOSTS[i]}=${SERVERS[i]}
    done
    cat <<EOF

----------------------------------------- Install Info -----------------------------------------

IP --> 主机名对应关系
$(for ((i=0;i<=$SER_LEN;i++)); do echo -e "    ${SERVERS[i]} --> ${HOSTS[i]}"; done)

  zookeeper:
      zookeeper: $(for i in $ZOO_SERVER; do echo -e "$(eval echo '$'"${i}:2181") \c"; done)

  hadoop:
       namenode: $(for i in $NameNode; do echo -e "$(eval echo '$'"${i}:50070") \c"; done)
       datanode: $(for i in $DataNode; do echo -e "$(eval echo '$'"${i}:50075") \c"; done)

  fastdfs:
        storage: $(for i in $STORAGE_SERVER; do echo -e "$(eval echo '$'"${i}") \c"; done)
        tracker: $(for i in $TRACKER_SERVER; do echo -e "$(eval echo '$'"${i}:22122") \c"; done)

        storage:
              nginx: $(for i in $STORAGE_SERVER; do echo -e "$(eval echo '$'"${i}:8888/80") \c"; done)
          keeplived: $(for i in $STORAGE_SERVER; do echo -e "$(eval echo '$'"${i}") \c"; done)
        keep_master: $(for i in $KEEP_MASTER; do echo -e "$(eval echo '$'"${i}") \c"; done)
           keep_vip: ${KEEP_VIP}:80

  hbase:
         master: $(for i in $HBASE_MASTER; do echo -e "$(eval echo '$'"${i}:16010") \c"; done)
          slave: $(for i in $HBASE_SLAVE; do echo -e "$(eval echo '$'"${i}:16030") \c"; done)

  opentsdb:
       opentsdb: $(for i in $TSDB_SERVER; do echo -e "$(eval echo '$'"${i}:14242") \c"; done)

  kafka:
          kafka: $(for i in $KAFKA_SERVER; do echo -e "$(eval echo '$'"${i}:9092") \c"; done)

  apache-storm:
         master: $(for i in $STORM_MASTER; do echo -e "$(eval echo '$'"${i}:8080") \c"; done)
          slave: $(for i in $STORM_SLAVE; do echo -e "$(eval echo '$'"${i}") \c"; done)

------------------------------------------------------------------------------------------------

EOF
}

case "$1" in
    ip|IP) INFO_IP ;;
    host|HOST) INFO_HOST ;;
    *) echo -e "Usage $0 {ip/host}"
esac
