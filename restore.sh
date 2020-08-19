#!/bin/bash
set -euo pipefail

BACKUP_DIR=/var/www/dbrestore
MYSQL_USER=root
MYSQL_PASSWORD=secret
DB_OUTPUT=/var/www

for database in $(ls $BACKUP_DIR); do
    if [ -d "$BACKUP_DIR/$database" ]; then
        # read frm file
        for file in $(ls $BACKUP_DIR/$database | grep frm); do
            if [ -f "$BACKUP_DIR/$database/$file" ]; then
                if [ "${file: -3}" == "frm" ]; then
                    echo "Parsing file: $BACKUP_DIR/$database/$file"
                    mysqlfrm --server=$MYSQL_USER:$MYSQL_PASSWORD@localhost:3306 $BACKUP_DIR/$database/$file --user=$MYSQL_USER --port=3307 >"$BACKUP_DIR/$database/$file.txt"
                fi
            fi
        done
        #create database
        echo "Create Database: $database"
        mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "create database if not exists ${database} character set utf8mb4 collate utf8mb4_unicode_ci"
        for table in $(ls $BACKUP_DIR/$database | grep frm.txt); do
            if [ -f "$BACKUP_DIR/$database/$table" ]; then
                echo "Doing: $table"
                sleep 1.5
                sed -i 's/WARNING.*$//' $BACKUP_DIR/$database/$table
                # sed -i 's/CREATE TABLE/CREATE TABLE IF NOT EXISTS/' $BACKUP_DIR/$database/$table
                sed -i 's/0000-00-00 00:00:00/2010-01-01 00:00:00/g' $BACKUP_DIR/$database/$table
                mysql -u $MYSQL_USER -p$MYSQL_PASSWORD ${database} <$BACKUP_DIR/$database/$table
            fi
        done

        for table in $(ls $BACKUP_DIR/$database | grep frm.txt); do
            if [ -f "$BACKUP_DIR/$database/$table" ]; then
                echo "Discard table: $table"
                mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "ALTER TABLE $database.${table/\.frm\.txt/} DISCARD TABLESPACE"
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
                mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "ALTER TABLE $database.${table/\.ibd/} IMPORT TABLESPACE"
            fi
        done
        mysqldump -u $MYSQL_USER -p$MYSQL_PASSWORD $database >"$DB_OUTPUT/$database.sql"
    fi
done
