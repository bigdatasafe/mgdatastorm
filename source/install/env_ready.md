### 环境准备

> 部署安装之前，你应该了解下每个模块的用途，[传送门](https://mgdatastorm.readthedocs.io/en/latest/beginning/introduction.html)

**私有云用户自备设备：测点数量1万以内**




| 序号  | 设备名称  |  设备描述 |  数量 |  单位 |
| :------------: | ------------ | ------------ | :------------: | :------------: |
|1| 华为USG6350防火墙  | USG6350下一代防火墙含4合一授权  |  2 | 台  |
|2| 华为S6720S交换机  | 华为全万兆光纤交换机S6720S-26Q-EI-24S-DC  |  2 |  台 |
|3| RH2288HV3服务器  | 内存16GBx8、1.8TBx8 2.5寸 10K sas<br>CPU E5-2620V4x2、4x10GE、2x460W raid卡 | 2  |  台 |
|4| 万兆网卡  |  光口双万兆以太网卡 |  2 | 个  |
|5| 万兆光模块  | SFP+万兆多模光模块  |  24 |  个 |
|6| 光纤跳线 | 万兆光纤跳线3米OM3多模双芯LC-LC跳线  | 24  | 根  |
|7| 英特尔SSD  | 英特尔PCI-E半高SSD固态硬盘P4600 2T  |  4 | 块  |
|8| 超融合计算授权(每物理CPU)  |计算服务器虚拟化软件V5.0，企业级云平台软件-服务器虚拟化，虚拟机生命<br>周期管理，VMware异构管理，HA高可用，虚拟机备份，一键故障检测。   |  4 |  套 |
|9| 超融合存储授权(每物理CPU)  | 虚拟存储软件V2.0，企业级云平台软件-存储虚拟化，存储多副本，高性能读<br>写缓存，存储弹性扩展，数据故障切换，磁盘故障告警。  |  4 |  套 |
备注：此方式默认采用超融合架构部署，安全等级较高，且便于管理，前期现场部署可由供货商或运维协助处理。



**私有云用户自备设备：测点数量1万至10万之间**




| 序号  | 设备名称  |  设备描述 |  数量 |  单位 |
| :------------: | ------------ | ------------ | :------------: | :------------: |
|1| 华为USG6350防火墙  | USG6350下一代防火墙含4合一授权  |  2 | 台  |
|2| 华为S6720S交换机  | 华为全万兆光纤交换机S6720S-26Q-EI-24S-DC  |  2 |  台 |
|3| RH2288HV3服务器  | 内存16GBx16、4TBx12 3.5寸 7.2K sata<br>CPU E5-2630V4x2、4x10GE、2x460W raid卡 | 3  |  台 |
|4| 万兆网卡  |  光口双万兆以太网卡 |  3 | 个  |
|5| 万兆光模块  | SFP+万兆多模光模块  |  34 |  个 |
|6| 光纤跳线 | 万兆光纤跳线3米OM3多模双芯LC-LC跳线  | 34  | 根  |
|7| 英特尔SSD  | 英特尔PCI-E半高SSD固态硬盘P4600 2T  |  6 | 块  |
|8| 超融合计算授权(每物理CPU)  |计算服务器虚拟化软件V5.0，企业级云平台软件-服务器虚拟化，虚拟机生命<br>周期管理，VMware异构管理，HA高可用，虚拟机备份，一键故障检测。   |  6 |  套 |
|9| 超融合存储授权(每物理CPU)  | 虚拟存储软件V2.0，企业级云平台软件-存储虚拟化，存储多副本，高性能读<br>写缓存，存储弹性扩展，数据故障切换，磁盘故障告警。  |  6 |  套 |
备注：此方式默认采用超融合架构部署，安全等级较高，且便于管理，前期现场部署可由供货商或运维协助处理。


**半私有云设备清单：用户提供虚拟机或租赁云资源**




| 序号  | 配置规格  |  资源配置参考清单 |  台数 |  备注 |
| :------------: | ------------ | ------------ | :------------: | ------------ |
| 1  | 经济适用版 |  8核CPU32G内存10M带宽标配 | 2 |  性能有限，可用率较低 |
| 2  | 基础冗余版 |  8核CPU16G内存10M带宽标配 | 6 |  数据冗余，可用率良好 |
| 3  | 高可用版   |  8核CPU32G内存20M带宽标配 | 8 |  性能良好，可用率乐观 |
| 4  | 集团专属版 |  8核CPU32G内存30M带宽标配 | 12|  集团专属，可靠性及较高  |
备注：存储空间说明，由测点量、采集频率和存储年限共同组成，详情参考自动计算文档。


**对外开放端口清单，映射需采用对外不对等方式开通**




| 序号  | 端口  |  用途 |  备注 |
| :------------: | :------------: | ------------ | ------------ |
| 1  | 80    |芒果系统平台专用端口|  芒果平台专用 |
| 2  | 5666  |ht监视画面对外端口  |  监视画面专用 |
| 3  | 8090  |图片服务器对外端口  |  图片服务专用 |
| 4  | 8091  |报表服务器对外端口  |  报表服务专用 |
| 5  | 5191  |璇思网关数据采集主端口|  璇思网关数据采集专用 |
| 6  | 5192  |璇思网关数据采集备端口|  璇思网关数据采集专用 |
| 7  | 6181  |璇思网关管理平台主端口|  璇思网关网管管理专用 |
| 8  | 6182  |璇思网关管理平台备端口|  璇思网关网管管理专用 |
备注：所有映射端口，均需与应用所在的服务器相关端口保持一致，其它网关类似。

**各个环境下部署方式介绍**




| 序号  | 资源状态  |  部署方式 |  备注 |
| :------------: | ------------ | ------------ | ------------ |
| 1  | 私有云无设备|集中采购设备和超融合授权|镜像导入，脚本启动|
| 2  | 私有云有设备|按用户需求择优选择虚拟化|镜像导入，脚本启动|
| 3  | 私有云自备虚机|脚本、模板、镜像方式部署|文档交付，脚本启动|
| 4  | 半私有云租赁虚机|脚本、模板、镜像方式部署|文档交付，脚本启动|
| 5  | 半私有云租赁昊沧|脚本、模板、镜像方式部署|文档交付，脚本启动|
备注：开发和调试机默认以最小环境运行，采用一键部署方式运行。


**本项目部署方式介绍**

- 此部署为高可用分布式架构默认标配8台，标准架构6台无冗余
- 如客户环境不满足条件，可将web应用和mysql数据库机器合并使用

**Web应用建议配置**

- 系统： CentOS7+
- CPU：  8Core+
- 内存： 32G+
- 磁盘： >=100+
- 台数： 2台 

**Mysql数据库建议配置**

- 系统： CentOS7+
- CPU：  8Core+
- 内存： 16G+
- 磁盘： >=300+
- 台数： 2台 

**大数据处理建议配置**
- 系统： CentOS7+
- CPU：  8Core+
- 内存： 16G+
- 磁盘： >=500+
- 台数： 4台


**准备基础环境**

> 基础环境需要用到以下服务，我们也提供了简单的[初始化脚本](https://github.com/bigdatasafe/mgdatastorm/blob/master/script/system_init_v1.sh)

- 建议版本
  - Nginx-1.16.0
  - Mysql-5.7.26
  - Emqttd-3.0.0
  - Mongodb-3.6
  - Hadoop-2.7.7
  - Zookeeper-3.4.14
  - Hbase-1.2.12
  - Kafka-2.12
  - Storm-1.2.2
  - Opentsdb-2.4.0
  - Fastdfs-5.11
  - Redis-4.0.10


**优化系统**

注意：

- 如果你的系统是新的，我们建议你先优化下系统，同样我们也提供了[优化系统脚本](https://github.com/bigdatasafe/mgdatastorm/blob/master/script/system_init_v1.sh)
- 以下基础环境中，若你的系统中已经存在可跳过，直接配置，建议使用我们推荐的版本



创建项目目录

```
$ mkdir -p /opt/Mango/ && cd /opt/Mango/
```

**环境变量**

> 以下内容贴入到`vim /opt/Mango/env.sh`文件，刚开始接触这里可能会稍微有点难理解，后面文档将会说明每个环境变量的用途，主要修改域名/地址和密码信息, `source /opt/Mango/env.sh`




```shell

echo -e "\033[31m 注意：token_secret一定要做修改，防止网站被攻击!!!!!!! \033[0m"
echo -e "\033[32m 注意：token_secret一定要做修改，防止网站被攻击!!!!!!! \033[0m"
echo -e "\033[33m 注意：token_secret一定要做修改，防止网站被攻击!!!!!!! \033[0m"

echo -e "\033[31m 注意：如果你修改了模块默认域名地址，部署的时候一定要修改doc/nginx_ops.conf 以及网关配置configs.lua中的域名，并保持一致 \033[0m"

echo -e "\033[32m 注意：如果你修改了模块默认域名地址，部署的时候一定要修改doc/nginx_ops.conf 以及网关配置configs.lua中的域名，并保持一致 \033[0m"

echo -e "\033[33m 注意：如果你修改了模块默认域名地址，部署的时候一定要修改doc/nginx_ops.conf 以及网关配置configs.lua中的域名，并保持一致 \033[0m"

#重要的事情说三遍，如果你修改了以上涉及到的，请务必一定要对应起来！！！！
#本机的IP地址
export LOCALHOST_IP="192.168.30.111"

#设置你的MYSQL密码
export MYSQL_PASSWORD="m9uSFL7duAVXfeAwGUSG"

### 设置你的redis密码
export REDIS_PASSWORD="cWCVKJ7ZHUK12mVbivUf"

### RabbitMQ用户密码信息
export MQ_USER="ss"
export MQ_PASSWORD="5Q2ajBHRT2lFJjnvaU0g"

##这部分是模块化部署，微服务，每个服务都有一个单独的域名，默认都内部通信，可不用修改域名，如果你修改成了自己的域名，后续部署的时候每个项目下docs/nginx_ops.conf对应的servername和网关转发的时候域名一定要对应起来。
### 管理后端地址
export mg_domain="mg.hc-yun.com"

### 定时任务地址,目前只启动一个进程，不用域名，直接IP即可
export cron_domain="192.168.30.111"

### 任务系统地址
export task_domain="task.hc-yun.com"

### CMDB系统地址
export cmdb_domain="cmdb2.hc-yun.com"

### 运维工具地址
export tools_domain="tools.hc-yun.com"


### 域名管理地址
export dns_domain="dns.hc-yun.com"


### 配置中心域名
export kerrigan_domain="kerrigan.hc-yun.com"

### 前端地址,也就是你的访问地址
export front_domain="demo.hc-yun.com"

### api网关地址
export api_gw_url="gw.hc-yun.com"


#Mango-admin用到的cookie和token，可留默认
export cookie_secret="nJ2oZis0V/xlArY2rzpIE6ioC9/KlqR2fd59sD=UXZJ=3OeROB"
# 这里Mango-admin和gw网关都会用到，一定要修改。可生成随意字符
export token_secret="pXFb4i%*834gfdh963df718iodGq4dsafsdadg7yI6ImF1999aaG7"


##如果要进行读写分离，Master-slave主从请自行建立，一般情况下都是只用一个数据库就可以了
# 写数据库
export DEFAULT_DB_DBHOST="192.168.30.111"
export DEFAULT_DB_DBPORT='3306'
export DEFAULT_DB_DBUSER='root'
export DEFAULT_DB_DBPWD=${MYSQL_PASSWORD}
#export DEFAULT_DB_DBNAME=${mysql_database}

# 读数据库
export READONLY_DB_DBHOST='192.168.30.111'
export READONLY_DB_DBPORT='3306'
export READONLY_DB_DBUSER='root'
export READONLY_DB_DBPWD=${MYSQL_PASSWORD}
#export READONLY_DB_DBNAME=${mysql_database}

# 消息队列
export DEFAULT_MQ_ADDR='192.168.30.111'
export DEFAULT_MQ_USER=${MQ_USER}
export DEFAULT_MQ_PWD=${MQ_PASSWORD}

# 缓存
export DEFAULT_REDIS_HOST='192.168.30.111'
export DEFAULT_REDIS_PORT=6379
export DEFAULT_REDIS_PASSWORD=${REDIS_PASSWORD}


```

`source /opt/Mango/env.sh, 最后一定不要忘记source` 


**安装Docker-compose**
> 若已安装docker-compose可跳过
```shell
echo -e "\033[32m [INFO]: Start install docker,docker-compose \033[0m"
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum-config-manager --enable docker-ce-edge
yum install -y docker-ce
###启动
/bin/systemctl start docker.service
### 开机自启
/bin/systemctl enable docker.service
#安装docker-compose编排工具
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python3 get-pip.py
pip3 install docker-compose
if [ $? == 0 ];then
    echo -e "\033[32m [INFO]: docker-compose install success. \033[0m"
else
    echo -e "\033[31m [ERROR]: docker-compose install faild \033[0m"
    exit -2
fi
```

**安装MySQL**

> 一般来说 一个MySQL实例即可，如果有需求可以自行搭建主从，每个服务都可以有自己的数据库
>
> 我们这里示例是用Docker部署的MySQL，你也可以使用你自己的MySQL

```shell
echo -e "\033[32m [INFO]: Start install mysql5.7 \033[0m"
cat >docker-compose.yml <<EOF
mysql:
  restart: unless-stopped
  image: mysql:5.7
  volumes:
    - /data/mysql:/var/lib/mysql
    - /data/mysql_conf:/etc/mysql/conf.d
  ports:
    - "3306:3306"
  environment:
    - MYSQL_ROOT_PASSWORD=${MYSQL_PASSWORD}
EOF
docker-compose up -d   #启动
if [ $? == 0 ];then
    echo -e "\033[32m [INFO]: mysql install success. \033[0m"
    echo -e "\033[32m [INFO]: 没有mysql客户端的同学自己安装一下子哈, yum install mysql -y. \033[0m"
    echo -e "\033[32m [INFO]: mysql -h127.0.0.1 -uroot -p${MYSQL_PASSWORD} \033[0m"
else
    echo -e "\033[31m [ERROR]: mysql57 install faild \033[0m"
    exit -3
fi
```

**安装Redis**
```shell
echo -e "\033[32m [INFO]: Start install redis3.2 \033[0m"
yum -y install redis-3.2.*

echo "[INFO]: start init redis"
### 开启AOF
sed -i 's#appendonly no$#appendonly yes#g' /etc/redis.conf
### 操作系统决定
sed -i 's#appendfsync .*$$#appendfsync everysec$#g' /etc/redis.conf
### 修改绑定IP
sed -i 's/^bind 127.0.0.1$/#bind 127.0.0.1/g' /etc/redis.conf
### 是否以守护进程方式启动
sed -i 's#daemonize no$#daemonize yes#g' /etc/redis.conf
### 当时间间隔超过60秒，或存储超过1000条记录时，进行持久化
sed -i 's#^save 60 .*$#save 60 1000#g' /etc/redis.conf
### 快照压缩
sed -i 's#rdbcompression no$#rdbcompression yes#g' /etc/redis.conf
### 添加密码
sed -i "s#.*requirepass .*#requirepass ${REDIS_PASSWORD}#g" /etc/redis.conf
systemctl start redis
systemctl status redis
systemctl enable redis

if [ $? == 0 ];then
    echo -e "\033[32m [INFO]: redis install success. \033[0m"
    echo -e "\033[32m [INFO]: redis-cli -h 127.0.0.1 -p 6379 -a ${REDIS_PASSWORD}"
else
    echo -e "\033[31m [ERROR]: redis install faild \033[0m"
    exit -4
fi
```


**安装RabbitMQ**

`注意安装完MQ后不要修改主机名，否则MQ可能会崩掉`
```shell
echo -e "\033[32m [INFO]: Start install rabbitmq \033[0m"
# echo $LOCALHOST_IP hc-yun.com >> /etc/hosts
# echo hc-yun.com > /etc/hostname
# export HOSTNAME=hc-yun.com
yum install  -y rabbitmq-server
rabbitmq-plugins enable rabbitmq_management
systemctl start rabbitmq-server
rabbitmqctl add_user ${MQ_USER} ${MQ_PASSWORD}
rabbitmqctl set_user_tags ${MQ_USER} administrator
rabbitmqctl  set_permissions  -p  '/'  ${MQ_USER} '.' '.' '.'
systemctl restart rabbitmq-server
systemctl enable rabbitmq-server
systemctl status rabbitmq-server

# rabbitmq-server -detached
status=`systemctl status rabbitmq-server | grep "running" | wc -l`
if [ $status == 1 ];then
    echo -e "\033[32m [INFO]: rabbitmq install success. \033[0m"
else
    echo -e "\033[31m [ERROR]: rabbitmq install faild \033[0m"
    exit -5
fi
```
