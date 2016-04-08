#!/bin/bash
SOFT_DIR=/usr/local/src
REDIS=redis-3.0.3.tar.gz
REDIS_PATH=/usr/local/redis
SERVER1=172.16.0.181
SERVER2=172.16.0.182


redis_install() {
	cd $SOFT_DIR
	tar fx $REDIS
	redis=`echo $REDIS |awk -F".tar" ''{print $1}`
	cd $redis
	make && make install
	[ -d $REDIS_PATH ] || mkdir -p $REDIS_PATH
	mkdir -p $REDIS_PATH/{bin,conf,var}
	cp redis.conf $REDIS_PATH/conf/
	cd src/
	cp redis-server $REDIS_PATH/bin/
	redis-benchmark $REDIS_PATH/bin/
	redis-cli $REDIS_PATH/bin/
	cp redis-trib.rb $REDIS_PATH/bin/
}
redis_cluster_set() {
	#SERVER1
	cd $REDIS_PATH
	mkdir ./conf/{7000,7001,7001}
	cp ./conf/redis.conf ./conf/{7000/,7001/,7002/}
	vim ./conf/700{0/1/2}/redis.conf
		daemonize				yes
		pidfile					/usr/local/redis/var/redis_700{0/1/2}.pid
		port					700{0/1/2}
		cluster-enabled			yes
		cluster-config-file		nodes.conf
		cluster-node-timeout	50000
		appendonly				yes
	:wq
	#SERVER2
	cd $REDIS_PATH
	mkdir ./conf/{7003,7004,7005}
	cp ./conf/redis.conf ./conf/{7003/,7004/,7005/}
	vim ./conf/700{3/4/5}/redis.conf
		daemonize				yes
		pidfile					/usr/local/redis/var/redis_700{3/4/5}.pid
		port					700{3/4/5}
		cluster-enabled			yes
		cluster-config-file		nodes.conf
		cluster-node-timeout	50000
		appendonly				yes
	:wq
}
start_redis() {
	#SERVER1
	cd $REDIS_PATH/conf/700{0/1/2} && redis-server redis.conf
	ps -ef |grep redis
	netstat -ntlp |grep redis
	#SERVER2
	cd $REDIS_PATH/conf/700{3/4/5} && redis-server redis.conf
	ps -ef |grep redis
	netstat -ntlp |grep redis
}
create_redis_cluster() {
	yum install -y ruby ruby-devel rubygems rpm-build
	gem install redis
	#create redis cluster master and slave
	$REDIS_PATH/bin/redis-trib.rb create --replicas 1 172.16.0.181:7000 172.16.0.181:7001 172.16.0.181:7002 172.16.0.182:7003 172.16.0.182:7004 172.16.0.182:7005
	#login redis cmd line 
	redis-cli -c -p 7000
	#test
	set hello howareyou
	>get hello
}