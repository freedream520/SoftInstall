#!/bin/bash
config_env_and_var() {
	[ $UID -ne 0 ] && echo "Must be Root to run" && exit 2
	yum install -y gcc* dos2unix tree
	read -p "Pls input the USER to run rsync(default: root):"  user
	[ "$user" == "" ] && user=root
	id $user >/dev/null 2>&1 || (useradd -M -s /sbin/nologin $user && echo "Add $user successed")
	read -p "Pls input the PASSWORD for rsync_user:"  pw
	while :
	do
		read -p "Pls input the PATH to monitor(format: /app/www/):"  path
		if [ "$path" == "" ];then
			echo -e "\033[31mYou must input the PATH.If you don't know,pls connect the Administrator\033[0m"
			continue
		else
			[ ! -d $path ] && (mkdir -p $path && echo "$path had maked successed")
			chown $user.$user $path
			break
		fi
	done
	read -p "Pls input the IP allow to connect rsyncd server:" ip
	read -p "Pls input the MOD for monitor-path(default: [monitor])(format: [www]):"  mod1
	[ "$mod1" == "" ] && mod1=[monitor]
	mod=`echo $mod1 |awk -F "[" '{print $2}' |awk -F "]" '{print $1}'`
}
install_and_set_rsync() 
{
rpm -qa |grep rsync
[ $? -eq 0 ] && echo "Rsync had installed" || yum install -y rsync
echo "$user:$pw" >/etc/rsyncd.pwd && chmod 600 /etc/rsyncd.pwd
echo "#Rsyncd server
#################################
# SET GLOBAL
uid=$user
gid=$user
port=873
use chroot=no
max connections=200
timeout=60
pid file=/var/run/rsyncd.pid
lock file=/var/run/rsyncd.lock
log file=/var/log/rsyncd.log
read only=no
list=no
hosts allow=$ip
hosts deny=*
auth users=$user
secrets file=/etc/rsyncd.pwd
##################################
# ADD MODULE
$mod1
comment=This is my $mod
path=$path" >/etc/rsyncd.conf
}
start_rsyncd() {
	echo "/usr/bin/rsync --daemon" >>/etc/rc.local
	/usr/bin/rsync --daemon
	rsync_status=`netstat -ntlp |grep 873 |grep -v grep |wc -l`
	[ $rsync_status -eq 0 ] && echo "Rsyncd server start failed" || echo "Rsyncd server start successed"	
}

config_env_and_var;install_and_set_rsync
start_rsyncd
