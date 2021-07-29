#!/usr/bin/env bash
# 检测区
##
#使用方法1  yum install wget vim -y && wget -N --no-check-certificate -q -O install.sh "https://cdn.jsdelivr.net/gh/jth445600/hello-world@master/shiyan5.sh" && chmod +x install.sh && bash install.sh
#https://cdn.jsdelivr.net/gh/jth445600/picgo@master
##使用方法1  yum install wget vim -y && wget -N --no-check-certificate -q -O install.sh "https://raw.githubusercontent.com/jth445600/hello-world/master/shiyan5.sh" && chmod +x install.sh && bash install.sh

source /etc/os-release
RELEASE=$ID
VERSION=$VERSION_ID

green "== Time  : $(date +"%Y-%m-%d %H:%M:%S")"
green "== OS    : $RELEASE $VERSION"
green "== Kernel: $(uname -r)"
green "== User  : $(whoami)"
sleep 2s


##install_wordpress
install_wordpress(){
    green "$(date +"%Y-%m-%d %H:%M:%S") ==== 安装wordpress"
    yum install -y iptables-services
    systemctl start iptables
    systemctl enable iptables
    iptables -F
    SSH_PORT=$(awk '$1=="Port" {print $2}' /etc/ssh/sshd_config)
    if [ ! -n "$SSH_PORT" ]; then
        iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
    else
        iptables -A INPUT -p tcp -m tcp --dport ${SSH_PORT} -j ACCEPT
    fi
    iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
    iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    service iptables save
    green "====================================================================="
    green "安全起见，iptables仅开启ssh,http,https端口，如需开放其他端口请自行放行"
    green "====================================================================="
    echo
    echo
    sleep 1
    yum -y install  wget
    mkdir /usr/share/wordpresstemp
    cd /usr/share/wordpresstemp/
    wget https://cn.wordpress.org/latest-zh_CN.zip
    if [ ! -f "/usr/share/wordpresstemp/latest-zh_CN.zip" ]; then
        red "从cn官网下载wordpress失败，尝试从github下载……"
        wget https://github.com/atrandys/wordpress/raw/master/latest-zh_CN.zip
    fi
    if [ ! -f "/usr/share/wordpresstemp/latest-zh_CN.zip" ]; then
        red "从github下载wordpress也失败了，请尝试手动安装……"
        green "从wordpress官网下载包然后命名为latest-zh_CN.zip，新建目录/usr/share/wordpresstemp/，上传到此目录下即可"
        exit 1
    fi
    green "==============="
    green " 1.安装必要软件"
    green "==============="
    sleep 1s
    echo
    wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    wget https://rpms.remirepo.net/enterprise/remi-release-7.rpm
    if [ -f "epel-release-latest-7.noarch.rpm" -a -f "remi-release-7.rpm" ]; then
        green "下载软件源成功"
    else
        red "下载软件源失败，退出安装"
        exit 1
    fi
    rpm -ivh remi-release-7.rpm epel-release-latest-7.noarch.rpm --force --nodeps
    #sed -i "0,/enabled=0/s//enabled=1/" /etc/yum.repos.d/epel.repo
    yum -y install unzip vim tcl expect curl socat
    echo
    echo
    green "============"
    green "2.安装PHP7.4"
    green "============"
    sleep 1
    yum -y install php74 php74-php-gd php74-php-opcache php74-php-pdo php74-php-mbstring php74-php-cli php74-php-fpm php74-php-mysqlnd php74-php-xml
    service php74-php-fpm start
    chkconfig php74-php-fpm on
    if [ `yum list installed | grep php74 | wc -l` -ne 0 ]; then
        echo
        green "【checked】 PHP7安装成功"
        echo
        echo
        sleep 2s
        php_status=1
    fi
    green "==============="
    green "  3.安装MySQL"
    green "==============="
    sleep 1s
    #wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
    wget https://repo.mysql.com/mysql80-community-release-el7-3.noarch.rpm
    rpm -ivh mysql80-community-release-el7-3.noarch.rpm --force --nodeps
    yum -y install mysql-server
    systemctl enable mysqld.service
    systemctl start  mysqld.service
    if [ `yum list installed | grep mysql-community | wc -l` -ne 0 ]; then
        green "【checked】 MySQL安装成功"
        echo
        echo
        sleep 2
        mysql_status=1
    fi
    echo
    echo
    green "==============="
    green "  4.配置MySQL"
    green "==============="
    sleep 2
    originpasswd=`cat /var/log/mysqld.log | grep password | head -1 | rev  | cut -d ' ' -f 1 | rev`
    mysqlpasswd=`mkpasswd -l 18 -d 2 -c 3 -C 4 -s 5 | sed $'s/[\'\/\;\"\:\.\?\&]//g'`
cat > ~/.my.cnf <<EOT
[mysql]
user=root
password="$originpasswd"
EOT
    mysql  --connect-expired-password  -e "alter user 'root'@'localhost' identified by '$mysqlpasswd';"
    systemctl restart mysqld
    sleep 5s
cat > ~/.my.cnf <<EOT
[mysql]
user=root
password="$mysqlpasswd"
EOT
    mysql  --connect-expired-password  -e "create database wordpress_db;"
    echo
    green "===================="
    green " 5.配置php和php-fpm"
    green "===================="
    echo
    echo
    sleep 1s
    sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/;" /etc/opt/remi/php74/php.ini
    sed -i "s/pm.start_servers = 5/pm.start_servers = 3/;s/pm.min_spare_servers = 5/pm.min_spare_servers = 3/;s/pm.max_spare_servers = 35/pm.max_spare_servers = 8/;" /etc/opt/remi/php74/php-fpm.d/www.conf
    systemctl restart php74-php-fpm.service
    systemctl restart nginx.service
    green "===================="
    green "  6.安装wordpress"
    green "===================="
    echo
    echo
    sleep 1s
    mkdir /usr/share/nginx
    mkdir /usr/share/nginx/html
    cd /usr/share/nginx/html
    mkdir tmp
    mv ./* tmp/
    mv /usr/share/wordpresstemp/latest-zh_CN.zip ./
    unzip latest-zh_CN.zip
    mv wordpress/* ./
    #cp wp-config-sample.php wp-config.php
    wget https://raw.githubusercontent.com/atrandys/trojan/master/wp-config.php
    green "===================="
    green "  7.配置wordpress"
    green "===================="
    echo
    echo
    sleep 1
    sed -i "s/database_name_here/wordpress_db/;s/username_here/root/;s?password_here?$mysqlpasswd?;" /usr/share/nginx/html/wp-config.php
    #echo "define('FS_METHOD', "direct");" >> /usr/share/nginx/html/wp-config.php
    chown -R apache:apache /usr/share/nginx/html/
    #chmod 775 apache:apache /usr/share/nginx/html/ -Rf
    chmod -R 755 /usr/share/nginx/html/wp-content
    sed -i '15a location ~ \.php$ {' /etc/nginx/conf.d/alone.conf
    sed -i '16a fastcgi_pass 127.0.0.1:9000;' /etc/nginx/conf.d/alone.conf 
    sed -i '17a fastcgi_param SCRIPT_FILENAME /usr/share/nginx/html$fastcgi_script_name;' /etc/nginx/conf.d/alone.conf
    sed -i '18a fastcgi_index index.php;' /etc/nginx/conf.d/alone.conf 
    sed -i '19a include fastcgi_params;' /etc/nginx/conf.d/alone.conf
    sed -i '20a   }' /etc/nginx/conf.d/alone.conf
    yum install lsof -y
    port_exist_check() {
    if [[ 0 -eq $(lsof -i:80 | grep -i -c "listen") ]]; then
        echo -e " 80端口未被占用 "
        sleep 1
    else
        echo -e "80端口被占用，以下为 80端口占用信息 80"
        lsof -i:80
        sleep 2
        lsof -i:80 | awk '{print $2}' | grep -v "PID" | xargs kill -9
        echo -e " kill 完成 "
        sleep 1
    fi
    }
    port_exist_check
    nginx
    green "=========================================================================="
    green " WordPress服务端配置已完成，请打开浏览器访问您的域名进行前台配置"
    green " 数据库密码等信息参考文件：/usr/share/nginx/html/wp-config.php"
    green "=========================================================================="
    green "本次安装检测信息如下："
    ps -aux | grep -e nginx -e xray -e mysql -e php
}

# -------------------------------------------------------------
# 检查系统
checkSystem(){
	if [[ ! -z `find /etc -name "redhat-release"` ]] || [[ ! -z `cat /proc/version | grep -i "centos" | grep -v grep ` ]]
	then
	    centosVersion=`rpm -q centos-release|awk -F "[-]" '{print $3}'|awk -F "[.]" '{print $1}'`
	    if [[ -z "${centosVersion}" ]] && [[ ! -z `cat /etc/centos-release|grep "release 8"` ]]
	    then
            centosVersion=8
	    fi

		release="centos"
		installType='yum -y install'
		removeType='yum -y remove'
		upgrade="yum update -y --skip-broken"
	elif [[ ! -z `cat /etc/issue | grep -i "debian" | grep -v grep` ]] || [[ ! -z `cat /proc/version | grep -i "debian" | grep -v grep` ]]
    then
        if [[ ! -z `cat /etc/issue|grep -i "8"` ]]
        then
            debianVersion=8
        fi
		release="debian"
		installType='apt -y install'
		upgrade="apt update -y"
		removeType='apt -y autoremove'
	elif [[ ! -z `cat /etc/issue | grep -i "ubuntu" | grep -v grep` ]] || [[ ! -z `cat /proc/version | grep -i "ubuntu" | grep -v grep` ]]
	then
		release="ubuntu"
		installType='apt-get -y install'
		upgrade="apt-get update -y"
		removeType='apt-get --purge remove'
    fi
    if [[ -z ${release} ]]
    then
        echoContent red "本脚本不支持此系统，请将下方日志反馈给开发者"
        cat /etc/issue
        cat /proc/version
        exit 0;
    fi
}

# 初始化全局变量
initVar(){
    installType='yum -y install'
    removeType='yum -y remove'
    upgrade="yum -y update"
    echoType='echo -e'

    # 域名
    domain=

    # CDN节点的address
    add=

    # 安装总进度
    totalProgress=1


    # 1.xray-core安装
    # 2.v2ray-core 安装
    # 3.v2ray-core[xtls] 安装
    coreInstallType=

    # 核心安装path
    coreInstallPath=

    # v2ctl Path
    ctlPath=
    # 1.全部安装
    # 2.个性化安装
    v2rayAgentInstallType=

    # 当前的个性化安装方式 01234
    currentInstallProtocolType=

    # 选择的个性化安装方式
    selectCustomInstallType=

    # v2ray-core配置文件的路径
    configPath=

    # xray-core配置文件的路径
    configPath=

    # 配置文件的path
    currentPath=

    # 配置文件的host
    currentHost=

    # 安装时选择的core类型
    selectCoreType=

    # 默认core版本
    v2rayCoreVersion=

    # 随机路径
    customPath=

    # centos version
    centosVersion=

    # UUID
    currentUUID=

    # pingIPv6 pingIPv4
    pingIPv4=
    pingIPv6=

    # 集成更新证书逻辑不再使用单独的脚本--RenewTLS
    renewTLS=$1
}

# 检测安装方式
readInstallType(){
    coreInstallType=
    configPath=

    # 1.检测安装目录
    if [[ -d "/etc/v2ray-agent" ]]
    then
        # 检测安装方式 v2ray-core
        if [[ -d "/etc/v2ray-agent/v2ray" && -f "/etc/v2ray-agent/v2ray/v2ray" && -f "/etc/v2ray-agent/v2ray/v2ctl" ]]
        then
            if [[ -d "/etc/v2ray-agent/v2ray/conf" && -f "/etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json" ]]
            then
                configPath=/etc/v2ray-agent/v2ray/conf/

                if [[ -z `cat /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json|grep xtls` ]]
                then
                    # 不带XTLS的v2ray-core
                    coreInstallType=2
                    coreInstallPath=/etc/v2ray-agent/v2ray/v2ray
                    ctlPath=/etc/v2ray-agent/v2ray/v2ctl
                elif [[ ! -z `cat /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json|grep xtls` ]]
                then
                    # 带XTLS的v2ray-core
                    coreInstallPath=/etc/v2ray-agent/v2ray/v2ray
                    ctlPath=/etc/v2ray-agent/v2ray/v2ctl
                    coreInstallType=3
                fi
            fi
        fi

        if [[ -d "/etc/v2ray-agent/xray" && -f "/etc/v2ray-agent/xray/xray" ]]
        then
            # 这里检测xray-core
            if [[ -d "/etc/v2ray-agent/xray/conf" && -f "/etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json" ]]
            then
                # xray-core
                configPath=/etc/v2ray-agent/xray/conf/
                coreInstallPath=/etc/v2ray-agent/xray/xray
                ctlPath=/etc/v2ray-agent/xray/xray
                coreInstallType=1
            fi
        fi
    fi
}

# 读取协议类型
readInstallProtocolType(){
    currentInstallProtocolType=
    
    while read row
    do
        if [[ ! -z `echo ${row}|grep VLESS_TCP_inbounds` ]]
        then
            currentInstallProtocolType=${currentInstallProtocolType}'0'
        fi
        if [[ ! -z `echo ${row}|grep VLESS_WS_inbounds` ]]
        then
            currentInstallProtocolType=${currentInstallProtocolType}'1'
        fi
        if [[ ! -z `echo ${row}|grep VMess_TCP_inbounds` ]]
        then
            currentInstallProtocolType=${currentInstallProtocolType}'2'
        fi
        if  [[ ! -z `echo ${row}|grep VMess_WS_inbounds` ]]
        then
            currentInstallProtocolType=${currentInstallProtocolType}'3'
        fi
    done < <(echo `ls ${configPath}|grep -v grep|grep inbounds.json|awk -F "[.]" '{print $1}'`)

    if [[ -f "/etc/v2ray-agent/trojan/trojan-go" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]]
    then
        currentInstallProtocolType=${currentInstallProtocolType}'4'
    fi
}

# 检查文件目录以及path路径
readConfigHostPathUUID(){
    currentPath=
    currentUUID=
    currentHost=
    currentPort=
    currentAdd=
    # 读取path
    if [[ ! -z "${configPath}" ]]
    then
        local path=`cat ${configPath}02_VLESS_TCP_inbounds.json|jq .inbounds[0].settings.fallbacks|jq -c '.[].path'|awk -F "[\"][/]" '{print $2}'|awk -F "[\"]" '{print $1}'|tail -n +2|head -n 1`
        if [[ ! -z "${path}" ]]
        then
            if [[ `echo ${path:0-3}` = "vws" ]]
            then
                currentPath=`echo ${path}|awk -F "[v][w][s]" '{print $1}'`
            elif [[ `echo ${path:0-2}` = "ws" ]]
            then
                currentPath=`echo ${path}|awk -F "[w][s]" '{print $1}'`
            elif [[ `echo ${path:0-2}` = "tcp" ]]
            then
                currentPath=`echo ${path}|awk -F "[t][c][p]" '{print $1}'`
            fi

        fi
    fi
    if [[ "${coreInstallType}" = "1" ]]
    then
        currentHost=`cat ${configPath}02_VLESS_TCP_inbounds.json|jq .inbounds[0].streamSettings.xtlsSettings.certificates[0].certificateFile|awk -F '[t][l][s][/]' '{print $2}'|awk -F '["]' '{print $1}'|awk -F '[.][c][r][t]' '{print $1}'`
        currentUUID=`cat ${configPath}02_VLESS_TCP_inbounds.json|jq .inbounds[0].settings.clients[0].id|awk -F '["]' '{print $2}'`
        currentAdd=`cat ${configPath}02_VLESS_TCP_inbounds.json|jq .inbounds[0].settings.clients[0].add|awk -F '["]' '{print $2}'`
        currentPort=`cat ${configPath}02_VLESS_TCP_inbounds.json|jq .inbounds[0].port`

    elif [[ "${coreInstallType}" = "2" || "${coreInstallType}" = "3" ]]
    then
        if [[ "${coreInstallType}" = "3" ]]
        then
            currentHost=`cat ${configPath}02_VLESS_TCP_inbounds.json|jq .inbounds[0].streamSettings.xtlsSettings.certificates[0].certificateFile|awk -F '[t][l][s][/]' '{print $2}'|awk -F '["]' '{print $1}'|awk -F '[.][c][r][t]' '{print $1}'`
        else
            currentHost=`cat ${configPath}02_VLESS_TCP_inbounds.json|jq .inbounds[0].streamSettings.tlsSettings.certificates[0].certificateFile|awk -F '[t][l][s][/]' '{print $2}'|awk -F '["]' '{print $1}'|awk -F '[.][c][r][t]' '{print $1}'`
        fi
        currentAdd=`cat ${configPath}02_VLESS_TCP_inbounds.json|jq .inbounds[0].settings.clients[0].add|awk -F '["]' '{print $2}'`
        currentUUID=`cat ${configPath}02_VLESS_TCP_inbounds.json|jq .inbounds[0].settings.clients[0].id|awk -F '["]' '{print $2}'`
        currentPort=`cat ${configPath}02_VLESS_TCP_inbounds.json|jq .inbounds[0].port`
    fi
}

# 清理旧残留
cleanUp(){
    if [[ "$1" = "v2rayClean" ]]
    then
        rm -rf `ls /etc/v2ray-agent/v2ray|egrep -v '(config_full.json|conf)'`
        handleV2Ray stop > /dev/null 2>&1
        rm -f /etc/systemd/system/v2ray.service
    elif [[ "$1" = "xrayClean" ]]
    then
        rm -rf `ls /etc/v2ray-agent/xray|egrep -v '(config_full.json|conf)'`
        handleXray stop > /dev/null 2>&1
        rm -f /etc/systemd/system/xray.service

    elif [[ "$1" = "v2rayDel" ]]
    then
        rm -rf /etc/v2ray-agent/v2ray/*

    elif [[ "$1" = "xrayDel" ]]
    then
        rm -rf /etc/v2ray-agent/xray/*
    fi
}

initVar $1
checkSystem
readInstallType
readInstallProtocolType
readConfigHostPathUUID


# -------------------------------------------------------------

echoContent(){
    case $1 in
        # 红色
        "red")
            ${echoType} "\033[31m${printN}$2 \033[0m"
        ;;
        # 天蓝色
        "skyBlue")
            ${echoType} "\033[1;36m${printN}$2 \033[0m"
        ;;
        # 绿色
        "green")
            ${echoType} "\033[32m${printN}$2 \033[0m"
        ;;
        # 白色
        "white")
            ${echoType} "\033[37m${printN}$2 \033[0m"
        ;;
        "magenta")
            ${echoType} "\033[31m${printN}$2 \033[0m"
        ;;
        "skyBlue")
            ${echoType} "\033[36m${printN}$2 \033[0m"
        ;;
        # 黄色
        "yellow")
            ${echoType} "\033[33m${printN}$2 \033[0m"
        ;;
    esac
}

# 初始化安装目录
mkdirTools(){
    mkdir -p /etc/v2ray-agent/tls
    mkdir -p /etc/v2ray-agent/v2ray/conf
    mkdir -p /etc/v2ray-agent/xray/conf
    mkdir -p /etc/v2ray-agent/trojan
    mkdir -p /etc/systemd/system/
    mkdir -p /tmp/v2ray-agent-tls/
}

# 安装工具包
installTools(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 安装工具"
    if [[ "${release}" = "centos" ]]
    then
        echoContent green " ---> 检查安装jq、nginx epel源、yum-utils、semanage"
        # jq epel源
        if [[ -z `command -v jq` ]]
        then
            rpm -ivh http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm > /dev/null 2>&1
        fi

        nginxEpel=""
        if [[ ! -z `rpm -qa|grep -v grep|grep nginx` ]]
        then
            local nginxVersion=`rpm -qa|grep -v grep|grep nginx|head -1|awk -F '[-]' '{print $2}'`;
            if [[ `echo ${nginxVersion}|awk -F '[.]' '{print $1}'` < 1 ]] && [[ `echo ${nginxVersion}|awk -F '[.]' '{print $2}'` < 17 ]]
            then
                rpm -qa|grep -v grep|grep nginx|xargs rpm -e > /dev/null 2>&1
            fi
        fi

        if [[ "${centosVersion}" = "6" ]]
        then
            nginxEpel="http://nginx.org/packages/centos/6/x86_64/RPMS/nginx-1.18.0-1.el6.ngx.x86_64.rpm"
            rpm -ivh ${nginxEpel} > /etc/v2ray-agent/error.log 2>&1
        elif [[ "${centosVersion}" = "7" ]]
        then
            nginxEpel="http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm"
            policyCoreUtils="policycoreutils-python.x86_64"
            rpm -ivh ${nginxEpel} > /etc/v2ray-agent/error.log 2>&1
        elif [[ "${centosVersion}" = "8" ]]
        then
            nginxEpel="http://nginx.org/packages/centos/8/x86_64/RPMS/nginx-1.18.0-1.el8.ngx.x86_64.rpm"
            policyCoreUtils="policycoreutils-python-utils-2.9-9.el8.noarch"
            # rpm -ivh ${nginxEpel} > /etc/v2ray-agent/error.log 2>&1
        fi

        # yum-utils
        if [[ "${centosVersion}" = "8" ]]
        then
            upgrade="yum update -y --skip-broken --nobest"
            installType="yum -y install --nobest"
            ${installType} yum-utils > /etc/v2ray-agent/error.log 2>&1
        else
            ${installType} yum-utils > /etc/v2ray-agent/error.log 2>&1
        fi

    fi
    # 修复ubuntu个别系统问题
    if [[ "${release}" = "ubuntu" ]]
    then
        dpkg --configure -a
    fi

    if [[ ! -z `ps -ef|grep -v grep|grep apt`  ]]
    then
        ps -ef|grep -v grep|grep apt|awk '{print $2}'|xargs kill -9
    fi

    echoContent green " ---> 检查、安装更新【新机器会很慢，耐心等待】"

    ${upgrade} > /dev/null
    if [[ "${release}" = "centos" ]]
    then
        rm -rf /var/run/yum.pid
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w wget` ]]
    then
        echoContent green " ---> 安装wget"
        ${installType} wget > /dev/null 2>&1
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w curl` ]]
    then
        echoContent green " ---> 安装curl"
        ${installType} curl > /dev/null 2>&1
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w unzip` ]]
    then
        echoContent green " ---> 安装unzip"
        ${installType} unzip > /dev/null 2>&1
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w socat` ]]
    then
        echoContent green " ---> 安装socat"
        ${installType} socat > /dev/null 2>&1
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w tar` ]]
    then
        echoContent green " ---> 安装tar"
        ${installType} tar > /dev/null 2>&1
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep cron` ]]
    then
        echoContent green " ---> 安装crontabs"
        if [[ "${release}" = "ubuntu" ]] || [[ "${release}" = "debian" ]]
        then
            ${installType} cron > /dev/null 2>&1
        else
            ${installType} crontabs > /dev/null 2>&1
        fi
    fi
    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w jq` ]]
    then
        echoContent green " ---> 安装jq"
        ${installType} jq > /dev/null 2>&1
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep binutils` ]]
    then
        echoContent green " ---> 安装binutils"
        ${installType} binutils > /dev/null  2>&1
    fi

    if [[ -z `find /bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep ping6` ]]
    then
        echoContent green " ---> 安装ping6"
        ${installType} inetutils-ping > /dev/null 2>&1
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w nginx` ]]
    then
        echoContent green " ---> 安装nginx"
        if [[ "${centosVersion}" = "8" ]]
        then
            rpm -ivh ${nginxEpel} > /etc/v2ray-agent/error.log 2>&1
        else
            ${installType} nginx > /dev/null 2>&1
        fi

        if [[ ! -z "${centosVersion}" ]]
        then
            systemctl daemon-reload
            systemctl enable nginx
        fi
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w semanage` ]]
    then
        echoContent green " ---> 安装semanage"
        ${installType} bash-completion > /dev/null 2>&1
        if [[ ! -z "${policyCoreUtils}" ]]
        then
            ${installType} ${policyCoreUtils} > /dev/null 2>&1
        fi
        if [[ ! -z `which semanage` ]]
        then
            semanage port -a -t http_port_t -p tcp 31300

        fi
    fi

    if [[ -z `find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin |grep -v grep|grep -w sudo` ]]
    then
        echoContent green " ---> 安装sudo"
        ${installType} sudo > /dev/null 2>&1
    fi
    # todo 关闭防火墙

    if [[ ! -d "/root/.acme.sh" ]]
    then
        echoContent green " ---> 安装acme.sh"
        curl -s https://get.acme.sh | sh > /etc/v2ray-agent/tls/acme.log
        if [[ -d "~/.acme.sh" ]] && [[ -z `ls -F ~/.acme.sh/|grep -w "acme.sh"` ]]
        then
            echoContent red "  acme安装失败--->"
            echoContent yellow "错误排查："
            echoContent red "  1.获取Github文件失败，请等待GitHub恢复后尝试，恢复进度可查看 [https://www.githubstatus.com/]"
            echoContent red "  2.acme.sh脚本出现bug，可查看[https://github.com/acmesh-official/acme.sh] issues"
            echoContent red "  3.反馈给开发者[私聊：https://t.me/mack_a] 或 [提issues]"
            exit 0
        fi
    fi
    if [[ -d "/root/.acme.sh" ]] && [[ -z `find /root/.acme.sh/ -name "acme.sh"` ]]
    then
        echoContent green " ---> 安装acme.sh"
        curl -s https://get.acme.sh | sh > /etc/v2ray-agent/tls/acme.log
        if [[ -d "~/.acme.sh" ]] && [[ -z `find /root/.acme.sh/ -name "acme.sh"` ]]
        then
            echoContent red "  acme安装失败--->"
            echoContent yellow "错误排查："
            echoContent red "  1.获取Github文件失败，请等待GitHub恢复后尝试，恢复进度可查看 [https://www.githubstatus.com/]"
            echoContent red "  2.acme.sh脚本出现bug，可查看[https://github.com/acmesh-official/acme.sh] issues"
            echoContent red "  3.反馈给开发者[私聊：https://t.me/mack_a] 或 [提issues]"
            exit 0
        fi
    fi
}

# 初始化Nginx申请证书配置
initTLSNginxConfig(){
    handleNginx stop
    echoContent skyBlue "\n进度  $1/${totalProgress} : 初始化Nginx申请证书配置"
    if [[ ! -z "${currentHost}" ]]
    then
        echo
        read -p "读取到上次安装记录，是否使用上次安装时的域名 ？[y/n]:" historyDomainStatus
        if [[ "${historyDomainStatus}" = "y" ]]
        then
            domain=${currentHost}
            echoContent yellow "\n ---> 域名：${domain}"
        else
            echo
            echoContent yellow  "请输入要配置的域名 例：blog.v2ray-agent.com --->"
            read -p "域名:" domain
        fi
    else
	echo
	echoContent yellow  "请输入要配置的域名 例：blog.v2ray-agent.com --->"
	read -p "域名:" domain
    fi

    if [[ -z ${domain} ]]
    then
        echoContent red "  域名不可为空--->"
        initTLSNginxConfig
    else
        # 修改配置
        echoContent green "\n ---> 配置Nginx"
        touch /etc/nginx/conf.d/alone.conf
        echo "server {listen 80;listen [::]:80;server_name ${domain};root /usr/share/nginx/html;location ~ /.well-known {allow all;}location /test {return 200 'fjkvymb6len';}}" > /etc/nginx/conf.d/alone.conf
        # 启动nginx
        handleNginx start
        echoContent yellow "\n检查IP是否设置为当前VPS"
        checkIP
        # 测试nginx
        echoContent yellow "\n检查Nginx是否正常访问"
        domainResult=`curl -s ${domain}/test|grep fjkvymb6len`
        if [[ ! -z ${domainResult} ]]
        then
            handleNginx stop
            echoContent green "\n ---> Nginx配置成功"
        else
            echoContent red " ---> 无法正常访问服务器，请检测域名是否正确、域名的DNS解析以及防火墙设置是否正确--->"
            exit 0;
        fi
    fi
}

# 修改nginx重定向配置
updateRedirectNginxConf(){

cat << EOF > /etc/nginx/conf.d/alone.conf
    server {
        listen 80;
        listen [::]:80;
        server_name ${domain};
        return 301 https://${domain}$request_uri;
    }
EOF

    if [[ "${debianVersion}" = "8" ]]
    then
cat << EOF >> /etc/nginx/conf.d/alone.conf
        server {
        listen 31300;
        server_name ${domain};
        root /usr/share/nginx/html;
        index index.php index.html;
        # location / {
        #     add_header Strict-Transport-Security "max-age=63072000" always;
        # }
#       location ~ /.well-known {allow all;}
#       location /test {return 200 'fjkvymb6len';}
    }
EOF
    else
cat << EOF >> /etc/nginx/conf.d/alone.conf
        server {
            listen 31300;
            server_name ${domain};
            root /usr/share/nginx/html;
            index index.php index.html;
            location / {
                add_header Strict-Transport-Security "max-age=63072000" always;
            }
    #       location ~ /.well-known {allow all;}
    #       location /test {return 200 'fjkvymb6len';}
        }
EOF
    fi

}

# 检查ip
checkIP(){
    echoContent skyBlue " ---> 检查ipv4中"
    pingIP=`ping -c 1 -W 1000 ${domain}|sed '1{s/[^(]*(//;s/).*//;q;}'`
    if [[ -z "${pingIP}" ]]
    then
        echoContent skyBlue " ---> 检查ipv6中"
        pingIP=`ping6 -c 1 ${domain}|sed '1{s/[^(]*(//;s/).*//;q;}'`
        pingIPv6=${pingIP}
    fi

    if [[ ! -z "${pingIP}" ]] # && [[ `echo ${pingIP}|grep '^\([1-9]\|[1-9][0-9]\|1[0-9][0-9]\|2[0-4][0-9]\|25[0-5]\)\.\([0-9]\|[1-9][0-9]\|1[0-9][0-9]\|2[0-4][0-9]\|25[0-5]\)\.\([0-9]\|[1-9][0-9]\|1[0-9][0-9]\|2[0-4][0-9]\|25[0-5]\)\.\([0-9]\|[1-9][0-9]\|1[0-9][0-9]\|2[0-4][0-9]\|25[0-5]\)$'` ]]
    then
        echo
        read -p "当前域名的IP为 [${pingIP}]，是否正确[y/n]？" domainStatus
        if [[ "${domainStatus}" = "y" ]]
        then
            echoContent green "\n ---> IP确认完成"
        else
            echoContent red "\n ---> 1.检查Cloudflare DNS解析是否正常"
            echoContent red " ---> 2.检查Cloudflare DNS云朵是否为灰色\n"
            exit 0;
        fi
    else
        read -p "IP查询失败，是否重试[y/n]？" retryStatus
        if [[ "${retryStatus}" = "y" ]]
        then
            checkIP
        else
            exit 0;
        fi
    fi
}
# 安装TLS
installTLS() {
	echoContent skyBlue "\n进度  $1/${totalProgress} : 申请TLS证书\n"
	local tlsDomain=${domain}
	# 安装tls
	if [[ -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" && -f "/etc/v2ray-agent/tls/${tlsDomain}.key" && -n $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]] || [[ -d "$HOME/.acme.sh/${tlsDomain}_ecc" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" ]]; then
		# 存在证书
		echoContent green " ---> 检测到证书"
		checkTLStatus "${tlsDomain}"
		if [[ "${tlsStatus}" == "已过期" ]]; then
			rm -rf $HOME/.acme.sh/${tlsDomain}_ecc/*
			rm -rf /etc/v2ray-agent/tls/${tlsDomain}*
			installTLS "$1"
		else
			echoContent green " ---> 证书有效"

			if ! ls /etc/v2ray-agent/tls/ | grep -q "${tlsDomain}.crt" || ! ls /etc/v2ray-agent/tls/ | grep -q "${tlsDomain}.key" || [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
				sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
			else
				echoContent yellow " ---> 如未过期请选择[n]\n"
				read -r -p "是否重新安装？[y/n]:" reInstallStatus
				if [[ "${reInstallStatus}" == "y" ]]; then
					rm -rf /etc/v2ray-agent/tls/*
					installTLS "$1"
				fi
			fi
		fi
	elif [[ -d "$HOME/.acme.sh" ]] && [[ ! -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" || ! -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" ]]; then
		echoContent green " ---> 安装TLS证书"
		if [[ -n "${pingIPv6}" ]]; then
			sudo "$HOME/.acme.sh/acme.sh" --issue -d "${tlsDomain}" --standalone -k ec-256 --server letsencrypt --listen-v6 >> /etc/v2ray-agent/tls/acme.log
		else
			sudo "$HOME/.acme.sh/acme.sh" --issue -d "${tlsDomain}" --standalone -k ec-256 --server letsencrypt >> /etc/v2ray-agent/tls/acme.log
		fi

		if [[ -d "$HOME/.acme.sh/${tlsDomain}_ecc" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.key" && -f "$HOME/.acme.sh/${tlsDomain}_ecc/${tlsDomain}.cer" ]]; then
			sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${tlsDomain}" --fullchainpath "/etc/v2ray-agent/tls/${tlsDomain}.crt" --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null
		fi

		if [[ ! -f "/etc/v2ray-agent/tls/${tlsDomain}.crt" || ! -f "/etc/v2ray-agent/tls/${tlsDomain}.key"  ]] || [[ -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.key") || -z $(cat "/etc/v2ray-agent/tls/${tlsDomain}.crt") ]]; then
			tail -n 10 /etc/v2ray-agent/tls/acme.log
			echoContent red " ---> TLS安装失败，请检查acme日志"
			exit 0
		fi
		echoContent green " ---> TLS生成成功"
	else
		echoContent yellow " ---> 未安装acme.sh"
		exit 0
	fi
}
# 配置伪装博客
initNginxConfig(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 配置Nginx"

        cat << EOF > /etc/nginx/conf.d/alone.conf
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};
    root /usr/share/nginx/html;
    location ~ /.well-known {allow all;}
    location /test {return 200 'fjkvymb6len';}
}
EOF
}

# 自定义/随机路径
randomPathFunction(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 生成随机路径"

    if [[ ! -z "${currentPath}" ]]
    then
        echo
        read -p "读取到上次安装记录，是否使用上次安装时的path路径 ？[y/n]:" historyPathStatus
        echo
    fi

    if [[ "${historyPathStatus}" = "y" ]]
    then
        customPath=${currentPath}
        echoContent green " ---> 使用成功\n"
    else
        echoContent yellow "请输入自定义路径[例: alone]，不需要斜杠，[回车]随机路径"
        read -p '路径:' customPath

        if [[ -z "${customPath}" ]]
        then
            customPath=`head -n 50 /dev/urandom|sed 's/[^a-z]//g'|strings -n 4|tr 'A-Z' 'a-z'|head -1`
            currentPath=${customPath:0:4}
        fi
    fi
    echoContent yellow "path：${customPath}"
    echoContent skyBlue "\n----------------------------"
}
# Nginx伪装博客
nginxBlog(){
    echoContent skyBlue "\n进度 $1/${totalProgress} : 添加伪装站点"
    if [[ -d "/usr/share/nginx/html" && -f "/usr/share/nginx/html/check" ]]
    then
        echo
        read -p "检测到安装伪装站点，是否需要重新安装[y/n]：" nginxBlogInstallStatus
        if [[ "${nginxBlogInstallStatus}" = "y" ]]
        then
            rm -rf /usr/share/nginx/html
            wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html1.zip > /dev/null
            unzip -o  /usr/share/nginx/html1.zip -d /usr/share/nginx/html > /dev/null
            rm -f /usr/share/nginx/html.zip*
            echoContent green " ---> 添加伪装站点成功"
        fi
    else
        rm -rf /usr/share/nginx/html
        wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html1.zip > /dev/null
        unzip -o  /usr/share/nginx/html1.zip -d /usr/share/nginx/html > /dev/null
        rm -f /usr/share/nginx/html1.zip*
        echoContent green " ---> 添加伪装站点成功"
    fi

}
# 操作Nginx
handleNginx(){
    if [[ -z `ps -ef|grep -v grep|grep nginx` ]] && [[ "$1" = "start" ]]
    then
        nginx
        sleep 0.5
        if [[ -z `ps -ef|grep -v grep|grep nginx` ]]
        then
            echoContent red " ---> Nginx启动失败，请检查日志"
            exit 0
        fi
    elif [[  "$1" = "stop" ]] && [[ ! -z `ps -ef|grep -v grep|grep nginx` ]]
    then
        nginx -s stop > /dev/null 2>&1
        sleep 0.5
        if [[ ! -z `ps -ef|grep -v grep|grep nginx` ]]
        then
            ps -ef|grep -v grep|grep nginx|awk '{print $2}'|xargs kill -9
        fi
    fi
}

# 定时任务更新tls证书
installCronTLS(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 添加定时维护证书"
    if [[ -z `crontab -l|grep -v grep|grep '/etc/v2ray-agent/install.sh'` ]]
    then
        crontab -l > /etc/v2ray-agent/backup_crontab.cron
        if [[ ! -z `cat /etc/v2ray-agent/backup_crontab.cron|grep /etc/v2ray-agent/reloadInstallTLS.sh` ]]
        then
            sed -i "s/30 1 \\* \\* \\* \\/bin\\/bash \\/etc\\/v2ray-agent\\/reloadInstallTLS.sh//g" `grep "30 1 \\* \\* \\* /bin/bash /etc/v2ray-agent/reloadInstallTLS.sh" -rl /etc/v2ray-agent/backup_crontab.cron`
        fi

        # 定时任务
        echo "30 1 * * * /bin/bash /etc/v2ray-agent/install.sh RenewTLS" >> /etc/v2ray-agent/backup_crontab.cron
        crontab /etc/v2ray-agent/backup_crontab.cron
    fi

    if [[ ! -z `crontab -l|grep -v grep|grep '/etc/v2ray-agent/install.sh'` ]]
    then
        echoContent green " ---> 添加定时维护证书成功"
    else
        echo "30 1 * * * /bin/bash /etc/v2ray-agent/install.sh RenewTLS" >> /etc/v2ray-agent/backup_crontab.cron
        crontab /etc/v2ray-agent/backup_crontab.cron
        echoContent green " ---> 添加定时维护证书成功"
    fi
}

# 更新证书
renewalTLS(){
    echoContent skyBlue "\n进度  1/1 : 更新证书"

    if [[ -d "/root/.acme.sh/${currentHost}_ecc" ]] && [[ -f "/root/.acme.sh/${currentHost}_ecc/${currentHost}.key" ]] && [[ -f "/root/.acme.sh/${currentHost}_ecc/${currentHost}.cer" ]]
    then
        modifyTime=`stat /root/.acme.sh/${currentHost}_ecc/${currentHost}.key|sed -n '7,6p'|awk '{print $2" "$3" "$4" "$5}'`

        modifyTime=`date +%s -d "${modifyTime}"`
        currentTime=`date +%s`
        stampDiff=`expr ${currentTime} - ${modifyTime}`
        days=`expr ${stampDiff} / 86400`
        remainingDays=`expr 90 - ${days}`
        tlsStatus=${remainingDays}
        if [[ ${remainingDays} -le 0 ]]
        then
            tlsStatus="已过期"
        fi
        echoContent skyBlue " ---> 证书生成日期:"`date -d @${modifyTime} +"%F %H:%M:%S"`
        echoContent skyBlue " ---> 证书生成天数:"${days}
        echoContent skyBlue " ---> 证书剩余天数:"${tlsStatus}

        if [[ ${remainingDays} -le 1 ]]
        then
            echoContent yellow " ---> 重新生成证书"
            handleNginx stop
            sudo ~/.acme.sh/acme.sh --cron --home /root/.acme.sh
            sudo ~/.acme.sh/acme.sh --installcert -d ${currentHost} --fullchainpath /etc/v2ray-agent/tls/${currentHost}.crt --keypath /etc/v2ray-agent/tls/${currentHost}.key --ecc >> /etc/v2ray-agent/tls/acme.log
            handleNginx start

            if [[ "${coreInstallType}" = "1" ]]
            then
                handleXray stop
                handleXray start
            elif [[ "${coreInstallType}" = "2" || "${coreInstallType}" = "3" ]]
            then
                handleV2Ray stop
                handleV2Ray start
            fi

        else
            echoContent green " ---> 证书有效"
        fi
    else
        echoContent red " ---> 未安装"
    fi
}
# 查看TLS证书的状态
checkTLStatus(){

    if [[ ! -z "$1" ]]
    then
        if [[ -d "/root/.acme.sh/$1_ecc" ]] && [[ -f "/root/.acme.sh/$1_ecc/$1.key" ]] && [[ -f "/root/.acme.sh/$1_ecc/$1.cer" ]]
        then
            modifyTime=`stat /root/.acme.sh/$1_ecc/$1.key|sed -n '7,6p'|awk '{print $2" "$3" "$4" "$5}'`

            modifyTime=`date +%s -d "${modifyTime}"`
            currentTime=`date +%s`
            stampDiff=`expr ${currentTime} - ${modifyTime}`
            days=`expr ${stampDiff} / 86400`
            remainingDays=`expr 90 - ${days}`
            tlsStatus=${remainingDays}
            if [[ ${remainingDays} -le 0 ]]
            then
                tlsStatus="已过期"
            fi
            echoContent skyBlue " ---> 证书生成日期:"`date -d @${modifyTime} +"%F %H:%M:%S"`
            echoContent skyBlue " ---> 证书生成天数:"${days}
            echoContent skyBlue " ---> 证书剩余天数:"${tlsStatus}
        fi
    fi
}

# 安装V2Ray、指定版本
installV2Ray(){
    readInstallType
    echoContent skyBlue "\n进度  $1/${totalProgress} : 安装V2Ray"
    # 首先要卸载掉其余途径安装的V2Ray
    if [[ ! -z `ps -ef|grep -v grep|grep v2ray` ]] && [[ -z `ps -ef|grep -v grep|grep v2ray|grep v2ray-agent` ]]
    then
        ps -ef|grep -v grep|grep v2ray|awk '{print $8}'|xargs rm -f
        ps -ef|grep -v grep|grep v2ray|awk '{print $2}'|xargs kill -9 > /dev/null 2>&1
    fi

    if [[ "${coreInstallType}" != "2" && "${coreInstallType}" != "3" ]]
    then
        if [[ "${selectCoreType}" = "2" ]]
        then
            version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        else
            version=${v2rayCoreVersion}
        fi

        echoContent green " ---> v2ray-core版本:${version}"
        if [[ ! -z `wget --help|grep show-progress` ]]
        then
            wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip
        else
            wget -c -P /etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip > /dev/null 2>&1
        fi

        unzip -o /etc/v2ray-agent/v2ray/v2ray-linux-64.zip -d /etc/v2ray-agent/v2ray > /dev/null
        rm -rf /etc/v2ray-agent/v2ray/v2ray-linux-64.zip
    else
        if [[ "${selectCoreType}" = "3" ]]
        then
            echoContent green " ---> 锁定v2ray-core版本为v4.32.1"
            rm -f /etc/v2ray-agent/v2ray/v2ray
            rm -f /etc/v2ray-agent/v2ray/v2ctl
            installV2Ray $1
        else
            echoContent green " ---> v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"
            read -p "是否更新、升级？[y/n]:" reInstallV2RayStatus
            if [[ "${reInstallV2RayStatus}" = "y" ]]
            then
                rm -f /etc/v2ray-agent/v2ray/v2ray
                rm -f /etc/v2ray-agent/v2ray/v2ctl
                installV2Ray $1
            fi
        fi
    fi
}

# 安装xray
installXray(){
    readInstallType
    echoContent skyBlue "\n进度  $1/${totalProgress} : 安装Xray"
    # 首先要卸载掉其余途径安装的Xray
    if [[ ! -z `ps -ef|grep -v grep|grep xray` ]] && [[ -z `ps -ef|grep -v grep|grep v2ray|grep v2ray-agent` ]]
    then
        ps -ef|grep -v grep|grep xray|awk '{print $8}'|xargs rm -f
        ps -ef|grep -v grep|grep xray|awk '{print $2}'|xargs kill -9 > /dev/null 2>&1
    fi

    if [[ "${coreInstallType}" != "1" ]]
    then
        version=`curl -s https://github.com/XTLS/Xray-core/releases|grep /XTLS/Xray-core/releases/tag/|head -1|awk '{print $3}'|awk -F "[<]" '{print $1}'`

        echoContent green " ---> Xray-core版本:${version}"
        if [[ ! -z `wget --help|grep show-progress` ]]
        then
            wget -c -q --show-progress -P /etc/v2ray-agent/xray/ https://github.com/XTLS/Xray-core/releases/download/${version}/Xray-linux-64.zip
        else
            wget -c -P /etc/v2ray-agent/xray/ https://github.com/XTLS/Xray-core/releases/download/${version}/Xray-linux-64.zip > /dev/null 2>&1
        fi

        unzip -o /etc/v2ray-agent/xray/Xray-linux-64.zip -d /etc/v2ray-agent/xray > /dev/null
        rm -rf /etc/v2ray-agent/xray/Xray-linux-64.zip
        chmod 655 /etc/v2ray-agent/xray/xray
    else
        echoContent green " ---> Xray-core版本:`/etc/v2ray-agent/xray/xray --version|awk '{print $2}'|head -1`"
        read -p "是否更新、升级？[y/n]:" reInstallXrayStatus
        if [[ "${reInstallXrayStatus}" = "y" ]]
        then
            rm -f /etc/v2ray-agent/xray/xray
            installXray $1
        fi
    fi
}

# 安装Trojan-go
installTrojanGo(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 安装Trojan-Go"
    if [[ -z `ls -F /etc/v2ray-agent/trojan/|grep -w "trojan-go"` ]]
    then
        version=`curl -s https://github.com/p4gefau1t/trojan-go/releases|grep /trojan-go/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        echoContent green " ---> Trojan-Go版本:${version}"
        if [[ ! -z `wget --help|grep show-progress` ]]
        then
            wget -c -q --show-progress -P /etc/v2ray-agent/trojan/ https://github.com/p4gefau1t/trojan-go/releases/download/${version}/trojan-go-linux-amd64.zip
        else
            wget -c -P /etc/v2ray-agent/trojan/ https://github.com/p4gefau1t/trojan-go/releases/download/${version}/trojan-go-linux-amd64.zip > /dev/null 2>&1
        fi
        unzip -o /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip -d /etc/v2ray-agent/trojan > /dev/null
        rm -rf /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip
    else
        echoContent green " ---> Trojan-Go版本:`/etc/v2ray-agent/trojan/trojan-go --version|awk '{print $2}'|head -1`"

        read -p "是否重新安装？[y/n]:" reInstallTrojanStatus
        if [[ "${reInstallTrojanStatus}" = "y" ]]
        then
            rm -rf /etc/v2ray-agent/trojan/trojan-go*
            installTrojanGo $1
        fi
    fi
}

# v2ray版本管理
v2rayVersionManageMenu(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : V2Ray版本管理"
    if [[ ! -d "/etc/v2ray-agent/v2ray/" ]]
    then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0;
    fi
    echoContent red "\n=============================================================="
    echoContent yellow "1.升级"
    echoContent yellow "2.回退"
    echoContent red "=============================================================="
    read -p "请选择：" selectV2RayType
    if [[ "${selectV2RayType}" = "1" ]]
    then
        updateV2Ray
    elif [[ "${selectV2RayType}" = "2" ]]
    then
        echoContent yellow "\n1.只可以回退最近的两个版本"
        echoContent yellow "2.不保证回退后一定可以正常使用"
        echoContent yellow "3.如果回退的版本不支持当前的config，则会无法连接，谨慎操作"
        echoContent skyBlue "------------------------Version-------------------------------"
        curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -3|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'|tail -n 2|awk '{print ""NR""":"$0}'
        echoContent skyBlue "--------------------------------------------------------------"
        read -p "请输入要回退的版本：" selectV2rayVersionType
        version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -3|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'|tail -n 2|awk '{print ""NR""":"$0}'|grep "${selectV2rayVersionType}:"|awk -F "[:]" '{print $2}'`
        if [[ ! -z "${version}" ]]
        then
            updateV2Ray ${version}
        else
            echoContent red "\n ---> 输入有误，请重新输入"
            v2rayVersionManageMenu 1
        fi
    fi

}

# xray版本管理
xrayVersionManageMenu(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : Xray版本管理"
    if [[ ! -d "/etc/v2ray-agent/xray/" ]]
    then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0;
    fi
    echoContent red "\n=============================================================="
    echoContent yellow "1.升级"
    echoContent yellow "2.回退"
    echoContent red "=============================================================="
    read -p "请选择：" selectXrayType
    if [[ "${selectXrayType}" = "1" ]]
    then
        updateXray
    elif [[ "${selectXrayType}" = "2" ]]
    then
        echoContent yellow "\n1.由于Xray-core频繁更新，只可以回退最近的一个版本"
        echoContent yellow "2.不保证回退后一定可以正常使用"
        echoContent yellow "3.如果回退的版本不支持当前的config，则会无法连接，谨慎操作"
        echoContent skyBlue "------------------------Version-------------------------------"
        curl -s https://github.com/XTLS/Xray-core/releases|grep /XTLS/Xray-core/releases/tag/|head -3|awk '{print $3}'|awk -F "[<]" '{print $1}'|tail -n 1|awk '{print ""NR""":"$0}'
        echoContent skyBlue "--------------------------------------------------------------"
        read -p "请输入要回退的版本：" selectXrayVersionType
        version=`curl -s https://github.com/XTLS/Xray-core/releases|grep /XTLS/Xray-core/releases/tag/|head -3|awk '{print $3}'|awk -F "[<]" '{print $1}'|tail -n 1|awk '{print ""NR""":"$0}'|grep "${selectXrayVersionType}:"|awk -F "[:]" '{print $2}'`
        if [[ ! -z "${version}" ]]
        then
            updateXray ${version}
        else
            echoContent red "\n ---> 输入有误，请重新输入"
            xrayVersionManageMenu 1
        fi
    fi

}
# 更新V2Ray
updateV2Ray(){
    readInstallType
    if [[ -z "${coreInstallType}" ]]
    then

        if [[ ! -z "$1" ]]
        then
            version=$1
        else
            version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        fi
        # 使用锁定的版本
        if [[ ! -z "${v2rayCoreVersion}" ]]
        then
            version=${v2rayCoreVersion}
        fi
        echoContent green " ---> v2ray-core版本:${version}"

        if [[ ! -z `wget --help|grep show-progress` ]]
        then
            wget -c -q --show-progress -P /etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip
        else
            wget -c -P /etc/v2ray-agent/v2ray/ https://github.com/v2fly/v2ray-core/releases/download/${version}/v2ray-linux-64.zip > /dev/null 2>&1
        fi

        unzip -o  /etc/v2ray-agent/v2ray/v2ray-linux-64.zip -d /etc/v2ray-agent/v2ray > /dev/null
        rm -rf /etc/v2ray-agent/v2ray/v2ray-linux-64.zip
        handleV2Ray stop
        handleV2Ray start
    else
        echoContent green " ---> 当前v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"

        if [[ ! -z "$1" ]]
        then
            version=$1
        else
            version=`curl -s https://github.com/v2fly/v2ray-core/releases|grep /v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        fi

        if [[ ! -z "${v2rayCoreVersion}" ]]
        then
            version=${v2rayCoreVersion}
        fi
        if [[ ! -z "$1" ]]
        then
            read -p "回退版本为${version}，是否继续？[y/n]:" rollbackV2RayStatus
            if [[ "${rollbackV2RayStatus}" = "y" ]]
            then
                if [[ "${coreInstallType}" = "2" || "${coreInstallType}" = "3"  ]]
                then
                    echoContent green " ---> 当前v2ray-core版本:`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`"
                elif [[ "${coreInstallType}" = "1"  ]]
                then
                    echoContent green " ---> 当前Xray-core版本:`/etc/v2ray-agent/xray/xray --version|awk '{print $2}'|head -1`"
                fi

                handleV2Ray stop
                rm -f /etc/v2ray-agent/v2ray/v2ray
                rm -f /etc/v2ray-agent/v2ray/v2ctl
                updateV2Ray ${version}
            else
                echoContent green " ---> 放弃回退版本"
            fi
        elif [[ "${version}" = "v`/etc/v2ray-agent/v2ray/v2ray --version|awk '{print $2}'|head -1`" ]]
        then
            read -p "当前版本与最新版相同，是否重新安装？[y/n]:" reInstallV2RayStatus
            if [[ "${reInstallV2RayStatus}" = "y" ]]
            then
                handleV2Ray stop
                rm -f /etc/v2ray-agent/v2ray/v2ray
                rm -f /etc/v2ray-agent/v2ray/v2ctl
                updateV2Ray
            else
                echoContent green " ---> 放弃重新安装"
            fi
        else
            read -p "最新版本为：${version}，是否更新？[y/n]：" installV2RayStatus
            if [[ "${installV2RayStatus}" = "y" ]]
            then
                rm -f /etc/v2ray-agent/v2ray/v2ray
                rm -f /etc/v2ray-agent/v2ray/v2ctl
                updateV2Ray
            else
                echoContent green " ---> 放弃更新"
            fi

        fi
    fi
}

# 更新Xray
updateXray(){
    readInstallType
    if [[ -z "${coreInstallType}" ]]
    then
        if [[ ! -z "$1" ]]
        then
            version=$1
        else
            version=`curl -s https://github.com/XTLS/Xray-core/releases|grep /XTLS/Xray-core/releases/tag/|head -1|awk '{print $3}'|awk -F "[<]" '{print $1}'`
        fi

        echoContent green " ---> Xray-core版本:${version}"

        if [[ ! -z `wget --help|grep show-progress` ]]
        then
            wget -c -q --show-progress -P /etc/v2ray-agent/xray/ https://github.com/XTLS/Xray-core/releases/download/${version}/Xray-linux-64.zip
        else
            wget -c -P /etc/v2ray-agent/xray/ https://github.com/XTLS/Xray-core/releases/download/${version}/Xray-linux-64.zip > /dev/null 2>&1
        fi

        unzip -o /etc/v2ray-agent/xray/Xray-linux-64.zip -d /etc/v2ray-agent/xray > /dev/null
        rm -rf /etc/v2ray-agent/xray/Xray-linux-64.zip
        chmod 655 /etc/v2ray-agent/xray/xray
        handleXray stop
        handleXray start
    else
        echoContent green " ---> 当前Xray-core版本:`/etc/v2ray-agent/xray/xray --version|awk '{print $2}'|head -1`"

        if [[ ! -z "$1" ]]
        then
            version=$1
        else
            version=`curl -s https://github.com/XTLS/Xray-core/releases|grep /XTLS/Xray-core/releases/tag/|head -1|awk '{print $3}'|awk -F "[<]" '{print $1}'`
        fi

        if [[ ! -z "$1" ]]
        then
            read -p "回退版本为${version}，是否继续？[y/n]:" rollbackXrayStatus
            if [[ "${rollbackXrayStatus}" = "y" ]]
            then
                echoContent green " ---> 当前Xray-core版本:`/etc/v2ray-agent/xray/xray --version|awk '{print $2}'|head -1`"

                handleXray stop
                rm -f /etc/v2ray-agent/xray/xray
                updateXray ${version}
            else
                echoContent green " ---> 放弃回退版本"
            fi
        elif [[ "${version}" = "v`/etc/v2ray-agent/xray/xray --version|awk '{print $2}'|head -1`" ]]
        then
            read -p "当前版本与最新版相同，是否重新安装？[y/n]:" reInstallXrayStatus
            if [[ "${reInstallXrayStatus}" = "y" ]]
            then
                handleXray stop
                rm -f /etc/v2ray-agent/xray/xray
                rm -f /etc/v2ray-agent/xray/xray
                updateXray
            else
                echoContent green " ---> 放弃重新安装"
            fi
        else
            read -p "最新版本为：${version}，是否更新？[y/n]：" installXrayStatus
            if [[ "${installXrayStatus}" = "y" ]]
            then
                rm -f /etc/v2ray-agent/xray/xray
                updateXray
            else
                echoContent green " ---> 放弃更新"
            fi

        fi
    fi
}
# 更新Trojan-Go
updateTrojanGo(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 更新Trojan-Go"
    if [[ ! -d "/etc/v2ray-agent/trojan/" ]]
    then
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0;
    fi
    if [[ -z `ls -F /etc/v2ray-agent/trojan/|grep "trojan-go"` ]]
    then
        version=`curl -s https://github.com/p4gefau1t/trojan-go/releases|grep /trojan-go/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
        echoContent green " ---> Trojan-Go版本:${version}"
        if [[ ! -z `wget --help|grep show-progress` ]]
        then
            wget -c -q --show-progress -P /etc/v2ray-agent/trojan/ https://github.com/p4gefau1t/trojan-go/releases/download/${version}/trojan-go-linux-amd64.zip
        else
            wget -c -P /etc/v2ray-agent/trojan/ https://github.com/p4gefau1t/trojan-go/releases/download/${version}/trojan-go-linux-amd64.zip > /dev/null 2>&1
        fi
        unzip -o /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip -d /etc/v2ray-agent/trojan > /dev/null
        rm -rf /etc/v2ray-agent/trojan/trojan-go-linux-amd64.zip
        handleTrojanGo stop
        handleTrojanGo start
    else
        echoContent green " ---> 当前Trojan-Go版本:`/etc/v2ray-agent/trojan/trojan-go --version|awk '{print $2}'|head -1`"
        if [[ ! -z `/etc/v2ray-agent/trojan/trojan-go --version` ]]
        then
            version=`curl -s https://github.com/p4gefau1t/trojan-go/releases|grep /trojan-go/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[>]" '{print $2}'|awk -F "[<]" '{print $1}'`
            if [[ "${version}" = "`/etc/v2ray-agent/trojan/trojan-go --version|awk '{print $2}'|head -1`" ]]
            then
                read -p "当前版本与最新版相同，是否重新安装？[y/n]:" reInstalTrojanGoStatus
                if [[ "${reInstalTrojanGoStatus}" = "y" ]]
                then
                    handleTrojanGo stop
                    rm -rf /etc/v2ray-agent/trojan/trojan-go
                    updateTrojanGo 1
                else
                    echoContent green " ---> 放弃重新安装"
                fi
            else
                read -p "最新版本为：${version}，是否更新？[y/n]：" installTrojanGoStatus
                if [[ "${installTrojanGoStatus}" = "y" ]]
                then
                    rm -rf /etc/v2ray-agent/trojan/trojan-go
                    updateTrojanGo 1
                else
                    echoContent green " ---> 放弃更新"
                fi
            fi
        fi
    fi
}

# 验证整个服务是否可用
checkGFWStatue(){
    echoContent skyBlue "\n进度 $1/${totalProgress} : 验证服务启动状态"
    if [[ ! -z `ps -ef|grep -v grep|grep v2ray` ]]
    then
        echoContent green " ---> 服务启动成功"
    else
        echoContent red " ---> 服务启动失败，请检查终端是否有日志打印"
        exit 0
    fi
}

# V2Ray开机自启
installV2RayService(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 配置V2Ray开机自启"
    if [[ ! -z `find /bin /usr/bin -name "systemctl"` ]]
    then
        rm -rf /etc/systemd/system/v2ray.service
        touch /etc/systemd/system/v2ray.service
        execStart='/etc/v2ray-agent/v2ray/v2ray -confdir /etc/v2ray-agent/v2ray/conf'
    cat << EOF > /etc/systemd/system/v2ray.service
[Unit]
Description=V2Ray - A unified platform for anti-censorship
Documentation=https://v2ray.com https://guide.v2fly.org
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=yes
ExecStart=${execStart}
Restart=on-failure
RestartPreventExitStatus=23


[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable v2ray.service
        echoContent green " ---> 配置V2Ray开机自启成功"
    fi
}

# Xray开机自启
installXrayService(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 配置Xray开机自启"
    if [[ ! -z `find /bin /usr/bin -name "systemctl"` ]]
    then
        rm -rf /etc/systemd/system/xray.service
        touch /etc/systemd/system/xray.service
        execStart='/etc/v2ray-agent/xray/xray run -confdir /etc/v2ray-agent/xray/conf'
    cat << EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray - A unified platform for anti-censorship
# Documentation=https://v2ray.com https://guide.v2fly.org
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=yes
ExecStart=${execStart}
Restart=on-failure
RestartPreventExitStatus=23


[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable xray.service
        echoContent green " ---> 配置Xray开机自启成功"
    fi
}
# Trojan开机自启
installTrojanService(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 配置Trojan开机自启"
    if [[ ! -z `find /bin /usr/bin -name "systemctl"` ]]
    then
        rm -rf /etc/systemd/system/trojan-go.service
        touch /etc/systemd/system/trojan-go.service

    cat << EOF > /etc/systemd/system/trojan-go.service
[Unit]
Description=Trojan-Go - A unified platform for anti-censorship
Documentation=Trojan-Go
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=yes
ExecStart=/etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config_full.json
Restart=on-failure
RestartPreventExitStatus=23


[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable trojan-go.service
        echoContent green " ---> 配置Trojan开机自启成功"
    fi
}
# 操作V2Ray
handleV2Ray(){
    if [[ ! -z `find /bin /usr/bin -name "systemctl"` ]] && [[ ! -z `ls /etc/systemd/system/|grep -v grep|grep v2ray.service` ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep "v2ray/v2ray"` ]] && [[ "$1" = "start" ]]
        then
            systemctl start v2ray.service
        elif [[ ! -z `ps -ef|grep -v grep|grep "v2ray/v2ray"` ]] && [[ "$1" = "stop" ]]
        then
            systemctl stop v2ray.service
        fi
    elif [[ -z `find /bin /usr/bin -name "systemctl"` ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep v2ray` ]] && [[ "$1" = "start" ]]
        then
            /usr/bin/v2ray/v2ray -config /etc/v2ray-agent/v2ray/config_full.json & > /dev/null 2>&1
        elif [[ ! -z `ps -ef|grep -v grep|grep v2ray` ]] && [[ "$1" = "stop" ]]
        then
            ps -ef|grep -v grep|grep v2ray|awk '{print $2}'|xargs kill -9
        fi
    fi
    sleep 0.5
    if [[ "$1" = "start" ]]
    then
        if [[ ! -z `ps -ef|grep -v grep|grep "v2ray/v2ray"` ]]
        then
            echoContent green " ---> V2Ray启动成功"
        else
            echoContent red "V2Ray启动失败"
            echoContent red "执行 [ps -ef|grep v2ray] 查看日志"
            exit 0;
        fi
    elif [[ "$1" = "stop" ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep "v2ray/v2ray"` ]]
        then
            echoContent green " ---> V2Ray关闭成功"
        else
            echoContent red "V2Ray关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep v2ray|awk '{print \$2}'|xargs kill -9】"
            exit 0;
        fi
    fi
}
# 操作xray
handleXray(){
    if [[ ! -z `find /bin /usr/bin -name "systemctl"` ]] && [[ ! -z `ls /etc/systemd/system/|grep -v grep|grep xray.service` ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep "xray/xray"` ]] && [[ "$1" = "start" ]]
        then
            systemctl start xray.service
        elif [[ ! -z `ps -ef|grep -v grep|grep "xray/xray"` ]] && [[ "$1" = "stop" ]]
        then
            systemctl stop xray.service
        fi
    elif [[ -z `find /bin /usr/bin -name "systemctl"` ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep xray` ]] && [[ "$1" = "start" ]]
        then
            /etc/v2ray-agent/xray/xray -config /etc/v2ray-agent/xray/02_VLESS_TCP_inbounds.json & > /dev/null 2>&1
        elif [[ ! -z `ps -ef|grep -v grep|grep xray` ]] && [[ "$1" = "stop" ]]
        then
            ps -ef|grep -v grep|grep xray|awk '{print $2}'|xargs kill -9
        fi
    fi
    sleep 0.5
    if [[ "$1" = "start" ]]
    then
        if [[ ! -z `ps -ef|grep -v grep|grep "xray/xray"` ]]
        then
            echoContent green " ---> Xray启动成功"
        else
            echoContent red "xray启动失败"
            echoContent red "执行 [ps -ef|grep xray] 查看日志"
            exit 0;
        fi
    elif [[ "$1" = "stop" ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep "xray/xray"` ]]
        then
            echoContent green " ---> Xray关闭成功"
        else
            echoContent red "xray关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep xray|awk '{print \$2}'|xargs kill -9】"
            exit 0;
        fi
    fi
}
# 操作Trojan-Go
handleTrojanGo(){
    if [[ ! -z `find /bin /usr/bin -name "systemctl"` ]] && [[ ! -z `ls /etc/systemd/system/|grep -v grep|grep trojan-go.service` ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep trojan-go` ]] && [[ "$1" = "start" ]]
        then
            systemctl start trojan-go.service
        elif [[ ! -z `ps -ef|grep -v grep|grep trojan-go` ]] && [[ "$1" = "stop" ]]
        then
            systemctl stop trojan-go.service
        fi
    elif [[ -z `find /bin /usr/bin -name "systemctl"` ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep trojan-go` ]] && [[ "$1" = "start" ]]
        then
            /etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config_full.json & > /dev/null 2>&1
        elif [[ ! -z `ps -ef|grep -v grep|grep trojan-go` ]] && [[ "$1" = "stop" ]]
        then
            ps -ef|grep -v grep|grep trojan-go|awk '{print $2}'|xargs kill -9
        fi
    fi
    sleep 0.5
    if [[ "$1" = "start" ]]
    then
        if [[ ! -z `ps -ef|grep -v grep|grep trojan-go` ]]
        then
            echoContent green " ---> Trojan-Go启动成功"
        else
            echoContent red "Trojan-Go启动失败"
            echoContent red "请手动执行【/etc/v2ray-agent/trojan/trojan-go -config /etc/v2ray-agent/trojan/config_full.json】,查看错误日志"
            exit 0;
        fi
    elif [[ "$1" = "stop" ]]
    then
        if [[ -z `ps -ef|grep -v grep|grep trojan-go` ]]
        then
            echoContent green " ---> Trojan-Go关闭成功"
        else
            echoContent red "Trojan-Go关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep trojan-go|awk '{print \$2}'|xargs kill -9】"
            exit 0;
        fi
    fi
}
# 初始化V2Ray 配置文件
initV2RayConfig(){
    echoContent skyBlue "\n进度 $2/${totalProgress} : 初始化V2Ray配置"
    if [[ ! -z "${currentUUID}" ]]
    then
        echo
        read -p "读取到上次安装记录，是否使用上次安装时的UUID ？[y/n]:" historyUUIDStatus
        if [[ "${historyUUIDStatus}" = "y" ]]
        then
            uuid=${currentUUID}
        fi
    else
        uuid=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    fi
    if [[ -z "${uuid}" ]]
    then
        echoContent red "\n ---> uuid读取错误，重新生成"
        uuid=`/etc/v2ray-agent/v2ray/v2ctl uuid`
    fi

    rm -rf /etc/v2ray-agent/v2ray/conf/*
    rm -rf /etc/v2ray-agent/v2ray/config_full.json

    cat << EOF > /etc/v2ray-agent/v2ray/conf/00_log.json
{
  "log": {
    "error": "/etc/v2ray-agent/v2ray/v2ray_error.log",
    "loglevel": "warning"
  }
}
EOF
    # routing
    cat << EOF > /etc/v2ray-agent/v2ray/conf/09_routing.json
{
    "routing":{
        "domainStrategy": "AsIs",
        "rules": [
          {
            "type": "field",
            "protocol": [
              "bittorrent"
            ],
            "outboundTag": "blocked"
          }
        ]
  }
}
EOF
    # outbounds
    if [[ ! -z "${pingIPv6}" ]]
    then
        cat << EOF > /etc/v2ray-agent/v2ray/conf/10_ipv6_outbounds.json
{
    "outbounds": [
        {
          "protocol": "freedom",
          "settings": {},
          "tag": "direct"
        }
    ]
}
EOF
else

    cat << EOF > /etc/v2ray-agent/v2ray/conf/10_ipv4_outbounds.json
{
    "outbounds": [
        {
          "protocol": "freedom",
          "settings": {
            "domainStrategy": "UseIPv4"
          },
          "tag": "IPv4-out"
        }
    ]
}
EOF
fi


    cat << EOF > /etc/v2ray-agent/v2ray/conf/10_bt_outbounds.json
{
    "outbounds": [
        {
          "protocol": "blackhole",
          "settings": {},
          "tag": "blocked"
        }
    ]
}
EOF


    # dns
    cat << EOF > /etc/v2ray-agent/v2ray/conf/11_dns.json
{
    "dns": {
        "servers": [
          "74.82.42.42",
          "8.8.8.8",
          "8.8.4.4",
          "1.1.1.1",
          "localhost"
        ]
  }
}
EOF
    # VLESS_TCP_TLS/XTLS
    # 回落nginx
    local fallbacksList='{"dest":31300,"xver":0}'

    if [[ ! -z `echo ${selectCustomInstallType}|grep 4` || "$1" = "all" ]]
    then
        # 回落trojan-go
        fallbacksList='{"dest":31296,"xver":0}'
    fi

    # VLESS_WS_TLS
    if [[ ! -z `echo ${selectCustomInstallType}|grep 1` || "$1" = "all" ]]
    then
        fallbacksList=${fallbacksList}',{"path":"/'${customPath}'ws","dest":31297,"xver":1}'
        cat << EOF > /etc/v2ray-agent/v2ray/conf/03_VLESS_WS_inbounds.json
{
"inbounds":[
    {
  "port": 31297,
  "listen": "127.0.0.1",
  "protocol": "vless",
  "settings": {
    "clients": [
      {
        "id": "${uuid}",
        "email": "${domain}_vless_ws"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "ws",
    "security": "none",
    "wsSettings": {
      "acceptProxyProtocol": true,
      "path": "/${customPath}ws"
    }
  }
}
]
}
EOF
    fi

    # VMess_TCP
    if [[ ! -z `echo ${selectCustomInstallType}|grep 2` || "$1" = "all"  ]]
    then
        fallbacksList=${fallbacksList}',{"path":"/'${customPath}'tcp","dest":31298,"xver":1}'
        cat << EOF > /etc/v2ray-agent/v2ray/conf/04_VMess_TCP_inbounds.json
{
"inbounds":[
{
  "port": 31298,
  "listen": "127.0.0.1",
  "protocol": "vmess",
  "tag":"VMessTCP",
  "settings": {
    "clients": [
      {
        "id": "${uuid}",
        "alterId": 1,
        "email": "${domain}_vmess_tcp"
      }
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "none",
    "tcpSettings": {
      "acceptProxyProtocol": true,
      "header": {
        "type": "http",
        "request": {
          "path": [
            "/${customPath}tcp"
          ]
        }
      }
    }
  }
}
]
}
EOF
    fi

    # VMess_WS
    if [[ ! -z `echo ${selectCustomInstallType}|grep 3` || "$1" = "all"  ]]
    then
        fallbacksList=${fallbacksList}',{"path":"/'${customPath}'vws","dest":31299,"xver":1}'
        cat << EOF > /etc/v2ray-agent/v2ray/conf/05_VMess_WS_inbounds.json
{
"inbounds":[
{
  "port": 31299,
  "protocol": "vmess",
  "tag":"VMessWS",
  "settings": {
    "clients": [
      {
        "id": "${uuid}",
        "alterId": 1,
        "add": "${add}",
        "email": "${domain}_vmess_ws"
      }
    ]
  },
  "streamSettings": {
    "network": "ws",
    "security": "none",
    "wsSettings": {
      "acceptProxyProtocol": true,
      "path": "/${customPath}vws"
    }
  }
}
]
}
EOF
    fi

    # VLESS_TCP
    if [[ "${selectCoreType}" = "2" ]]
    then
        cat << EOF > /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json
{
  "inbounds":[
    {
      "port": 443,
      "protocol": "vless",
      "tag":"VLESSTCP",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "add": "${add}",
            "email": "${domain}_VLESS_TLS_TCP"
          }
        ],
        "decryption": "none",
        "fallbacks": [
            ${fallbacksList}
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": [
            "http/1.1"
          ],
          "certificates": [
            {
              "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
              "keyFile": "/etc/v2ray-agent/tls/${domain}.key"
            }
          ]
        }
      }
    }
  ]
}
EOF
    elif [[ "${selectCoreType}" = "3" ]]
    then
        cat << EOF > /etc/v2ray-agent/v2ray/conf/02_VLESS_TCP_inbounds.json
{
"inbounds":[
{
  "port": 443,
  "protocol": "vless",
  "tag":"VLESSTCP",
  "settings": {
    "clients": [
     {
        "id": "${uuid}",
        "add":"${add}",
        "flow":"xtls-rprx-direct",
        "email": "${domain}_VLESS_XTLS/TLS-direct_TCP"
      }
    ],
    "decryption": "none",
    "fallbacks": [
        ${fallbacksList}
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "xtls",
    "xtlsSettings": {
      "alpn": [
        "http/1.1"
      ],
      "certificates": [
        {
          "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
          "keyFile": "/etc/v2ray-agent/tls/${domain}.key"
        }
      ]
    }
  }
}
]
}
EOF
    fi
}

# 初始化Xray 配置文件
initXrayConfig(){
    echoContent skyBlue "\n进度 $2/${totalProgress} : 初始化Xray配置"
    if [[ ! -z "${currentUUID}" ]]
    then
        echo
        read -p "读取到上次安装记录，是否使用上次安装时的UUID ？[y/n]:" historyUUIDStatus
        if [[ "${historyUUIDStatus}" = "y" ]]
        then
            uuid=${currentUUID}
        fi
    else
        uuid=`/etc/v2ray-agent/xray/xray uuid`
    fi
    if [[ -z "${uuid}" ]]
    then
        echoContent red "\n ---> uuid读取错误，重新生成"
        uuid=`/etc/v2ray-agent/xray/xray uuid`
    fi

    echoContent green "\n ---> 使用成功"

    rm -rf /etc/v2ray-agent/xray/conf/*

       # log
    cat << EOF > /etc/v2ray-agent/xray/conf/00_log.json
{
  "log": {
    "error": "/etc/v2ray-agent/xray/xray_error.log",
    "loglevel": "warning"
  }
}
EOF
    # routing
    cat << EOF > /etc/v2ray-agent/xray/conf/09_routing.json
{
    "routing":{
        "domainStrategy": "AsIs",
        "rules": [
          {
            "type": "field",
            "protocol": [
              "bittorrent"
            ],
            "outboundTag": "blocked"
          }
        ]
  }
}
EOF

   # outbounds
    if [[ ! -z "${pingIPv6}" ]]
    then
        cat << EOF > /etc/v2ray-agent/xray/conf/10_ipv6_outbounds.json
{
    "outbounds": [
        {
          "protocol": "freedom",
          "settings": {},
          "tag": "direct"
        }
    ]
}
EOF

else
    cat << EOF > /etc/v2ray-agent/xray/conf/10_ipv4_outbounds.json
{
    "outbounds": [
        {
          "protocol": "freedom",
          "settings": {
            "domainStrategy": "UseIPv4"
          },
          "tag": "IPv4-out"
        }
    ]
}
EOF
fi

    cat << EOF > /etc/v2ray-agent/xray/conf/10_bt_outbounds.json
{
    "outbounds": [
        {
          "protocol": "blackhole",
          "settings": {},
          "tag": "blocked"
        }
    ]
}
EOF

    # dns
    cat << EOF > /etc/v2ray-agent/xray/conf/11_dns.json
{
    "dns": {
        "servers": [
          "74.82.42.42",
          "8.8.8.8",
          "8.8.4.4",
          "1.1.1.1",
          "localhost"
        ]
  }
}
EOF
    # VLESS_TCP_TLS/XTLS
    # 回落nginx
    local fallbacksList='{"dest":31300,"xver":0}'

    if [[ ! -z `echo ${selectCustomInstallType}|grep 4` || "$1" = "all" ]]
    then
        # 回落trojan-go
        fallbacksList='{"dest":31296,"xver":0}'
    fi

    # VLESS_WS_TLS
    if [[ ! -z `echo ${selectCustomInstallType}|grep 1` || "$1" = "all" ]]
    then
        fallbacksList=${fallbacksList}',{"path":"/'${customPath}'ws","dest":31297,"xver":1}'
        cat << EOF > /etc/v2ray-agent/xray/conf/03_VLESS_WS_inbounds.json
{
"inbounds":[
    {
  "port": 31297,
  "listen": "127.0.0.1",
  "protocol": "vless",
  "settings": {
    "clients": [
      {
        "id": "${uuid}",
        "email": "${domain}_vless_ws"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "ws",
    "security": "none",
    "wsSettings": {
      "acceptProxyProtocol": true,
      "path": "/${customPath}ws"
    }
  }
}
]
}
EOF
    fi

    # VMess_TCP
    if [[ ! -z `echo ${selectCustomInstallType}|grep 2` || "$1" = "all"  ]]
    then
        fallbacksList=${fallbacksList}',{"path":"/'${customPath}'tcp","dest":31298,"xver":1}'
        cat << EOF > /etc/v2ray-agent/xray/conf/04_VMess_TCP_inbounds.json
{
"inbounds":[
{
  "port": 31298,
  "listen": "127.0.0.1",
  "protocol": "vmess",
  "tag":"VMessTCP",
  "settings": {
    "clients": [
      {
        "id": "${uuid}",
        "alterId": 1,
        "email": "${domain}_vmess_tcp"
      }
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "none",
    "tcpSettings": {
      "acceptProxyProtocol": true,
      "header": {
        "type": "http",
        "request": {
          "path": [
            "/${customPath}tcp"
          ]
        }
      }
    }
  }
}
]
}
EOF
    fi

    # VMess_WS
    if [[ ! -z `echo ${selectCustomInstallType}|grep 3` || "$1" = "all"  ]]
    then
        fallbacksList=${fallbacksList}',{"path":"/'${customPath}'vws","dest":31299,"xver":1}'
        cat << EOF > /etc/v2ray-agent/xray/conf/05_VMess_WS_inbounds.json
{
"inbounds":[
{
  "port": 31299,
  "protocol": "vmess",
  "tag":"VMessWS",
  "settings": {
    "clients": [
      {
        "id": "${uuid}",
        "alterId": 1,
        "add": "${add}",
        "email": "${domain}_vmess_ws"
      }
    ]
  },
  "streamSettings": {
    "network": "ws",
    "security": "none",
    "wsSettings": {
      "acceptProxyProtocol": true,
      "path": "/${customPath}vws"
    }
  }
}
]
}
EOF
    fi

    # VLESS_TCP
    cat << EOF > /etc/v2ray-agent/xray/conf/02_VLESS_TCP_inbounds.json
{
"inbounds":[
{
  "port": 443,
  "protocol": "vless",
  "tag":"VLESSTCP",
  "settings": {
    "clients": [
     {
        "id": "${uuid}",
        "add":"${add}",
        "flow":"xtls-rprx-direct",
        "email": "${domain}_VLESS_XTLS/TLS-direct_TCP"
      }
    ],
    "decryption": "none",
    "fallbacks": [
        ${fallbacksList}
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "xtls",
    "xtlsSettings": {
      "minVersion": "1.2",
      "alpn": [
        "http/1.1"
      ],
      "certificates": [
        {
          "certificateFile": "/etc/v2ray-agent/tls/${domain}.crt",
          "keyFile": "/etc/v2ray-agent/tls/${domain}.key",
          "ocspStapling": 3600,
          "usage":"encipherment"
        }
      ]
    }
  }
}
]
}
EOF
}

# 初始化Trojan-Go配置
initTrojanGoConfig(){

    echoContent skyBlue "\n进度 $1/${totalProgress} : 初始化Trojan配置"
    cat << EOF > /etc/v2ray-agent/trojan/config_full.json
{
    "run_type": "server",
    "local_addr": "127.0.0.1",
    "local_port": 31296,
    "remote_addr": "127.0.0.1",
    "remote_port": 31300,
    "disable_http_check":true,
    "log_level":3,
    "log_file":"/etc/v2ray-agent/trojan/trojan.log",
    "password": [
        "${uuid}"
    ],
    "dns":[
        "74.82.42.42",
        "8.8.8.8",
        "8.8.4.4",
        "1.1.1.1",
        "localhost"
    ],
    "transport_plugin":{
        "enabled":true,
        "type":"plaintext"
    },
    "websocket": {
        "enabled": true,
        "path": "/${customPath}tws",
        "host": "${domain}",
        "add":"${add}"
    },
    "router": {
        "enabled": false
    }
}
EOF
}

# 自定义CDN IP
customCDNIP(){
    echoContent skyBlue "\n进度 $1/${totalProgress} : 添加DNS智能解析"
    echoContent yellow "\n 移动:104.19.45.117"
    echoContent yellow " 联通:amp.cloudflare.com"
    echoContent yellow " 电信:www.digitalocean.com"
    echoContent skyBlue "----------------------------"
    read -p '是否使用？[y/n]:' dnsProxy
    if [[ "${dnsProxy}" = "y" ]]
    then
        add="domain08.qiu4.ml"
        echoContent green "\n ---> 使用成功"
    else
        add="${domain}"
    fi
}

# 通用
defaultBase64Code(){
    local type=$1
    local ps=$2
    local id=$3
    local hostPort=$4
    local host=
    local port=
    if [[ ! -z `echo ${hostPort}|grep ":"` ]]
    then
        host=`echo ${hostPort}|awk -F "[:]" '{print $1}'`
        port=`echo ${hostPort}|awk -F "[:]" '{print $2}'`
    else
        host=${hostPort}
        port=443
    fi

    local path=$5
    local add=$6
    if [[ "${type}" = "vlesstcp" ]]
    then
        local VLESSID=`echo ${id}|awk -F "[\"]" '{print $2}'`
        local VLESSEmail=`echo ${ps}|awk -F "[\"]" '{print $2}'`
        if [[ "${coreInstallType}" = "1" ]]
        then
            echoContent yellow " ---> 通用格式(VLESS+TCP+TLS/xtls-rprx-direct)"
            echoContent green "    vless://${VLESSID}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&flow=xtls-rprx-direct#${VLESSEmail}\n"
            echoContent yellow " ---> 二维码 VLESS(VLESS+TCP+TLS/xtls-rprx-direct)"
            echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${VLESSID}%40${host}%3A${port}%3F${encryption}%3Dnone%26security%3Dxtls%26type%3Dtcp%26${host}%3D${host}%26headerType%3Dnone%26flow%3Dxtls-rprx-direct%23${VLESSEmail}\n"

            echoContent yellow " ---> 通用格式(VLESS+TCP+TLS/xtls-rprx-splice)"
            echoContent green "    vless://${VLESSID}@${host}:${port}?encryption=none&security=xtls&type=tcp&host=${host}&headerType=none&flow=xtls-rprx-splice#${VLESSEmail}\n"
            echoContent yellow " ---> 二维码 VLESS(VLESS+TCP+TLS/xtls-rprx-splice)"
            echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${VLESSID}%40${host}%3A${port}%3F${encryption}%3Dnone%26security%3Dxtls%26type%3Dtcp%26${host}%3D${host}%26headerType%3Dnone%26flow%3Dxtls-rprx-splice%23${VLESSEmail}\n"

        elif [[ "${coreInstallType}" = "2" || "${coreInstallType}" = "3" ]]
        then
            echoContent yellow " ---> 通用格式(VLESS+TCP+TLS)"
            echoContent green "    vless://${VLESSID}@${host}:${port}?security=tls&encryption=none&host=${host}&headerType=none&type=tcp#${VLESSEmail}\n"
            echoContent yellow " ---> 二维码 VLESS(VLESS+TCP+TLS)"
            echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3a%2f%2f${VLESSID}%40${host}%3a${port}%3fsecurity%3dtls%26encryption%3dnone%26host%3d${host}%26headerType%3dnone%26type%3dtcp%23${VLESSEmail}\n"
        fi

    elif [[ "${type}" = "vmessws" ]]
    then
        qrCodeBase64Default=`echo -n '{"port":"'${port}'","ps":'${ps}',"tls":"tls","id":'"${id}"',"aid":"1","v":"2","host":"'${host}'","type":"none","path":"/'${path}'","net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent yellow " ---> 通用json(VMess+WS+TLS)"
        echoContent green '    {"port":"'${port}'","ps":'${ps}',"tls":"tls","id":'"${id}"',"aid":"1","v":"2","host":"'${host}'","type":"none","path":"/'${path}'","net":"ws","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'"}\n'
        echoContent yellow " ---> 通用vmess(VMess+WS+TLS)链接"
        echoContent green "    vmess://${qrCodeBase64Default}\n"
        echoContent yellow " ---> 二维码 vmess(VMess+WS+TLS)"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

    elif [[ "${type}" = "vmesstcp" ]]
    then
        qrCodeBase64Default=`echo -n '{"port":"'${port}'","ps":'${ps}',"tls":"tls","id":'"${id}"',"aid":"1","v":"2","host":"'${host}'","type":"http","path":"/'${path}'","net":"tcp","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'","obfs":"http","obfsParam":"'${host}'"}'|sed 's#/#\\\/#g'|base64`
        qrCodeBase64Default=`echo ${qrCodeBase64Default}|sed 's/ //g'`
        echoContent yellow " ---> 通用json(VMess+TCP+TLS)"
        echoContent green '    {"port":"'${port}'","ps":'${ps}',"tls":"tls","id":'"${id}"',"aid":"1","v":"2","host":"'${host}'","type":"http","path":"/'${path}'","net":"tcp","add":"'${add}'","allowInsecure":0,"method":"none","peer":"'${host}'","obfs":"http","obfsParam":"'${host}'"}\n'
        echoContent yellow " ---> 通用vmess(VMess+TCP+TLS)链接"
        echoContent green "    vmess://${qrCodeBase64Default}\n"
        echoContent yellow " ---> 二维码 vmess(VMess+TCP+TLS)"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vmess://${qrCodeBase64Default}\n"

    elif [[ "${type}" = "vlessws" ]]
    then
        local VLESSID=`echo ${id}|awk -F "[\"]" '{print $2}'`
        local VLESSEmail=`echo ${ps}|awk -F "[\"]" '{print $2}'`
        echoContent yellow " ---> 通用格式(VLESS+WS+TLS)"
        echoContent green "    vless://${VLESSID}@${add}:${port}?encryption=none&security=tls&type=ws&host=${host}&path=%2f${path}#${VLESSEmail}\n"

        echoContent yellow " ---> 二维码 VLESS(VLESS+TCP+TLS/XTLS)"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless%3A%2F%2F${VLESSID}%40${add}%3A${port}%3Fencryption%3Dnone%26security%3Dtls%26type%3Dws%26host%3D${host}%26path%3D%252f${path}%23${VLESSEmail}"

    elif [[ "${type}" = "trojan" ]]
    then
        # URLEncode
        echoContent yellow " ---> Trojan(TLS)"
        echoContent green "    trojan://${id}@${host}:${port}?peer=${host}&sni=${host}\n"
        echoContent yellow " ---> 二维码 Trojan(TLS)"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${host}%3a${port}%3fpeer%3d${host}%26sni%3d${host}%23${host}_trojan\n"

    elif [[ "${type}" = "trojangows" ]]
    then
        # URLEncode
        echoContent yellow " ---> Trojan-Go(WS+TLS) Shadowrocket"
        echoContent green "    trojan://${id}@${add}:${port}?allowInsecure=0&&peer=${host}&sni=${host}&plugin=obfs-local;obfs=websocket;obfs-host=${host};obfs-uri=${path}#${host}_trojan_ws\n"
        echoContent yellow " ---> 二维码 Trojan-Go(WS+TLS) Shadowrocket"
        echoContent green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${id}%40${add}%3a${port}%3fallowInsecure%3d0%26peer%3d${host}%26plugin%3dobfs-local%3bobfs%3dwebsocket%3bobfs-host%3d${host}%3bobfs-uri%3d${path}%23${host}_trojan_ws\n"

        path=`echo ${path}|awk -F "[/]" '{print $2}'`
        echoContent yellow " ---> Trojan-Go(WS+TLS) QV2ray"
        echoContent green "    trojan-go://${id}@${add}:${port}?sni=${host}&type=ws&host=${host}&path=%2F${path}#${host}_trojan_ws\n"
    fi
}

# 账号
showAccounts(){
    readInstallType
    readConfigHostPathUUID
    readInstallProtocolType
    echoContent skyBlue "\n进度 $1/${totalProgress} : 账号"

    # VLESS TCP
    if [[ ! -z "${configPath}" ]] && [[ ! -z `echo ${currentInstallProtocolType} | grep 0` || -z "${currentInstallProtocolType}"  ]]
    then
        echoContent skyBlue "\n===================== VLESS TCP TLS/XTLS-direct/XTLS-splice ======================\n"

        cat ${configPath}02_VLESS_TCP_inbounds.json|jq .inbounds[0].settings.clients|jq -c '.[]'|while read user
        do
            defaultBase64Code vlesstcp `echo ${user}|jq .email` `echo ${user}|jq .id` "${currentHost}:${currentPort}" ${currentHost}
        done
    fi

    # VLESS WS
    if [[ ! -z "${configPath}" ]] && [[ ! -z `echo ${currentInstallProtocolType} | grep 1` || -z "${currentInstallProtocolType}"  ]]
    then
        echoContent skyBlue "\n================================ VLESS WS TLS CDN ================================\n"

        cat ${configPath}03_VLESS_WS_inbounds.json|jq .inbounds[0].settings.clients|jq -c '.[]'|while read user
        do
            defaultBase64Code vlessws `echo ${user}|jq .email` `echo ${user}|jq .id` "${currentHost}:${currentPort}" "${currentPath}ws" ${currentAdd}
        done
    fi

    # VMess TCP
    if [[ ! -z "${configPath}" ]] && [[ ! -z `echo ${currentInstallProtocolType}|grep 2` || -z "${currentInstallProtocolType}"  ]]
    then
        echoContent skyBlue "\n================================= VMess TCP TLS  =================================\n"

        cat ${configPath}04_VMess_TCP_inbounds.json|jq .inbounds[0].settings.clients|jq -c '.[]'|while read user
        do
            defaultBase64Code vmesstcp `echo ${user}|jq .email` `echo ${user}|jq .id` "${currentHost}:${currentPort}" "${currentPath}tcp" "${currentHost}"
        done
    fi
    # VMess WS
    if [[ ! -z "${configPath}" ]] && [[ ! -z `echo ${currentInstallProtocolType} | grep 3` || -z "${currentInstallProtocolType}"  ]]
    then
        echoContent skyBlue "\n================================ VMess WS TLS CDN ================================\n"

        cat ${configPath}05_VMess_WS_inbounds.json|jq .inbounds[0].settings.clients|jq -c '.[]'|while read user
        do
            defaultBase64Code vmessws `echo ${user}|jq .email` `echo ${user}|jq .id` "${currentHost}:${currentPort}" "${currentPath}vws" ${currentAdd}
        done
    fi

    # trojan-go
    if [[ -d "/etc/v2ray-agent/" ]] && [[ -d "/etc/v2ray-agent/trojan/" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]]
    then
        showStatus=true
#        local trojanUUID=`cat /etc/v2ray-agent/trojan/config_full.json |jq .password[0]|awk -F '["]' '{print $2}'`
        local trojanGoPath=`cat /etc/v2ray-agent/trojan/config_full.json|jq .websocket.path|awk -F '["]' '{print $2}'`
        local trojanGoAdd=`cat /etc/v2ray-agent/trojan/config_full.json|jq .websocket.add|awk -F '["]' '{print $2}'`
        echoContent skyBlue "\n==================================  Trojan TLS  ==================================\n"
        cat /etc/v2ray-agent/trojan/config_full.json |jq .password|while read user
        do
            trojanUUID=`echo ${user}|awk -F '["]' '{print $2}'`
            if [[ ! -z "${trojanUUID}" ]]
            then
                defaultBase64Code trojan trojan ${trojanUUID} ${currentHost}
            fi
        done


        echoContent skyBlue "\n================================  Trojan WS TLS   ================================\n"
        if [[ -z ${trojanGoAdd} ]]
        then
            trojanGoAdd=${currentHost}
        fi

        cat /etc/v2ray-agent/trojan/config_full.json |jq .password|while read user
        do
            trojanUUID=`echo ${user}|awk -F '["]' '{print $2}'`
            if [[ ! -z "${trojanUUID}" ]]
            then
                defaultBase64Code trojangows trojan ${trojanUUID} ${currentHost} ${trojanGoPath} ${trojanGoAdd}
            fi

        done
    fi

}

# 更新伪装站
updateNginxBlog(){
    echoContent skyBlue "\n进度 $1/${totalProgress} : 更换伪装站点"
    echoContent red "=============================================================="
    echoContent yellow "# 如需自定义，请手动复制模版文件到 /usr/share/nginx/html \n"
    echoContent yellow "1.数据统计模版"
    echoContent yellow "2.下雪动画用户注册登录模版"
    echoContent yellow "3.物流大数据服务平台模版"
    echoContent yellow "4.植物花卉模版"
    echoContent red "=============================================================="
    read -p "请选择：" selectInstallNginxBlogType

    if [[ "${selectInstallNginxBlogType}" =~ ^[1-4]$ ]]
    then
        rm -rf /usr/share/nginx/html
        if [[ ! -z `wget --help|grep show-progress` ]]
        then
            wget -c -q --show-progress -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${selectInstallNginxBlogType}.zip > /dev/null
        else
            wget -c -P --show-progress -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${selectInstallNginxBlogType}.zip > /dev/null
        fi

        unzip -o  /usr/share/nginx/html${selectInstallNginxBlogType}.zip -d /usr/share/nginx/html > /dev/null
        rm -f /usr/share/nginx/html${selectInstallNginxBlogType}.zip*
        echoContent green " ---> 更换伪装博客成功"
    else
        echoContent red " ---> 选择错误，请重新选择"
        updateNginxBlog
    fi
}

# 卸载脚本
unInstall(){
    read -p "是否确认卸载安装内容？[y/n]:" unInstallStatus
    if [[ "${unInstallStatus}" != "y" ]]
    then
        echoContent green " ---> 放弃卸载"
        menu
        exit;
    fi

    handleNginx stop
    if [[ -z `ps -ef|grep -v grep|grep nginx` ]]
    then
        echoContent green " ---> 停止Nginx成功"
    fi

    handleV2Ray stop
    handleTrojanGo stop
    rm -rf /etc/systemd/system/v2ray.service
    echoContent green " ---> 删除V2Ray开机自启完成"
    rm -rf /etc/systemd/system/trojan-go.service
    echoContent green " ---> 删除Trojan-Go开机自启完成"
    rm -rf /tmp/v2ray-agent-tls/*
    if [[ -d "/etc/v2ray-agent/tls" ]] && [[ ! -z `find /etc/v2ray-agent/tls/ -name "*.key"` ]] && [[ ! -z `find /etc/v2ray-agent/tls/ -name "*.crt"` ]]
    then
        mv /etc/v2ray-agent/tls /tmp/v2ray-agent-tls
        if [[ ! -z `find /tmp/v2ray-agent-tls -name '*.key'` ]]
        then
            echoContent yellow " ---> 备份证书成功，请注意留存。[/tmp/v2ray-agent-tls]"
        fi
    fi

    rm -rf /etc/v2ray-agent
    rm -rf /etc/nginx/conf.d/alone.conf
    rm -rf /usr/bin/vasma
    rm -rf /usr/sbin/vasma
    echoContent green " ---> 卸载快捷方式完成"
    echoContent green " ---> 卸载v2ray-agent完成"
}

# 修改V2Ray CDN节点
updateV2RayCDN(){

    # todo 重构此方法
    echoContent skyBlue "\n进度 $1/${totalProgress} : 修改CDN节点"

    if [[ ! -z ${currentAdd} ]]
    then
        echoContent red "=============================================================="
        echoContent yellow "1.CNAME www.digitalocean.com"
        echoContent yellow "2.CNAME amp.cloudflare.com"
        echoContent yellow "3.CNAME domain08.qiu4.ml"
        echoContent yellow "4.手动输入"
        echoContent red "=============================================================="
        read -p "请选择:" selectCDNType
        case ${selectCDNType} in
        1)
            setDomain="www.digitalocean.com"
        ;;
        2)
            setDomain="amp.cloudflare.com"
        ;;
        3)
            setDomain="domain08.qiu4.ml"
        ;;
        4)
            read -p "请输入想要自定义CDN IP或者域名:" setDomain
        ;;
        esac

        if [[ ! -z ${setDomain} ]]
        then
            if [[ ! -z ${currentAdd} ]]
            then
                sed -i "s/\"${currentAdd}\"/\"${setDomain}\"/g"  `grep "${currentAdd}" -rl ${configPath}02_VLESS_TCP_inbounds.json`
            fi

            if [[ `cat ${configPath}02_VLESS_TCP_inbounds.json|grep -v grep|grep add|awk -F '["]' '{print $4}'` = ${setDomain} ]]
            then
                echoContent green " ---> CDN修改成功"
                if [[ "${coreInstallType}" = "1" ]]
                then
                    handleXray stop
                    handleXray start
                elif [[ "${coreInstallType}" = "2" || "${coreInstallType}" = "3" ]]
                then
                    handleV2Ray stop
                    handleV2Ray start
                fi

            else
                echoContent red " ---> 修改CDN失败"
            fi

            # trojan
            if [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]]
            then
                add=`cat /etc/v2ray-agent/trojan/config_full.json|jq .websocket.add|awk -F '["]' '{print $2}'`
                if [[ ! -z ${add} ]]
                then
                    sed -i "s/${add}/${setDomain}/g"  `grep "${add}" -rl /etc/v2ray-agent/trojan/config_full.json`
                fi
            fi

            if [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]] && [[ `cat /etc/v2ray-agent/trojan/config_full.json|jq .websocket.add|awk -F '["]' '{print $2}'` = ${setDomain} ]]
            then
                echoContent green "\n ---> Trojan CDN修改成功"
                handleTrojanGo stop
                handleTrojanGo start
            elif [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config_full.json" ]]
            then
                echoContent red " ---> 修改Trojan CDN失败"
            fi
        fi
    else
        echoContent red " ---> 未安装可用类型"
    fi
    menu
}

# manageUser 用户管理
manageUser(){
    echoContent skyBlue "\n进度 $1/${totalProgress} : 多用户管理"
    echoContent skyBlue "-----------------------------------------------------"
    echoContent yellow "1.添加用户"
    echoContent yellow "2.删除用户"
    echoContent skyBlue "-----------------------------------------------------"
    read -p "请选择：" manageUserType
    if [[ "${manageUserType}" = "1" ]]
    then
        addUser
    elif [[ "${manageUserType}" = "2" ]]
    then
        removeUser
    else
        echoContent red " ---> 选择错误"
    fi
}

# 自定义uuid
customUUID(){
    read -p "是否自定义UUID ？[y/n]:" customUUIDStatus
    echo
    if [[ "${customUUIDStatus}" = "y" ]]
    then
        read -p "请输入合法的UUID:" currentCustomUUID
        echo
        if [[ -z "${currentCustomUUID}" ]]
        then
            echoContent red " ---> UUID不可为空"
        else
            local repeat=
            cat ${configPath}02_VLESS_TCP_inbounds.json|jq '.inbounds[0].settings.clients[].id'|awk -F "[\"]" '{print $2}'|while read line
            do
                if [[ "${line}" = "${currentCustomUUID}" ]]
                then
                    echo repeat >/tmp/v2ray-agent
                fi
            done
            if [[ -f "/tmp/v2ray-agent" && ! -z `cat /tmp/v2ray-agent` ]]
            then
                echoContent red " ---> UUID不可重复"
                rm /tmp/v2ray-agent
                exit;
            fi
        fi
    fi
}

# 自定义email
customUserEmail(){
    read -p "是否自定义email ？[y/n]:" customEmailStatus
    echo
    if [[ "${customEmailStatus}" = "y" ]]
    then
        read -p "请输入合法的email:" currentCustomEmail
        echo
        if [[ -z "${currentCustomEmail}" ]]
        then
            echoContent red " ---> email不可为空"
        else
            local repeat=
            cat ${configPath}02_VLESS_TCP_inbounds.json|jq '.inbounds[0].settings.clients[].email'|awk -F "[\"]" '{print $2}'|while read line
            do
                if [[ "${line}" = "${currentCustomEmail}" ]]
                then
                    echo repeat >/tmp/v2ray-agent
                fi
            done
            if [[ -f "/tmp/v2ray-agent" && ! -z `cat /tmp/v2ray-agent` ]]
            then
                echoContent red " ---> email不可重复"
                rm /tmp/v2ray-agent
                exit;
            fi
        fi
    fi
}

# 添加用户
addUser(){
    read -p "请输入要添加的用户数量：" userNum
    echo
    if [[ -z ${userNum} || ${userNum} -le 0 ]]
    then
        echoContent red " ---> 输入有误，请重新输入"
        exit
    fi

    # 生成用户
    local users=
    local trojanGoUsers=
    if [[ "${userNum}" = "1" ]]
    then
        customUUID
        customUserEmail
    fi

    while [[ ${userNum} -gt 0 ]]
    do
        let userNum--
        if [[ ! -z "${currentCustomUUID}" ]]
        then
            uuid=${currentCustomUUID}
        else
            uuid=`${ctlPath} uuid`
        fi

        if [[ ! -z "${currentCustomEmail}" ]]
        then
            email=${currentCustomEmail}
        else
            email=${currentHost}_${uuid}
        fi

        if [[ ${userNum} = 0 ]]
        then
            users=${users}{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-direct\",\"email\":\"${email}\"}

            if [[ ! -z `echo ${currentInstallProtocolType}|grep 4` ]]
            then
                trojanGoUsers=${trojanGoUsers}\"${uuid}\"
            fi
        else
            users=${users}{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-direct\",\"email\":\"${email}\"},

            if [[ ! -z `echo ${currentInstallProtocolType}|grep 4` ]]
            then
                trojanGoUsers=${trojanGoUsers}\"${uuid}\",
            fi
        fi

    done
    # 兼容v2ray-core
    if [[ "${coreInstallType}" = "2" ]]
    then
        users=`echo ${users}|sed 's/"flow":"xtls-rprx-direct",/"alterId":1,/g'`
    fi

    if [[ ! -z `echo ${currentInstallProtocolType} | grep 0` ]]
    then
        local vlessUsers=`echo ${users}|sed 's/"alterId":1,//g'`
        local vlessTcpResult=`cat ${configPath}02_VLESS_TCP_inbounds.json|jq -r '.inbounds[0].settings.clients += ['${vlessUsers}']'`
        echo ${vlessTcpResult} | jq . > ${configPath}02_VLESS_TCP_inbounds.json
    fi

    users=`echo ${users}|sed 's/"flow":"xtls-rprx-direct",/"alterId":1,/g'`

    if [[ ! -z `echo ${currentInstallProtocolType} | grep 1` ]]
    then
        local vlessUsers=`echo ${users}|sed 's/"alterId":1,//g'`
        local vlessWsResult=`cat ${configPath}03_VLESS_WS_inbounds.json|jq -r '.inbounds[0].settings.clients += ['${vlessUsers}']'`
        echo ${vlessWsResult}|jq . > ${configPath}03_VLESS_WS_inbounds.json
    fi

    if [[ ! -z `echo ${currentInstallProtocolType}|grep 2` ]]
    then
        local vmessTcpResult=`cat ${configPath}04_VMess_TCP_inbounds.json|jq -r '.inbounds[0].settings.clients += ['${users}']'`
        echo ${vmessTcpResult}|jq . > ${configPath}04_VMess_TCP_inbounds.json
    fi

    if [[ ! -z `echo ${currentInstallProtocolType} | grep 3` ]]
    then
        local vmessWsResult=`cat ${configPath}05_VMess_WS_inbounds.json|jq -r '.inbounds[0].settings.clients += ['${users}']'`
        echo ${vmessWsResult}|jq . > ${configPath}05_VMess_WS_inbounds.json
    fi

    if [[ ! -z `echo ${currentInstallProtocolType} | grep 4` ]]
    then
        local trojanResult=`cat ${configPath}../../trojan/config_full.json|jq -r '.password += ['${trojanGoUsers}']'`
        echo ${trojanResult}|jq . > ${configPath}../../trojan/config_full.json
        handleTrojanGo stop
        handleTrojanGo start
    fi


    if [[ "${coreInstallType}" = "1" ]]
    then
        handleXray stop
        handleXray start
    elif [[ "${coreInstallType}" = "2" || "${coreInstallType}" = "3" ]]
    then
        handleV2Ray stop
        handleV2Ray start
    fi
    echoContent green " ---> 添加完成"
    showAccounts 1
}

# 移除用户
removeUser(){
    if [[ ! -z `echo ${currentInstallProtocolType} | grep 0` ]]
    then
        cat ${configPath}02_VLESS_TCP_inbounds.json|jq .inbounds[0].settings.clients|jq .[].email|awk -F "[\"]" '{print $2}'|awk '{print NR""":"$0}'
        read -p "请选择要删除的用户编号[仅支持单个删除]:" delUserIndex
        if [[ `cat ${configPath}02_VLESS_TCP_inbounds.json|jq -r '.inbounds[0].settings.clients|length'` -lt ${delUserIndex} ]]
        then
            echoContent red " ---> 选择错误"
        else
            delUserIndex=`expr ${delUserIndex} - 1`
            local vlessTcpResult=`cat ${configPath}02_VLESS_TCP_inbounds.json|jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])'`
            echo ${vlessTcpResult}|jq . > ${configPath}02_VLESS_TCP_inbounds.json
        fi
    fi
    if [[ ! -z "${delUserIndex}" ]]
    then
        if [[ ! -z `echo ${currentInstallProtocolType} | grep 1` ]]
        then
            local vlessTcpResult=`cat ${configPath}03_VLESS_WS_inbounds.json|jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])'`
            echo ${vlessTcpResult}|jq . > ${configPath}03_VLESS_WS_inbounds.json
        fi

        if [[ ! -z `echo ${currentInstallProtocolType}|grep 2` ]]
        then
            local vlessTcpResult=`cat ${configPath}04_VMess_TCP_inbounds.json|jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])'`
            echo ${vlessTcpResult}|jq . > ${configPath}04_VMess_TCP_inbounds.json
        fi

        if [[ ! -z `echo ${currentInstallProtocolType} | grep 3` ]]
        then
            local vlessTcpResult=`cat ${configPath}05_VMess_WS_inbounds.json|jq -r 'del(.inbounds[0].settings.clients['${delUserIndex}'])'`
            echo ${vlessTcpResult}|jq . > ${configPath}05_VMess_WS_inbounds.json
        fi

        if [[ ! -z `echo ${currentInstallProtocolType} | grep 4` ]]
        then
            local trojanResult=`cat ${configPath}../../trojan/config_full.json|jq -r 'del(.password['${delUserIndex}'])'`
            echo ${trojanResult}|jq . > ${configPath}../../trojan/config_full.json
            handleTrojanGo stop
            handleTrojanGo start
        fi
        if [[ "${coreInstallType}" = "1" ]]
        then
            handleXray stop
            handleXray start
        elif [[ "${coreInstallType}" = "2" || "${coreInstallType}" = "3" ]]
        then
            handleV2Ray stop
            handleV2Ray start
        fi
    fi
}
# 更新脚本
updateV2RayAgent(){
    echoContent skyBlue "\n进度  $1/${totalProgress} : 更新v2ray-agent脚本"
    wget -P /etc/v2ray-agent/ -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /etc/v2ray-agent/install.sh && /bin/bash /etc/v2ray-agent/install.sh
}

# 安装BBR
bbrInstall(){
    echoContent red "\n=============================================================="
    echoContent green "BBR脚本用的[ylx2016]的成熟作品，地址[https://github.com/ylx2016/Linux-NetSpeed]，请熟知"
    echoContent red "   1.安装【推荐原版BBR+FQ】"
    echoContent red "   2.回退主目录"
    echoContent red "=============================================================="
    read -p "请选择：" installBBRStatus
    if [[ "${installBBRStatus}" = "1" ]]
    then
        wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    else
        menu
    fi
}

# 查看、检查日志
checkLog(){
    echoContent skyBlue "\n功能 $1/${totalProgress} : 查看日志"
    echoContent red "\n=============================================================="
    local coreType=
    if [[ "${coreInstallType}" = "1" ]]
    then
        coreType=xray/xray

    elif [[ "${coreInstallType}" = "2" || "${coreInstallType}" = "3" ]]
    then
        coreType=v2ray/v2ray
    else
        echoContent red " ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0;
    fi


    echoContent skyBlue "-------------------------V2Ray/Xray--------------------------------"
    echoContent yellow "1.查看error日志"
    echoContent yellow "2.监听error日志"
    echoContent yellow "3.清空日志"
    echoContent skyBlue "-----------------------Trojan-Go------------------------------"
    echoContent yellow "4.查看Trojan-Go日志"
    echoContent yellow "5.监听Trojan-GO日志"
    echoContent yellow "6.清空Trojan-GO日志"
    echoContent skyBlue "-------------------------Nginx--------------------------------"
    echoContent yellow "7.查看Nginx日志"
    echoContent yellow "8.清空Nginx日志"
    echoContent red "=============================================================="


    read -p "请选择：" selectLogType
    case ${selectLogType} in
        1)
            cat /etc/v2ray-agent/xray/xray_error.log
        ;;
        2)
            tail -f /etc/v2ray-agent/xray/xray_error.log
        ;;
        3)
            echo '' > /etc/v2ray-agent/xray/xray_error.log
            echoContent green " ---> 清空完毕"
        ;;
        4)
            cat /etc/v2ray-agent/trojan/trojan.log
        ;;
        5)
            tail -f /etc/v2ray-agent/trojan/trojan.log
        ;;
        6)
            echo '' > /etc/v2ray-agent/trojan/trojan.log
            echoContent green " ---> 清空完毕"
        ;;
        7)
            cat /var/log/nginx/access.log
        ;;
        8)
            echo '' > /var/log/nginx/access.log
        ;;
    esac
    sleep 1
    menu
}

# 脚本快捷方式
aliasInstall(){
    if [[ -f "/root/install.sh" ]] && [[ -d "/etc/v2ray-agent" ]] && [[ ! -z `cat /root/install.sh|grep "作者：mack-a"` ]]
    then
        mv /root/install.sh /etc/v2ray-agent/install.sh
        if [[ -d "/usr/bin/" ]] && [[ ! -f "/usr/bin/vasma" ]]
        then
            ln -s /etc/v2ray-agent/install.sh /usr/bin/vasma
            chmod 700 /usr/bin/vasma
            rm -rf /root/install.sh
        elif [[ -d "/usr/sbin" ]] && [[ ! -f "/usr/sbin/vasma" ]]
        then
            ln -s /etc/v2ray-agent/install.sh /usr/sbin/vasma
            chmod 700 /usr/sbin/vasma
            rm -rf /root/install.sh
        fi
        echoContent green "快捷方式创建成功，可执行[vasma]重新打开脚本"
    fi
}

# 检查ipv6、ipv4
checkIPv6(){
    pingIPv6=`ping6 -c 1 www.google.com|sed '2{s/[^(]*(//;s/).*//;q;}'|tail -n +2`
    if [[ -z "${pingIPv6}" ]]
    then
        echoContent red " ---> 不支持ipv6"
        exit;
    fi
}

