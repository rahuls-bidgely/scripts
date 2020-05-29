
if [ -z $PROMOTEBUILDVERSION ]; then
echo "Please mention PROMOTEBUILDVERSION"
exit 333
fi



mkdir dep-$PROMOTEBUILDVERSION ; cd dep-$PROMOTEBUILDVERSION
#mkdir dep-$BUILD_NUMBER ; cd dep-$BUILD_NUMBER/


if [ -z $PATCH ]; 
then
SOURCERPMFOLDER='debs/nonprodqa'
RPMSTODEPLOY2=`echo $RPMSTODEPLOY | sed 's/,/|/g'`

PROMOTEBUILDVERSION_DISAGG=`echo $PROMOTEBUILDVERSION_DISAGG | sed 's/,/|/g'`
PROMOTEBUILDVERSION=`echo $PROMOTEBUILDVERSION | sed 's/,/|/g'`


else
SOURCERPMFOLDER=patch
RPMSTODEPLOY2=`echo $RPMSTODEPLOY | sed 's/,/|/g'`
fi


cat << PROMOTEBUILDS >> promotebuild-scripts.sh
#!/bin/bash
if [ -z $PATCH ]; 
then
echo "Copying all rpms from release..."

PROMOTEBUILDVERSION_DISAGG=\`echo "$PROMOTEBUILDVERSION_DISAGG" | sed 's/,/|/g'\`
SOURCERPMFOLDER=$SOURCERPMFOLDER
PROMOTEBUILDVERSION=${PROMOTEBUILDVERSION}
#PROMOTEBUILDVERSION=\`echo "${PROMOTEBUILDVERSION}" | sed 's/,/|/g'\`


echo "copying the rpms..."
ssh ubuntu@repo2.bidgely.com -n 'RPM=\`ls /var/www/html/${SOURCERPMFOLDER}/* | egrep -e "${PROMOTEBUILDVERSION}_"\`; echo \$RPM ;echo "copying the rpms..." ;cp \$RPM /var/www/html/preprod/; ls /var/www/html/preprod/* | egrep -e ${PROMOTEBUILDVERSION}_'




if [ ! -z "$PROMOTEBUILDVERSION_DISAGG" ]; then
echo "copying the disagg rpms..."
ssh ubuntu@repo2.bidgely.com -n 'RPM=\`ls /var/www/html/${SOURCERPMFOLDER}/* | egrep -e "${PROMOTEBUILDVERSION_DISAGG}" \`; echo \$RPM ; echo "copying the disagg rpms..." ; cp \$RPM /var/www/html/preprod/; ls /var/www/html/preprod/* | egrep -e "${PROMOTEBUILDVERSION_DISAGG}" '
fi

#ssh ubuntu@repo2.bidgely.com -n 'cp /var/www/html/qa/Packages.gz /var/www/html/preprod/'



echo ----------------------
echo "running dpkg scan..."

ssh ubuntu@repo2.bidgely.com -n "cd /var/www/html/preprod ; rm -rf *.rpm"
ssh ubuntu@repo2.bidgely.com -n "cd /var/www/html ; ./preprod-repo.sh"

echo ==============start=========
ssh ubuntu@repo2.bidgely.com -n 'cd /var/www/html/preprod/; zcat Packages.gz  | egrep -e "$PROMOTEBUILDVERSION|$PROMOTEBUILDVERSION_DISAGG"'



echo ==============end=========
else
echo "Copying packages from patch"
SOURCERPMFOLDER=$SOURCERPMFOLDER
PROMOTEBUILDVERSION=${PROMOTEBUILDVERSION}
ssh ubuntu@repo2.bidgely.com -n 'RPM=\`ls /var/www/html/${SOURCERPMFOLDER}/* | egrep -e "${PROMOTEBUILDVERSION}" | egrep -e "$RPMSTODEPLOY2"\`; echo \$RPM ; cp \$RPM /var/www/html/preprod/; ls /var/www/html/preprod/* | egrep -e ${PROMOTEBUILDVERSION}'


echo ----------------------
echo "running dpkg scan..."

ssh ubuntu@repo2.bidgely.com -n "cd /var/www/html ; ./preprod-repo.sh"

echo ==============start=========
ssh ubuntu@repo2.bidgely.com -n 'cd /var/www/html/preprod/; zcat Packages.gz  | egrep -e "$PROMOTEBUILDVERSION|$PROMOTEBUILDVERSION_DISAGG"'



#ssh ubuntu@repo2.bidgely.com -n 'cd /var/www/html/preprod/ ; dpkg-scanpackages -m . /dev/null  | sed 's/.\///g' | gzip --fast > Packages.gz'
fi
PROMOTEBUILDS

