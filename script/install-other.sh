#!/bin/bash

# 下载的软件包路径
PACKAGE_DIR=/home/software

# 需要编译的软件解压路径
SOURCE_DIR=/usr/local/src

# 输出颜色
CGREEN='\E[1;32m'
CCYAN='\E[1;36m'
CEND='\E[0m'

# 获取 eth0 网卡 ip
LOCAL_IP=$(nmcli device show eth0 | grep IP4.ADDRESS | awk '{print $NF}' | cut -d '/' -f1 | head -n1)

# 功能列表
METHOD=(INSTALL_MYSQL INSTALL_MONGODB INSTALL_EMQTT INSTALL_NODE INSTALL_REDIS INSTALL_JDK INSTALL_TOMCAT INSTALL_HAZECAST MYSQL_BACKUP)

CHOICE(){
    clear
    echo -e """$CGREEN
-------------------------- info --------------------------

    当前服务器IP：$LOCAL_IP
      选择的服务：${METHOD[ARG]}

----------------------------------------------------------
$CEND
"""

    # 确认操作
    echo -e "$CGREEN 确认请输入[Y]: $CEND \c"
    read choice
    [ "$choice" != 'Y' ] && { echo -e "$CCYAN \n\t取消/退出...\n $CEND"; exit 1; }

    # 初始化
    PREP
}

# 初始化
PREP(){
    # 优化ssh连接速度
    sed -i "s/#UseDNS yes/UseDNS no/" /etc/ssh/sshd_config
    sed -i "s/GSSAPIAuthentication .*/GSSAPIAuthentication no/" /etc/ssh/sshd_config
    systemctl restart sshd

    # selinux
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
    yum install -y wget net-tools
}

CONF_FIREWALLD(){
    list="$1"
    for port in $list; do
        echo -e "$CGREEN -------------------- Allow Port $port -------------------- $CEND"
        firewall-cmd --zone=public --add-port=$port/tcp --permanent     # 永久生效允许 XXX 端口
        firewall-cmd --reload                                           # 重新载入防火墙配置
        firewall-cmd --zone=public --query-port=$port/tcp               # 查看 XXX 端口是否允许
        firewall-cmd --zone=public --list-ports
        sleep 3
    done
}

