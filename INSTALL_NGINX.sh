
#!/bin/bash
#相关源码包路径
#wget https://nginx.org/download/nginx-1.18.0.tar.gz
. /etc/init.d/functions
SRC_DIR=`pwd`
COLOR='echo -e \E[01;31m'
END='\E[0m'
NGINX='nginx-1.18.0'
SUF='.tar.gz'
INS_DIR=/apps/nginx

check_nginx () {
	if [ $UID -ne 0 ];then
		action "当前用户不是root,安装失败!" false
		exit 
	fi
	cd ${SRC_DIR}
	if [ ! -f $NGINX$SUF ];then
		$COLOR "缺少相关源码包,请将相关源码包放到${SRC_DIR}" $END
		exit
	fi
	if [ `ps -ef |grep nginx|wc -l` -gt 1 ];then
		action "nginx已安装，安装失败" false
		exit
	fi
}

install_nginx () {
	$COLOR "开始安装nginx服务..." $END
	yum -q -y  install wget gcc make pcre-devel openssl-devel zlib-devel &>/dev/null
	tar xf $NGINX$SUF
	cd $NGINX
	./configure \
--prefix=$INS_DIR \
--pid-path=$INS_DIR/run/nginx.pid \
--with-http_ssl_module \
--with-http_v2_module \
--with-http_realip_module \
--with-http_stub_status_module \
--with-http_gzip_static_module \
--with-pcre \
--with-stream \
--with-stream_ssl_module \
--with-stream_realip_module
	make && make install
	id nginx &> /dev/null || { useradd -s /sbin/nologin -r nginx ; action "创建nginx用户"; }
	chown -R nginx.nginx ${INS_DIR}
	sed -ri 's/^#user.*/user nginx;/' ${INS_DIR}/conf/nginx.conf
	ln -s ${INS_DIR}/sbin/nginx /usr/sbin/
	cat > /usr/lib/systemd/system/nginx.service <<EOF
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=${INS_DIR}/run/nginx.pid
ExecStartPre=/usr/bin/rm -f ${INS_DIR}/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP `echo '$MAINPID'`
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=process
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
	sed -ri 's@(^#pid).*@\1  /apps/nginx/run/nginx.pid;@' ${INS_DIR}/conf/nginx.conf
	systemctl daemon-reload
	systemctl enable --now nginx
	[ $? -ne 0 ] && { $COLOR"nginx启动失败，退出!"$END;exit; }
	action "nginx安装完成" 
}

main () {
	check_nginx
	install_nginx
}
main
