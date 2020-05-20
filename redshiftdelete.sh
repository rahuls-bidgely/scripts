#!/bin/bash
cd tmp/
find . ! -name 'redshift.sql' -type f -exec rm -f {} +

date > wed

month=`awk '{print $2}' wed`
day=`awk '{print $3}' wed`
year=`awk '{print $6}' wed`
aws s3 cp s3://bidgely-artifacts/redshift-retain-tables/$(date +%Y)/$month/$day/textfile .

if [ $? -eq 0 ]; then

cat textfile
echo "Start"
PGPASSWORD=${REDSHIFTPASSWORD} psql -h ${REDSHIFT_URL}  -U ${REDSHIFT_USER}  -p 5439 bdw -f redshift.sql > originaltables.csv

cat  originaltables.csv

awk '{print $3}' originaltables.csv > temp1.csv
sed -e '1,2d' < temp1.csv > temp2.csv
head -n -2 temp2.csv > temp3.csv

awk -F, 'FNR==NR {f2[$1];next} !($0 in f2)' textfile temp3.csv > test.sql


awk -F "|" '{gsub(/ /, "", $0); print "drop table  test_db." $1";"} ' test.sql > test1.sql

cat test1.sql

PGPASSWORD=${REDSHIFTPASSWORD} psql -h ${REDSHIFT_URL}  -U ${REDSHIFT_USER}  -p 5439 bdw  < test1.sql 

sleep 20

PGPASSWORD=${REDSHIFTPASSWORD} psql -h ${REDSHIFT_URL}  -U ${REDSHIFT_USER}  -p 5439 bdw -f redshift.sql > finalop.csv

cat finalop.csv

else
echo "echo deleting all tables"
PGPASSWORD=${REDSHIFTPASSWORD} psql -h ${REDSHIFT_URL}  -U ${REDSHIFT_USER}  -p 5439 bdw -f redshift.sql > originaltables.csv
cat  originaltables.csv

awk '{print $3}' originaltables.csv > temp1.csv
sed -e '1,2d' < temp1.csv > temp2.csv
head -n -2 temp2.csv > temp3.csv
mv temp3.csv test.sql
awk -F "|" '{gsub(/ /, "", $0); print "drop table  test_db." $1";"} ' test.sql > test1.sql

cat test1.sql
PGPASSWORD=${REDSHIFTPASSWORD} psql -h ${REDSHIFT_URL}  -U ${REDSHIFT_USER}  -p 5439 bdw  < test1.sql 

sleep 20

PGPASSWORD=${REDSHIFTPASSWORD} psql -h ${REDSHIFT_URL}  -U ${REDSHIFT_USER}  -p 5439 bdw -f redshift.sql > finalop.csv

cat finalop.csv
fi
echo "End"
