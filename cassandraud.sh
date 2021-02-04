#!/bin/bash
sudo mkfs.ext4 /dev/xvdb
sudo mkfs.ext4 /dev/xvdc
sudo mkdir -m 000 /mnt1
sudo mkdir -m 000 /mnt2
echo "/dev/xvdb /mnt1 auto noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/xvdc /mnt2 auto noatime 0 0" | sudo tee -a /etc/fstab
mount /mnt1
mount /mnt2
chown -R cassandra:cassandra /mnt1
chown -R cassandra:cassandra /mnt2
cd /mnt1/
mkdir cassandra
cd cassandra
mkdir commitlog
cd ~
cd /mnt2/
mkdir cassandra
cd cassandra
mkdir data
chown -R cassandra:cassandra /mnt1/
chown -R cassandra:cassandra /mnt2/
sed -i 's/192.168.10.10,192.168.11.10,192.168.12.10/10.0.48.29,10.0.48.30,10.0.48.31/g' /etc/cassandra/cassandra.yaml;
sed -i 's/PrfmCluster/NACluster/g' /etc/cassandra/cassandra.yaml;
sed -i 's/dc1/us-east-m4/g' /etc/cassandra/cassandra-rackdc.properties;
sed -i 's/rack1/1b/g' /etc/cassandra/cassandra-rackdc.properties;
sed -i 's/Ec2Snitch/GossipingPropertyFileSnitch/g' /etc/cassandra/cassandra.yaml;
ip=`/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}'`
sed -i 's/192.168.10.10/'"$ip"'/g' /etc/cassandra/cassandra.yaml;
