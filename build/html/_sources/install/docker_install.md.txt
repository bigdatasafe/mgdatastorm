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

