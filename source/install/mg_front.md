### 项目前端

> 我们提供的有release包，建议直接下载release包更为方便！

**一、 直接下载资源包**

- 建议使用最新版本[Release](<http://git.hc-yun.com/mango/cloud/web.git/>)

```
echo -e "\033[32m [INFO]: mango(项目前端) Start install. \033[0m"
CODO_VER="codo-beta-0.3.2"
if ! which wget &>/dev/null; then yum install -y wget >/dev/null 2>&1;fi
[ ! -d /root/mango/web ] && mkdir -p /root/mango/web
cd /var/www && wget http://git.hc-yun.com/mango/cloud/${CODO_VER}/${CODO_VER}.tar.gz
tar zxf ${CODO_VER}.tar.gz
if [ $? == 0 ];then
    echo -e "\033[32m [INFO]: mango(项目前端) install success. \033[0m"
else
    echo -e "\033[31m [ERROR]: mango(项目前端) install faild \033[0m"
    exit -8
fi
```

- 前端的静态文件会存放在`/root/mango/web`目录内
- 测试一下 `ll /root/mango/web/index.html` 看下文件是不是存在

**后续访问使用gateway网关中的vhosts，节省资源，这里不单独安装配置nginx**