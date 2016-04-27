#!/bin/bash
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#Author		liush
#Date		2015-12-31
#Func		install fastdfs service
#Ver		1.0
#Note 		This script is suitable for CentOS6.5 x64 and only support input one tracker-ip and storage-ip
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SOFT_DIR=/usr/local/src/
NGINX_SDIR=/usr/local/src/lnmp/soft/nginx-1.8.0/
NGINX_CMD=/usr/local/nginx/sbin/nginx
FASTDFS=FastDFS_v4.06.tar.gz
FASTDFS_NGINX_MODULE=fastdfs-nginx-module_v1.16.tar.gz

#Collect information from user input
user_input() {
	read -p "Pls choose the service you want to install(default trackerd(T))[trackerd(T)/storaged(S)/trackerd_and_storage(A)] :"  CHOOSE
	[ "$CHOOSE" == "" ] && CHOOSE=T
	read -p "Pls input the path you want install fastdfs to(default /usr/local/fdfs):"  FASTDFS_DDIR
	[ "$FASTDFS_DDIR" == "" ] && FASTDFS_DDIR=/usr/local/fdfs
	[ -d $FASTDFS_DDIR ] || mkdir -p $FASTDFS_DDIR
	read -p "Pls input the path you want config fastdfs in(default /opt/fdfs):"  FASTDFS_DIR
	[ "$FASTDFS_DIR" == "" ] && FASTDFS_DIR=/opt/fdfs
	[ -d $FASTDFS_DIR ] || mkdir -p $FASTDFS_DIR
	read -p "Pls input your website path(default /app/www/):"  WEBDIR
	[ "$WEBDIR" == "" ] && WEBDIR=/app/www/
	[ -d $WEBDIR ] || mkdir -p $WEBDIR
	while :
	do
		read -p "Pls input the ip for fastdfs-tracker(format: 1.1.1.1):"  T_IP
		IP_FORMAT=`echo $T_IP |awk -F. '{print NF}'`
		if [ "$T_IP" == "" ] || [ $IP_FORMAT -ne 4 ];then
			echo "You must input right ip,try again."
			continue
		else
			break
		fi
	done
	while :
	do
		read -p "Pls input the ip for fastdfs-storage(format: 1.1.1.1):"  S_IP
		IP_FORMAT=`echo $S_IP |awk -F. '{print NF}'`
		if [ "$S_IP" == "" ] || [ $IP_FORMAT -ne 4 ];then
			echo "You must input the right ip,try again."
			continue
		else
			break
		fi
	done
	clear
}
check_env() {
	[ $UID -ne 0 ] && (echo "Must be ROOT to run";exit 2)
	TRACKER_DIR=$FASTDFS_DIR/tracker
	STORAGE_DIR=$FASTDFS_DIR/storage
	CLIENT_DIR=$FASTDFS_DIR/client
	[ -d $TRACKER_DIR ] || mkdir -p $TRACKER_DIR
	[ -d $STORAGE_DIR ] || mkdir -p $STORAGE_DIR
	[ -d $CLIENT_DIR ] || mkdir -p $CLIENT_DIR
	id fdfs >/dev/null 2>&1 || (groupadd fdfs && useradd -s /sbin/nologin -M -g fdfs fdfs)
	chown -R fdfs.fdfs $FASTDFS_DIR
	yum install -y gcc* libevent-devel pcre-devel zlib-devel perl
	[ $? -eq 0 ] && echo "yum install successed" || (echo "yum instal failed";exit 1)
	clear
}
fastdfs_install() {
	cd $SOFT_DIR && tar fx $FASTDFS
	fastdfs=`echo $FASTDFS |awk -F "_" '{print $1}'`
	cd $fastdfs
	sed -i "s#TARGET_PREFIX=/usr/local#TARGET_PREFIX=$FASTDFS_DDIR#g" make.sh
	sed -i "s/#WITH_LINUX_SERVICE=1/WITH_LINUX_SERVICE=1/g" make.sh
	./make.sh >/dev/null && ./make.sh install >/dev/null
	[ $? -eq 0 ] && echo "$FASTDFS install successed" || (echo "$FASTDFS install failed";exit 1)
	clear
}
fastdfs_nginx_module_add() {
	cd $SOFT_DIR && tar fx $FASTDFS_NGINX_MODULE
	fastdfs_nginx_module=`echo $FASTDFS_NGINX_MODULE |awk -F "_" '{print $1}'`
	sed -i "s#/usr/local/include/#$FASTDFS_DDIR/include/#g" $fastdfs_nginx_module/src/config
	sed -i "s#/usr/local/lib#$FASTDFS_DDIR/lib#g" $fastdfs_nginx_module/src/config
	echo "$FASTDFS_DDIR/lib" >> /etc/ld.so.conf && ldconfig
	#configure-arguments=
	mv /usr/local/nginx /usr/local/nginx-def
	cd $NGINX_SDIR
	./configure --add-module=/usr/local/src/$fastdfs_nginx_module/src --prefix=/usr/local/nginx --with-http_ssl_module --with-http_stub_status_module --with-http_gzip_static_module --with-http_realip_module --with-http_dav_module --with-http_flv_module --with-http_addition_module --with-http_sub_module
	if [ $? -eq 0 ];then
		make 
		if [ $? -eq 0 ];then
			make install
			if [ $? -eq 0 ];then
				echo "Add nginx module $FASTDFS_NGINX_MODULE successed"
			else
				echo "Nginx re-install failed";exit 1
			fi
		else
			echo "Nginx re-make failed";exit 1
		fi
	else
		echo "Nginx re-configure failed";exit 1
	fi
	clear
}
tracker_set() {
	#Modify service config file
	sed -i "s#/usr/local/bin/#$FASTDFS_DDIR/bin/#g" /etc/init.d/fdfs_trackerd
	#Modify tracker config file
	sed -i "s#base_path=/home/yuqing/fastdfs#base_path=$TRACKER_DIR#g" /etc/fdfs/tracker.conf
	sed -i "s#http.server_port=8080#http.server_port=80#g" /etc/fdfs/tracker.conf
    	sed -i "s/run_by_group=/run_by_group=fdfs/g" /etc/fdfs/tracker.conf
    	sed -i "s/run_by_user=/run_by_user=fdfs/g" /etc/fdfs/tracker.conf
    	#Modify storage_ids config file
    	cp $SOFT_DIR/$fastdfs/conf/storage_ids.conf /etc/fdfs
    	IP_NUM=`echo ${S_IPS} |awk '{print NF}'`
    	echo "100001	group1	$T_IP" >>/etc/fdfs/storage_ids.conf
    	echo "100002	group1	$S_IP" >>/etc/fdfs/storage_ids.conf
    	#echo "100003	group1	$S_IP2" >>/etc/fdfs/storage_ids.conf
    	#Modify client config file
    	sed -i "s#base_path=/home/yuqing/fastdfs#base_path=$CLIENT_DIR#g" /etc/fdfs/client.conf
    	sed -i "s#tracker_server=192.168.0.197:22122#tracker_server=$T_IP:22122#g" /etc/fdfs/client.conf
    	sed -i "s#http.tracker_server_port=8080#http.tracker_server_port=80#g" /etc/fdfs/client.conf
    	sed -i "s/\#\#include http.conf/\#include http.conf/g" /etc/fdfs/client.conf

    	#Add the services to the startup
    	chkconfig fdfs_trackerd on
    	clear
}
storage_set() {
	#Modify service config file
	sed -i "s#/usr/local/bin/#$FASTDFS_DDIR/bin/#g" /etc/init.d/fdfs_storaged
	#Modify storage config file
	sed -i "s#base_path=/home/yuqing/fastdfs#base_path=$STORAGE_DIR#g" /etc/fdfs/storage.conf
	sed -i "s#store_path0=/home/yuqing/fastdfs#store_path0=$STORAGE_DIR#g" /etc/fdfs/storage.conf
	sed -i "s#http.server_port=8888#http.server_port=80#g" /etc/fdfs/storage.conf
	sed -i "s/run_by_group=/run_by_group=fdfs/g" /etc/fdfs/storage.conf
	sed -i "s/run_by_user=/run_by_user=fdfs/g" /etc/fdfs/storage.conf
	sed -i "s/tracker_server=192.168.209.121:22122/tracker_server=$T_IP:22122/g" /etc/fdfs/storage.conf
	#Modify storage_ids config file
	cp $SOFT_DIR/$fastdfs/conf/storage_ids.conf /etc/fdfs
	echo "  100001   group1  $T_IP" >> /etc/fdfs/storage_ids.conf
	echo "  100002   group1  $S_IP" >> /etc/fdfs/storage_ids.conf
	#echo "  100003   group1  $S_IP2" >> /etc/fdfs/storage_ids.conf
	#Modify client config file
	sed -i "s#base_path=/home/yuqing/fastdfs#base_path=$CLIENT_DIR#g" /etc/fdfs/client.conf
	sed -i "s#tracker_server=192.168.0.197:22122#tracker_server=$T_IP:22122#g" /etc/fdfs/client.conf
	sed -i "s/\#\#include http.conf/\#include http.conf/g" /etc/fdfs/client.conf
	sed -i "s#http.tracker_server_port=8080#http.tracker_server_port=80#g" /etc/fdfs/client.conf
	#Add the services to the startup
	chkconfig fdfs_storaged  on
	clear
}
tracker_and_storage_set() {
	#Modify service config file
	sed -i "s#/usr/local/bin/#$FASTDFS_DDIR/bin/#g" /etc/init.d/fdfs_storaged
	sed -i "s#/usr/local/bin/#$FASTDFS_DDIR/bin/#g" /etc/init.d/fdfs_trackerd
	#Modify tracker config file
	sed -i "s#base_path=/home/yuqing/fastdfs#base_path=$TRACKER_DIR#g" /etc/fdfs/tracker.conf
	sed -i "s/run_by_group=/run_by_group=fdfs/g" /etc/fdfs/tracker.conf
	sed -i "s/run_by_user=/run_by_user=fdfs/g" /etc/fdfs/tracker.conf
	sed -i "s#http.server_port=8080#http.server_port=80#g" /etc/fdfs/tracker.conf
	#Modify storage config file
	sed -i "s#base_path=/home/yuqing/fastdfs#base_path=$STORAGE_DIR#g" /etc/fdfs/storage.conf
	sed -i "s#store_path0=/home/yuqing/fastdfs#store_path0=$STORAGE_DIR#g" /etc/fdfs/storage.conf
	sed -i "s#http.server_port=8888#http.server_port=80#g" /etc/fdfs/storage.conf
	sed -i "s/run_by_group=/run_by_group=fdfs/g" /etc/fdfs/storage.conf
	sed -i "s/run_by_user=/run_by_user=fdfs/g" /etc/fdfs/storage.conf
	sed -i "s/tracker_server=192.168.209.121:22122/tracker_server=$T_IP:22122/g" /etc/fdfs/storage.conf
	#Modify storage_ids config file
	cp $SOFT_DIR/$fastdfs/conf/storage_ids.conf /etc/fdfs
	echo "  100001   group1  $T_IP" >> /etc/fdfs/storage_ids.conf
	echo "  100002   group1  $S_IP" >> /etc/fdfs/storage_ids.conf
	#echo "  100003   group1  $S_IP2" >> /etc/fdfs/storage_ids.conf
	#Modify client config file
	sed -i "s#base_path=/home/yuqing/fastdfs#base_path=$CLIENT_DIR#g" /etc/fdfs/client.conf
	sed -i "s#tracker_server=192.168.0.197:22122#tracker_server=$T_IP:22122#g" /etc/fdfs/client.conf
	sed -i "s/\#\#include http.conf/\#include http.conf/g" /etc/fdfs/client.conf
	sed -i "s#http.tracker_server_port=8080#http.tracker_server_port=80#g" /etc/fdfs/client.conf
	#Add the services to the startup 
	chkconfig fdfs_trackerd  on
	chkconfig fdfs_storaged  on
	clear
}
mod_fastdfs_set() {
	cp $SOFT_DIR/$fastdfs_nginx_module/src/mod_fastdfs.conf /etc/fdfs/
	sed -i "s/tracker_server=tracker:22122/tracker_server=$T_IP:22122/g" /etc/fdfs/mod_fastdfs.conf
	sed -i "s#store_path0=/home/yuqing/fastdfs#store_path0=$STORAGE_DIR#g" /etc/fdfs/mod_fastdfs.conf
	sed -i "s/url_have_group_name = false/url_have_group_name = true/g" /etc/fdfs/mod_fastdfs.conf
	sed -i "s/http.need_find_content_type=false/http.need_find_content_type=true/g" /etc/fdfs/mod_fastdfs.conf
	clear
}