# ipv6 人机验证
ipv6HumanVerification(){
    if [[ -z "${configPath}" ]]
    then
        echoContent red " ---> 未安装，请使用脚本安装"
        menu
        exit;
    fi

    checkIPv6
    echoContent skyBlue "\n功能 1/${totalProgress} : ipv6人机验证"
    echoContent red "\n=============================================================="
    echoContent yellow "1.添加"
    echoContent yellow "2.卸载"
    read -p "请选择:" ipv6Status
    if [[ "${ipv6Status}" = "1" ]]
    then
        cat << EOF > ${configPath}09_routing.json
{
    "routing":{
        "domainStrategy": "IPOnDemand",
        "rules": [
          {
            "type": "field",
            "protocol": [
              "bittorrent"
            ],
            "outboundTag": "blocked"
          },
          {
            "type": "field",
            "domain": [
              "domain:google.com",
              "domain:google.com.hk"
            ],
            "outboundTag": "IP6-out"
          }
        ]
  }
}
EOF

        cat << EOF > ${configPath}10_ipv4_outbounds.json
{
  "outbounds": [
    {
          "protocol": "freedom",
          "settings": {
            "domainStrategy": "UseIPv4"
          },
          "tag": "IPv4-out"
    },
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv6"
      },
      "tag": "IP6-out"
    }
  ]
}
EOF
        echoContent green " ---> 人机验证修改成功"

    elif [[ "${ipv6Status}" = "2" ]]
    then
        cat << EOF > ${configPath}09_routing.json
{
    "routing":{
        "domainStrategy": "AsIs",
        "rules": [
          {
            "type": "field",
            "protocol": [
              "bittorrent"
            ],
            "outboundTag": "blocked"
          }
        ]
  }
}
EOF

        cat << EOF > ${configPath}10_ipv4_outbounds.json
{
    "outbounds": [
        {
          "protocol": "freedom",
          "settings": {
            "domainStrategy": "UseIPv4"
          },
          "tag": "IPv4-out"
        }
    ]
}
EOF
        echoContent green " ---> 人机验证卸载成功"
    else
        echoContent red " ---> 选择错误"
        ipv6HumanVerification
        exit
    fi

    if [[ "${coreInstallType}" = "1" ]]
    then
        handleXray stop
        handleXray start

    elif [[ "${coreInstallType}" = "2" || "${coreInstallType}" = "3" ]]
    then
        handleV2Ray stop
        handleV2Ray start
    fi
}

