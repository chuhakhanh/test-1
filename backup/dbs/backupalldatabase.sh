#!/bin/bash

USER="root"
PASSWORD="s4ngt4o&h0ch01"
OUTPUT="/vg_vps/images/backup/dbs"

#rm "$OUTPUTDIR/*gz" > /dev/null 2>&1

databases=`mysql -u $USER -p$PASSWORD -e "SHOW DATABASES;" | tr -d "| " | grep -v Database`

for db in $databases; do
    if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] ; then
        echo "Dumping database: $db"
        mysqldump -u $USER -p$PASSWORD --databases $db > $OUTPUT/`date +%Y%m%d%H%M`.$db.sql
        gzip $OUTPUT/`date +%Y%m%d%H%M`.$db.sql
    fi
done