#judge services status
service_status() {
	if [ "$CHOOSE" == "trackerd" ] || [ "$CHOOSE" == "T" ];then
	    service fdfs_trackerd start  >/dev/null 2>&1 
	    echo "Service fdfs_trackerd starting................................."
	    sleep 10
	    status1=`netstat -ntlpu |grep fdfs_trackerd |wc -l`
	    if [ "$status1" == "0" ]; then
	        echo -e "\033[31mService fdfs_trackerd is not avlaible,please check your configure!!\033[0m"
	    else
	        echo -e "\033[32mFdfs_trackerd start successed.\033[0m"
	    fi
		#service nginxd start >/dev/null 2>&1 || ${NGINX_CMD}
		#status2=`netstat -nutpl |grep nginx |wc -l`
	    #if [ "$status2" == "0" ];then
	    #    echo -e "\033[31mNginxd is not alvlaible,plase check your configure!!!\033[0m"
	    #else
	    #    echo -e "\033[32mNginxd is started successed.\033[0m"
	    #fi	
	elif [ "$CHOOSE" == "storaged" ] || [ "$CHOOSE" == "S" ];then
		service fdfs_storaged start >/dev/null 2>&1 
		echo "Service fdfs_storaged starting..................................."
	    sleep 10
	    status1=`netstat -ntlpu |grep fdfs_storaged |wc -l`
	    if [ "$status1" == "0" ]; then
	        echo -e "\033[31mService fdfs_storaged is not avlaible,please check your configure!!\033[0m"
	    else
	        echo -e "\033[32mFdfs_storaged start successed.\033[0m"
	    fi
		service nginxd start >/dev/null 2>&1 || ${NGINX_CMD}
		echo "Service nginxd starting.........................................."
		sleep 3
		status2=`netstat -nutpl |grep nginx |wc -l`
	    if [ "$status2" == "0" ];then
	        echo -e "\033[31mNginxd is not alvlaible,plase check your configure!!!\033[0m"
	    else
	        echo -e "\033[32mNginxd is started successed.\033[0m"
	    fi	
	elif [ "$CHOOSE" == "trackerd_and_storage" ] || [ "$CHOOSE" == "A" ];then
		service fdfs_trackerd start  >/dev/null 2>&1 
		echo "Service fdfs_trackerd starting................................."
	    sleep 10
	    status1=`netstat -ntlpu |grep fdfs_trackerd |wc -l`
	    if [ "$status1" == "0" ]; then
	        echo -e "\033[31mService fdfs_trackerd is not avlaible,please check your configure!!\033[0m"
	    else
	        echo -e "\033[32mFdfs_trackerd start successed.\033[0m"
	    fi
		service fdfs_storaged start >/dev/null 2>&1 
		echo "Service fdfs_storaged starting..................................."
	    sleep 10
	    status2=`netstat -ntlpu |grep fdfs_storaged |wc -l`
	    if [ "$status1" == "0" ]; then
	        echo -e "\033[31mService fdfs_storaged is not avlaible,please check your configure!!\033[0m"
	    else
	        echo -e "\033[32mFdfs_storaged start successed.\033[0m"
	    fi
	    service nginxd start >/dev/null 2>&1 || ${NGINX_CMD}
	    echo "Service nginxd starting.........................................."
	    sleep 3
		status3=`netstat -nutpl |grep nginx |wc -l`
	    if [ "$status2" == "0" ];then
	        echo -e "\033[31mNginxd is not alvlaible,plase check your configure!!!\033[0m"
	    else
	        echo -e "\033[32mNginxd is started successed.\033[0m"
	    fi	
	fi
	clear	  
}
nginx_helps() {
cat <<EOF
Pls insert the following fields in the "server" region of nginx config file:

	location /group1/M00 {
        root $WEBDIR;
        ngx_fastdfs_module;
	}
EOF
}
##Begin install
install() {
	user_input
	if [ "$CHOOSE" == "trackerd" ] || [ "$CHOOSE" == "T" ];then 
		check_env;fastdfs_install;tracker_set
		service_status
	#if [ "$CHOOSE" == "trackerd" ] || [ "$CHOOSE" == "T" ];then 
	#	check_env;fastdfs_install;fastdfs_nginx_module_add
	#	tracker_set;mod_fastdfs_set
	#	service_status
	elif [ "$CHOOSE" == "storaged" ] || [ "$CHOOSE" == "S" ];then
		check_env;fastdfs_install;fastdfs_nginx_module_add
		storage_set;mod_fastdfs_set
		ln -s /$STORAGE_DIR/data $WEBDIR/M00
		service_status;nginx_helps
	elif [ "$CHOOSE" == "trackerd_and_storage" ] || [ "$CHOOSE" == "A" ];then
		check_env;fastdfs_install;fastdfs_nginx_module_add
		tracker_and_storage_set;mod_fastdfs_set
		ln -s /$STORAGE_DIR/data $WEBDIR/M00
		service_status;nginx_helps
	fi
}

###############################################################################
install 
clear
