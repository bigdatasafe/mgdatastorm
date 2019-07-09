#!/bin/bash

BASE_DIR=$(cd "$(dirname $0)"; pwd)

# 循环执行直到成功
function repeat() {
    while true; do
        $@ && return
    done
}

if [ -f './conf.cfg' ]; then
    source ./conf.cfg
else
    echo -e "\n----------------------- Please Crate conf.cfg -----------------------\n"
    curl http://kaifa.hc-yun.com:30027/base/conf.cfg
    echo -e "\n\n\n"
    exit 1
fi

clear
let SER_LEN=${#SERVERS[@]}-1
cat <<EOF

---------------------------------- info ----------------------------------

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
--------------------------------------------------------------------------

EOF

read -p '确认以上信息请输入[Y]：' ARG
[ "$ARG" != 'Y' ] && { echo -e '\n\t取消...\n'; exit 1; }


# 判断内\外网
ping -c2 192.168.2.7 >/dev/null
if [ $? -eq 0 ];then
    SERVER='192.168.2.7'
else
    SERVER='kaifa.hc-yun.com:30027'
fi


# 软件下载链接
DOWNLOAD_SERVER_DIR="http://$SERVER/base/software"
JDK_VER=8u211
ZOOKEEPER_VER=3.4.14
HADOOP_VER=2.7.7
HBASE_VER=1.2.12
OPENTSDB_VER=2.4.0
KAFKA_VER=2.12-2.2.0
STORM_VER=1.2.2
FASTDFS_VER=5.11
LIBFASTCOMMON_VER=1.0.39
NGINX_VER=1.14.2
FASTDFS_NGINX_MODULE_VER=1.20


PACKAGE_LIST=(
  jdk-${JDK_VER}-linux-x64.tar.gz
  zookeeper-${ZOOKEEPER_VER}.tar.gz
  hadoop-${HADOOP_VER}.tar.gz
  hbase-${HBASE_VER}-bin.tar.gz
  opentsdb-${OPENTSDB_VER}.noarch.rpm
  kafka_${KAFKA_VER}.tgz
  apache-storm-${STORM_VER}.tar.gz
  fastdfs-${FASTDFS_VER}.tar.gz
  libfastcommon-${LIBFASTCOMMON_VER}.tar.gz
  nginx-${NGINX_VER}.tar.gz
  fastdfs-nginx-module-${FASTDFS_NGINX_MODULE_VER}.tar.gz
)

# 配置YUM源
rm -f /etc/yum.repos.d/*.repo
curl -so /etc/yum.repos.d/epel-7.repo http://mirrors.aliyun.com/repo/epel-7.repo
curl -so /etc/yum.repos.d/Centos-7.repo http://mirrors.aliyun.com/repo/Centos-7.repo
sed -i '/aliyuncs.com/d' /etc/yum.repos.d/Centos-7.repo /etc/yum.repos.d/epel-7.repo

# 秘钥登录
SERVER_LIST="${SERVERS[@]}"
PORT=${SSH_PORT:-22}
./ssh-key-copy.sh "$SERVER_LIST" $USER $PASS $PORT

# 安装 wget
[ -f '/usr/bin/wget' ] || yum  install -y wget
mkdir -p $PACKAGE_DIR && cd $PACKAGE_DIR

# 创建软件包目录
for node in ${SERVERS[@]}; do
    ssh -p $PORT -T $node "mkdir -p $PACKAGE_DIR"
done

# 获取本机 eth0网卡IP
LOCAL_IP=$(nmcli device show eth0 | grep IP4.ADDRESS | awk '{print $NF}' | cut -d '/' -f1)

# 下载,发送软件到所有节点
for package in ${PACKAGE_LIST[@]}; do
    # 下载软件
    repeat wget -c $DOWNLOAD_SERVER_DIR/$package
    # 将软件发送到其他节点
    for node in ${SERVERS[@]}; do
        [ "$LOCAL_IP" == "$node" ] && continue
        scp -P $PORT -q $package ${node}:${PACKAGE_DIR} &
    done
done

cd ${BASE_DIR}
# 复制安装脚本到软件安装目录
for node in ${SERVERS[@]}; do
    scp -P $PORT -q info.sh conf.cfg install.sh ssh-key-copy.sh $node:${PACKAGE_DIR} &
done

clear
cat <<EOF

----------------------------------- 所有节点执行 -----------------------------------

    cd $PACKAGE_DIR && ./install.sh

------------------------------------------------------------------------------------

EOF
