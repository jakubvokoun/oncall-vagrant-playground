#!/bin/sh

set -e
set -x

 sudo yum -y update
 sudo yum -y install epel python python-devel python-virtualenv \
    mariadb-server openldap-devel libssl-devel libxml2-devel git \
    openssl-devel libffi-devel wget
sudo yum -y groupinstall "Development tools"

cd /tmp
wget https://bin.equinox.io/c/ekMN3bCZFUn/forego-stable-linux-amd64.tgz
sudo tar xvf forego-stable-linux-amd64.tgz -C /usr/local/bin

sudo systemctl enable mariadb
sudo systemctl start mariadb

cd $HOME
test -d $HOME/oncall && rm -rf $HOME/oncall
git clone https://github.com/linkedin/oncall
cd $HOME/oncall

echo "drop database if exists oncall" | mysql -u root
mysql -u root < ./db/schema.v0.sql
mysql -u root -o oncall < ./db/dummy_data.sql

sed -i 's/slackclient/slackclient==1.3.2/' setup.py
sed -i 's/oncall-mysql/localhost/' configs/config.yaml
sed -i 's/1234//' configs/config.yaml

virtualenv venv
source venv/bin/activate
python setup.py develop
pip install --upgrade pip || true
pip install -e '.[dev]' || true

sudo tee /etc/systemd/system/oncall.service <<EOF
[Unit]
Description=Oncall
After=network.target

[Service]
Type=simple
User=vagrant
Group=vagrant
ExecStart=/bin/sh -c 'cd /home/vagrant/oncall && source venv/bin/activate && forego start'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable oncall
sudo systemctl start oncall
