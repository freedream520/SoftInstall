#!/bin/bash
############### ENV ##############
#         disk /dev/sdb1         #
# hostname	node1	172.16.0.183 #
# hostname	node2	172.16.0.184 #
##################################
SOFT_DIR=/usr/local/src/
DRBD=drbd-8.4.1.tar.gz

set_env() {
	#set in node1 and node2
	/etc/init.d/iptables stop
	echo "node1	172.16.0.183" >>/etc/hosts
	echo "node2	172.16.0.184" >>/etc/hosts
	mkdir /drbd
	yum -y install gcc kernel-devel kernel-headers flex
}
drbd_install() {
	#set in node1 and node2
	cd $SOFT_DIR && tar fx $DRBD
	drbd=`echo $DRBD |awk -F ".tar" '{print $1}'`
	cd $drbd
	./configure --prefix=/usr/local/drbd --with-km
	make KDIR=/usr/src/kernels/2.6.32-431.el6.x86_64/
	make install
	mkdir -p /usr/local/drbd/var/run/drbd
	cp /usr/local/drbd/etc/rc.d/init.d/drbd /etc/rc.d/init.d
	#Install drbd module
	cd drbd
	make clean
	make KDIR=/usr/src/kernels/2.6.32-431.el6.x86_64/
	cp drbd.ko /lib/modules/2.6.32-431.el6.x86_64/kernel/lib/
	modprobe drbd
	lsmod |grep drbd
}
set_drbd() {
	#set in node1 and node2
	cd /usr/local/drbd/etc/
	#drbd配置文件
	cat drbd.conf
	# You can find an example in  /usr/share/doc/drbd.../drbd.conf.example
	include "drbd.d/global_common.conf";
	include "drbd.d/*.res";
	#配置全局文件
	vim drbd.d/global_common.conf
	global {
		usage-count		no;#drbd是否启用统计.
		common {
			protocol	C;#使用drbd同步协议
			handlers {
				pri-on-incon-degr "/usr/lib/drbd/notify-pri-on-incon-degr.sh; /usr/lib/drbd/notify-emergency-reboot.sh; echo b > /proc/sysrq-trigger ; reboot -f";
		        pri-lost-after-sb "/usr/lib/drbd/notify-pri-lost-after-sb.sh; /usr/lib/drbd/notify-emergency-reboot.sh; echo b > /proc/sysrq-trigger ; reboot -f";
		        local-io-error "/usr/lib/drbd/notify-io-error.sh; /usr/lib/drbd/notify-emergency-shutdown.sh; echo o > /proc/sysrq-trigger ; halt -f"; 
			}
			startup {
				#wfc-timeout degr-wfc-timeout outdated-wfc-timeout wait-after-sb 
			}
			options {
				#cpu-mask on-no-data-accessible
			}
			disk {
				on-io-error		detach;#配置I/O错误处理策略为分离
			}
			net {
				cram-hmac-alg	"sha1";#设置加密算法
        		shared-secret 	"allendrbd";#设置加密密钥 
			}
			syncer {
				rate	1024M;#设置主备节点同步时的网络速率
			}
		}
	}
	#添加资源文件
	vim	drbd.d/drbd.res
	resource drbd {
		on node1 {
			device		/dev/drbd0;
			disk		/dev/sdb1;
			address		172.16.0.183:7789;
			meta-disk	internal;
		}
		on node2 {
			device		/dev/drbd0;
			disk		/dev/sdb1;
			address		172.16.0.184:7789;
			meta-disk	internal;
		}
	}
}
startup() {
	#set in node1 and node2
	dd if=/dev/zero of=/dev/sdb1 bs=1M count=10
	drbdadm create-md drbd
	service drbd start
	#set in primary(node1)
	drbdadm primary --force drbd 	#设置主节点
	cat /proc/drbd 					#查看节点状态
	mkfs.ext3 /dev/drbd0
	mount /dev/drbd0 /db
}
order() {
	service drbd start 			#启动drbd
	service drbd stop 			#停止drbd
	drbdadm up drbd 			#启动drbd
	drbdadm cstate drbd 		#查看资源连接状态
	drdbadm down drbd 			#停止drbd
	drbdadm role drbd 			#查看资源角色
	drbdadm dstate drbd 		#查看硬盘状态
	drbdadm primary drbd 		#升为主节点
	drbdadm secondary drbd 		#降为备节点
}

drbd说明：

只有主节点才能挂载/dev/drbd0,备节点不可挂载。备节点要挂载/dev/drbd0，必须先升级为主节点，同时原主节点必须降级为备节点。
当需要查看备节点同步主节点的数据是否成功时，可以先在备节点运行service drbd stop，然后挂载/dev/sdb1查看数据。