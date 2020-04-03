#!/bin/bash
set -euo pipefail

BACKUP_DIR=/var/www/restore
MYSQL_USER=root
MYSQL_PASSWORD=Vmms@123
DB_OUTPUT=/var/www/databases

for database in $(ls $BACKUP_DIR); do
    if [ -d "$BACKUP_DIR/$database" ]; then
        # read frm file
        for file in $(ls $BACKUP_DIR/$database | grep frm); do
            if [ -f "$BACKUP_DIR/$database/$file" ]; then
                echo "Parsing file: $BACKUP_DIR/$database/$file"
                mysqlfrm --server=$MYSQL_USER:$MYSQL_PASSWORD@localhost:3306 $BACKUP_DIR/$database/$file --user=$MYSQL_USER --port=3307 >"$BACKUP_DIR/$database/$file.txt"
            fi
        done
        #create database
        echo "Create Database: $database"
        mysql -u root -psecret -e "create database if not exists ${database} character set utf8mb4 collate utf8mb4_unicode_ci"
        for table in $(ls $BACKUP_DIR/$database | grep frm.txt); do
            if [ -f "$BACKUP_DIR/$database/$table" ]; then
                sed -i 's/WARNING.*$//' $BACKUP_DIR/$database/$table
                sed -i 's/0000-00-00 00:00:00/2010-01-01 00:00:00/g' $BACKUP_DIR/$database/$table
                mysql -u root -psecret ${database} <$BACKUP_DIR/$database/$table
            fi
        done

        for table in $(ls $BACKUP_DIR/$database | grep frm.txt); do
            if [ -f "$BACKUP_DIR/$database/$table" ]; then
                echo "Discard table: $table"
                mysql -u root -psecret -e "ALTER TABLE $database.${table/\.frm\.txt/} DISCARD TABLESPACE"
            fi
        done
        for table in $(ls $BACKUP_DIR/$database | grep .ibd); do
            if [ -f "$BACKUP_DIR/$database/$table" ]; then
                if [ -f "/var/lib/mysql/$database/$table" ]; then
                    rm /var/lib/mysql/$database/$table
                fi
                cp $BACKUP_DIR/$database/$table /var/lib/mysql/$database/
            fi
        done
        chown mysql:mysql /var/lib/mysql/$database/*
        for table in $(ls $BACKUP_DIR/$database | grep .ibd); do
            if [ -f "$BACKUP_DIR/$database/$table" ]; then
                mysql -u root -psecret -e "ALTER TABLE $database.${table/\.ibd/} IMPORT TABLESPACE"
            fi
        done
        mysqldump -u root -psecret $database >"$DB_OUTPUT/$database.sql"
    fi
done
