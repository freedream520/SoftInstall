#!/bin/bash
host=
src=
des=
user=
/usr/bin/inotifywait -mrq -e modify,delete,create,attrib $src | while read files 
do
	/usr/bin/rsync -avzP --delete --progress --password-file=/usr/local/rsync/rsyncd.pw $src $user@$host::$des
	echo "${files} was rsynced" >>/var/log/rsyncd.log 2>&1
done