#!/bin/bash -x
> /var/log/cloud-init-output.log
> /var/log/cloud-init.log
echo "=================USER SCRIPT START===================="
cat <<"setvariables" > /tmp/setvariables.sh
export TAGNAME=hawk
export TAGCOMPONENT=daemons
export TAGENV=nonprodqa
export OWNER=ops
export UTILITY=all
export STARTDATE=2017-07-02T00:01:00Z
export ENDDATE=2027-07-02T00:00:00Z
export AMIID=ami-0d599be3961a582b0
export SNAPSHOTID=
export SUBNET=subnet-63443d05
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export BIDGELY_ENV=nonprodqa
export SECURITYGROUP='sg-7cefc601'
export KEYPAIR=dev
export INSTANCEPROFILE=arn:aws:iam::189675173661:instance-profile/nonprodqa-iam-instance-profile
export QUEUE_SUFFIX=
export REPO=repo2.bidgely.com
export REPODIR=debs/nonprodqa
export S3ARTIFACTSBUCKET=bidgely-artifacts/operations
export CLOUDWATCH=YES
export SNSTOPIC=SPOT-PROD
export RPMLIST=nonprodqa
setvariables
chmod 700 /tmp/setvariables.sh
source /tmp/setvariables.sh
aws s3 cp s3://bidgely-artifacts2/userdata/hawkuserdata.sh .
chmod 700 hawkuserdata.sh
./hawkuserdata.sh
