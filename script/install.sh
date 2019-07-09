#!/bin/bash

# 读取配置文件
if [ -f './conf.cfg' ]; then
    source ./conf.cfg
else
    echo -e "\n----------------------- Please Crate conf.cfg -----------------------\n"
    curl http://kaifa.hc-yun.com:30027/base/conf.cfg
    echo -e "\n\n\n"
    exit 1
fi

# sshd 端口号
PORT=${SSH_PORT:-22}

# 检测 HOSTS,SERVERS 数组个数
if [ "${#HOSTS[@]}" != "${#SERVERS[@]}" ]; then
    echo -e "\n\tHOSTS与SERVERS 数组个数不匹配...\n"
    exit 1
fi

# 获取 eth0 网卡IP
LOCAL_IP=$(nmcli device show eth0 | grep IP4.ADDRESS | awk '{print $NF}' | cut -d '/' -f1 | head -n1)
[ "$LOCAL_IP" ] || { echo -e "\n\t获取本地IP地址失败...\n"; exit 1; }

# 配置 hosts 解析
if [ "$(echo ${SERVERS[@]} | grep $LOCAL_IP)" ]; then
    sed -i '3,$d' /etc/hosts
    echo -e "\n# hadoop" >> /etc/hosts
    let SER_LEN=${#SERVERS[@]}-1
    for ((i=0;i<=$SER_LEN;i++)); do
        echo "${SERVERS[i]}  ${HOSTS[i]}" >> /etc/hosts
    done
fi

# 更改主机名
for ((i=0;i<=$SER_LEN;i++)); do
    if [ "${SERVERS[i]}" == "$LOCAL_IP" ]; then
        hostnamectl set-hostname ${HOSTS[i]}
    fi
done

PREP(){
    # 优化ssh连接速度
    sed -i "s/#UseDNS yes/UseDNS no/" /etc/ssh/sshd_config
    sed -i "s/GSSAPIAuthentication .*/GSSAPIAuthentication no/" /etc/ssh/sshd_config
    systemctl restart sshd

    # selinux
    systemctl stop firewalld
    systemctl disable firewalld
    setenforce 0
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

    # 可打开文件限制 进程限制
    if [ ! "$(cat /etc/security/limits.conf | grep '# mango')" ]; then
        echo -e "\n# mango" >> /etc/security/limits.conf
        echo "* soft nofile 65535" >> /etc/security/limits.conf
        echo "* hard nofile 65535" >> /etc/security/limits.conf
        echo "* soft nproc 65535"  >> /etc/security/limits.conf
        echo "* hard nproc 65535"  >> /etc/security/limits.conf
        echo "* soft  memlock  unlimited"  >> /etc/security/limits.conf
        echo "* hard memlock  unlimited"  >> /etc/security/limits.conf
    fi

    # 安装yum源
    rm -f /etc/yum.repos.d/*.repo
    curl -so /etc/yum.repos.d/epel-7.repo http://mirrors.aliyun.com/repo/epel-7.repo
    curl -so /etc/yum.repos.d/Centos-7.repo http://mirrors.aliyun.com/repo/Centos-7.repo
    sed -i '/aliyuncs.com/d' /etc/yum.repos.d/Centos-7.repo /etc/yum.repos.d/epel-7.repo

    # 时间同步
    yum install -y ntpdate
    ntpdate ntp1.aliyun.com
    hwclock -w
    crontab -l > /tmp/crontab.tmp
    echo "*/20 * * * * /usr/sbin/ntpdate ntp1.aliyun.com > /dev/null 2>&1 && /usr/sbin/hwclock -w" >> /tmp/crontab.tmp
    cat /tmp/crontab.tmp | uniq > /tmp/crontab
    crontab /tmp/crontab
    rm -f /tmp/crontab.tmp /tmp/crontab

    # 安装 wget
    yum install -y wget
}

# 安装 JDK
INSTALL_JDK(){
    # 安装JDK
    mkdir -p /usr/java/ $PACKAGE_DIR && cd $PACKAGE_DIR
    tar zxf jdk-${JDK_VER}-linux-x64.tar.gz -C /usr/java/

    # 配置环境变量
    config=/etc/profile.d/jdk.sh
    echo '#!/bin/bash' > $config
    echo 'export JAVA_HOME=/usr/java/jdk1.8.0_211' >> $config
    echo 'export JRE_HOME=${JAVA_HOME}/jre' >> $config
    echo 'export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib:$CLASSPATH' >> $config
    echo 'export PATH=$JAVA_HOME/bin:$PATH' >> $config

    # 读取环境变量
    chmod +x $config
    source $config
}

# 安装 zookeeper
INSTALL_ZOOKEEPER(){
    mkdir -p $SOFT_INSTALL_DIR $PACKAGE_DIR && cd $PACKAGE_DIR
    tar zxf zookeeper-${ZOOKEEPER_VER}.tar.gz -C $SOFT_INSTALL_DIR
    mkdir -p ${SOFT_INSTALL_DIR}/zookeeper-${ZOOKEEPER_VER}/{logs,data}
    config=${SOFT_INSTALL_DIR}/zookeeper-${ZOOKEEPER_VER}/conf/zoo.cfg
    echo 'tickTime=2000' > $config
    echo 'initLimit=10' >> $config
    echo 'syncLimit=5' >> $config
    echo "dataDir=$SOFT_INSTALL_DIR/zookeeper-${ZOOKEEPER_VER}/data" >> $config
    echo "dataLogDir=$SOFT_INSTALL_DIR/zookeeper-${ZOOKEEPER_VER}/logs" >> $config
    echo 'clientPort=2181' >> $config
    echo 'autopurge.snapRetainCount=500' >> $config
    echo 'autopurge.purgeInterval=24' >> $config
    count=1
    for node in $ZOO_SERVER; do
        echo "server.$count=$node:2888:3888"  >> $config
        [ "$node" == "`hostname`" ] && echo "$count" > ${SOFT_INSTALL_DIR}/zookeeper-${ZOOKEEPER_VER}/data/myid
        let count++
    done
    
    # 配置环境变量
    config=/etc/profile.d/zookeeper.sh
    echo '#!/bin/bash' > $config
    echo "export ZOOKEEPER_HOME=${SOFT_INSTALL_DIR}/zookeeper-${ZOOKEEPER_VER}" >> $config
    echo 'export PATH=$ZOOKEEPER_HOME/bin:$PATH' >> $config

    # 读取环境变量
    chmod +x $config
    source $config
}

# zookeeper 启动脚本
ZOOKEEPER_SERVICE_SCRIPT(){
cat <<EOF   > ${SOFT_INSTALL_DIR}/zookeeper-${ZOOKEEPER_VER}/bin/zk.sh
#!/bin/bash

echo "\$1"
user="root"
iparray=($ZOO_SERVER)

case "\$1" in
    start) cmd='zkServer.sh start' ;;
    status) cmd='zkServer.sh status' ;;
    stop) cmd='zkServer.sh stop' ;;
    *) { echo -e "\nUsage \$0 {start|stop|status}"; exit 1; }  ;;
