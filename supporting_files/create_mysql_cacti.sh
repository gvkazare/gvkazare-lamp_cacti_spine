#!/bin/bash

echo "========================================================================"
echo "=> Creating MySQL cacti databases and user cacti with 9PIu8AbWQSf8 password"

STATCODE=5
mysql -uroot -e "create database cacti;" > /dev/null 2>&1
STATCODE="$?"
echo $STATCODE

if [ $STATCODE -eq 0 ]; then
    echo "=> cacti DB creating and < /opt/cacti/cacti.sql"
    mysql -uroot cacti < /opt/cacti/cacti.sql
    mysql -uroot mysql < /usr/share/mysql/mysql_test_data_timezone.sql


#echo "
#[mysqld]

#collation_server=utf8mb4_unicode_ci
#character_set_client=utf8mb4
#max_heap_table_size=31M
#tmp_table_size=31M
#join_buffer_size=61M
#innodb_buffer_pool_size=480M
#innodb_doublewrite = OFF
#innodb_flush_log_at_timeout=3
#innodb_read_io_threads=32
#innodb_write_io_threads=16
#innodb_buffer_pool_instances=2
#innodb_io_capacity=5000
#innodb_io_capacity_max=10000
#" > /etc/mysql/my.cnf

else
   echo "=> cacti DB existed"
fi




echo "=> Creating user cacti with 9PIu8AbWQSf8 password"
mysql -uroot -e "GRANT ALL ON cacti.* TO cacti@localhost IDENTIFIED BY '9PIu8AbWQSf8'; flush privileges; "

#import the mysql_test_data_timezone.sql to mysql database
#mysql -uroot -p mysql < /usr/share/mysql/mysql_test_data_timezone.sql

#Grant the permission to cactiuser
#mysql -uroot -e "GRANT SELECT ON mysql.time_zone_name TO cacti@localhost; flush privileges; "
mysql -uroot -e "GRANT SELECT ON mysql.time_zone_name TO cacti@localhost IDENTIFIED BY '9PIu8AbWQSf8'; flush privileges; "
mysql -uroot -e "ALTER DATABASE cacti CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; "

echo "=> MySQL cacti databases has been created"
echo "========================================================================"