INSTALL_MYSQL(){
    CHOICE

    # 创建 Mysql 安装源
    cat <<EOF   > /etc/yum.repos.d/mysql-community.repo 
[mysql-connectors-community]
name=MySQL Connectors Community
baseurl=https://mirrors.tuna.tsinghua.edu.cn/mysql/yum/mysql-connectors-community-el7/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql

[mysql-tools-community]
name=MySQL Tools Community
baseurl=https://mirrors.tuna.tsinghua.edu.cn/mysql/yum/mysql-tools-community-el7/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql

# Enable to use MySQL 5.5
[mysql55-community]
name=MySQL 5.5 Community Server
baseurl=http://repo.mysql.com/yum/mysql-5.5-community/el/7/$basearch/
enabled=0
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql

# Enable to use MySQL 5.6
[mysql56-community]
name=MySQL 5.6 Community Server
baseurl=https://mirrors.tuna.tsinghua.edu.cn/mysql/yum/mysql56-community-el7/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql

[mysql57-community]
name=MySQL 5.7 Community Server
baseurl=https://mirrors.tuna.tsinghua.edu.cn/mysql/yum/mysql57-community-el7/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql

[mysql80-community]
name=MySQL 8.0 Community Server
baseurl=https://mirrors.tuna.tsinghua.edu.cn/mysql/yum/mysql80-community-el7/
enabled=0
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql
EOF

    # 安装 MySql-5.7
    yum install -y mysql-community-server

    # 启动 MySql 服务,跟随系统启动
    systemctl start mysqld
    systemctl enable mysqld

    # 创建自动初始化脚本
    yum install -y expect
    cat > mysql_secure_installation.exp  <<'EOF'
#!/usr/bin/expect
set timeout 10
set oldpass [lindex $argv 0]
set newpass [lindex $argv 1]
spawn bash -c "mysql_secure_installation"
expect "Enter password for user root: "
    send "$oldpass\n"
expect "New password: "
    send "$newpass\n"
expect "Re-enter new password: "
    send "$newpass\n"
expect "Change the password for root ? ((Press y|Y for Yes, any other key for No) : "
    send "Y\n"
expect "New password: "
    send "$newpass\n"
expect "Re-enter new password: "
    send "$newpass\n"
expect "Do you wish to continue with the password provided?(Press y|Y for Yes, any other key for No) : "
    send "Y\n"
expect "Remove anonymous users? (Press y|Y for Yes, any other key for No) : "
    send "Y\n"
expect "Disallow root login remotely? (Press y|Y for Yes, any other key for No) : "
    send "Y\n"
expect "Remove test database and access to it? (Press y|Y for Yes, any other key for No) : "
    send "Y\n"
expect "Reload privilege tables now? (Press y|Y for Yes, any other key for No) : "
    send "Y\n"
    send "\n"
    send "exit"
    send "\n"
expect eof
EOF

    # 自动初始化MySql,更改密码
    NEW_PASS=zaq1@WSX
    OLD_PASS=$(grep "temporary password" /var/log/mysqld.log|awk '{ print $11}'| tail -n1)
    chmod +x mysql_secure_installation.exp
    ./mysql_secure_installation.exp $OLD_PASS $NEW_PASS

    # 启用root远程登录
    mysql -uroot -p$NEW_PASS --connect-expired-password -e "grant all on *.* to 'root'@'%' identified by  '$NEW_PASS' with grant option;"

    # 更改数据存储路径
    systemctl stop mysqld
    mv /etc/my.cnf /etc/my.cnf.default
    mkdir -p /home/hadoop
    mv /var/lib/mysql /home/hadoop/mysql

    # 以本机IP最后一段为MySqlID
    ID=$(echo $LOCAL_IP | awk -F '.' '{print $NF}')

    # 创建配置文件
    cat <<EOF > /etc/my.cnf
[mysqld]
server-id=$ID
datadir=/home/hadoop/mysql
socket=/home/hadoop/mysql/mysql.sock
character-set-server=utf8
symbolic-links=0
max_connections=50000
wait_timeout=30000
interactive_timeout=30000
lower_case_table_names=1
sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
default-storage-engine=INNODB
symbolic-links=0
log-error=/var/log/mysqld.log
explicit_defaults_for_timestamp=true
pid-file=/var/run/mysqld/mysqld.pid
# 启用/关闭binlog日志
# log-bin=/home/hadoop/mysql/mysql-bin/binlog
# log_bin_trust_function_creators=1
# 此参数表示binlog日志保留的时间，默认单位是天。
# expire_logs_days=7

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
socket=/home/hadoop/mysql/mysql.sock

[mysqld.server]
character-set-server=utf8
socket=/home/hadoop/mysql/mysql.sock

[mysqld.safe]
character-set-server=utf8
socket=/home/hadoop/mysql/mysql.sock

[mysql]
# default-character-set=utf8
socket=/home/hadoop/mysql/mysql.sock

[mysql.server]
# default-character-set=utf8
socket=/home/hadoop/mysql/mysql.sock

[client]
default-character-set=utf8
socket=/home/hadoop/mysql/mysql.sock
EOF

    # 创建二进制日志目录,更改数据目录权限,重启MySql服务
    mkdir -p /home/hadoop/mysql/mysql-bin
    chown mysql:mysql -R /home/hadoop/mysql
    systemctl restart mysqld

    # 配置防火墙
    CONF_FIREWALLD "3306"
}

INSTALL_MONGODB(){
    CHOICE
    # 创建安装源
    cat <<EOF > /etc/yum.repos.d/mongodb-org.repo
[mongodb-org]
[mongodb-org]
name=MongoDB Repository
baseurl=http://mirrors.aliyun.com/mongodb/yum/redhat/7Server/mongodb-org/3.6/x86_64/
gpgcheck=0
enabled=1
EOF

    # 更新yum缓存,安装mongodb
    yum -y makecache fast
    yum install -y mongodb-org

    # 更改监听IP, 更改数据存储路径
    mkdir -p /home/hadoop/mongo
    sed -i "s/bindIp: 127.0.0.1/bindIp: 0.0.0.0/g" /etc/mongod.conf
    sed -i "s#dbPath:.*#dbPath: /home/hadoop/mongo#" /etc/mongod.conf
    chown mongod.mongod -R /home/hadoop/mongo
    
    # 启动服务&&跟随系统启动
    systemctl start mongod
    systemctl enable mongod
    systemctl restart mongod

    # 配置防火墙
    CONF_FIREWALLD "27017"
}