# v2ray-core个性化安装
customV2RayInstall(){
    echoContent skyBlue "\n========================个性化安装============================"
    echoContent yellow "VLESS前置，必须安装0，如果只需要安装0，回车即可"
    if [[ "${selectCoreType}" = "2" ]]
    then
        echoContent yellow "0.VLESS+TLS+TCP"
    else
        echoContent yellow "0.VLESS+TLS/XTLS+TCP"
    fi

    echoContent yellow "1.VLESS+TLS+WS[CDN]"
    echoContent yellow "2.VMess+TLS+TCP"
    echoContent yellow "3.VMess+TLS+WS[CDN]"
    echoContent yellow "4.Trojan、Trojan+WS[CDN]"
    read -p "请选择[多选]，[例如:123]:" selectCustomInstallType
    echoContent skyBlue "--------------------------------------------------------------"
    if [[ -z ${selectCustomInstallType} ]]
    then
        selectCustomInstallType=0
    fi

    if [[ "${selectCustomInstallType}" =~ ^[0-4]+$ ]]
    then
        cleanUp xrayClean
        totalProgress=17
        installTools 1
        # 申请tls
        initTLSNginxConfig 2
        installTLS 3
        handleNginx stop
        initNginxConfig 4
        # 随机path
        if [[ ! -z `echo ${selectCustomInstallType}|grep 1` ]] || [[ ! -z `echo ${selectCustomInstallType}|grep 3` ]] || [[ ! -z `echo ${selectCustomInstallType}|grep 4` ]]
        then
            randomPathFunction 5
            customCDNIP 6
        fi
        nginxBlog 7
        updateRedirectNginxConf
        handleNginx start

        # 安装V2Ray
        installV2Ray 8
        installV2RayService 9
        initV2RayConfig custom 10
        cleanUp xrayDel
        if [[ ! -z `echo ${selectCustomInstallType}|grep 4` ]]
        then
            installTrojanGo 11
            installTrojanService 12
            initTrojanGoConfig 13
            handleTrojanGo stop
            handleTrojanGo start
        else
            # 这里需要删除trojan的服务
            handleTrojanGo stop
            rm -rf /etc/v2ray-agent/trojan/*
            rm -rf /etc/systemd/system/trojan-go.service
        fi
        installCronTLS 14
        handleV2Ray stop
        handleV2Ray start
        # 生成账号
        checkGFWStatue 15
        showAccounts 16
    else
        echoContent red " ---> 输入不合法"
        customV2RayInstall
    fi
}

# Xray-core个性化安装
customXrayInstall(){
    echoContent skyBlue "\n========================个性化安装============================"
    echoContent yellow "VLESS前置，默认安装0，如果只需要安装0，则只选择0即可"
    echoContent yellow "0.VLESS+TLS/XTLS+TCP"
    echoContent yellow "1.VLESS+TLS+WS[CDN]"
    echoContent yellow "2.VMess+TLS+TCP"
    echoContent yellow "3.VMess+TLS+WS[CDN]"
    echoContent yellow "4.Trojan、Trojan+WS[CDN]"
    read -p "请选择[多选]，[例如:123]:" selectCustomInstallType
    echoContent skyBlue "--------------------------------------------------------------"
    if [[ -z ${selectCustomInstallType} ]]
    then
        echoContent red " ---> 不可为空"
        customXrayInstall
    elif [[ "${selectCustomInstallType}" =~ ^[0-4]+$ ]]
    then
        cleanUp v2rayClean
        totalProgress=17
        installTools 1
        # 申请tls
        initTLSNginxConfig 2
        installTLS 3
        handleNginx stop
        initNginxConfig 4
        # 随机path
        if [[ ! -z `echo ${selectCustomInstallType}|grep 1` ]] || [[ ! -z `echo ${selectCustomInstallType}|grep 3` ]] || [[ ! -z `echo ${selectCustomInstallType}|grep 4` ]]
        then
            randomPathFunction 5
            customCDNIP 6
        fi
        nginxBlog 7
        updateRedirectNginxConf
        handleNginx start

        # 安装V2Ray
        installXray 8
        installXrayService 9
        initXrayConfig custom 10
        cleanUp v2rayDel
        if [[ ! -z `echo ${selectCustomInstallType}|grep 4` ]]
        then
            installTrojanGo 11
            installTrojanService 12
            initTrojanGoConfig 13
            handleTrojanGo stop
            handleTrojanGo start
        else
            # 这里需要删除trojan的服务
            handleTrojanGo stop
            rm -rf /etc/v2ray-agent/trojan/*
            rm -rf /etc/systemd/system/trojan-go.service
        fi
        installCronTLS 14
        handleXray stop
        handleXray start
        # 生成账号
        checkGFWStatue 15
        showAccounts 16
    else
        echoContent red " ---> 输入不合法"
        customXrayInstall
    fi
}
# 选择核心安装---v2ray-core、xray-core、锁定版本的v2ray-core[xtls]
selectCoreInstall(){
   
                xrayCoreInstall
}


# v2ray-core 安装
v2rayCoreInstall(){
    cleanUp xrayClean
    selectCustomInstallType=
    totalProgress=17
    installTools 2
    # 申请tls
    initTLSNginxConfig 3
    installTLS 4
    handleNginx stop
    initNginxConfig 5
    randomPathFunction 6
    # 安装V2Ray
    installV2Ray 7
    installV2RayService 8
    installTrojanGo 9
    installTrojanService 10
    customCDNIP 11
    initV2RayConfig all 12
    cleanUp xrayDel
    initTrojanGoConfig 13
    installCronTLS 14
    nginxBlog 15
    updateRedirectNginxConf
    handleV2Ray stop
    sleep 2
    handleV2Ray start
    handleNginx start
    handleTrojanGo stop
    sleep 1
    handleTrojanGo start
    # 生成账号
    checkGFWStatue 16
    showAccounts 17
}

# xray-core 安装
xrayCoreInstall(){
    cleanUp v2rayClean
    selectCustomInstallType=

    totalProgress=17
    installTools 2
    # 申请tls
    initTLSNginxConfig 3
    installTLS 4
    handleNginx stop
    initNginxConfig 5
    randomPathFunction 6
    # 安装Xray
    handleV2Ray stop
    installXray 7
    installXrayService 8
    installTrojanGo 9
    installTrojanService 10
    customCDNIP 11
    initXrayConfig all 12
    cleanUp v2rayDel
    initTrojanGoConfig 13
#    installCronTLS 14
    nginxBlog 15
    updateRedirectNginxConf
    handleXray stop
    sleep 2
    handleXray start

    handleNginx start
    handleTrojanGo stop
    sleep 1
    handleTrojanGo start
    # 生成账号
    install_wordpress
    checkGFWStatue 16
    showAccounts 17
}

# 核心管理
coreVersionManageMenu(){

    if [[ -z "${coreInstallType}" ]]
    then
        echoContent red "\n ---> 没有检测到安装目录，请执行脚本安装内容"
        menu
        exit 0;
    fi
    if [[ "${coreInstallType}" = "1" ]]
    then
        xrayVersionManageMenu 1
    elif [[ "${coreInstallType}" = "2" ]]
    then
        v2rayCoreVersion=
        v2rayVersionManageMenu 1

    elif [[ "${coreInstallType}" = "3" ]]
    then
        v2rayCoreVersion=v4.32.1
        v2rayVersionManageMenu 1
    fi
}
# 定时任务检查证书
cronRenewTLS(){
    if [[ "${renewTLS}" = "RenewTLS" ]]
    then
        renewalTLS
        exit 0;
    fi
}
# 主菜单
menu(){
    cd
    echoContent red "\n=============================================================="
   # echoContent green "作者：mack-a"
   # echoContent green "当前版本：v2.2.24"
   # echoContent green "Github：https://github.com/mack-a/v2ray-agent"
    echoContent green "描述：xray七合一共存脚本+wordpress"
    echoContent green "仅支持centos7!!"
    echoContent red "=============================================================="
    echoContent yellow "1.安装xray+wordpress"
    echoContent skyBlue "-------------------------工具管理-----------------------------"
    echoContent yellow "3.查看账号"
    echoContent yellow "4.更换伪装站"
    echoContent yellow "5.更新证书"
    echoContent yellow "6.更换CDN节点"
    echoContent yellow "7.多用户管理"
    echoContent yellow "8.ipv6人机验证"
    echoContent skyBlue "-------------------------版本管理-----------------------------"
    echoContent yellow "9.core版本管理"
    echoContent yellow "10.更新Trojan-Go"
    echoContent yellow "11.更新脚本"
    echoContent yellow "12.安装BBR"
    echoContent skyBlue "-------------------------脚本管理-----------------------------"
    echoContent yellow "13.查看日志"
    echoContent yellow "14.卸载脚本"
    echoContent red "=============================================================="
    mkdirTools
    aliasInstall
    read -p "请选择:" selectInstallType
     case ${selectInstallType} in
        1)
            selectCoreInstall
        ;;
        2)
            selectCoreInstall
        ;;
        3)
            showAccounts 1
        ;;
        4)
            updateNginxBlog 1
        ;;
        5)
            renewalTLS 1
        ;;
        6)
            updateV2RayCDN 1
        ;;
        7)
            manageUser 1
        ;;
        8)
            ipv6HumanVerification
        ;;
        9)
            coreVersionManageMenu 1
        ;;
        10)
            updateTrojanGo 1
        ;;
        11)
            updateV2RayAgent 1
        ;;
        12)
            bbrInstall
        ;;
        13)
            checkLog 1
        ;;
        14)
            unInstall 1
        ;;
    esac
}
cronRenewTLS
menu
