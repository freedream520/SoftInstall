#!/bin/bash
SOFT_DIR=/usr/local/src/rsyncd/soft
RSYNC=rsync-3.1.1.tar.gz
RSYNC_PATH=/usr/local/rsync
INOTIFY=inotify-tools-3.14.tar.gz

check_env() {
	[ $UID -ne 0 ] && echo "Must be Root to run" && exit 2
	[ id $user >/dev/null 2>&1 ] || useradd -M -s /sbin/nologin $user
	[ ! -d $floder ] && mkdir $floder
	[ -f /etc/init.d/rsync ] && mv /etc/init.d/rsync /etc/init.d/rsync.bak
	[ -f /etc/init.d/rsyncd ] && mv /etc/init.d/rsyncd /etc/init.d/rsyncd.bak
	yum -y remove rsync >/dev/null 2>&1
	yum install -y gcc* dos2unix 
}
rsync_install() {
	echo "Install $RSYNC now............."
	[ ! -f $SOFT_DIR/$RSYNC ] && echo "There is no $RSYNC" && exit 2
	cd $SOFT_DIR && tar fx $RSYNC
	rsync=`echo $RSYNC |awk -F ".tar" '{print $1}'`
	cd $rsync 
	./configure --prefix=$RSYNC_PATH
	if [ $? -eq 0 ];then
		make && make install
		if [ $? -eq 0 ];then
			echo "$RSYNC install successed"
			ln -s $RSYNC_PATH/bin/rsync /usr/bin/
		else
			echo "$RSYNC make/make install failed";exit 1
		fi
	else
		echo "$RSYNC configure failed";exit 1
	fi
}

inotify_install() {
	echo "Install $INOTIFY now............."
	[ ! -f $SOFT_DIR/$INOTIFY ] && echo "There is no $INOTIFY" && exit 2
	cd $SOFT_DIR && tar fx $INOTIFY
	inotify=`echo $INOTIFY |awk -F ".tar" '{print $1}'`
	cd $inotify
	./configure --prefix=/usr/local/inotify
	if [ $? -eq 0 ];then
		make && make install
		if [ $? -eq 0 ];then
			echo "$INOTIFY install successed"
			ln -s /usr/local/inotify/bin/* /usr/bin/
		else
			echo "$INOTIFY make/make install failed";exit 1
		fi
	else
		echo "$INOTIFY configure failed";exit 1
	fi
}

set_rsync() {
	if [ $choice -eq 1 ];then
		cd $SOFT_DIR/../
		echo "$pw" >$RSYNC_PATH/rsyncd.pw && chmod 600 $RSYNC_PATH/rsyncd.pw
		cp inotify-monitor.sh $RSYNC_PATH/ && dos2unix $RSYNC_PATH/inotify-monitor.sh
		chmod 755 $RSYNC_PATH/inotify-monitor.sh
		sed -i "s/des=/des=$des/" $RSYNC_PATH/inotify-monitor.sh
		sed -i "s/host=/host=$ip/" $RSYNC_PATH/inotify-monitor.sh
		sed -i "s#src=#src=$floder#" $RSYNC_PATH/inotify-monitor.sh
		sed -i "s/user=/user=$user/" $RSYNC_PATH/inotify-monitor.sh
	elif [ $choice -eq 2 ];then
		uid=`ls -ld $floder |awk '{print $3}'`
		gid=`ls -ld $floder |awk '{print $4}'`
		cd $SOFT_DIR/../
		cp rsyncd_server /etc/init.d/rsyncd && dos2unix /etc/init.d/rsyncd && chmod 755 /etc/init.d/rsyncd
		cp rsyncd.conf $RSYNC_PATH/ && dos2unix $RSYNC_PATH/rsyncd.conf && chmod 644 $RSYNC_PATH/rsyncd.conf
		cp rsyncd.motd $RSYNC_PATH/ && dos2unix $RSYNC_PATH/rsyncd.motd && chmod 644 $RSYNC_PATH/rsyncd.motd 
		echo "$user:$pw" >$RSYNC_PATH/rsyncd.pw && chmod 600 $RSYNC_PATH/rsyncd.pw
		sed -i "/path=/i\[$des]" $RSYNC_PATH/rsyncd.conf
		sed -i "s#path=#path=$floder#" $RSYNC_PATH/rsyncd.conf
		sed -i "s/auth users=/auth users=$user/" $RSYNC_PATH/rsyncd.conf
		sed -i "s/uid=root/uid=$uid/" $RSYNC_PATH/rsyncd.conf
		sed -i "s/gid=root/gid=$gid/" $RSYNC_PATH/rsyncd.conf
	fi
}

var_input() {
	if [ $choice -eq 1 ];then
		read -p "Pls input the USER to run rsync:" user
		read -p "Pls input the PASSWORD for user:" pw
		read -p "Pls input the FLODER to monitor(format: /app/www/):" floder
		read -p "Pls input the IP for rsync client:" ip
		read -p "Pls input the inotify DES for monitor-floder:" des
	elif [ $choice -eq 2 ];then
		read -p "Pls input the USER to run rsync:" user
		read -p "Pls input the PASSWORD for user:" pw
		read -p "Pls input the FLODER to monitor(format: /app/www/):" floder
		read -p "Pls input the inotify DES for monitor-floder:" des
	fi
}
#var_input;check_env;rsync_install;inotify_install;set_rsync

cmd_help() 
{
cat << EOF

+++++++++++++++++++++++++++++++++++++++++++++++++++++
 Pls execute allow commond in the applicate env

 Rsync server:
	nohup sh $RSYNC_PATH/inotify-monitor.sh &
	
 Rsync client:
	service rsyncd start
+++++++++++++++++++++++++++++++++++++++++++++++++++++
EOF
}

while :
do 
	clear
	cat << EOF
	++++++  There will be install Rsync  +++++++
	--------------------------------------------
	|******Please Enter Your Choice:[0-2]******|
	--------------------------------------------
	(1)Install for server
	(2)Install for client
	(0)Quit
EOF
	read -p "Pls input your choice:" choice
	case $choice in
		1)
		clear
		var_input;check_env;rsync_install;inotify_install;set_rsync
		clear
		[ $? -eq 0 ] && echo "Rsync install successed" || echo "Rsync install failed"
		cmd_help
		exit 0
		;;
		2)
		clear
		var_input;check_env;rsync_install;set_rsync
		clear
		[ $? -eq 0 ] && echo "Rsync install successed" || echo "Rsync install failed"
		cmd_help
		exit 0
		;;
		0|*)
		clear
		exit 0
		;;
	esac
done
