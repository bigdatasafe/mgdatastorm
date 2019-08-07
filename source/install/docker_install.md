### Docker部署

>前面提到了快速部署，这里整理下一键docker部署脚本供体验和前期研发或测试使用。


**0.注意**

- 此部署文档仅供测试或研发使用
- docker部署体验版本为：Beta1.0.1
- docker部署和分布式手动部署稍有不同，默认提供docker批量执行，仅供体验
- 项目使用针对技术爱好者强烈推荐分布式手动部署，更快的熟悉每个模块的功能，便于后续排错 [分布式手动部署文档](https://mgdatastorm.readthedocs.io/en/latest/install/distributed_install.html)


**1.建议配置**
> 标配一台：主要用于时序数据采集和存储和微服务部署和结构数据存储。
- 系统： CentOS7+
- CPU：  8Core+
- 内存：  32G+
- 磁盘：  >=100GB+ `存储空间计算参考:100个测点1分钟采集一次，年存储空间消耗30GB。`

**2.适配系统**
- 测试兼容阿里云CentOS7+、Redhat7+
- 测试兼容华为云CentOS7+、Redhat7+
- 测试兼容腾讯云CentOS7+、Redhat7+
- 其余平台/系统目前暂时没有进行过多测试


**3.优化系统**

- 如果你的系统是新的，我们建议你先优化下系统，此步非必须，同样我们也提供了[优化系统脚本](https://github.com/bigdatasafe/mgdatastorm/blob/master/script/system_init_v1.sh)
- 以下基础环境中，若你的系统中已存在可跳过，并进行直接配置，建议使用我们推荐的版本

**4.开始部署**

> 说明 在执行启动容器前请替换 docker-compose.yml 中的 FDFS_WEB_SERVER 变量为容器宿主机IP:8888,此IP与端口为 Fastdfs 资源展示用

    FDFS_WEB=192.168.2.76:8888
    sed -e "s#FDFS_WEB_SERVER=.*#FDFS_WEB_SERVER=$FDFS_WEB#" docker-compose.yml

***0.使用仓库镜像部署(11f版本)***

> 0.下载解压部署脚本

    curl -O http://kaifa.hc-yun.com:30050/mango/test/-/archive/master/test-master.tar.gz
    tar xvf test-master.tar.gz
    cd test-master

    # 替换默认镜像下载地址,使用harbor中的镜像才用的到(注意：如果是武汉内网请忽略)
    file_list=$(grep -r '192.168.2.30' ./template/ | awk -F ':' '{print $1}' | uniq)
    sed -i 's#192.168.2.30#180.167.148.12:30051#' $file_list

> 1.安装docker环境

    ./docker-install.sh install
    source ~/.bashrc

> 2.生成容器启动文件

    ./tools.sh --harbor 11f

> 3.下载并启动容器

    docker-compose up -d

***1.构建镜像并部署***

> 0.下载解压部署脚本

    curl -O http://kaifa.hc-yun.com:30050/mango/test/-/archive/master/test-master.tar.gz
    tar xvf test-master.tar.gz
    cd test-master

    # 替换默认镜像下载地址,使用harbor中的镜像才用的到(注意：如果是武汉内网请忽略)
    file_list=$(grep -r '192.168.2.30' ./template/ | awk -F ':' '{print $1}' | uniq)
    sed -i 's#192.168.2.30#180.167.148.12:30051#' $file_list

> 1.安装docker环境

    ./docker-install.sh install
    source ~/.bashrc

> 2.下载资源(war包,dockerfile等)

    ./download.sh 11f
    
> 3.生成基础环境启动脚本(mysql,mongod,redis,zookeeper,hbase等)

    ./tools.sh --depend 11f local

> 4.生成微服务镜像

    ./tools.sh --build 11f

> 5.启动容器

    docker-compose up -d

**5.自定义war包**

> 0.将包放到/tmp目录

    cd /tmp
    wget http://ftp.hc-yun.com/mango-war/11G/alarm-task-1.1.1.0001.war

> 1.启动http服务(python自带简单http服务)

    python -m SimpHTTPServer 7766

> 2.新开一个终端,读取脚本

    cd /root/test
    source change_war.sh

> 3.生成镜像,替换启动文件中的版本

    replace alarm-task http://localhost:7766/alarm-task-1.1.1.0001.war

说明：
- replace     调用脚本中的方法
- alarm-task  需要替换的包所在路径(ls ./mango/alarm-task)
- war包路径   http路径

> 4.更新容器

    docker-compose up -d

注意：
- 1.替换前如配置文件有变更请修改 ./central-config 对应配置
- 2.如果其他服务对当前服务有依赖请先停止服务后再重新启动
    docker-compose stop && docker-compose up -d

**6.容器管理**

    docker-compose up -d                # 后台启动所有容器
    docker-compose up -d zookeeper      # 后台启动指定容器
    docker-compose logs -f              # 打印所有日志
    docker-compose logs -f zookeeper    # 打印所有日志
    
    # 手动启动容器(请先启动完成注册中心,网管,uaa后再启动其他)
    sed -i 's#JHIPSTER_SLEEP=.*#JHIPSTER_SLEEP=3#' docker-compose.yml       # 更改容器延时启动时间
    docker-compose -f depend.yml up -d
    docker-compose up -d jhipster-registry
    docker-compose up -d uaa
    docker-compose up -d gateway
    docker-compose up -d job
    docker-compose up -d loong
    docker-compose up -d calctask
    docker-compose up -d backstage
    docker-compose up -d base
    docker-compose up -d message
    docker-compose up -d patrol
    docker-compose up -d box
    docker-compose up -d inventory
    docker-compose up -d calcroot
    docker-compose up -d equipment
    docker-compose up -d alarm-task
    docker-compose up -d voice
    docker-compose up -d ht-3d-editor
    docker-compose up -d dcmqtt dcapi
    docker-compose up -d web
