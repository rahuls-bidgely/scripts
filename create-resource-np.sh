#!/bin/bash -x
cat << OFF >offtimes.txt
3 09 30
3 09 31
3 09 32
3 09 33
3 09 34
3 09 35
3 09 36
3 09 37
3 09 38
3 09 39
3 09 40
3 09 41
3 09 42
3 09 43
3 09 44
3 09 45
3 09 46
3 09 47
3 09 48
3 09 49
3 09 50
3 09 51
3 09 52
3 09 53
3 09 54
3 09 55
3 09 56
3 09 57
3 09 58
3 09 59
3 10 00
3 10 01
3 10 02
3 10 03
3 10 04
3 10 05
3 10 06
3 10 07
3 10 08
3 10 09
3 10 10
3 10 11
3 10 12
3 10 13
3 10 14
3 10 15
3 10 16
3 10 17
3 10 18
3 10 19
3 10 20
3 10 21
3 10 22
3 10 23
3 10 24
3 10 25
3 10 26
3 10 27
3 10 28
3 10 29
3 10 30

OFF
TOR=`date -u +%u\ %H\ %M`

if [ `cat offtimes.txt |grep "$TOR" |wc -l` != 0 ] 
   then 
   	echo "Try after 4 pm IST"
    exit 1
fi


if [ -z "$JIRA_REQUEST_ID" ];then
echo "Please provide a valid JIRA request ID"
exit 777
fi



#version=$(aws elasticbeanstalk describe-application-versions --application-name  dev-api --region us-west-2   | grep VersionLabel | head -1 | tr -d \" |  tr "," " " | awk '{print $2}')
#echo API_VERSION_LABEL=$version >> dev.properties

#Convert QUEUE_SUFFIX to lower case
QUEUE_SUFFIX=`echo "$QUEUE_SUFFIX" | awk '{print tolower($0)}'`

#Load variables
pwd
source dep-${BUILD_NUMBER}/jenkins/dev_uat_create/queues.list
source dep-${BUILD_NUMBER}/jenkins/dev_uat_create/buckets.list
source dep-${BUILD_NUMBER}/jenkins/dev_uat_create/bucket-events.list

#Check for non-empty QUEUE_SUFFIX
if [ -z "$QUEUE_SUFFIX" ]
then
	echo "<h1>Please define QUEUE_SUFFIX to proceed<h1>"
    exit 1
fi


#Check if QUEUE_SUFFIX is already in use
aws configure set preview.sdb true
SDB_ENTRY=`aws --region us-east-1 sdb get-attributes --domain-name ${SDB_TABLE} --item-name ${QUEUE_SUFFIX} --attribute-names creationdate --output text`
echo $SDB_ENTRY
 
if [ ! -z "$SDB_ENTRY" ] && [ -z "$existing_queue" ]
then
echo "<h1>QUEUE_SUFFIX already in use. Use a different one.<h1>"
    exit 1
    fi
    if [ -z "$SDB_ENTRY" ] && [ -z "$existing_queue" ]
    then 
    echo "creating queue"
fi

if [ ! -z "$SDB_ENTRY" ] && [ "$existing_queue" = "YES" ]
then
echo "creating extra instance"
fi
 



TAGNAME=daemons-${QUEUE_SUFFIX}
TAGCOMPONENT=daemons
TAGENV=${ENV}
OWNER=${Owner}
UTILITY=${Utility}
QUEUE_SUFFIX=${QUEUE_SUFFIX}


if [ $Instances -ne 0 ]
then

cd dep-${BUILD_NUMBER}/jenkins/

chmod 755 spot-fleet-complete-setup-feature-env.sh

cat << USERDATA > userdata
#!/bin/bash
echo "=================USER SCRIPT START===================="
echo
JAVA_HOME=/usr/lib/jvm/java-8-oracle/jre
BIDGELY_ENV=${ENV}
QUEUE_SUFFIX=${QUEUE_SUFFIX}
S3ARTIFACTSBUCKET=bidgely-artifacts/operations
REPO=repo2.bidgely.com/debs/uat
REPODIR=/

echo "=======USER SCRIPT STARTING========"
echo
echo "Tagging the instance and its volumes"

