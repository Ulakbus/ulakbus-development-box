#!/bin/bash
#
# Setup the the box. This runs as root

apt-get -y update

apt-get -y install curl
apt-get -y install git
apt-get -y install apt-file
apt-file update
apt-get -y install software-properties-common
# You can install anything you need here.

apt-get -y update
apt-get -y upgrade

ulimit -n 65536
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

apt-add-repository ppa:webupd8team/java -y && apt-get update
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
apt-get install -y oracle-java8-installer

curl -s https://packagecloud.io/install/repositories/zetaops/riak/script.deb.sh |sudo bash
apt-get install riak=2.1.1-1

sed -i "s/search = off/search = on/" /etc/riak/riak.conf

service riak restart

apt-get install -y libssl-dev
apt-get install -y libffi-dev


apt-get install -y redis-server

apt-get install -y  apt-transport-https
curl -s https://zato.io/repo/zato-0CBD7F72.pgp.asc | sudo apt-key add -
apt-add-repository https://zato.io/repo/stable/2.0/ubuntu
apt-get update
apt-get install -y zato

sudo su - zato sh -c "
mkdir ~/ulakbus;

zato quickstart create ~/ulakbus sqlite localhost 6379 --kvdb_password='' --verbose;"

apt-get install -y virtualenvwrapper

mkdir /app
/usr/sbin/useradd --home-dir /app --shell /bin/bash --comment 'ulakbus operations' ulakbus

chown ulakbus:ulakbus /app -Rf

sudo su - ulakbus sh -c "
cd ~;

virtualenv --no-site-packages env;
source env/bin/activate;

pip install --upgrade pip;
git clone https://github.com/zetaops/ulakbus.git;
cd /app/ulakbus;
pip install -r requirements.txt;
pip install git+https://github.com/zetaops/pyoko.git;
"
