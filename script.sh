#!/bin/bash

BACKUP_DIR=/var/www/dbbackup

declare -a databases

for entry in $(ls $BACKUP_DIR); do
    if [ -d "$BACKUP_DIR/$entry" ]; then
        databases=("$BACKUP_DIR/$entry" "${databases[@]}")
    fi
done

for i in "${databases[@]}"; do
    declare -a frmfiles
    for file in $(ls -d $i *.frm); do
        if [ -f "$i/$file" ]; then
            frmfiles=("$i/$file" "${frmfiles[@]}")
        fi
    done
    for f in "${frmfiles[@]}"; do
        echo $f
        mysqlfrm --server=root:secret@localhost:3306 $f > "$f.txt" --user=root --port=3307
    done
done