INSTANCEID=\$(curl -s http://169.254.169.254/latest/meta-data/instance-id );
aws ec2 create-tags --resources \$INSTANCEID --tags Key=Name,Value=$TAGNAME Key=Environment,Value=$TAGENV Key=Component,Value=$TAGCOMPONENT Key=QueueSuffix,Value=$QUEUE_SUFFIX Key=Owner,Value=$OWNER Key=Utility,Value=$UTILITY --region $REGION
INSTANC_VOLUMES=\$(aws ec2 describe-volumes --filter Name=attachment.instance-id,Values=\$INSTANCEID --query Volumes[].VolumeId --out text --region $REGION);
for i in \`echo \$INSTANC_VOLUMES\`; do echo \$i ; aws ec2 create-tags --resources \$i --tags Key=Name,Value=$TAGNAME Key=Component,Value=$TAGCOMPONENT Key=QueueSuffix,Value=$QUEUE_SUFFIX Key=Environment,Value=$TAGENV Key=Owner,Value=$OWNER Key=Utility,Value=$UTILITY  --region $REGION; done
#echo ${QUEUE_SUFFIX} > q
echo "Configuring \$REPO/\$REPODIR"
# Create Source list for packages to install from our local repo
echo "deb http://\${REPO} \${REPODIR}" >> /etc/apt/sources.list
echo "Package: *" > /etc/apt/preferences
echo 'Pin: origin "\${REPO}"' >> /etc/apt/preferences
echo "Pin-Priority: 1001" >> /etc/apt/preferences

apt-get update;

apt-get install htop -y
echo 

# Move Logs To S3 and Node Termination Checker Setup
aws s3 cp s3://\$S3ARTIFACTSBUCKET/termination_checker.sh /opt/bidgely/
aws s3 cp s3://\$S3ARTIFACTSBUCKET/terminationcheckercron /etc/cron.d/

chmod 777 /opt/bidgely/termination_checker.sh

# Set env
echo "Configuring env variable's"
sed -i 's/BIDGELY_ENV=.*//g' /etc/environment;
sed -i 's/JAVA_HOME=.*//g' /etc/environment;
echo BIDGELY_ENV=\${BIDGELY_ENV} >> /etc/environment;
echo JAVA_HOME=\${JAVA_HOME} >> /etc/environment;
#if [ ! -z "\$QUEUE_SUFFIX" ]; then
#echo QUEUE_SUFFIX=\${QUEUE_SUFFIX} >> /etc/environment;
#echo QUEUE_SUFFIX=${QUEUE_SUFFIX} >> /etc/environment;
echo QUEUE_SUFFIX=\${QUEUE_SUFFIX} >> /etc/environment
#fi


echo "Setting up public pem keys"
# Set the pem keys for login
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDm9y8GYBZWuaMBwYIISxd1oJSM9wuKNy4sDEjt7yjRcDzCWpenwZhtVM0rnIZyRIy0c1fx4wLeIJ0Q01ijffpvS00dZOj0XLCQ/56e+ODhOyLvQxgOEQGm/2lx5bosiBv7yN0KcwO+Vuc7vpIKBkr8hE6ntH/LkKBr0bBaAhOJX+WmSvIdV6XuXxJrhwSas1T8YZlrW6ykl6z2eR5cdPJgqVEcZitRESK65l/f22gC4eogccJAQnEDtuvJPnqCfgHOJ/eVwvp7wmf0B3E03JiHVQygZZMh/C80FjmSzKJVSA21HWjtGigU1nQwmQCn0ewdpoGhLqLURgd0rwxolnBx auto
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCf9/UbuEp6wPTzJTPuTvcdxIZWM2iUDQgUfjFW07CIH0H1P0o1YLnQsCQqKGxePPuSuBma3239sNQ/6D8w1/EB6nh5S3XP7F+yyAQqs8rZNNYY1EnFnrzQ4qpBy+7uUZEGUu3v5YRPHF99rTNo3lDbjZQ3bTu6WeOxjqQfuZFEL6k9eNIjQjPumlUG6qf1u6jefxOvA6O9Rip+9lkipC8IktrDz0CXBTTk2MW/qFWP9RIGB+XyIk7v2XeUAIT+B/uuO/zaA3uhN9AFPwok/h/d/caaJyfr87zUAwTR2qyoMZOpE6c0NOf6xkhOvCFpGi1NEh4MfyWDrPrihLb8IjN7 bops
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4hLkA190wTcAWd54XEyNznKElDBgn0g3rSdHOCCZBLYnpOXRRTyYnujGEYXktauOFseTbl+l1cc0j75td+d0Bi4K1bX/MmI1b5kJB12MCMIWNfAsXbXF6CVTDdgyZFqc4V1lbk5RvgPggieg2SnhDMX1XZmP6N9VPMB3j02Roxbcs+0MpAcUa13fJ5ZSrh+8nBq3vWDobpk/+F80C4mQbqm6NOhPKxF/vK2+qY6fneAgMo2HrHVwPvWTUQvNfNLQrevvbac7otM8zoePyha70CteqLw/f8EK2NiwSyYqPFst6bjNa4I+7rr75kOy44RuRO1viS9bGfI6kUdH3zG6r bsup
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCSPAMBR9eSqVwsKR//PLm0h48Eco1Rn26OSHy9F2pyHzY++hAMWjc0uPf6zbAIeYsVXi0O2SwU48x+Q0y/mqUyUig8e5/6/i19AEDntEks2JjG46b7hD7+b+/VgF5kj578uAPoFAVsJOqvE5TOd6g0KGYX3ZIh/AM632+J0ti2TjKK7I9qfBYHDQKQvGyLoVlQemnTO0zhdZHyjfo4YYAOdBkfO4MIM5Oy9P8C8cIBjw9MnQP99ovkYtJ7AUp22rIgB1l4zoNeeiWfVawKAl/v7+QA0OKcRWH7dAhFFTz2WEwcWfvwCdINSfZK3yh9mHiYqAXHRAumdsVWJu/5XNMb jenkins" > /home/ubuntu/.ssh/authorized_keys

echo "=================USER SCRIPT END===================="
USERDATA

for ((i=1;i<=$Instances;i++))	
do
	if [ "$ENV" = "dev" ]; then
    	./spot-fleet-complete-setup-feature-env.sh $TAGNAME $TAGCOMPONENT $TAGENV $Owner $UTILITY $QUEUE_SUFFIX ami-00b5b6ec322e3793e snap-0ecceec5a7fa5362b
    elif [ "$ENV" = "uat" ]; then
    	aws --region us-west-2 ec2 run-instances --image-id ami-6672ff1e --count 1 --instance-type r4.xlarge --key-name uat --security-group-ids "sg-08039c77" --subnet-id subnet-726ea80b --user-data file://userdata --block-device-mappings DeviceName=/dev/sda1,VirtualName=RootVolume,Ebs={VolumeType=standard} --iam-instance-profile Name=uat-iam-instance-profile
    	#aws --region us-west-2 ec2 run-instances --image-id ami-001687ed21bf26dda --count 1 --instance-type c5.large --key-name uat --security-group-ids "sg-08039c77" --subnet-id subnet-726ea80b --user-data file://userdata --block-device-mappings DeviceName=/dev/sda1,VirtualName=RootVolume,Ebs={VolumeType=standard} --iam-instance-profile Name=uat-iam-instance-profile

    fi
done



cd ../..
fi


if [ $PDFInstances -ne 0 ] 
then

cd dep-${BUILD_NUMBER}/jenkins/

chmod 755 spot-fleet-complete-setup-feature-env.sh

cat << USERDATA > userdata
#!/bin/bash
echo "=================USER SCRIPT START===================="
echo
JAVA_HOME=/usr/lib/jvm/java-8-oracle/jre
BIDGELY_ENV=${ENV}
S3ARTIFACTSBUCKET=bidgely-artifacts/operations
REPO=repo2.bidgely.com/debs/uat
QUEUE_SUFFIX=${QUEUE_SUFFIX}
REPODIR=/

echo "=======USER SCRIPT STARTING========"
echo
echo "Tagging the instance and its volumes"

INSTANCEID=\$(curl -s http://169.254.169.254/latest/meta-data/instance-id );
aws ec2 create-tags --resources \$INSTANCEID --tags Key=Name,Value=$TAGNAME Key=Environment,Value=$TAGENV Key=Component,Value=$TAGCOMPONENT Key=QueueSuffix,Value=$QUEUE_SUFFIX Key=Owner,Value=$OWNER Key=Utility,Value=$UTILITY --region $REGION
INSTANC_VOLUMES=\$(aws ec2 describe-volumes --filter Name=attachment.instance-id,Values=\$INSTANCEID --query Volumes[].VolumeId --out text --region $REGION);
for i in \`echo \$INSTANC_VOLUMES\`; do echo \$i ; aws ec2 create-tags --resources \$i --tags Key=Name,Value=$TAGNAME Key=Component,Value=$TAGCOMPONENT Key=QueueSuffix,Value=$QUEUE_SUFFIX Key=Environment,Value=$TAGENV Key=Owner,Value=$OWNER Key=Utility,Value=$UTILITY  --region $REGION; done
echo
echo "Configuring \$REPO/\$REPODIR"
# Create Source list for packages to install from our local repo
echo "deb http://\${REPO} \${REPODIR}" >> /etc/apt/sources.list
echo "Package: *" > /etc/apt/preferences
echo 'Pin: origin "\${REPO}"' >> /etc/apt/preferences
echo "Pin-Priority: 1001" >> /etc/apt/preferences

apt-get update;

apt-get install htop -y

# Move Logs To S3 and Node Termination Checker Setup
aws s3 cp s3://\$S3ARTIFACTSBUCKET/termination_checker.sh /opt/bidgely/
aws s3 cp s3://\$S3ARTIFACTSBUCKET/terminationcheckercron /etc/cron.d/

chmod 777 /opt/bidgely/termination_checker.sh

# Set env
echo "Configuring env variable's"
sed -i 's/BIDGELY_ENV=.*//g' /etc/environment;
sed -i 's/JAVA_HOME=.*//g' /etc/environment;
echo BIDGELY_ENV=\${BIDGELY_ENV} >> /etc/environment;
echo JAVA_HOME=\${JAVA_HOME} >> /etc/environment;
if [ ! -z "\$QUEUE_SUFFIX" ]; then
echo QUEUE_SUFFIX=\${QUEUE_SUFFIX} >> /etc/environment;
fi

echo "Setting up public pem keys"
# Set the pem keys for login
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDm9y8GYBZWuaMBwYIISxd1oJSM9wuKNy4sDEjt7yjRcDzCWpenwZhtVM0rnIZyRIy0c1fx4wLeIJ0Q01ijffpvS00dZOj0XLCQ/56e+ODhOyLvQxgOEQGm/2lx5bosiBv7yN0KcwO+Vuc7vpIKBkr8hE6ntH/LkKBr0bBaAhOJX+WmSvIdV6XuXxJrhwSas1T8YZlrW6ykl6z2eR5cdPJgqVEcZitRESK65l/f22gC4eogccJAQnEDtuvJPnqCfgHOJ/eVwvp7wmf0B3E03JiHVQygZZMh/C80FjmSzKJVSA21HWjtGigU1nQwmQCn0ewdpoGhLqLURgd0rwxolnBx auto
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCf9/UbuEp6wPTzJTPuTvcdxIZWM2iUDQgUfjFW07CIH0H1P0o1YLnQsCQqKGxePPuSuBma3239sNQ/6D8w1/EB6nh5S3XP7F+yyAQqs8rZNNYY1EnFnrzQ4qpBy+7uUZEGUu3v5YRPHF99rTNo3lDbjZQ3bTu6WeOxjqQfuZFEL6k9eNIjQjPumlUG6qf1u6jefxOvA6O9Rip+9lkipC8IktrDz0CXBTTk2MW/qFWP9RIGB+XyIk7v2XeUAIT+B/uuO/zaA3uhN9AFPwok/h/d/caaJyfr87zUAwTR2qyoMZOpE6c0NOf6xkhOvCFpGi1NEh4MfyWDrPrihLb8IjN7 bops
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4hLkA190wTcAWd54XEyNznKElDBgn0g3rSdHOCCZBLYnpOXRRTyYnujGEYXktauOFseTbl+l1cc0j75td+d0Bi4K1bX/MmI1b5kJB12MCMIWNfAsXbXF6CVTDdgyZFqc4V1lbk5RvgPggieg2SnhDMX1XZmP6N9VPMB3j02Roxbcs+0MpAcUa13fJ5ZSrh+8nBq3vWDobpk/+F80C4mQbqm6NOhPKxF/vK2+qY6fneAgMo2HrHVwPvWTUQvNfNLQrevvbac7otM8zoePyha70CteqLw/f8EK2NiwSyYqPFst6bjNa4I+7rr75kOy44RuRO1viS9bGfI6kUdH3zG6r bsup
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCSPAMBR9eSqVwsKR//PLm0h48Eco1Rn26OSHy9F2pyHzY++hAMWjc0uPf6zbAIeYsVXi0O2SwU48x+Q0y/mqUyUig8e5/6/i19AEDntEks2JjG46b7hD7+b+/VgF5kj578uAPoFAVsJOqvE5TOd6g0KGYX3ZIh/AM632+J0ti2TjKK7I9qfBYHDQKQvGyLoVlQemnTO0zhdZHyjfo4YYAOdBkfO4MIM5Oy9P8C8cIBjw9MnQP99ovkYtJ7AUp22rIgB1l4zoNeeiWfVawKAl/v7+QA0OKcRWH7dAhFFTz2WEwcWfvwCdINSfZK3yh9mHiYqAXHRAumdsVWJu/5XNMb jenkins" > /home/ubuntu/.ssh/authorized_keys

echo "=================USER SCRIPT END===================="
USERDATA


for ((i=1;i<=$PDFInstances;i++))	
do
  if [ "$ENV" = "dev" ]; then
      echo "creating pdf box in DEV"

      ./spot-fleet-complete-setup-feature-env.sh $TAGNAME $TAGCOMPONENT $TAGENV $Owner $UTILITY $QUEUE_SUFFIX  ami-0470fed65451936f7 snap-01f076e7c7c0c11e2
      fi
      done
    if [ "$ENV" = "uat" ]; then
    echo "creating pdf box in UAT"
      aws --region us-west-2 ec2 run-instances --image-id ami-0470fed65451936f7 --count 1 --instance-type r4.xlarge --key-name uat --security-group-ids "sg-08039c77" --subnet-id subnet-726ea80b --user-data file://userdata --block-device-mappings DeviceName=/dev/sda1,VirtualName=RootVolume,Ebs={VolumeType=standard} --iam-instance-profile Name=uat-iam-instance-profile
      #aws --region us-west-2 ec2 run-instances --image-id ami-001687ed21bf26dda --count 1 --instance-type c5.large --key-name uat --security-group-ids "sg-08039c77" --subnet-id subnet-726ea80b --user-data file://userdata --block-device-mappings DeviceName=/dev/sda1,VirtualName=RootVolume,Ebs={VolumeType=standard} --iam-instance-profile Name=uat-iam-instance-profile

    fi




cd ../..
fi

if [ $pyamidisagg -ne 0 ] 
then

cd dep-${BUILD_NUMBER}/jenkins/

chmod 755 spot-fleet-complete-setup-feature-env.sh

cat << USERDATA > userdata
#!/bin/bash
echo "=================USER SCRIPT START===================="
echo
JAVA_HOME=/usr/lib/jvm/java-8-oracle/jre
BIDGELY_ENV=${ENV}
S3ARTIFACTSBUCKET=bidgely-artifacts/operations
REPO=repo2.bidgely.com/debs/uat
QUEUE_SUFFIX=${QUEUE_SUFFIX}
REPODIR=/

echo "=======USER SCRIPT STARTING========"
echo
echo "Tagging the instance and its volumes"

INSTANCEID=\$(curl -s http://169.254.169.254/latest/meta-data/instance-id );
aws ec2 create-tags --resources \$INSTANCEID --tags Key=Name,Value=$TAGNAME Key=Environment,Value=$TAGENV Key=Component,Value=$TAGCOMPONENT Key=QueueSuffix,Value=$QUEUE_SUFFIX Key=Owner,Value=$OWNER Key=Utility,Value=$UTILITY --region $REGION
INSTANC_VOLUMES=\$(aws ec2 describe-volumes --filter Name=attachment.instance-id,Values=\$INSTANCEID --query Volumes[].VolumeId --out text --region $REGION);
for i in \`echo \$INSTANC_VOLUMES\`; do echo \$i ; aws ec2 create-tags --resources \$i --tags Key=Name,Value=$TAGNAME Key=Component,Value=$TAGCOMPONENT Key=QueueSuffix,Value=$QUEUE_SUFFIX Key=Environment,Value=$TAGENV Key=Owner,Value=$OWNER Key=Utility,Value=$UTILITY  --region $REGION; done
echo
echo "Configuring \$REPO/\$REPODIR"
# Create Source list for packages to install from our local repo
echo "deb http://\${REPO} \${REPODIR}" >> /etc/apt/sources.list
echo "Package: *" > /etc/apt/preferences
echo 'Pin: origin "\${REPO}"' >> /etc/apt/preferences
echo "Pin-Priority: 1001" >> /etc/apt/preferences

apt-get update;

apt-get install htop -y

# Move Logs To S3 and Node Termination Checker Setup
aws s3 cp s3://\$S3ARTIFACTSBUCKET/termination_checker.sh /opt/bidgely/
aws s3 cp s3://\$S3ARTIFACTSBUCKET/terminationcheckercron /etc/cron.d/

chmod 777 /opt/bidgely/termination_checker.sh

# Set env
echo "Configuring env variable's"
sed -i 's/BIDGELY_ENV=.*//g' /etc/environment;
sed -i 's/JAVA_HOME=.*//g' /etc/environment;
echo BIDGELY_ENV=\${BIDGELY_ENV} >> /etc/environment;
echo JAVA_HOME=\${JAVA_HOME} >> /etc/environment;
if [ ! -z "\$QUEUE_SUFFIX" ]; then
echo QUEUE_SUFFIX=\${QUEUE_SUFFIX} >> /etc/environment;
fi

echo "Setting up public pem keys"
# Set the pem keys for login
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDm9y8GYBZWuaMBwYIISxd1oJSM9wuKNy4sDEjt7yjRcDzCWpenwZhtVM0rnIZyRIy0c1fx4wLeIJ0Q01ijffpvS00dZOj0XLCQ/56e+ODhOyLvQxgOEQGm/2lx5bosiBv7yN0KcwO+Vuc7vpIKBkr8hE6ntH/LkKBr0bBaAhOJX+WmSvIdV6XuXxJrhwSas1T8YZlrW6ykl6z2eR5cdPJgqVEcZitRESK65l/f22gC4eogccJAQnEDtuvJPnqCfgHOJ/eVwvp7wmf0B3E03JiHVQygZZMh/C80FjmSzKJVSA21HWjtGigU1nQwmQCn0ewdpoGhLqLURgd0rwxolnBx auto
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCf9/UbuEp6wPTzJTPuTvcdxIZWM2iUDQgUfjFW07CIH0H1P0o1YLnQsCQqKGxePPuSuBma3239sNQ/6D8w1/EB6nh5S3XP7F+yyAQqs8rZNNYY1EnFnrzQ4qpBy+7uUZEGUu3v5YRPHF99rTNo3lDbjZQ3bTu6WeOxjqQfuZFEL6k9eNIjQjPumlUG6qf1u6jefxOvA6O9Rip+9lkipC8IktrDz0CXBTTk2MW/qFWP9RIGB+XyIk7v2XeUAIT+B/uuO/zaA3uhN9AFPwok/h/d/caaJyfr87zUAwTR2qyoMZOpE6c0NOf6xkhOvCFpGi1NEh4MfyWDrPrihLb8IjN7 bops
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4hLkA190wTcAWd54XEyNznKElDBgn0g3rSdHOCCZBLYnpOXRRTyYnujGEYXktauOFseTbl+l1cc0j75td+d0Bi4K1bX/MmI1b5kJB12MCMIWNfAsXbXF6CVTDdgyZFqc4V1lbk5RvgPggieg2SnhDMX1XZmP6N9VPMB3j02Roxbcs+0MpAcUa13fJ5ZSrh+8nBq3vWDobpk/+F80C4mQbqm6NOhPKxF/vK2+qY6fneAgMo2HrHVwPvWTUQvNfNLQrevvbac7otM8zoePyha70CteqLw/f8EK2NiwSyYqPFst6bjNa4I+7rr75kOy44RuRO1viS9bGfI6kUdH3zG6r bsup
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCSPAMBR9eSqVwsKR//PLm0h48Eco1Rn26OSHy9F2pyHzY++hAMWjc0uPf6zbAIeYsVXi0O2SwU48x+Q0y/mqUyUig8e5/6/i19AEDntEks2JjG46b7hD7+b+/VgF5kj578uAPoFAVsJOqvE5TOd6g0KGYX3ZIh/AM632+J0ti2TjKK7I9qfBYHDQKQvGyLoVlQemnTO0zhdZHyjfo4YYAOdBkfO4MIM5Oy9P8C8cIBjw9MnQP99ovkYtJ7AUp22rIgB1l4zoNeeiWfVawKAl/v7+QA0OKcRWH7dAhFFTz2WEwcWfvwCdINSfZK3yh9mHiYqAXHRAumdsVWJu/5XNMb jenkins" > /home/ubuntu/.ssh/authorized_keys

echo "=================USER SCRIPT END===================="
USERDATA


for ((i=1;i<=$pyamidisagg;i++))	
do
  if [ "$ENV" = "dev" ]; then
      echo "creating pdf box in DEV"

      ./spot-fleet-complete-setup-feature-env.sh $TAGNAME $TAGCOMPONENT $TAGENV $Owner $UTILITY $QUEUE_SUFFIX  ami-001687ed21bf26dda snap-01bd20d5145287d5e
      fi
      done
    if [ "$ENV" = "uat" ]; then
    echo "creating pdf box in UAT"
      aws --region us-west-2 ec2 run-instances --image-id ami-001687ed21bf26dda --count 1 --instance-type r4.xlarge --key-name uat --security-group-ids "sg-08039c77" --subnet-id subnet-726ea80b --user-data file://userdata --block-device-mappings DeviceName=/dev/sda1,VirtualName=RootVolume,Ebs={VolumeType=standard} --iam-instance-profile Name=uat-iam-instance-profile
      #aws --region us-west-2 ec2 run-instances --image-id ami-001687ed21bf26dda --count 1 --instance-type c5.large --key-name uat --security-group-ids "sg-08039c77" --subnet-id subnet-726ea80b --user-data file://userdata --block-device-mappings DeviceName=/dev/sda1,VirtualName=RootVolume,Ebs={VolumeType=standard} --iam-instance-profile Name=uat-iam-instance-profile

    fi




cd ../..
fi

# PDF ami-0aea0bd0c246f626e
# Python ami-001687ed21bf26dda snap-01bd20d5145287d5e
# Daemons Disagg ami-6672ff1e

#Create api server
if [ "$ApiServer" = "YES" ]
then
cat << APIJSON >apitemplate.json
{
  "ApplicationName": "${ENV}-api",
  "EnvironmentName": "${ENV}-api-${QUEUE_SUFFIX}",
  "Description": "${ENV} api for ${QUEUE_SUFFIX}",
  "CNAMEPrefix": "${ENV}-api-${QUEUE_SUFFIX}",
  "Tier": {
    "Name": "WebServer",
    "Type": "Standard",
    "Version": "1.0"
  },
  "Tags": [
    {
      "Key": "Utility",
      "Value": "${Utility}"
    },
    {
      "Key": "Component",
      "Value": "api"
    },
    {
      "Key": "Environment",
      "Value": "${ENV}"
    },
    {
      "Key": "Owner",
      "Value": "${Owner}"
    },
    {
      "Key": "QueueSuffix",
      "Value": "${QUEUE_SUFFIX}"
    }
  ],
  "VersionLabel": "${API_VERSION_LABEL}",
  "SolutionStackName": "${API_STACK_NAME}",
  "OptionSettings": [
    {
      "Namespace": "aws:ec2:vpc",
      "OptionName": "VPCId",
      "Value": "${VPC_ID}"
    },
    {
      "Namespace": "aws:ec2:vpc",
      "OptionName": "Subnets",
      "Value": "${SUBNETS}"
    },
    {
      "Namespace": "aws:ec2:vpc",
      "OptionName": "ELBSubnets",
      "Value": "${ELB_SUBNETS}"
    },
    {
      "Namespace": "aws:ec2:vpc",
      "OptionName": "AssociatePublicIpAddress",
      "Value": "false"
    },
    {
      "Namespace": "aws:elasticbeanstalk:environment",
      "OptionName": "EnvironmentType",
      "Value": "LoadBalanced"
    },
    {
      "Namespace": "aws:elasticbeanstalk:environment",
      "OptionName": "LoadBalancerType",
      "Value": "classic"
    },
    {
      "Namespace": "aws:autoscaling:launchconfiguration",
      "OptionName": "EC2KeyName",
      "Value": "${EC2_KEYNAME}"
    },
    {
      "Namespace": "aws:autoscaling:launchconfiguration",
      "OptionName": "IamInstanceProfile",
      "Value": "${INSTANCE_PROFILE}"
    },
    {
      "Namespace": "aws:autoscaling:launchconfiguration",
      "OptionName": "RootVolumeSize",
      "Value": "10"
    },
    {
      "Namespace": "aws:autoscaling:launchconfiguration",
      "OptionName": "RootVolumeType",
      "Value": "standard"
    },
    {
      "Namespace": "aws:autoscaling:launchconfiguration",
      "OptionName": "SecurityGroups",
      "Value": "${SECURITY_GROUPS}"
    },
    {
      "Namespace": "aws:autoscaling:launchconfiguration",
      "OptionName": "InstanceType",
      "Value": "${API_INSTANCE_TYPE}"
    },
    {
      "Namespace": "aws:autoscaling:asg",
      "OptionName": "MinSize",
      "Value": "1"
    },
    {
      "Namespace": "aws:autoscaling:asg",
      "OptionName": "MaxSize",
      "Value": "2"
    },
    {
      "Namespace": "aws:autoscaling:trigger",
      "OptionName": "LowerThreshold",
      "Value": "2000000"
    },
    {
      "Namespace": "aws:autoscaling:trigger",
      "OptionName": "UpperThreshold",
      "Value": "6000000"
    },
    {
      "Namespace": "aws:autoscaling:trigger",
      "OptionName": "Statistic",
      "Value": "Average"
    },
    {
      "Namespace": "aws:autoscaling:trigger",
      "OptionName": "Unit",
      "Value": "Count"
    },
    {
      "Namespace": "aws:elb:loadbalancer",
      "OptionName": "CrossZone",
      "Value": "false"
    },
    {
      "Namespace": "aws:elb:loadbalancer",
      "OptionName": "SecurityGroups",
      "Value": "${ELB_SECURITY_GROUPS}"
    },
    {
      "Namespace": "aws:elb:loadbalancer",
      "OptionName": "ManagedSecurityGroup",
      "Value": "${ELB_SECURITY_GROUPS}"
    },
    {
      "Namespace": "aws:elb:listener:443",
      "OptionName": "ListenerProtocol",
      "Value": "HTTPS"
    },
    {
      "Namespace": "aws:elb:listener:80",
      "OptionName": "InstanceProtocol",
      "Value": "HTTP"
    },
    {
      "Namespace": "aws:elb:listener:443",
      "OptionName": "SSLCertificateId",
      "Value": "arn:aws:iam::189675173661:server-certificate/bidgely-wc-cert-exp-29102020"
    },
    {
      "Namespace": "aws:elb:listener:443",
      "OptionName": "InstancePort",
      "Value": "80"
    },
    {
      "Namespace": "aws:elasticbeanstalk:application",
      "OptionName": "Application Healthcheck URL",
      "Value": "/systime"
    },
    {
      "Namespace": "aws:elasticbeanstalk:command",
      "OptionName": "BatchSize",
      "Value": "30"
    },
    {
      "Namespace": "aws:elasticbeanstalk:command",
      "OptionName": "BatchSizeType",
      "Value": "Percentage"
    },
    {
      "Namespace": "aws:elb:healthcheck",
      "OptionName": "Interval",
      "Value": "10"
    },
    {
      "Namespace": "aws:elasticbeanstalk:sns:topics",
      "OptionName": "Notification Topic ARN",
      "Value": "${ELB_SNS_TOPIC}"
    },
    {
      "Namespace": "aws:elasticbeanstalk:xray",
      "OptionName": "XRayEnabled",
      "Value": "false"
    },
    {
      "Namespace": "aws:elasticbeanstalk:container:tomcat:jvmoptions",
      "OptionName": "JVM Options",
      "Value": "-Dmy.env=${ENV}  -Dcass.clusterName=${CASS_CLUSTER} -Dcass.disagg.clusterName=${CASS_CLUSTER} -Dkmskey=${KMS_KEY} -Dfirehose.skipDataCopy=${FIREHOSE_SKIP_COPY} -Dqueue.suffix=${QUEUE_SUFFIX}"
    },
    {
      "Namespace": "aws:elasticbeanstalk:container:tomcat:jvmoptions",
      "OptionName": "XX:MaxPermSize",
      "Value": "256m"
    },
    {
      "Namespace": "aws:elasticbeanstalk:container:tomcat:jvmoptions",
      "OptionName": "Xms",
      "Value": "4096m"
    },
    {
      "Namespace": "aws:elasticbeanstalk:container:tomcat:jvmoptions",
      "OptionName": "Xmx",
      "Value": "4096m"
    },
    {
    "Namespace": "aws:elasticbeanstalk:cloudwatch:logs",
    "OptionName": "DeleteOnTerminate",
    "Value": "True"
  },
  {
    "Namespace": "aws:elasticbeanstalk:cloudwatch:logs",
    "OptionName": "StreamLogs",
    "Value": "True"
  },
  {
    "Namespace": "aws:elasticbeanstalk:cloudwatch:logs",
    "OptionName": "RetentionInDays",
    "Value": "7"
  }
  ]
}
APIJSON
aws --region $REGION elasticbeanstalk create-environment --cli-input-json file://apitemplate.json | tee output.file
cat output.file
envid=`cat output.file | grep EnvironmentId | awk '{print $2}' | sed 's/"//g' | sed 's/,//g'|head -1`
if [ ! -z "$DnsConfiguration" ]
	then
    DnsConfiguration="$DnsConfiguration
    ${QUEUE_SUFFIX}${ENV}api.bidgely.com ${ENV}-api-${QUEUE_SUFFIX}"
    else
    DnsConfiguration="${QUEUE_SUFFIX}${ENV}api.bidgely.com ${ENV}-api-${QUEUE_SUFFIX}"
fi

#If dev, change launch configuration to launch spot instances
if [ "$ENV" = "dev" ]; then
cd dep-${BUILD_NUMBER}/jenkins/
chmod 755 spotebs.sh
count=0
while [ $count -ne 1 ]
do
    sleep 5
    count=`aws --region ${REGION} elasticbeanstalk  describe-events --environment-name ${ENV}-api-${QUEUE_SUFFIX} --environment-id ${envid}  |grep "Successfully launched environment" | wc -l`
done
./spotebs.sh ${ENV}-api-${QUEUE_SUFFIX}
cd ../..
fi

fi

#Create frontend
if [ "$FrontendServer" = "YES" ]
then
if [ ! -z "$Fetype" ]
then
for i in `echo $Fetype |tr "," " "`
do
cat << FEJSON >fetemplate.json
{
  "ApplicationName": "${ENV}-fe",
  "EnvironmentName": "${ENV}-${i}-${QUEUE_SUFFIX}",
  "Description": "${ENV} ${i} for ${QUEUE_SUFFIX}",
  "CNAMEPrefix": "${ENV}-${i}-${QUEUE_SUFFIX}",
  "Tier": {
    "Name": "WebServer",
    "Type": "Standard",
    "Version": "1.0"
  },
  "Tags": [
    {
      "Key": "Utility",
      "Value": "${Utility}"
    },
    {
      "Key": "Component",
      "Value": "${i}"
    },
    {
      "Key": "Environment",
      "Value": "${ENV}"
    },
    {
      "Key": "QueueSuffix",
      "Value": "${QUEUE_SUFFIX}"
    },
    {
      "Key": "Owner",
      "Value": "${Owner}"
    }
  ],
  "VersionLabel": "${FE_VERSION_LABEL}",
  "SolutionStackName": "${FE_STACK_NAME}",
  "OptionSettings": [
    {
      "Namespace": "aws:ec2:vpc",
      "OptionName": "VPCId",
      "Value": "${VPC_ID}"
    },
    {
      "Namespace": "aws:ec2:vpc",
      "OptionName": "Subnets",
      "Value": "${SUBNETS}"
    },
    {
      "Namespace": "aws:ec2:vpc",
      "OptionName": "ELBSubnets",
      "Value": "${ELB_SUBNETS}"
    },
    {
      "Namespace": "aws:ec2:vpc",
      "OptionName": "AssociatePublicIpAddress",
      "Value": "false"
    },
    {
      "Namespace": "aws:elasticbeanstalk:environment",
      "OptionName": "EnvironmentType",
      "Value": "LoadBalanced"
    },
    {
      "Namespace": "aws:elasticbeanstalk:environment",
      "OptionName": "LoadBalancerType",
      "Value": "classic"
    },
    {
      "Namespace": "aws:autoscaling:launchconfiguration",
      "OptionName": "EC2KeyName",
      "Value": "${ENV}"
    },
    {
      "Namespace": "aws:autoscaling:launchconfiguration",
      "OptionName": "IamInstanceProfile",
      "Value": "${INSTANCE_PROFILE}"
    },
    {
      "Namespace": "aws:autoscaling:launchconfiguration",
      "OptionName": "RootVolumeSize",
      "Value": "10"
    },
    {
      "Namespace": "aws:autoscaling:launchconfiguration",
      "OptionName": "RootVolumeType",
      "Value": "standard"
    },
    {
      "Namespace": "aws:autoscaling:launchconfiguration",
      "OptionName": "SecurityGroups",
      "Value": "${SECURITY_GROUPS}"
    },
    {
      "Namespace": "aws:autoscaling:launchconfiguration",
      "OptionName": "InstanceType",
      "Value": "${FE_INSTANCE_TYPE}"
    },
    {
      "Namespace": "aws:autoscaling:asg",
      "OptionName": "MinSize",
      "Value": "1"
    },
    {
      "Namespace": "aws:autoscaling:asg",
      "OptionName": "MaxSize",
      "Value": "2"
    },
    {
      "Namespace": "aws:autoscaling:trigger",
      "OptionName": "LowerThreshold",
      "Value": "2000000"
    },
    {
      "Namespace": "aws:autoscaling:trigger",
      "OptionName": "UpperThreshold",
      "Value": "6000000"
    },
    {
      "Namespace": "aws:autoscaling:trigger",
      "OptionName": "Statistic",
      "Value": "Average"
    },
    {
      "Namespace": "aws:autoscaling:trigger",
      "OptionName": "Unit",
      "Value": "Count"
    },
    {
      "Namespace": "aws:elb:loadbalancer",
      "OptionName": "CrossZone",
      "Value": "false"
    },
    {
      "Namespace": "aws:elb:loadbalancer",
      "OptionName": "SecurityGroups",
      "Value": "${FE_ELB_SECURITY_GROUPS}"
    },
    {
      "Namespace": "aws:elb:loadbalancer",
      "OptionName": "ManagedSecurityGroup",
      "Value": "${FE_ELB_SECURITY_GROUPS}"
    },
    {
      "Namespace": "aws:elb:listener:443",
      "OptionName": "ListenerProtocol",
      "Value": "HTTPS"
    },
    {
      "Namespace": "aws:elb:listener:80",
      "OptionName": "InstanceProtocol",
      "Value": "HTTP"
    },
    {
      "Namespace": "aws:elb:listener:443",
      "OptionName": "SSLCertificateId",
      "Value": "arn:aws:iam::189675173661:server-certificate/bidgely-wc-cert-exp-29102020"
    },
    {
      "Namespace": "aws:elb:listener:443",
      "OptionName": "InstancePort",
      "Value": "80"
    },
    {
      "Namespace": "aws:elasticbeanstalk:application",
      "OptionName": "Application Healthcheck URL",
      "Value": "TCP:80"
    },
    {
      "Namespace": "aws:elasticbeanstalk:command",
      "OptionName": "BatchSize",
      "Value": "30"
    },
    {
      "Namespace": "aws:elasticbeanstalk:command",
      "OptionName": "BatchSizeType",
      "Value": "Percentage"
    },
    {
      "Namespace": "aws:elb:healthcheck",
      "OptionName": "Interval",
      "Value": "10"
    },
    {
      "Namespace": "aws:elasticbeanstalk:sns:topics",
      "OptionName": "Notification Topic ARN",
      "Value": "${ELB_SNS_TOPIC}"
    },
    {
    "Namespace": "aws:elasticbeanstalk:cloudwatch:logs",
    "OptionName": "DeleteOnTerminate",
    "Value": "True"
  },
  {
    "Namespace": "aws:elasticbeanstalk:cloudwatch:logs",
    "OptionName": "StreamLogs",
    "Value": "True"
  },
  {
    "Namespace": "aws:elasticbeanstalk:cloudwatch:logs",
    "OptionName": "RetentionInDays",
    "Value": "7"
  }
  ]
}
FEJSON
aws --region $REGION elasticbeanstalk create-environment --cli-input-json file://fetemplate.json |tee output.file2
envid2=`cat output.file2 | grep EnvironmentId | awk '{print $2}' | sed 's/"//g' | sed 's/,//g'|head -1`

if [ ! -z "$DnsConfiguration" ]
	then
    	if [ "$i" = "fe" ]
        then
		DnsConfiguration="$DnsConfiguration
        ${QUEUE_SUFFIX}${ENV}.bidgely.com ${ENV}-fe-${QUEUE_SUFFIX}"
		fi
		if [ "$i" = "admintool" ]
        then
		DnsConfiguration="$DnsConfiguration
        ${QUEUE_SUFFIX}-admin${ENV}.bidgely.com ${ENV}-admintool-${QUEUE_SUFFIX}"
		fi
	else
		if [ "$i" = "fe" ]
        then
		DnsConfiguration="${QUEUE_SUFFIX}${ENV}.bidgely.com ${ENV}-fe-${QUEUE_SUFFIX}"
		fi
		if [ "$i" = "admintool" ]
        then
		DnsConfiguration="${QUEUE_SUFFIX}-admin${ENV}.bidgely.com ${ENV}-admintool-${QUEUE_SUFFIX}"
		fi
fi

if [ "$ENV" = "dev" ]; then
cd dep-${BUILD_NUMBER}/jenkins/
chmod 755 spotebs.sh
count=0
while [ $count -ne 1 ]
do
    sleep 5
    count=`aws --region $REGION elasticbeanstalk  describe-events --environment-name ${ENV}-${i}-${QUEUE_SUFFIX} --environment-id ${envid2}  |grep "Successfully launched environment" | wc -l`
done
./spotebs.sh ${ENV}-${i}-${QUEUE_SUFFIX}
cd ../..
fi

done

fi

fi

#Create Buckets
if [ "$CreateBuckets" = "YES" ]
then
	while read -r bucket
    do
    	echo "creating s3://$bucket" 
    	aws --region $REGION s3 mb s3://$bucket
    	aws --region $REGION s3api put-bucket-tagging --bucket $bucket --tagging "TagSet=[{Key=Environment,Value=${ENV}},{Key=Utility,Value=${Utility}},{Key=Owner,Value=${Owner}},{Key=QueueSuffix,Value=${QUEUE_SUFFIX}},{Key=Name,Value=${bucket}}]"
    done <<< "$BucketNames"
fi
#Create Queues
if [ "$CreateQueues" = "YES" ]
then
	while read -r queue 
	do 
    	echo "creating queue $queue" 
    	aws --region $REGION sqs create-queue --queue-name $queue
        aws --region $REGION sqs set-queue-attributes --queue-url https://$REGION.queue.amazonaws.com/$AWSACCOUNTID/$queue --attributes ReceiveMessageWaitTimeSeconds=20,VisibilityTimeout=3600
        cat << START > $queue.json
{
"Policy": "{\"Version\":\"2012-10-17\",\"Id\":\"arn:aws:sqs:${REGION}:${AWSACCOUNTID}:${queue}/SQSDefaultPolicy\",\"Statement\":[{\"Sid\":\"Sid1510310352179\",\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"SQS:*\",\"Resource\":\"arn:aws:sqs:${REGION}:${AWSACCOUNTID}:${queue}\"}]}" 
}
START

	    aws sqs set-queue-attributes --attributes file://${queue}.json --queue-url https://sqs.${REGION}.amazonaws.com/${AWSACCOUNTID}/${queue}  --region $REGION
		aws sqs tag-queue --queue-url https://sqs.${REGION}.amazonaws.com/${AWSACCOUNTID}/${queue} --tags Name=${queue},Component=sqs,Environment=${ENV},Owner=${Owner},Utility=${Utility},QueueSuffix=${QUEUE_SUFFIX}  --region $REGION
	done <<< "$QueueNames"
fi

#Creating events
if [ "$CreateEvents" = "YES" ]
then
	echo "Creating events on buckets"
	while read -r bucketevent
    do
    	BUCKET=`echo $bucketevent |awk '{print $1}'` 
    
    	echo $bucketevent |awk '{ if (NF==3) print "\{\n\"Id\"\: \""$3"\",\n\"QueueArn\"\: \"arn\:aws\:sqs\:'$REGION'\:'$AWSACCOUNTID':"$2"\"\,\n\"Events\"\: \[\n\"s3:ObjectCreated:\*\"\n\]\n\}" ; else print "\{\n\"Filter\": \{\n\"Key\": \{\n\"FilterRules\":\[\n\{\n\"Name\":\"Prefix\",\n\"Value\":\""$4"\"\n\}\n\]\n\}\n\}\,\n\"Id\"\: \""$3"\",\n\"QueueArn\"\: \"arn\:aws\:sqs\:'$REGION'\:'$AWSACCOUNTID':"$2"\"\,\n\"Events\"\: \[\n\"s3:ObjectCreated:\*\"\n\]\n\}"}'  |jq . >/tmp/jselement 
    	if [ -e $BUCKET ]
    	then 
        	echo "," >> $BUCKET 
        	cat /tmp/jselement >>$BUCKET 
    	else 
    		echo "{\"QueueConfigurations\": [" > $BUCKET 
        	cat /tmp/jselement >>$BUCKET
    	fi
    done <<< "$BucketQueueEvents"
	for i in `echo "$BucketQueueEvents" |awk '{print $1}' | sort|uniq` 
	do 
    	echo "Putting notification on bucket $i"
    	echo "]}" >> $i
		cat $i | jq . >>$i.json
        cat $i.json
		aws --region $REGION s3api put-bucket-notification-configuration --bucket $i --notification-configuration file://$i.json 
		rm -rf $i $i.json
	done
fi



#!/bin/bash
aws configure set preview.sdb true

if [ "$ENV" = uat ];then
aws --region us-east-1  sdb put-attributes  --domain-name UatCreation --item-name ${QUEUE_SUFFIX} --attributes Name=Owner,Value=${Owner} Name=Utility,Value=${Utility} Name=endDate,Value=`date -d +30day +%s` Name=Environment,Value=uat Name=creationdate,Value=`date +%s`,Replace=True --expected Name=creationdate,Exists=False
else

aws --region us-east-1  sdb put-attributes  --domain-name FeatureCreation --item-name ${QUEUE_SUFFIX} --attributes Name=Owner,Value=${Owner} Name=Utility,Value=${Utility} Name=endDate,Value=`date -d +30day +%s` Name=Environment,Value=uat Name=creationdate,Value=`date +%s`,Replace=True --expected Name=creationdate,Exists=False
fi

#DNS
if [ ! -z "$DnsConfiguration" ]
	then
	echo "$DnsConfiguration" > dns
aws --region $REGION sts assume-role --role-arn arn:aws:iam::084566063886:role/testrole --role-session-name UAT_creation_`date +%s` > /tmp/creds
export AWS_SECRET_ACCESS_KEY=`cat /tmp/creds |grep SecretAccessKey |awk -F\" '{print $(NF-1)}'`
export AWS_ACCESS_KEY_ID=`cat /tmp/creds |grep AccessKeyId |awk -F\" '{print $(NF-1)}'`
export AWS_SESSION_TOKEN=`cat /tmp/creds |grep SessionToken |awk -F\" '{print $(NF-1)}'`

cat dns |while read -r line 
do 
    	if [ `echo $line | wc -w ` = 2 ] 
    	then
    		RecordName=`echo $line |awk '{print $1}'`
    		RecordValue=`echo $line |awk '{print $2".us-west-2.elasticbeanstalk.com"}'`
    	else
    		echo invalid DNS
    	exit 1
    	fi
cat << DNS > dns.json
{
  "HostedZoneId": "Z3U7HZTJWL9TUF",
  "ChangeBatch": {
    "Comment": "Resource record for ${ENV} of ${QUEUE_SUFFIX}",
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "${RecordName}",
          "Type": "CNAME",
          "TTL": 300,
          "ResourceRecords": [
            {
              "Value": "${RecordValue}"
            }
          ]
        }
      }
    ]
  }
}
DNS
cat dns.json


aws route53 change-resource-record-sets --cli-input-json file://dns.json

done
fi
