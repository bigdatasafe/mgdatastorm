### 快速部署

> 这里先简单说明下，最近有很多同学在部署的时候遇到了各种各样的问题，很多都是一些文档不仔细/网络不给力/修改了不改修改的配置导致的，所以专门提供了快速部署，让各位小伙伴们进行快速体验。


**注意**

- 此部署为单机部署
- 此部署文档不建议线上使用
- 快速部署体验版本为：Beta0.1.1
- 快速部署和分布式稍有不同，不提供技术指导，仅供体验
- 线上使用强烈推荐分布式部署，更快的熟悉每个模块的功能，便于后续排错 [分布式部署文档](https://mgdatastorm.readthedocs.io/en/latest/distributed_install.html)



**部署视频**
> 近期有部分同学反应说部署太麻烦了，为什么不做成一个Docker，其实我们这里单项目已经是Docker部署了，为了更好的让用户更快的了解我们的平台，我们正在准备部署视频，[视频入口](localhost)


**建议配置**

- 系统： CentOS7+
- CPU：  8Core+
- 内存：  16G+
- 磁盘：  >=50+

**适配系统**
- 测试兼容阿里云CentOS7+
- 测试兼容华为云CentOS7+
- 测试兼容腾讯云CentOS7+
- 其余平台/系统没有进行多测试


**优化系统**

注意：

- 如果你的系统是新的，我们建议你先优化下系统，此步非必须，同样我们也提供了[优化系统脚本](https://github.com/bigdatasafe/mgdatastorm/blob/master/script/system_init_v1.sh)
- 以下基础环境中，若你的系统中已经存在可跳过，直接配置，建议使用我们推荐的版本

**快速开始**

- 快速部署脚本下载地址：https://github.com/bigdatasafe/mgdatastorm/blob/master/script/fast_depoly.sh
```shell  

#下载脚本，赋权执行即可，执行的时候将你的内网IP当作参数传进来
chmod +x fast_depoly.sh
sh fast_depoly.sh <内网IP>  

```  
**访问**

`注意： 这里如果没修改默认域名、且没有域名解析的同学，请访问的时候绑定下本地Hosts，防止访问到我们默认的Demo机器上。`

- 地址：demo.hc-yun.com
- 用户：16888888888
- 密码：888888

**日志路径**

> 若这里访问有报错，请看下日志，一般都是配置错误。
- 日志路径：所有模块日志统一`/var/log/supervisor/`