#!/bin/sh
gunzip < /var/backups/cacti_db.gz | mysql -uroot cacti
tar xzf /var/backups/cacti_rra.tar.gz -C /
