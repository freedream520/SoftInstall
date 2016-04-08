#!/bin/bash
SOFT_DIR=/usr/local/src/
SERSYNC_PREFIX=/usr/local/sersync
SERSYNC=sersync-x64.tar.gz
config_env_and_var() {
	[ $UID -ne 0 ] && echo "Must be Root to run" && exit 2
	yum install -y gcc* dos2unix tree 
	read -p "Pls input the USER to run rsync(default: root):"  user
	[ "$user" == "" ] && user=root
	[ id $user >/dev/null 2>&1 ] || (useradd -M -s /sbin/nologin $user && echo "Add $user successed")
	read -p "Pls input the PASSWORD for rsync_user:"  pw
	while :
	do
		read -p "Pls input the IP of rsyncd server:"  ip
		if [ "$ip" == "" ];then
			echo -e "\033[31mYou must input the IP of Rsyncd.If you don't know,pls connect the Administrator\033[0m"
			continue
		else
			break
		fi
	done	
	while :
	do
		read -p "Pls input the PATH to monitor(format: /app/www/):"  path
		if [ "$path" == "" ];then
			echo -e "\033[31mYou must input the PATH.If you don't know,pls connect the Administrator\033[0m"
			continue
		else
			[ ! -d $path ] && (mkdir -p $path && echo "$path had maked successed")
			break
		fi
	done
	read -p "Pls input the MOD for monitor-path(default: [monitor])(format: [www]):"  mod1
	mod=`echo $mod1 |awk -F "[" '{print $2}' |awk -F "]" '{print $1}'`
}
install_and_set_rsync() {
	rpm -qa |grep rsync
	[ $? -eq 0 ] && echo "Rsync had installed" || yum install -y rsync
	echo "$pw" >/etc/rsyncd.pwd && chmod 600 /etc/rsyncd.pwd
}
install_and_set_sersync() {
	[ ! -f $SOFT_DIR/$SERSYNC ] && (echo "There is no $SERSYNC";exit 2)
	cd $SOFT_DIR && tar fx $SERSYNC
	sersync=`echo $SERSYNC |awk -F ".tar" '{print $1}'`
	mv $sersync $SERSYNC_PREFIX
	cd $SERSYNC_PREFIX && mkdir -p ./{logs,conf,bin}
	mv sersync* ./bin/sersync
	cp confxml.xml ./conf/${mod}_confxml.xml && mv confxml.xml ./conf/confxml.xml.def
	echo "export PATH=$PATH:$SERSYNC_PREFIX/bin" >>/etc/profile && source /etc/profile
	sed -i 's#<delete start="true"/>#<delete start="false"/>#g' ./conf/${mod}_confxml.xml
	sed -i "s#<localpath watch=\"/opt/tongbu\">#<localpath watch=\"$path\">#g" ./conf/${mod}_confxml.xml
	sed -i "s#<remote ip=\"127.0.0.1\" name=\"tongbu1\"/>#<remote ip=\"$ip\" name=\"$mod\"/>#g" ./conf/${mod}_confxml.xml
	sed -i "s#<auth start=\"false\" users=\"root\" passwordfile=\"/etc/rsync.pas\"/>#<auth start=\"true\" users=\"$user\" passwordfile=\"/etc/rsyncd.pwd\"/>#g" ./conf/${mod}_confxml.xml
	sed -i 's#<timeout start="false" time="100"/>#<timeout start="true" time="100"/>#g' ./conf/${mod}_confxml.xml
	sed -i "s#<failLog path=\"/tmp/rsync_fail_log.sh\" timeToExecute=\"60\"/>#<failLog path=\"$SERSYNC_PREFIX/logs/rsync_fail_log.sh\" timeToExecute=\"60\"/>#g" ./conf/${mod}_confxml.xml
}
start_rsyncd() {
	$SERSYNC_PREFIX/bin/sersync -d -r -o $SERSYNC_PREFIX/conf/${mod}_confxml.xml
	sersync_status=`ps -aux |grep sersync |grep -v grep |wc -l`
	[ $sersync_status -eq 0 ] && echo "Sersync start failed" || echo "Sersync start successed" 
}

config_env_and_var;install_and_set_rsync;install_and_set_sersync
start_rsyncd