#!/usr/bin/env bash

if [ -d /var/lib/cassandra/data/system ]; then
  echo "file /var/lib/cassandra/data/system already exists"
  exit 0
fi

sudo bash -c 'cat <<EOF > /etc/yum.repos.d/cassandra.repo
[cassandra]
name=Apache Cassandra
baseurl=https://www.apache.org/dist/cassandra/redhat/311x/
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://www.apache.org/dist/cassandra/KEYS
EOF'

sudo yum update -y
sudo yum install cassandra -y

java -version

sudo bash -c 'cat <<EOF > /etc/systemd/system/cassandra.service
[Unit]
Description=Apache Cassandra
Documentation=http://cassandra.apache.org/
After=network.target

[Service]
Type=forking
User=cassandra
Group=cassandra
LimitNOFILE=100000:10000000
Environment=CASSANDRA_CONF=/etc/cassandra/conf
ExecStart=/usr/sbin/cassandra -p /var/run/cassandra/cassandra.pid
PIDFile=/var/run/cassandra/cassandra.pid
TimeoutStopSec=180
Restart=no

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl enable cassandra

sleep 15

sudo systemctl stop cassandra.service

sudo rm -rf /var/lib/cassandra/data/system

sleep 2
