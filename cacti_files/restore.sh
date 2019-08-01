#!/bin/sh
echo "Start restore"

echo "=> MYSQL DB restore"
gunzip < /var/backups/cacti_db.gz | mysql -uroot cacti

echo "=> RRA restore"
tar xzf /var/backups/cacti_rra.tar.gz -C /

echo "End restore"
