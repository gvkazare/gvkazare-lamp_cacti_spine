#!/bin/sh
mysql -u root -pmysqlpsswd < /var/backups/alldb_backup.sql
tar xzf /var/backups/rra.tar.gz -C /