INSTALL_EMQTT(){
    CHOICE
    yum install -y unzip
    mkdir -p $PACKAGE_DIR && cd $PACKAGE_DIR
    wget -c http://kaifa.hc-yun.com:30027/base/software/emqttd-centos7-v2.3.11.zip
    unzip emqttd-centos7-v2.3.11.zip -d /usr/local
    sed -i "s#node.name = emq@.*#node.name = emq@$LOCAL_IP#" /usr/local/emqttd/etc/emq.conf

    # 防火墙
    CONF_FIREWALLD "4369 8080 8083 8084 18083 6369 4369"

    # 创建服务管理脚本
    cat > /usr/lib/systemd/system/emqtt.service  <<EOF
[Unit]
Description=emqx enterprise
After=network.target

[Service]
Type=forking
Environment=HOME=/root
ExecStart=/bin/sh /usr/local/emqttd/bin/emqttd start
LimitNOFILE=1048576
ExecStop=/bin/sh /usr/local/emqttd/bin/emqttd stop

[Install]
WantedBy=multi-user.target
EOF

    # 启动服务,跟随系统启动
    systemctl start emqtt
    systemctl enable emqtt
}

INSTALL_NODE(){
    CHOICE
    mkdir -p $PACKAGE_DIR && cd $PACKAGE_DIR
    wget -c http://kaifa.hc-yun.com:30027/base/software/node-v9.0.0-linux-x64.tar.gz
    tar xzf node-v9.0.0-linux-x64.tar.gz
    mv node-v9.0.0-linux-x64 /usr/local/nodejs
    ln -s /usr/local/nodejs/bin/npm /usr/local/bin/
    ln -s /usr/local/nodejs/bin/node /usr/local/bin/
}

INSTALL_REDIS(){
    CHOICE

    # 安装gcc
    yum install -y gcc

    # 下载,编译安装redis
    mkdir -p $PACKAGE_DIR && cd $PACKAGE_DIR
    wget -c http://kaifa.hc-yun.com:30027/base/software/redis-4.0.10.tar.gz
    tar xzf redis-4.0.10.tar.gz -C $SOURCE_DIR
    cd $SOURCE_DIR/redis-*
    make MALLOC=libc && cd src
    make install PREFIX=/usr/local/redis

    # 优化参数
    if [ ! "$(cat /etc/sysctl.conf | grep '# redis')" ]; then
        echo -e "\n# redis" >> /etc/sysctl.conf
        echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
        echo 'net.core.somaxconn= 1024' >> /etc/sysctl.conf
        sysctl -p
        
        echo -e "\n# redis\necho never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.d/rc.local
        chmod +x  /etc/rc.d/rc.local
        echo never > /sys/kernel/mm/transparent_hugepage/enabled
    fi

    # 配置redis
    mkdir -p /usr/local/redis/etc
    /usr/bin/cp ../redis.conf /usr/local/redis/etc
    sed -i "s/bind 127.0.0.1/bind $LOCAL_IP/" /usr/local/redis/etc/redis.conf
    sed -i 's#^dir.*#dir /var/lib/redis#' /usr/local/redis/etc/redis.conf

    # 创建服务用户
    groupadd -g 995 redis
    useradd -r -g redis -u 997 -s /sbin/nologin redis

    # 创建数据目录
    mkdir /var/lib/redis
    chown -Rf redis:redis /var/lib/redis

    # 创建服务关闭脚本
    cat > /usr/local/redis/bin/redis-shutdown  <<'EOF'
#!/bin/bash
#
# Wrapper to close properly redis and sentinel
test x"$REDIS_DEBUG" != x && set -x

REDIS_CLI=/usr/local/redis/bin/redis-cli

# Retrieve service name
SERVICE_NAME="$1"
if [ -z "$SERVICE_NAME" ]; then
   SERVICE_NAME=redis
fi

# Get the proper config file based on service name
CONFIG_FILE="/usr/local/redis/etc/$SERVICE_NAME.conf"

# Use awk to retrieve host, port from config file
HOST=`awk '/^[[:blank:]]*bind/ { print $2 }' $CONFIG_FILE | tail -n1`
PORT=`awk '/^[[:blank:]]*port/ { print $2 }' $CONFIG_FILE | tail -n1`
PASS=`awk '/^[[:blank:]]*requirepass/ { print $2 }' $CONFIG_FILE | tail -n1`
SOCK=`awk '/^[[:blank:]]*unixsocket\s/ { print $2 }' $CONFIG_FILE | tail -n1`

# Just in case, use default host, port
HOST=${HOST:-127.0.0.1}
if [ "$SERVICE_NAME" = redis ]; then
    PORT=${PORT:-6379}
else
    PORT=${PORT:-26739}
fi

# Setup additional parameters
# e.g password-protected redis instances
[ -z "$PASS"  ] || ADDITIONAL_PARAMS="-a $PASS"

# shutdown the service properly
if [ -e "$SOCK" ] ; then
	$REDIS_CLI -s $SOCK $ADDITIONAL_PARAMS shutdown
else
	$REDIS_CLI -h $HOST -p $PORT $ADDITIONAL_PARAMS shutdown
fi
EOF

    chmod +x /usr/local/redis/bin/redis-shutdown
 
    cat > /usr/lib/systemd/system/redis.service <<'EOF'
[Unit]
Description=Redis persistent key-value database
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/redis/bin/redis-server /usr/local/redis/etc/redis.conf --supervised systemd
ExecStop=/usr/local/redis/bin/redis-shutdown
Type=notify
User=redis
Group=redis
RuntimeDirectory=redis
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF

    # 配置防火墙
    CONF_FIREWALLD "6379"

    # 启动服务,跟随系统启动
    systemctl start redis
    systemctl enable redis
}

