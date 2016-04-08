#!/bin/bash
LOCALIP=172.16.0.%
MYSQLIP=172.16.0.181
USER=redmine
MYSQL_USER=root
PW='redmineadmin'
MYSQL_PW='mysqladmin'
DATABASE=redmine
SOFT_DIR=/usr/local/src
RUBY=ruby-2.0.0-p353.tar.gz
RUBYGEM=rubygems-2.5.1.tgz
REDMINE=redmine-3.1.1.tar.gz
WEBROOT=/var/www/html/

check() {
	id www >/dev/null 2>&1 || useradd www
	echo "wwwadmin" |passwd --stdin www
	echo "www    ALL=(ALL)       ALL" >>/etc/sudoers
	yum install -y gcc gcc-c++ make automake autoconf curl-devel openssl openssl-devel zlib-devel ImageMagick-devel mysql mysql-devel
}

setmysql() {
	mysqladmin -u$MYSQL_USER -p$MYSQL_PW create $DATABASE
	mysql -u$MYSQL_USER -p$MYSQL_PW -e "grant all privileges on $DATABASE.* to \'$USER\'@\'$LOCALIP\' identified by \'$PWD\' with grant option"
	mysql -u$MYSQL_USER -p$MYSQL_PW -e "grant all privileges on redmine.* to 'redmine'@'172.16.0.181' identified by 'redmineadmin' with grant option"
	mysqladmin -u$MYSQL_USER -p$MYSQL_PW flush-privileges
}
rubyinstall() {
	cd $SOFT_DIR && tar fx $RUBY
	ruby=`echo $RUBY |awk -F ".tar" '{print $1}'`
	cd $ruby
	./configure --prefix=/usr/local/ruby
	make && make install
	echo "export PATH=$PATH:/usr/local/ruby/bin" >>/etc/profile
	sleep 2
	source /etc/profile
}
rubygeminstall() {
	cd $SOFT_DIR && tar fx $RUBYGEM
	rubygem=`echo $RUBYGEM |awk -F ".tgz" '{print $1}'`
	cd $rubygem 
	ruby setup.rb
	########################################
	gem sources -a https://ruby.taobao.org/
	gem sources --remove https://rubygems.org/
	gem sources -l
	gem install rails 
}
redmineinstall() {
	cd $SOFT_DIR && tar fx $REDMINE
	redmine=`echo $REDMINE |awk -F ".tar" '{print $1}'`
	mv $redmine /var/www/html/redmine
	cd /var/www/html/redmine/
	sed -i "s#source 'https://rubygems.org'#source 'https://ruby.taobao.org/'#" Gemfile
	cp config/database.yml.example config/database.yml
	sed -i "8s#host: localhost#host: $MYSQLIP#" config/database.yml
	sed -i "9s#username: root#username: $USER#" config/database.yml
	sed -i "10s#password: \"\"#password: \"$PW\"#" config/database.yml
	gem install bundler
	bundle install

	rake generate_secret_token
	RAILS_ENV=production rake db:migrate 
	RAILS_ENV=production REDMINE_LANG=zh rake redmine:load_default_data
	chown -R www.www /var/www/html/redmine
} 
start_and_stop() {
	cd /var/www/html/redmine/
	ruby bin/rails server webrick -e production -d
	ps -aux |grep ruby
	kill -9 'rubypid'
}

#整合nginx和redmine
combine() {
	#set redmine
	cd /var/www/html/redmine/public
	cp dispatch.fcgi.example dispatch.fcgi
	cp htaccess.fcgi.example htaccess
	chown -R www.www /var/www/html/redmine
	gem install passenger
	passenger-install-nginx-module
}
helps() {
	cat <<EOF
	cd /usr/local/nginx/conf/
	vim nginx.conf
	http {
		passenger_root	/usr/local/ruby/lib/ruby/gems/2.0.0/gems/passenger-5.0.23;
		passenger_ruby 	/usr/local/ruby/bin/ruby;
		...................
		.....其余不变......
		...................
		server {
			listen				80;
			root 				/var/www/html/redmine/public;
			server_name			work.manager.com;
			passenger_enabled 	on;
		}
	}
	service nginxd start
EOF
}