esac

for ip in \${iparray[*]}; do
    echo "------> ssh to \$ip"
    ssh -p $PORT -T \$user@\$ip "\$cmd"
    echo "------> jps:"
    ssh -p $PORT -T \$user@\$ip 'jps'
    echo
done
EOF

    chmod +x ${SOFT_INSTALL_DIR}/zookeeper-${ZOOKEEPER_VER}/bin/zk.sh
}

# hadoop 5节点集群安装
INSTALL_HADOOP_5(){
    cd $PACKAGE_DIR
    tar zxf hadoop-${HADOOP_VER}.tar.gz -C ${SOFT_INSTALL_DIR}
    mkdir -p ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/{logs,tmp,name,data,journal}

    # 配置环境变量
    config=/etc/profile.d/hadoop.sh
    echo '#!/bin/bash' > $config
    echo "export HADOOP_HOME=$SOFT_INSTALL_DIR/hadoop-${HADOOP_VER}" >> $config
    echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin' >> $config

    # 读取环境变量
    chmod +x $config
    source $config

    # 创建 core-site.xml
    ZOO_LIST="$(for i in $ZOO_SERVER; do echo $i:2181; done)"
    ZOO_LIST="$(echo $ZOO_LIST | sed 's# #,#g')"
    cat <<EOF > ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/etc/hadoop/core-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
 <property>
     <name>fs.defaultFS</name>
     <value>hdfs://hadoopha</value>
 </property>
 <property>
     <name>hadoop.tmp.dir</name>
     <value>file:${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/tmp</value>
 </property>
 <property>
    <name>ha.zookeeper.quorum</name>
    <value>$ZOO_LIST</value>
 </property>
 <property>
    <name>ha.zookeeper.session-timeout.ms</name>
    <value>15000</value>
 </property>
</configuration>
EOF

    # 创建 hdfs-site.xml
    DATANODE="$(for i in $DataNode ; do echo $i:8485; done)"
    DATANODE="$(echo $DATANODE | sed 's# #;#g')"
    cat <<EOF > ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/etc/hadoop/hdfs-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
 <property>
     <name>dfs.namenode.name.dir</name>
     <value>file:${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/name</value>
 </property>
 <property>
     <name>dfs.datanode.data.dir</name>
     <value>file:${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/data</value>
 </property>
 <property>
     <name>dfs.replication</name>
     <value>3</value>
 </property>
 <!--HA配置 -->
 <property>
     <name>dfs.nameservices</name>
     <value>hadoopha</value>
 </property>
 <property>
     <name>dfs.ha.namenodes.hadoopha</name>
     <value>nn1,nn2</value>
 </property>
 <!--namenode1 RPC端口 -->
 <property>
     <name>dfs.namenode.rpc-address.hadoopha.nn1</name>
     <value>${HDP_NN1}:9000</value>
 </property>
 <!--namenode1 HTTP端口 -->
 <property>
     <name>dfs.namenode.http-address.hadoopha.nn1</name>
     <value>${HDP_NN1}:50070</value>
 </property>
 <!--namenode2 RPC端口 -->
 <property>
     <name>dfs.namenode.rpc-address.hadoopha.nn2</name>
     <value>${HDP_NN2}:9000</value>
 </property>
  <!--namenode2 HTTP端口 -->
 <property>
     <name>dfs.namenode.http-address.hadoopha.nn2</name>
     <value>${HDP_NN2}:50070</value>
 </property>
  <!--HA故障切换 -->
 <property>
     <name>dfs.ha.automatic-failover.enabled</name>
     <value>true</value>
 </property>
 <!-- journalnode 配置 -->
 <property>
     <name>dfs.namenode.shared.edits.dir</name>
     <value>qjournal://${DATANODE}/hadoopha</value>
 </property>
 <property>
     <name>dfs.client.failover.proxy.provider.hadoopha</name>
     <value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
 </property>
 <property>
     <name>dfs.ha.fencing.methods</name>
     <value>shell(/bin/true)</value>
  </property>
   <!--SSH私钥 -->
  <property>
      <name>dfs.ha.fencing.ssh.private-key-files</name>
      <value>/root/.ssh/id_rsa</value>
  </property>
 <!--SSH超时时间 -->
  <property>
      <name>dfs.ha.fencing.ssh.connect-timeout</name>
      <value>30000</value>
  </property>
  <!--Journal Node文件存储地址 -->
  <property>
      <name>dfs.journalnode.edits.dir</name>
      <value>${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/journal</value>
  </property>
</configuration>
EOF

    # 修改yarn-site.xml配置文件
    cat <<EOF > ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/etc/hadoop/yarn-site.xml
<?xml version="1.0"?>
<configuration>
    <!-- 开启RM高可用 -->
    <property>
         <name>yarn.resourcemanager.ha.enabled</name>
         <value>true</value>
    </property>
    <!-- 指定RM的cluster id -->
    <property>
         <name>yarn.resourcemanager.cluster-id</name>
         <value>yrc</value>
    </property>
    <!-- 指定RM的名字 -->
    <property>
         <name>yarn.resourcemanager.ha.rm-ids</name>
         <value>rm1,rm2</value>
    </property>
    <!-- 分别指定RM的地址 -->
    <property>
         <name>yarn.resourcemanager.hostname.rm1</name>
         <value>${HDP_RM1}</value>
    </property>
    <property>
         <name>yarn.resourcemanager.hostname.rm2</name>
         <value>${HDP_RM2}</value>
    </property>
    <!-- 指定zk集群地址 -->
    <property>
         <name>yarn.resourcemanager.zk-address</name>
         <value>${ZOO_LIST}</value>
    </property>
    <property>
         <name>yarn.nodemanager.aux-services</name>
         <value>mapreduce_shuffle</value>
    </property>
</configuration>
EOF

    # 创建 mapred-site.xml
    cat <<EOF > ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/etc/hadoop/mapred-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
   <property>
          <name>mapreduce.framework.name</name>
          <value>yarn</value>
   </property>
   <property>
         <name>mapreduce.map.memory.mb</name>
         <value>2048</value>
   </property>
   <property>
          <name>mapreduce.reduce.memory.mb</name>
          <value>2048</value>
   </property>
</configuration>
EOF

    # 加入DataNode节点主机名
    rm -f ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/etc/hadoop/slaves
    for node in $DataNode; do
        echo "$node"  >> ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/etc/hadoop/slaves
    done
    
    # SSH端口
    echo "export HADOOP_SSH_OPTS=\"-p $PORT\"" >> /home/hadoop/hadoop-${HADOOP_VER}/etc/hadoop/hadoop-env.sh

    # hadoop 集群内核优化
    cat > /etc/sysctl.conf  <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
vm.swappiness = 0
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_rmem = 8192 262144 4096000
net.ipv4.tcp_wmem = 4096 262144 4096000
net.ipv4.tcp_max_orphans = 300000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.ip_local_port_range = 1025 65535
net.ipv4.tcp_max_syn_backlog = 100000
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp.keepalive_time = 1200
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.netfilter.ip_conntrack_tcp_timeout_established = 1500
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.sysrq = 1
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.tcp_max_orphans = 3276800
fs.file-max = 800000
net.core.somaxconn=32768
net.core.rmem_default = 12697600
net.core.wmem_default = 12697600
net.core.rmem_max = 873800000
net.core.wmem_max = 655360000
EOF

    # 立即生效
    sysctl -p 
}

# hadoop 3节点集群安装
INSTALL_HADOOP_3(){
    cd $PACKAGE_DIR
    tar zxf hadoop-${HADOOP_VER}.tar.gz -C ${SOFT_INSTALL_DIR}
    mkdir -p ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/{logs,tmp,name,data,journal}

    # 配置环境变量
    config=/etc/profile.d/hadoop.sh
    echo '#!/bin/bash' > $config
    echo "export HADOOP_HOME=$SOFT_INSTALL_DIR/hadoop-${HADOOP_VER}" >> $config
    echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin' >> $config

    # 读取环境变量
    chmod +x $config
    source $config

    # 创建 core-site.xml
    # ZOO_LIST="$(for i in $ZOO_SERVER; do echo $i:2181; done)"
    # ZOO_LIST="$(echo $ZOO_LIST | sed 's# #,#g')"
    cat <<EOF > ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/etc/hadoop/core-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://${NameNode}:9000</value>
    </property>
    <property>
        <name>io.file.buffer.size</name>
        <value>13107200</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>file:${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/tmp</value>
    </property>
</configuration>
EOF

    # 创建 hdfs-site.xml
    DATANODE="$(for i in $DataNode ; do echo $i:8485; done)"
    DATANODE="$(echo $DATANODE | sed 's# #;#g')"
    cat <<EOF > ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/etc/hadoop/hdfs-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
    <property>
        <name>dfs.namenode.secondary.http-address</name>
        <value>${NameNode}:50090</value>
    </property>
    <property>
        <name>dfs.replication</name>
        <value>2</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/name</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file:${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/data</value>
    </property>
</configuration>
EOF

    # 修改yarn-site.xml配置文件
    cat <<EOF > ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/etc/hadoop/yarn-site.xml
<?xml version="1.0"?>

<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.resourcemanager.address</name>
        <value>${NameNode}:8032</value>
    </property>
    <property>
        <name>yarn.resourcemanager.scheduler.address</name>
        <value>${NameNode}:8030</value>
    </property>
    <property>
        <name>yarn.resourcemanager.resource-tracker.address</name>
        <value>${NameNode}:8031</value>
    </property>
    <property>
        <name>yarn.resourcemanager.admin.address</name>
        <value>${NameNode}:8033</value>
    </property>
    <property>
        <name>yarn.resourcemanager.webapp.address</name>
        <value>${NameNode}:8088</value>
    </property>
</configuration>
EOF

    # 创建 mapred-site.xml
    cat <<EOF > ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/etc/hadoop/mapred-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.address</name>
        <value>${NameNode}:10020</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.address</name>
        <value>${NameNode}:19888</value>
    </property>
</configuration>
EOF

    # 加入DataNode节点主机名
    rm -f ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/etc/hadoop/slaves
    for node in $DataNode; do
        echo "$node"  >> ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/etc/hadoop/slaves
    done
    
    # SSH端口
    echo "export HADOOP_SSH_OPTS=\"-p $PORT\"" >> /home/hadoop/hadoop-${HADOOP_VER}/etc/hadoop/hadoop-env.sh

    # hadoop 集群内核优化
    cat > /etc/sysctl.conf  <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
vm.swappiness = 0
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_rmem = 8192 262144 4096000
net.ipv4.tcp_wmem = 4096 262144 4096000
net.ipv4.tcp_max_orphans = 300000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.ip_local_port_range = 1025 65535
net.ipv4.tcp_max_syn_backlog = 100000
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp.keepalive_time = 1200
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.netfilter.ip_conntrack_tcp_timeout_established = 1500
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.sysrq = 1
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.tcp_max_orphans = 3276800
fs.file-max = 800000
net.core.somaxconn=32768
net.core.rmem_default = 12697600
net.core.wmem_default = 12697600
net.core.rmem_max = 873800000
net.core.wmem_max = 655360000
EOF

    # 立即生效
    sysctl -p 
}

# hadoop 5节点初始化
INIT_HADOOP_5(){
cat <<EEOF    > init-hadoop.sh
#!/bin/bash

source /etc/profile

# NameNode start zookeeper
ssh -p $PORT -T `hostname` <<EOF
    source /etc/profile.d/zookeeper.sh
    zk.sh start
EOF

sleep 5
# start zkfc
ssh -p $PORT -T `hostname` <<EOF
    source /etc/profile.d/hadoop.sh
    hdfs zkfc -formatZK -force
EOF

sleep 5
# datanode 启动  journalnode
for node in $DataNode;do
    ssh -p $PORT -T \$node <<EOF
      source /etc/profile.d/hadoop.sh
      hadoop-daemon.sh  start journalnode
EOF
done

sleep 5
# NodeName Master 初始化
ssh -p $PORT -T $HDP_NN1 <<EOF
    source /etc/profile.d/hadoop.sh
    hdfs namenode -format -force
EOF

sleep 5
# start datanode
for node in $DataNode;do
    ssh -p $PORT -T \$node <<EOF
      source /etc/profile.d/hadoop.sh
      hadoop-daemon.sh start datanode
EOF
done

sleep 5
# start namenode1 master
ssh -p $PORT -T $HDP_NN1 <<EOF
    source /etc/profile.d/hadoop.sh
    hadoop-daemon.sh start namenode
EOF

sleep 5
# start namenode2 master
ssh -p $PORT -T $HDP_NN2 <<EOF
    source /etc/profile.d/hadoop.sh
    hdfs namenode -bootstrapStandby -force
    hadoop-daemon.sh start namenode
EOF

sleep 5
# NameNode start zkfc
for node in $NameNode;do
    ssh -p $PORT -T \$node <<EOF
      source /etc/profile.d/hadoop.sh
      hadoop-daemon.sh start zkfc
EOF
done
EEOF
}

# hadoop 3节点初始化
INIT_HADOOP_3(){
cat <<EEOF    > init-hadoop.sh
#!/bin/bash

source /etc/profile

# NameNode start zookeeper
ssh -p $PORT -T `hostname` <<EOF
    source /etc/profile.d/zookeeper.sh
    zk.sh start
EOF

sleep 5
# init hadoop
ssh -p $PORT -T $NameNode <<EOF
    source /etc/profile.d/hadoop.sh
    hdfs namenode -format -force
EOF

sleep 5
# start hadoop
ssh -p $PORT -T $NameNode <<EOF
    source /etc/profile.d/hadoop.sh
    ${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/sbin/start-all.sh
EEOF
}

# 安装 hbase(hdp双namenode)
INSTALL_HBASE_5(){
    # 下载解压
    mkdir -p $PACKAGE_DIR && cd $PACKAGE_DIR
    tar zxf hbase-${HBASE_VER}-bin.tar.gz -C ${SOFT_INSTALL_DIR}/

    # 配置 hbase
    sed -i 's/# export HBASE_MANAGES_ZK=true/export HBASE_MANAGES_ZK=false/' ${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}/conf/hbase-env.sh
    ZOOK_SERVER_LIST="$(echo $ZOO_SERVER | sed 's/ /,/g')"
    cat <<EOF    > ${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}/conf/hbase-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
<property>
    <name>hbase.rootdir</name>
    <!-- hadoopha 是namenode HA配置的 dfs.nameservices名称 -->
    <value>hdfs://hadoopha/hbase</value>
</property>
<property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
</property>
<property>
    <name>hbase.zookeeper.quorum</name>
    <value>${ZOOK_SERVER_LIST}</value>
</property>
<property>
    <name>hbase.zookeeper.property.clientPort</name>
    <value>2181</value>
</property>
<property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>${SOFT_INSTALL_DIR}/zookeeper-${ZOOKEEPER_VER}/data</value>
</property>
<property>
    <name>hbase.tmp.dir</name>
    <value>${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}/tmp</value>
</property>
<property>
    <name>hbase.client.scanner.timeout.period</name>
    <value>180000</value>
</property>
<property>
    <name>zookeeper.session.timeout</name>
    <value>120000</value>
</property>
<property>
    <name>hbase.rpc.timeout</name>
    <value>300000</value>
</property>
<property>
    <name>hbase.hregion.majorcompaction</name>
    <value>0</value>
</property>
<property>
    <name>hbase.regionserver.thread.compaction.large</name>
    <value>5</value>
</property>
<property>
    <name>hbase.regionserver.thread.compaction.small</name>
    <value>5</value>
</property>
<property>
    <name>hbase.regionserver.thread.compaction.throttle</name>
    <value>10737418240</value>
</property>
<property>
    <name>hbase.regionserver.regionSplitLimit</name>
    <value>150</value>
</property>
<property>
    <name>hfile.block.cache.size</name>
    <value>0</value>
</property>
</configuration>
EOF

    mkdir -p ${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}/{data,logs,tmp}
    rm -f ${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}/conf/regionservers
    for node in $HBASE_SLAVE; do echo "$node" >> ${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}/conf/regionservers ;done

    # 添加环境变量
    config=/etc/profile.d/hbase.sh
    echo '#!/bin/bash' > $config
    echo "export HBASE_HOME=${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}" >> $config
    echo 'export PATH=$HBASE_HOME/bin:$PATH' >> $config
    
    # SSH端口
    echo "export HBASE_SSH_OPTS=\"-p $PORT\"" >> /home/hadoop/hbase-${HBASE_VER}/conf/hbase-env.sh

    # 读取环境变量
    chmod +x $config
    source $config
}

# 安装hbase(hdp单namenode)
INSTALL_HBASE_3(){
    # 下载解压
    mkdir -p $PACKAGE_DIR && cd $PACKAGE_DIR
    tar zxf hbase-${HBASE_VER}-bin.tar.gz -C ${SOFT_INSTALL_DIR}/

    # 配置 hbase
    sed -i 's/# export HBASE_MANAGES_ZK=true/export HBASE_MANAGES_ZK=false/' ${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}/conf/hbase-env.sh
    ZOOK_SERVER_LIST="$(echo $ZOO_SERVER | sed 's/ /,/g')"
    cat <<EOF    > ${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}/conf/hbase-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
<property>
    <name>hbase.rootdir</name>
    <value>hdfs://${NameNode}:9000/hbase</value>
</property>
<property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
</property>
<property>
    <name>hbase.zookeeper.quorum</name>
    <value>${ZOOK_SERVER_LIST}</value>
</property>
<property>
    <name>hbase.zookeeper.property.clientPort</name>
    <value>2181</value>
</property>
<property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>${SOFT_INSTALL_DIR}/zookeeper-${ZOOKEEPER_VER}/data</value>
</property>
<property>
    <name>hbase.tmp.dir</name>
    <value>${SOFT_INSTALL_DIR}/zookeeper-${ZOOKEEPER_VER}/tmp</value>
</property>
<property>
    <name>hbase.client.scanner.timeout.period</name>
    <value>180000</value>
</property>
<property>
    <name>zookeeper.session.timeout</name>
    <value>120000</value>
</property>
<property>
    <name>hbase.rpc.timeout</name>
    <value>300000</value>
</property>
<property>
    <name>hbase.hregion.majorcompaction</name>
    <value>0</value>
</property>
<property>
    <name>hbase.regionserver.thread.compaction.large</name>
    <value>5</value>
</property>
<property>
    <name>hbase.regionserver.thread.compaction.small</name>
    <value>5</value>
</property>
<property>
    <name>hbase.regionserver.thread.compaction.throttle</name>
    <value>10737418240</value>
</property>
<property>
    <name>hbase.regionserver.regionSplitLimit</name>
    <value>150</value>
</property>
<property>
    <name>hfile.block.cache.size</name>
    <value>0</value>
</property>
</configuration>
EOF

    mkdir -p ${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}/{data,logs,tmp}
    rm -f ${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}/conf/regionservers
    for node in $HBASE_SLAVE; do echo "$node" >> ${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}/conf/regionservers ;done

    # 添加环境变量
    config=/etc/profile.d/hbase.sh
    echo '#!/bin/bash' > $config
    echo "export HBASE_HOME=${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}" >> $config
    echo 'export PATH=$HBASE_HOME/bin:$PATH' >> $config
    
    # SSH端口
    echo "export HBASE_SSH_OPTS=\"-p $PORT\"" >> /home/hadoop/hbase-${HBASE_VER}/conf/hbase-env.sh

    # 读取环境变量
    chmod +x $config
    source $config

}

# 安装 opentsdb
INSTALL_TSDB(){
    cd $PACKAGE_DIR
    yum install -y opentsdb-${OPENTSDB_VER}.noarch.rpm
    ZOOK_SERVER_LIST="$(echo $ZOO_SERVER | sed 's/ /,/g')"
    confile=/etc/opentsdb/opentsdb.conf
    echo 'tsd.c
ore.preload_uid_cache = true' > $confile
    echo 'tsd.core.auto_create_metrics = true' >> $confile
    echo 'tsd.storage.enable_appends = true' >> $confile
    echo 'tsd.core.enable_ui = true' >> $confile
    echo 'tsd.core.enable_api = true' >> $confile
    echo 'tsd.network.port = 14242' >> $confile
    echo 'tsd.http.staticroot = /usr/share/opentsdb/static' >> $confile
    echo "tsd.http.cachedir = ${SOFT_INSTALL_DIR}/opentsdb/tmp" >> $confile
    echo 'tsd.http.request.enable_chunked = true' >> $confile
    echo 'tsd.http.request.max_chunk = 65535' >> $confile
    echo "tsd.storage.hbase.zk_quorum = ${ZOOK_SERVER_LIST}" >> $confile
    echo 'tsd.query.timeout = 0' >> $confile
    echo 'tsd.query.filter.expansion_limit = 65535' >> $confile
    echo 'tsd.network.keep_alive = true' >> $confile
    echo 'tsd.network.backlog = 3072' >> $confile
    echo 'tsd.storage.fix_duplicates=true' >> $confile

    mkdir -p ${SOFT_INSTALL_DIR}/opentsdb/{data,logs,tmp}
}

# 安装 kafka
INSTALL_KAFKA(){
    # 下载解压
    mkdir -p $PACKAGE_DIR && cd $PACKAGE_DIR
    tar zxf kafka_${KAFKA_VER}.tgz -C ${SOFT_INSTALL_DIR}

    # 配置kafka
    mkdir -p ${SOFT_INSTALL_DIR}/kafka_${KAFKA_VER}/{data,logs,tmp}
    ID=$(echo $LOCAL_IP | awk -F '.' '{print $NF}')
    ZOO_LIST="$(for i in $ZOO_SERVER; do echo $i:2181; done)"
    ZOO_LIST="$(echo $ZOO_LIST | sed 's# #,#g')"
    config=${SOFT_INSTALL_DIR}/kafka_${KAFKA_VER}/config/server.properties
    echo "broker.id=$ID" > $config
    echo "listeners=PLAINTEXT://${LOCAL_IP}:9092" >> $config
    echo 'num.network.threads=3' >> $config
    echo 'num.io.threads=8' >> $config
    echo '#auto.create.topics.enable =true' >> $config
    echo 'socket.send.buffer.bytes=102400' >> $config
    echo 'socket.receive.buffer.bytes=102400' >> $config
    echo 'socket.request.max.bytes=104857600' >> $config
    echo "log.dirs=${SOFT_INSTALL_DIR}/kafka_${KAFKA_VER}/logs" >> $config
    echo 'num.partitions=1' >> $config
    echo 'num.recovery.threads.per.data.dir=1' >> $config
    echo 'offsets.topic.replication.factor=1' >> $config
    echo 'transaction.state.log.replication.factor=1' >> $config
    echo 'transaction.state.log.min.isr=1' >> $config
    echo 'log.retention.hours=168' >> $config
    echo 'log.segment.bytes=1073741824' >> $config
    echo 'log.retention.check.interval.ms=300000' >> $config
    echo "zookeeper.connect=$ZOO_LIST" >> $config
    echo 'zookeeper.connection.timeout.ms=60000' >> $config
    echo 'group.initial.rebalance.delay.ms=0' >> $config
    
    # 配置环境变量
    config=/etc/profile.d/kafka.sh
    echo '#!/bin/bash' > $config
    echo "export KAFKA_HOME=${SOFT_INSTALL_DIR}/kafka_${KAFKA_VER}" >> $config
    echo 'export PATH=$KAFKA_HOME/bin:$PATH' >> $config

    # 读取环境变量
    chmod +x $config
    source $config
}

# 安装 storm
INSTALL_STORM(){
    # 下载解压
    cd $PACKAGE_DIR
    tar zxf apache-storm-${STORM_VER}.tar.gz -C ${SOFT_INSTALL_DIR}

    config=${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}/conf/storm.yaml
    echo 'storm.zookeeper.servers:' > $config
    for node in $ZOO_SERVER; do echo "  - \"$node\"" >> $config ; done
    echo 'storm.local.dir: "${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}/data"' >> $config
    echo "nimbus.seeds: [\"$STORM_MASTER\"]" >> $config
    echo 'nimbus.childopts: "-Xmx2596m"' >> $config
    echo 'supervisor.childopts: "-Xmx2596m"' >> $config
    echo 'worker.childopts: "-Xmx2048m"' >> $config
    echo 'supervisor.slots.ports:' >> $config
    echo '  - 6700' >> $config
    echo '  - 6701' >> $config
    echo '  - 6702' >> $config
    echo '  - 6703' >> $config
    rm -f ${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}/bin/supervisor-hosts
    for node in $STORM_SLAVE; do echo "$node" >> ${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}/bin/supervisor-hosts; done

    # 服务启动脚本
    cat <<EOF  > ${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}/bin/start-all.sh
#!/bin/bash

source /etc/profile
bin=${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}/bin
supervisors=\$bin/supervisor-hosts

storm nimbus >/dev/null 2>&1 &
storm ui >/dev/null 2>&1 &

cat \$supervisors | while read supervisor
  do
    echo "---> \$supervisor"
    ssh -p $PORT -T \$supervisor \$bin/start-supervisor.sh &
done
EOF

    cat <<'EOF'  >${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}/bin/start-supervisor.sh
#!/bin/bash
source /etc/profile

storm supervisor >/dev/null 2>&1 &
EOF

    # 服务关闭脚本
    cat <<EOF  >${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}/bin/stop-all.sh
#!/bin/bash

source /etc/profile
bin=${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}/bin
supervisors=\$bin/supervisor-hosts

kill -9 \$(ps -ef | grep -v grep | grep daemon.nimbus | awk '{print \$2}')
kill -9 \$(ps -ef | grep -v grep | grep ui.core | awk '{print \$2}')

cat \$supervisors | while read supervisor
  do
    echo "---> \$supervisor"
    ssh -p $PORT -T \$supervisor \$bin/stop-supervisor.sh &
done
EOF

    cat <<EOF  >${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}/bin/stop-supervisor.sh
#!/bin/bash
source /etc/profile

kill -9 \$(ps -ef | grep -v grep | grep daemon.supervisor| awk '{print \$2}')
EOF

    chmod +x ${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}/bin/*.sh

    # 配置环境变量
    config=/etc/profile.d/storm.sh
    echo '#!/bin/bash' > $config
    echo "export STORM_HOME=${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}" >> $config
    echo 'export PATH=$STORM_HOME/bin:$PATH' >> $config

    # 读取环境变量
    chmod +x $config
    source $config
}

# 安装 fastdfs
INSTALL_FASTDFS(){
    # 安装编译环境
    yum install -y unzip make cmake gcc gcc-c++ perl wget

    # 下载解压软件
    mkdir -p $PACKAGE_DIR && cd $PACKAGE_DIR
    tar -xvf libfastcommon-${LIBFASTCOMMON_VER}.tar.gz -C $SOURCE_DIR
    tar -xvf fastdfs-${FASTDFS_VER}.tar.gz -C $SOURCE_DIR
    
    # 编译安装 libfastcommon
    cd $SOURCE_DIR/libfastcommon-${LIBFASTCOMMON_VER}
    ./make.sh && ./make.sh install
    
    #编译安装 fastdfs
    cd $SOURCE_DIR/fastdfs-${FASTDFS_VER}
    ./make.sh && ./make.sh install
    /usr/bin/cp $SOURCE_DIR/fastdfs-${FASTDFS_VER}/conf/http.conf  /etc/fdfs/
    /usr/bin/cp $SOURCE_DIR/fastdfs-${FASTDFS_VER}/conf/mime.types /etc/fdfs/
}

CONFIG_TRACKER(){
    mkdir -p $TRACKER_DIR
    /usr/bin/cp -a /etc/fdfs/tracker.conf.sample /etc/fdfs/tracker.conf
    sed -i "s#store_group=.*#store_group=group1#" /etc/fdfs/tracker.conf
    sed -i "s#base_path=.*#base_path=$TRACKER_DIR#" /etc/fdfs/tracker.conf
    
    # 创建服务管理脚本
    cat > /usr/lib/systemd/system/fdfs_trackerd.service <<EOF
[Unit]
Description=The FastDFS File server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=$TRACKER_DIR/data/fdfs_trackerd.pid
ExecStart=/usr/bin/fdfs_trackerd /etc/fdfs/tracker.conf start
ExecReload=/usr/bin/fdfs_trackerd /etc/fdfs/tracker.conf restart
ExecStop=/usr/bin/fdfs_trackerd /etc/fdfs/tracker.conf stop

[Install]
WantedBy=multi-user.target
EOF

    # 启动 fdfs_trackerd 服务, 跟随系统启动
    systemctl daemon-reload
    systemctl enable fdfs_trackerd.service
    systemctl start fdfs_trackerd.service
    systemctl status fdfs_trackerd.service
}

CONFIG_STORAGE(){
    mkdir -p $STORAGE_DIR
    /usr/bin/cp -a /etc/fdfs/storage.conf.sample /etc/fdfs/storage.conf
    sed -i "s#base_path=.*#base_path=$STORAGE_DIR#" /etc/fdfs/storage.conf
    sed -i "s#store_path0=.*#store_path0=$STORAGE_DIR#" /etc/fdfs/storage.conf
    sed -i "/tracker_server=/d" /etc/fdfs/storage.conf
    for node in $TRACKER_SERVER; do
        sed -i "113a tracker_server=${node}:22122" /etc/fdfs/storage.conf
    done

    # 创建服务管理脚本
    cat > /usr/lib/systemd/system/fdfs_storaged.service <<EOF
[Unit]
Description=The FastDFS File server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=$STORAGE_DIR/data/fdfs_storaged.pid
ExecStart=/usr/bin/fdfs_storaged /etc/fdfs/storage.conf start
ExecReload=/usr/bin/fdfs_storaged /etc/fdfs/storage.conf restart
ExecStop=/usr/bin/fdfs_storaged /etc/fdfs/storage.conf stop

[Install]
WantedBy=multi-user.target
EOF

    # 启动 fdfs_storaged 服务, 跟随系统启动
    systemctl daemon-reload
    systemctl enable fdfs_storaged.service
    systemctl start fdfs_storaged.service
    systemctl status fdfs_storaged.service
}

CONFIG_CLIENT(){
    mkdir -p $STORAGE_DIR
    /usr/bin/cp -a /etc/fdfs/client.conf.sample /etc/fdfs/client.conf
    sed -i "s#base_path=.*#base_path=$STORAGE_DIR#" /etc/fdfs/client.conf
    sed -i "/tracker_server=/d" /etc/fdfs/client.conf
        for node in $TRACKER_SERVER; do
        sed -i "13a tracker_server=${node}:22122" /etc/fdfs/client.conf
    done
}

INSTALL_NGINX(){
    # 安装依赖环境
    yum install -y pcre pcre-devel zlib zlib-devel openssl openssl-devel
    
    # 下载解压软件
    cd $PACKAGE_DIR
    tar -zxf nginx-${NGINX_VER}.tar.gz -C $SOURCE_DIR
    tar -zxf fastdfs-nginx-module-${FASTDFS_NGINX_MODULE_VER}.tar.gz -C $SOURCE_DIR
    
    # 编译安装
    cd $SOURCE_DIR/nginx-${NGINX_VER}
    export C_INCLUDE_PATH=/usr/include/fastcommon
    ./configure --prefix=/usr/local/nginx --add-module=$SOURCE_DIR/fastdfs-nginx-module-${FASTDFS_NGINX_MODULE_VER}/src
    make && make install
    
    # 配置
    /usr/bin/cp $SOURCE_DIR/fastdfs-nginx-module-${FASTDFS_NGINX_MODULE_VER}/src/mod_fastdfs.conf /etc/fdfs/
    sed -i "/tracker_server=/d" /etc/fdfs/mod_fastdfs.conf
    sed -i "s#base_path=.*#base_path=$STORAGE_DIR#" /etc/fdfs/mod_fastdfs.conf
    sed -i "s#store_path0=.*#store_path0=$STORAGE_DIR#" /etc/fdfs/mod_fastdfs.conf
    sed -i "s#url_have_group_name = .*#url_have_group_name = true#" /etc/fdfs/mod_fastdfs.conf
    
    sed -i "s#group_count =.*#group_count = 1#" /etc/fdfs/mod_fastdfs.conf
    for node in $TRACKER_SERVER; do
        sed -i "39a tracker_server=${node}:22122" /etc/fdfs/mod_fastdfs.conf
    done

    # nginx
    cat <<'EOF'  > /usr/local/nginx/conf/nginx.conf
worker_processes  4;

events {
    worker_connections  65535;
    use epoll;
}

http {
    include            mime.types;
    default_type       application/octet-stream;
    sendfile           on;
    keepalive_timeout  65;
    server {
        listen       8888;
        server_name  localhost;

        location / {
            root   html;
            index  index.html index.htm;
        }

        location ~ /group1/M00 {
            ngx_fastdfs_module;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;   
        }
    }

    include /usr/local/nginx/conf.d/*.conf;
}
EOF

    echo -e "\n[group1]\ngroup_name=group1\nstorage_server_port=23000\nstore_path_count=1\nstore_path0=$STORAGE_DIR" >>/etc/fdfs/mod_fastdfs.conf


    # nginx proxy 8888
    confile='/usr/local/nginx/conf.d/dfs_proxy.conf'
    mkdir -p /usr/local/nginx/conf.d
    echo 'upstream fdfs_group1 {' > $confile
    for node in $STORAGE_SERVER;do
        echo -e "    server ${node}:8888 weight=2 max_fails=2 fail_timeout=30s;" >> $confile
    done
    echo '}' >> $confile
    echo 'server {' >> $confile
    echo "    listen       80;" >> $confile
    echo "    server_name  localhost;" >> $confile
    echo '' >> $confile
    echo 'location / {' >> $confile
    echo '    proxy_pass http://fdfs_group1;' >> $confile
    echo '}' >> $confile
    echo '' >> $confile
    echo '    location ~ /group1/M00 {' >> $confile
    echo '        proxy_pass http://fdfs_group1;' >> $confile
    echo '    }' >> $confile
    echo "    error_log    $NGINX_LOGS/error_dfs_proxy.log;" >> $confile
    echo "    access_log   $NGINX_LOGS/access_dfs_proxy.log;" >> $confile
    echo '}' >> $confile
    echo "<h1>$HOSTNAME $(hostname -I)</h1>" > /usr/local/nginx/html/index.html

    # 配置环境变量
    config=/etc/profile.d/nginx.sh
    echo '#!/bin/bash' > $config
    echo "export NGINX_HOME=/usr/local/nginx" >> $config
    echo 'export PATH=$NGINX_HOME/sbin:$PATH' >> $config

    # 读取环境变量
    chmod +x $config
    source $config

    # 启动nginx
    /usr/local/nginx/sbin/nginx
    echo '/usr/local/nginx/sbin/nginx' >> /etc/rc.d/rc.local
    chmod +x /etc/rc.d/rc.local
}

INSTALL_KEEPALIVED(){
    # install keepelived
    yum install -y keepalived

    # 配置keepalived
    if [ "`hostname`" == "$KEEP_MASTER" ]; then
        ROLE='MASTER'
        PRIORITY=100
        WEIGHT='-40'
    else
        ROLE='BACKUP'
        PRIORITY=90
        WEIGHT='2'
    fi
    ID="$(echo $LOCAL_IP | awk -F '.' '{print $NF}')"
    cat > /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived

global_defs {
   router_id $ID
   script_user root
   enable_script_security
}

vrrp_script nginx {
    script "/etc/keepalived/check_nginx.sh"
    interval 2
    weight $WEIGHT
}

vrrp_instance VI_1 {
    state $ROLE
    interface eth0
    virtual_router_id 110
    priority $PRIORITY
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass zxdr5few
    }

    virtual_ipaddress {
        $KEEP_VIP
    }
    
    track_script {
        nginx
    }
}
EOF

    # 创建检测脚本
    cat > /etc/keepalived/check_nginx.sh   <<'EOF'
#!/bin/sh
A=`ps -C nginx --no-header |wc -l`
if [ $A -eq 0 ]
then
    exit 1
fi
EOF
    chmod +x /etc/keepalived/check_nginx.sh

    # 服务管理
    systemctl restart keepalived
    systemctl enable keepalived
    systemctl status keepalived
}

# 初始化 opentsdb 脚本
INIT_OPENTSDB(){
    cat <<EEOF   > init-opentsdb.sh
#!/bin/bash

source /etc/profile

# start hbase
/home/hadoop/hbase-${HBASE_VER}/bin/start-hbase.sh

# copy 创建 opentsdb 表文件到当前节点
sleep 15
scp -P $PORT $(echo $TSDB_SERVER | awk '{print $1}'):/usr/share/opentsdb/tools/create_table.sh /tmp/create_table.sh
sed -i 's#\$TSDB_TTL#2147483647#' /tmp/create_table.sh

# 导入 opentsdb 表
env COMPRESSION=none HBASE_HOME=/home/hadoop/hbase-${HBASE_VER} /tmp/create_table.sh

sleep 25
# 启动 opentsdb
for node in $TSDB_SERVER; do
    ssh -p $PORT -T \$node "tsdb tsd --config=/etc/opentsdb/opentsdb.conf > /dev/null 2>&1 &"
done

# 启动 kafka
for node in $KAFKA_SERVER; do
    ssh -p $PORT -T \$node kafka-server-start.sh -daemon /home/hadoop/kafka_${KAFKA_VER}/config/server.properties
done

# 启动 apache-storm
/home/hadoop/apache-storm-${STORM_VER}/bin/start-all.sh


cat <<EOF

 # 测试fastdfs
    a.查看集群状态
    fdfs_monitor /etc/fdfs/client.conf | egrep 'ip_addr|tracker'

    b.上传测试
    fdfs_test /etc/fdfs/client.conf upload /usr/local/src/fastdfs-${FASTDFS_VER}/conf/anti-steal.jpg
EOF
EEOF
}

# 服务管理脚本
SERVER_MANAGE_SCRIPT(){
    cat <<EEOF    > /usr/local/bin/mango
#!/bin/bash

ARG=\$1

START(){
    echo "----> start zookeeper"
    ssh -p $PORT -T `hostname` "${SOFT_INSTALL_DIR}/zookeeper-${ZOOKEEPER_VER}/bin/zk.sh start"

    sleep 5
    echo "----> start hadoop"
    ssh -p $PORT -T `hostname` "${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/sbin/start-all.sh"

    sleep 5
    echo "----> start hbase"
    ssh -p $PORT -T ${HBASE_MASTER} "${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}/bin/start-hbase.sh"

    sleep 5
    echo "----> start kafka"
    for node in $KAFKA_SERVER; do
        echo "--> \$node"
        ssh -p $PORT -T \$node kafka-server-start.sh -daemon $SOFT_INSTALL_DIR/kafka_${KAFKA_VER}/config/server.properties
    done

    sleep 10
    echo "----> start storm"
    ssh -p $PORT -T ${STORM_MASTER} "${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}/bin/start-all.sh"

    sleep 15
    echo "----> start opentsdb"
    for node in $TSDB_SERVER; do
        echo "--> \$node"
        ssh -p $PORT -T \$node "tsdb tsd --config=/etc/opentsdb/opentsdb.conf > /dev/null 2>&1 &"
    done
}

STOP(){
    echo "----> stop opentsdb"
    for node in $TSDB_SERVER; do
        echo "--> \$node"
        ssh -p $PORT -T \$node "jps | grep TSDMain | awk '{print \\\$1}' | xargs kill > /dev/null 2>&1"
    done

    echo "----> stop storm"
    ssh -p $PORT -T ${STORM_MASTER} "${SOFT_INSTALL_DIR}/apache-storm-${STORM_VER}/bin/stop-all.sh"

    sleep 5
    echo "----> stop hbase"
    ssh -p $PORT -T ${HBASE_MASTER} "${SOFT_INSTALL_DIR}/hbase-${HBASE_VER}/bin/stop-hbase.sh"

    sleep 5
    echo "----> stop hadoop"
    # ssh -p $PORT -T ${STORM_MASTER} "${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/sbin/stop-all.sh"
    ssh -p $PORT -T ${STORM_MASTER} "${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/sbin/stop-dfs.sh"
    ssh -p $PORT -T ${STORM_MASTER} "${SOFT_INSTALL_DIR}/hadoop-${HADOOP_VER}/sbin/stop-yarn.sh"

    sleep 5
    echo "----> stop kafka"
    for node in $KAFKA_SERVER; do
        echo "--> \$node"
        ssh -p $PORT -T \$node "${SOFT_INSTALL_DIR}/kafka_${KAFKA_VER}/bin/kafka-server-stop.sh"
    done

    sleep 5
    echo "----> stop zookeeper"
    ssh -p $PORT -T `hostname` "${SOFT_INSTALL_DIR}/zookeeper-${ZOOKEEPER_VER}/bin/zk.sh stop"
}

INFO(){
    echo -e "\n\tUSAGE: \$0 {start|stop}\n"
}

case "\$ARG" in
    start) START ;;
    stop) STOP ;;
    *) INFO ;;
esac
EEOF

    chmod +x /usr/local/bin/mango
}

# 初始化信息
INIT_INFO(){
cat <<EOF

----------------------------------------- 初始化命令 -----------------------------------------

 1.初始化 hadoop
    # 脚本功能启动zookeeper 初始化 hadoop 集群
    source /etc/profile
    sh $PACKAGE_DIR/init-hadoop.sh

 2.初始化 opentsdb
    # 脚本功能启动 hbase, opentsdb, kafka, storm
    source /etc/profile
    sh $PACKAGE_DIR/init-opentsdb.sh


 3.测试fastdfs
    a.查看集群状态
    fdfs_monitor /etc/fdfs/client.conf | egrep 'ip_addr|tracker'

    b.上传测试
    fdfs_test /etc/fdfs/client.conf upload /usr/local/src/fastdfs-5.11/conf/anti-steal.jpg

 4.服务管理
    mango stop     # 关闭服务
    mango start    # 启动服务

-----------------------------------------------------------------------------------------------

EOF
}

# 初始化
if [ "$(echo ${SERVERS[@]} | grep $LOCAL_IP)" ]; then
    PREP
fi

# 安装 JDK
jdk_list="$NameNode $DataNode $HBASE_MASTER $HBASE_SLAVE $TSDB_SERVER $KAFKA_SERVER $STORM_MASTER $STORM_SLAVE"
if [ "$(echo $jdk_list | grep `hostname`)" ]; then
    INSTALL_JDK
fi

# 安装 zookeeper
if [ "$(echo $ZOO_SERVER | grep `hostname`)" ]; then
    INSTALL_ZOOKEEPER
fi

# 安装 hadoop(判断数组变量小于5使用3节点模板配置)
if [ "$(echo $NameNode $DataNode | grep `hostname`)" ]; then
    if [ ${#SERVERS[@]} -lt 5 ]; then
        INSTALL_HADOOP_3
    else
        INSTALL_HADOOP_5
    fi
fi

# 安装 hbase
if [ "$(echo $HBASE_MASTER $HBASE_SLAVE | grep `hostname`)" ]; then
    if [ ${#SERVERS[@]} -lt 5 ]; then
        INSTALL_HBASE_3
    else
        INSTALL_HBASE_5
    fi
fi

# 安装 opentsdb
if [ "$(echo $TSDB_SERVER | grep `hostname`)" ]; then
    INSTALL_TSDB
fi

# 安装 kafka
if [ "$(echo $KAFKA_SERVER | grep `hostname`)" ]; then
    INSTALL_KAFKA
fi

# 安装 storm
if [ "$(echo $STORM_MASTER $STORM_SLAVE | grep `hostname`)" ]; then
    INSTALL_STORM
fi

# 安装 fastdfs
if [ "$(echo $TRACKER_SERVER $STORAGE_SERVER | grep `hostname`)" ]; then
    # 安装fastdfs
    INSTALL_FASTDFS

    # 配置客户端
    CONFIG_CLIENT
fi

# 配置 tracker
if [ "$(echo $TRACKER_SERVER | grep `hostname`)" ]; then
    CONFIG_TRACKER
fi

# 配置sotrage
if [ "$(echo $STORAGE_SERVER | grep `hostname`)" ]; then
    CONFIG_STORAGE

    # 安装 nginx
    INSTALL_NGINX

    # 安装 keepalived
    INSTALL_KEEPALIVED
fi

# NameNode 节点执行
if [ "$(echo $NameNode | grep `hostname`)" ]; then
    # 秘钥登录
    HOST_LIST="${HOSTS[@]}"
    SERVER_LIST="${SERVERS[@]}"
    cd $PACKAGE_DIR
    ./ssh-key-copy.sh "$HOST_LIST $SERVER_LIST" $USER $PASS $PORT
    
    # zookeeper 服务管理脚本
    ZOOKEEPER_SERVICE_SCRIPT

    # hadoop 初始化脚本
    if [ ${#SERVERS[@]} -lt 5 ]; then
        INIT_HADOOP_3
    else
        INIT_HADOOP_5
    fi

    # 服务管理脚本( mango stop/start)
    SERVER_MANAGE_SCRIPT
    
    # opentsdb 初始化脚本
    INIT_OPENTSDB
fi

if [ "$(echo $NameNode | awk '{print $1}')" == `hostname` ]; then
    INIT_INFO
fi