# 安装JDK
INSTALL_JDK(){
    CHOICE
    mkdir -p /usr/java/ $PACKAGE_DIR && cd $PACKAGE_DIR
    wget -c http://kaifa.hc-yun.com:30027/base/software/jdk-8u211-linux-x64.tar.gz
    tar zxf jdk-8u211-linux-x64.tar.gz -C /usr/java/

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

INSTALL_TOMCAT(){
    CHOICE

    source /etc/profile

    # 判断是否安装了JDK
    test $JAVA_HOME
    if [ $? -ne 0 ]; then
        echo -e "$CCYAN \n\t请检查是否安装了JDK...\n $CEND"
        exit 1
    fi

    # 下载解压tomcat
    mkdir -p $PACKAGE_DIR && cd $PACKAGE_DIR
    wget -c https://mirrors.tuna.tsinghua.edu.cn/apache/tomcat/tomcat-9/v9.0.20/bin/apache-tomcat-9.0.20.tar.gz
    tar xzf apache-tomcat-9.0.20.tar.gz
    mv apache-tomcat-9.0.20 /usr/local/tomcat9

    # 创建服务用户
    groupadd -g 53 tomcat
    useradd -r -g tomcat -u 53 -s /sbin/nologin tomcat

    # 创建服务管理脚本
    cat >/usr/lib/systemd/system/tomcat.service  <<EOF
[Unit]
Description=tomcat9
After=network.target
# Wants=jms.service   # 依赖的服务

[Service]
Type=forking
# PIDFile=/usr/local/tomcat9/tomcat.pid
ExecStart=/usr/local/tomcat9/bin/startup.sh
Environment="JAVA_HOME=$JAVA_HOME" "JRE_HOME=$JRE_HOME"
ExecStop=/usr/local/tomcat9/bin/shutdown.sh
# User=tomcat

[Install]
WantedBy=multi-user.target
EOF

    # 配置日志
    cat > /etc/logrotate.d/tomcat <<EOF
/usr/local/tomcat9/logs/catalina.out
{
    copytruncate
    daily
    rotate 7
    missingok
    notifempty
    compress
    create 0644 root root
}
EOF

    # 配置防火墙
    CONF_FIREWALLD "8080"

    # 启动服务,跟随系统启动
    systemctl start tomcat
    systemctl enable tomcat
}

INSTALL_HAZECAST(){
    CHOICE

    source /etc/profile

    # 判断是否安装了JDK
    test $JAVA_HOME
    if [ $? -ne 0 ]; then
        echo -e "$CCYAN \n\t请检查是否安装了JDK...\n $CEND"
        exit 1
    fi

    # 下载解压
    wget -c http://kaifa.hc-yun.com:30027/base/software/hazelcast-3.9.1.tar.gz
    tar xf hazelcast-3.9.1.tar.gz
    
    # 设置分组名     
    sed -i 's#mango-dev#mango-prod#' hazelcast/bin/hazelcast.xml
    
    # 配置管理地址
    sed -i 's#<management-center.*#<\!-- & -->#' hazelcast/bin/hazelcast.xml
    sed -i '/<management-center.*/a\    <management-center enabled="true">http://localhost:9099/hazelcast-mancenter</management-center>' hazelcast/bin/hazelcast.xml
    chmod +x hazelcast/bin/*.sh
    
    # 复制3份
    mkdir /usr/local/hazelcast
    cp -a hazelcast /usr/local/hazelcast/haze1
    cp -a hazelcast /usr/local/hazelcast/haze2
    mv hazelcast /usr/local/hazelcast/haze3

    # 创建服务启动/关闭脚本
    cat > /usr/local/hazelcast/service.sh <<'EOF'
#!/bin/bash

ARG=$1

BASE_DIR=$(cd "`dirname $0`"; pwd)
cd $BASE_DIR

for i in 1 2 3; do
    sh haze${i}/bin/${ARG}.sh
done
EOF

    chmod +x /usr/local/hazelcast/service.sh

    # 创建服务管理脚本
    cat > /usr/lib/systemd/system/haze.service <<EOF
[Unit]
Description=hazelcast
After=network.target
# Wants=jms.service   # 依赖的服务

[Service]
Type=forking
# PIDFile=/usr/local/tomcat9/tomcat.pid
ExecStart=/usr/local/hazelcast/service.sh start
Environment="JAVA_HOME=$JAVA_HOME" "JRE_HOME=$JRE_HOME"
ExecStop=/usr/local/hazelcast/service.sh stop

[Install]
WantedBy=multi-user.target
EOF

    # 配置防火墙
    CONF_FIREWALLD "5701 5702 5703"


    # 启动服务,跟随系统启动
    systemctl daemon-reload
    systemctl enable haze
    systemctl restart haze
}

BACKUP_MYSQL(){
    echo -e "$CGREEN 请输入 MYSQL ROOT 密码: $CEND \c"
    read -s MYSQL_ROOT_PASS
    MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS:-zaq1@WSX}

    echo -e "$CGREEN 请输入 RSYNC 服务器IP: $CEND \c"
    read RSYNC_SERVER_IP
    if [ ! -n "$RSYNC_SERVER_IP" ]; then
        echo -e "$CCYAN \n\tRSYNC 服务器 IP 不能为空...\n $CEND"
        exit 1
    fi

    # 创建备份用户
    mysql -uroot -p$MYSQL_ROOT_PASS -e "
      create user dumper@'127.0.0.1' identified by 'rO.fWIEU0I';
      grant select on *.* to dumper@'127.0.0.1';
      grant show view on *.* to dumper@'127.0.0.1';
      grant lock tables on *.* to dumper@'127.0.0.1';
      grant trigger on *.* to dumper@'127.0.0.1';"
    if [ $? -ne 0 ]; then
        echo -e "$CCYAN \n\tMYSQL ROOT 密码错误...\n $CEND"
        exit 1
    fi

    # 将备份用户密码写入配置文件实现免密码
    echo """
[mysqldump]
user = dumper
password = 'rO.fWIEU0I'
""" >>/etc/my.cnf

    # 安装rsync,创建本地目录
    yum install -y rsync
    mkdir -p /home/backup /script

    # 创建备份脚本
    cat >/script/backup_mysql.sh <<'EOF'
#!/usr/bin/bash

# 数据库备份脚本
# 远程备份保留一周
# 日期: 2019-06-18
# 版本: V2

# 定义变量
mysqldump='/usr/bin/mysqldump'
bakdir='/home/backup'
remote_dir='rsync://dumper@RSYNC_SERVER_IP/backupmysql'
pass_file='/etc/rsync.password'
d1=$(date +%F)
WEEK_DAY=$(date +%w)

# 定义日志
exec &> /tmp/mysql_bak.log
echo "mysql backup begin at `date`"

# 备份所有数据库 
$mysqldump -h 127.0.0.1 --all-databases > $bakdir/mysql-backup-all-$d1.sql

# 压缩所有sql文件
gzip $bakdir/mysql-backup-all-$d1.sql

# 把当天的备份文件同步到远程(如果同步成功则删除本地，如果失败则重命名备份文件)
rsync -a --password-file=$pass_file $bakdir/mysql-backup-all-$d1.sql.gz $remote_dir/mysql-backup-all-$WEEK_DAY.sql.gz
ARG=$?
if [ $ARG -eq 0 ]; then
    rm -f $bakdir/mysql-backup-all-$d1.sql.gz
else
    mv $bakdir/mysql-backup-all-$d1.sql.gz $bakdir/mysql-backup-all-$WEEK_DAY.sql.gz
fi

echo 'mysql backup end at 'date''
EOF

    # 替换RSYNC服务器地址
    sed -i "s#RSYNC_SERVER_IP#$RSYNC_SERVER_IP#" /script/backup_mysql.sh

    # 创建rsync密码文件
    echo "rO.fWIEU0I" > /etc/rsync.password
    chmod 600 /etc/rsync.password

    # 创建定时任务(先导出已存在的任务)
    chmod +x /script/backup_mysql.sh
    crontab -l > /tmp/crontab.tmp
    echo "10 1 * * * /script/backup_mysql.sh" >> /tmp/crontab.tmp
    cat /tmp/crontab.tmp | uniq > /tmp/crontab
    crontab /tmp/crontab
    rm -f /tmp/crontab.tmp /tmp/crontab
}

BACKUP_RSYNC(){
    # 安装rsync
    yum install -y rsync

    # 获取当前子网
    NF=$(echo $LOCAL_IP | awk -F '.' '{print $NF}')
    SUB_NET="$(echo $LOCAL_IP | sed "s#$NF#0#")"

    # 创建配置文件
    cat > /etc/rsyncd.conf   <<EOF
uid = root
gid = root
port = 873
#list = false
use chroot = no
strict modes = yes
max connections = 10

pid file = /var/run/rsyncd.pid
lock file = /var/run/rsyncd.lock
log file = /var/log/rsyncd.log

timeout = 900
exclude = lost+found/
transfer logging = yes
ignore nonreadable = yes
dont compress = *.gz *.tgz *.zip *.z *.Z *.rpm *.deb *.bz2

[backupmysql]
ignore errors
read only = false
write only = false
path = /home/backupmysql
comment = mysql backup
auth users = dumper
hosts deny = 0.0.0.0/32
hosts allow = ${SUB_NET}/24
secrets file = /etc/rsyncd.secrets
EOF

    # 创建账户文件
    echo "dumper:rO.fWIEU0I"  > /etc/rsyncd.secrets
    chmod 600 /etc/rsyncd.secrets

    # 创建数据存储目录
    mkdir /home/backupmysql

    # 启动服务跟随系统启动
    systemctl restart rsyncd
    systemctl enable rsyncd

    # 配置防火墙
    CONF_FIREWALLD "873"
}

MYSQL_BACKUP(){
    CHOICE

echo -e """$CGREEN
--------------------- 请选择当前角色 ---------------------

    0. MySql
    1. Rsync
    9. Exit

----------------------------------------------------------
$CEND
"""

echo -e "$CGREEN 请输入编号 [0, 1, 9]: $CEND \c"
read ARG

case "$ARG" in
    0)
        BACKUP_MYSQL ;;
    1)
        BACKUP_RSYNC ;;
    9)
        echo -e "$CCYAN \n\t用户取消...\n $CEND" ;;
    *)
        echo -e "$CCYAN \n\t输入错误...\n $CEND" ;;
esac
}


echo -e """$CGREEN
----------------- 请输入编号安装相应服务 -----------------

    0. Install MySql
    1. Install MongoDB
    2. Install Emqtt
    3. Install Node
    4. Install Redis
    5. Install JDK
    6. Install Tomcat
    7. Install Hazelcast
    8. MySql Backup(Rsync)
    9. Exit

----------------------------------------------------------
$CEND
"""

echo -e "$CGREEN 请输入编号 [0, 1, 2, 3, 4, 5, 6, 7, 9]: $CEND \c"
read ARG

case "$ARG" in
    0)
        INSTALL_MYSQL ;;
    1)
        INSTALL_MONGODB ;;
    2)
        INSTALL_EMQTT ;;
    3)
        INSTALL_NODE ;;
    4)
        INSTALL_REDIS ;;
    5)
        INSTALL_JDK ;;
    6)
        INSTALL_TOMCAT ;;
    7)
        INSTALL_HAZECAST ;;
    8)
        MYSQL_BACKUP ;;
    9)
        echo -e "$CCYAN \n\t用户取消...\n $CEND" ;;
    *)
        echo -e "$CCYAN \n\t输入错误...\n $CEND" ;;
esac
