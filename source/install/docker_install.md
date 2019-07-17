### Docker部署

>前面提到了快速部署，这里整理下一键docker部署脚本供体验和前期研发或测试使用。


**注意**

- 此部署为docker一键部署
- 此部署文档仅供测试或研发使用
- docker部署体验版本为：Beta1.0.1
- docker部署和分布式手动部署稍有不同，默认提供docker批量执行，仅供体验
- 项目使用针对技术爱好者强烈推荐分布式手动部署，更快的熟悉每个模块的功能，便于后续排错 [分布式手动部署文档](https://mgdatastorm.readthedocs.io/en/latest/install/distributed_install.html)


**建议配置**
> 标配一台：主要用于时序数据采集和存储和微服务部署和结构数据存储。
- 系统： CentOS7+
- CPU：  8Core+
- 内存：  32G+
- 磁盘：  >=100GB+ `存储空间计算参考:100个测点1分钟采集一次，年存储空间消耗30GB。`

**适配系统**
- 测试兼容阿里云CentOS7+、Redhat7+
- 测试兼容华为云CentOS7+、Redhat7+
- 测试兼容腾讯云CentOS7+、Redhat7+
- 其余平台/系统目前暂时没有进行过多测试


**优化系统**

- 如果你的系统是新的，我们建议你先优化下系统，此步非必须，同样我们也提供了[优化系统脚本](https://github.com/bigdatasafe/mgdatastorm/blob/master/script/system_init_v1.sh)
- 以下基础环境中，若你的系统中已存在可跳过，并进行直接配置，建议使用我们推荐的版本

**快速开始**

> 说明

> 在执行启动容器前请替换 docker-compose.yml 中的 FDFS_WEB_SERVER 变量

    - 原因：backstage 配置文件中有 JSON 风格配置无法转换为 key:value 方式(使用脚本在容器初次执行时解压jar包,复制配置文件,重新打包)

    FDFS_WEB=192.168.2.76:8888      # 替换此IP与端口为 fastdfs 资源展示IP与端口
    sed -e "s#FDFS_WEB_SERVER=.*#FDFS_WEB_SERVER=$FDFS_WEB#" docker-compose.yml

> 11d 与 11e 区别

    0.有部分war包更新, 数据库名有部分更改
    1.message, loong, alarmTask 这三个微服务添加了依赖mg_job数据库配置
    2.新增mg_job数据库依赖后导致mysql连接数到达上限拒绝服务(修改mysql最大连接数 默认为150)

>  下载解压

    curl -O http://kaifa.hc-yun.com:30050/mango/test/-/archive/master/test-master.tar.gz
    tar xvf test-master.tar.gz
    cd test-master

>  部署11d

> 0.安装 docker 环境

    ./docker-install.sh install
    source ~/.bashrc

> 1.下载资源

    ./download.sh 11d

> 2.生成基础环境启动脚本

    ./tools.sh --depend 11d network

> 3.生成镜像

    ./tools.sh --build 11d

> 4.下载基础镜像

    docker-compose -f depend.yml pull

> 5.启动容器

    docker-compose up -d

> 6.查看日志

    docker-compose logs -f


>  部署11d

> 0.安装 docker 环境

    ./docker-install.sh install
    source ~/.bashrc


> 1.下载资源

    ./download.sh 11e

> 2.生成基础环境启动脚本

    ./tools.sh --depend 11e network

> 3.生成镜像

    ./tools.sh --build 11e

> 4.下载基础镜像

    docker-compose -f depend.yml pull

> 5.启动容器

    docker-compose up -d
    
> 6.查看日志

    docker-compose logs -f
