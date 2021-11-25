#!/bin/sh
#
# This is the version for ops. My apologies for the naming sillyness.
#

# PROVIDE: mysql
# REQUIRE: NETWORKING SERVERS mysql-client
# BEFORE: DAEMON
# KEYWORD: shutdown

version=`/usr/local/bin/mysql_config --version`;
majmin=${version%.*}
major=${majmin%%.*}
minor=${majmin##*.}

opts="-O long_query_time=2 --skip-innodb"
opts="$opts -O max_connections=300 -O key_buffer=32M"
opts="$opts -O table_cache=256 -O sort_buffer=4M -O record_buffer=1M"

logopt="--log-long-format --log=/users/mshobana/emulab-devel/build/log/mysql/base --log-bin=/users/mshobana/emulab-devel/build/log/mysql/update --log-slow-queries=/users/mshobana/emulab-devel/build/log/mysql/slowqueries"

if [ $major -eq 5 ]; then
	safeprog=/usr/local/bin/mysqld_safe
	if [ $minor -gt 1 ]; then
	    logopt="--general_log=1 --general_log_file=/users/mshobana/emulab-devel/build/log/mysql/base"
	    logopt="$logopt --log-bin=/users/mshobana/emulab-devel/build/log/mysql/update"
	    logopt="$logopt --slow_query_log=1 --binlog-format=MIXED"
	    logopt="$logopt --slow_query_log_file=/users/mshobana/emulab-devel/build/log/mysql/slowqueries"

	    # XXX awkward: no -O, a couple of name changes
	    opts="--default-storage-engine=MyISAM --long_query_time=2"
	    opts="$opts --key_buffer_size=32M --table_open_cache=256"
	    opts="$opts --sort_buffer_size=4M"
	    opts="$opts --read_buffer_size=1M --max_connections=300"
	fi
	# so that we can dump tables
	if [ $minor -gt 4 ]; then
	    opts="$opts --secure-file-priv="
	fi
	# so we can start using innodb tables, maybe with compression.
	if [ $minor -gt 5 ]; then
	    opts="$opts --innodb_file_per_table=1 --innodb_file_format=Barracuda"
	    # Backwards compatibility.
	    opts="$opts --lower_case_table_names=0 --log_output=file"
	    # Strict mode is coming, but we can't handle it.
	    opts="$opts --sql_mode=ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"
	fi
else
	safeprog=/usr/local/bin/safe_mysqld
fi

case "$1" in
	#
	# XXX hack, might need --skip-grant-tables when starting after mysql
    	# has been upgraded but before mysql_upgrade has been run. In fact,
    	# you probably won't be able to start mysqld to run mysql_upgrade
    	# without this!
    	#
	upgradestart)
		if [ -x $safeprog ]; then
			$safeprog --pid-file=/var/db/mysql/mysqld.pid --user=mysql --skip-grant-tables $opts $logopt > /dev/null 2>&1 &
			echo -n ' mysqld'
		fi
		;;
	start|faststart|quietstart|onestart|forcestart)
		if [ -x $safeprog ]; then
			$safeprog --pid-file=/var/db/mysql/mysqld.pid --user=mysql $opts $logopt > /dev/null 2>&1 &
			echo -n ' mysqld'
		fi
		;;
	stop|faststop|quietstop|onestop|forcestop)
		/usr/bin/killall mysqld > /dev/null 2>&1 && echo -n ' mysqld'
		;;
	*)
		echo ""
		echo "Usage: `basename $0` { start | stop }"
		echo ""
		exit 64
		;;
esac





