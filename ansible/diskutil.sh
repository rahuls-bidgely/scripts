dusage=$(df -Ph | grep -vE '^tmpfs|cdrom' | sed s/%//g | awk '{ if($5 > 90) print $0;}')
fscount=$(echo "$dusage" | wc -l)
if [ $fscount -ge 2 ]; then
echo "$dusage" | mail -s "Disk Space Alert On $(hostname) at $(date)" productsupport@bidgely.com,rahuls@bidgely.com -aFrom:Rahul\<rahuls@bidgely.com\>
else
echo "Disk usage is in under threshold"
  fi
