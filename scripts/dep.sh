#!/bin/bash
#
# Setup the the box. This runs as root
#
#

# Required for build of lxml
dd if=/dev/zero of=/swapfile bs=1024 count=524288
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile


# Rabbitmq Adding Repository
echo 'deb http://www.rabbitmq.com/debian/ testing main' |
        sudo tee /etc/apt/sources.list.d/rabbitmq.list

wget -O- https://www.rabbitmq.com/rabbitmq-signing-key-public.asc |
        sudo apt-key add -

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C2518248EEA14886
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 6B73A36E6026DFCA

# update package infos and upgrade all currently installed
apt-get -y update && apt-get -y upgrade

# Rabbitmq Server Installation
apt-get -y install rabbitmq-server

# install basic tools
apt-get -y install curl git apt-transport-https wget
apt-get -y install xterm vim htop multitail sysstat nmap tcpdump python-dev

apt-get -y install apt-file
apt-file update
apt-get -y install software-properties-common

apt-get -y update && apt-get -y upgrade

# python-lxml requirements
apt-get -y install libpam0g-dev libjpeg8-dev libxml2-dev libxslt1-dev
apt-get -y install libssl-dev libffi-dev
apt-get -y install python-dev
apt-get -y install python-lxml

# set python default encoding utf-8
sed -i "1s/^/import sys \nsys.setdefaultencoding('utf-8') \n /" /usr/lib/python2.7/sitecustomize.py


# java install for solr
apt-add-repository ppa:webupd8team/java -y && apt-get -y update
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
apt-get install -y oracle-java8-installer

===================================== # Riak Installation and Configuration BEGIN ======================================
# riak package
curl -s https://packagecloud.io/install/repositories/basho/riak/script.deb.sh | sudo bash
apt-get install -y riak

# service stop and wait
service riak stop
sleep 10

# file limits and some recommended tunings
echo 'ulimit -n 65536' >> /etc/default/riak
echo "session    required   pam_limits.so" >> /etc/pam.d/common-session
echo "session    required   pam_limits.so" >> /etc/pam.d/common-session-noninteractive
sed -i '$i\*              soft     nofile          65536\n\*              hard     nofile          65536'  /etc/security/limits.conf

# change linux boot options for riak performance
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="elevator=noop /' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="clocksource=hpet /' /etc/default/grub
update-grub

sed -i "s/search = off/search = on/" /etc/riak/riak.conf
sed -i "s/anti_entropy = active/anti_entropy = passive/" /etc/riak/riak.conf
sed -i "s/storage_backend = bitcask/storage_backend = multi/" /etc/riak/riak.conf
sed -i "s/search.solr.start_timeout = 30s/search.solr.start_timeout = 120s/" /etc/riak/riak.conf
sed -i "s/leveldb.maximum_memory.percent = 70/leveldb.maximum_memory.percent = 30/" /etc/riak/riak.conf
sed -i "s/listener.http.internal = 127.0.0.1:8098/listener.http.internal = 0.0.0.0:8098/" /etc/riak/riak.conf
sed -i "s/listener.protobuf.internal = 0.0.0.0:8087/listener.protobuf.internal = 0.0.0.0:8087/" /etc/riak/riak.conf

echo "multi_backend.bitcask_mult.storage_backend = bitcask
multi_backend.bitcask_mult.bitcask.data_root = /var/lib/riak/bitcask_mult
multi_backend.leveldb_mult.storage_backend = leveldb
multi_backend.leveldb_mult.leveldb.data_root = /var/lib/riak/leveldb_mult
multi_backend.default = bitcask_mult
search.solr.jvm_options = -d64 -Xms512m -Xmx512m -XX:+UseStringCache -XX:+UseCompressedOops" >> /etc/riak/riak.conf

===================================== # Riak Installation END ==========================================================


# Redis Installation
apt-get install -y redis-server
sed -i "s/bind 127.0.0.1/bind 0.0.0.0/" /etc/redis/redis.conf


# ===================================== # Zato Installation and Configuration BEGIN ====================================

curl -s https://zato.io/repo/zato-0CBD7F72.pgp.asc | sudo apt-key add -
apt-add-repository https://zato.io/repo/stable/2.0/ubuntu -y
apt-get -y update
apt-get install -y zato

sudo su - zato sh -c "

wget https://raw.githubusercontent.com/zetaops/ulakbus-development-box/master/scripts/env-vars/zato_environment_variables
cat ~/zato_environment_variables >> ~/.profile
source ~/.profile

mkdir ~/ulakbus;

# Create a new zato project named ulakbus
zato quickstart create ~/ulakbus sqlite localhost 6379 --kvdb_password='' --servers 1 --verbose;

# Change password of zato admin to new one.(Password = ulakbus)
echo 'command=update_password
path=/opt/zato/ulakbus/web-admin
store_config=True
username=admin
password=ulakbus' > ~/ulakbus/zatopw.conf

zato from-config ~/ulakbus/zatopw.conf
"

apt-get install -y virtualenvwrapper

mkdir /app
/usr/sbin/useradd --home-dir /app --shell /bin/bash --comment 'ulakbus operations' ulakbus
chown ulakbus:ulakbus /app -Rf

#Add ulakbus user to sudoers
adduser ulakbus sudo

sudo su - ulakbus sh -c "
cd ~

#environment variables specific to all libs
mkdir env-vars
cd env-vars
wget https://raw.githubusercontent.com/zetaops/ulakbus-development-box/master/scripts/env-vars/ulakbus_postactivate
wget https://raw.githubusercontent.com/zetaops/ulakbus-development-box/master/scripts/env-vars/pyoko_postactivate
wget https://raw.githubusercontent.com/zetaops/ulakbus-development-box/master/scripts/env-vars/zengine_postactivate

cd ~
#ulakbus virtualenv
virtualenv --no-site-packages ulakbusenv
cat ~/env-vars/ulakbus_postactivate >> ~/ulakbusenv/bin/activate

echo "

# ulakbus-env variables
export ZENGINE_SETTINGS=ulakbus.settings
export LC_CTYPE=en_US.UTF-8
export RIAK_PORT=8098
export REDIS_SERVER=127.0.0.1:6379
export RIAK_SERVER=127.0.0.1
export RIAK_PROTOCOL=http
export PYOKO_SETTINGS=ulakbus.settings
export PYTHONUNBUFFERED=1
export DEFAULT_BUCKET_TYPE='models'
export LOG_HANDLER='file'
export LOG_FILE='/app/logs/ulakbus.log'
export DEBUG=1
export DEBUG_LEVEL=11
export MQ_VHOST=ulakbus
export MQ_PASS=123
export MQ_USER=ulakbus

" >> ~/ulakbusenv/bin/activate

# necessary for LOG_FILE env-var
mkdir /app/logs/

#pyoko virtualenv
virtualenv --no-site-packages pyokoenv
cat ~/env-vars/pyoko_postactivate >> ~/pyokoenv/bin/activate

#zengine virtualenv
virtualenv --no-site-packages zengineenv
cat ~/env-vars/zengine_postactivate >> ~/zengineenv/bin/activate

# clone pyoko from github
git clone https://github.com/zetaops/pyoko.git

# clone zengine from github
git clone https://github.com/zetaops/zengine.git

# clone ulakbus from github
git clone https://github.com/zetaops/ulakbus.git

# clone faker from github
git clone https://github.com/zetaops/faker.git

# =========== ulakbus BEGIN =========
#activate ulakbusenv
source ~/ulakbusenv/bin/activate

pip install --upgrade pip
pip install ipython

cd ~/ulakbus
pip install -r requirements/develop.txt

pip uninstall --y Pyoko
pip uninstall --y pyoko
pip uninstall --y zengine

rm -rf ~/ulakbusenv/lib/python2.7/site-packages/Pyoko*
rm -rf ~/ulakbusenv/lib/python2.7/site-packages/pyoko*
rm -rf ~/ulakbusenv/lib/python2.7/site-packages/zengine*

deactivate
# =========== ulakbus END =========



# =========== pyoko BEGIN =========
#activate pyokoenv
source ~/pyokoenv/bin/activate

pip install --upgrade pip
pip install ipython

cd ~/pyoko
pip install -r requirements/default.txt

deactivate
# =========== pyoko END =========



# =========== zengine BEGIN =========
#activate zengineenv
source ~/zengineenv/bin/activate

pip install --upgrade pip
pip install ipython

cd ~/zengine
pip install -r requirements/default.txt

pip uninstall --y Pyoko

rm -rf ~/zengineenv/lib/python2.7/site-packages/Pyoko*

deactivate
# =========== zengine END =========


# Copy libraries: pyoko, ulakbus, zengine to ulakbusenv
ln -s ~/pyoko/pyoko      ~/ulakbusenv/lib/python2.7/site-packages
ln -s ~/ulakbus/ulakbus  ~/ulakbusenv/lib/python2.7/site-packages
ln -s ~/zengine/zengine  ~/ulakbusenv/lib/python2.7/site-packages
ln -s ~/ulakbus/tests    ~/ulakbusenv/lib/python2.7/site-packages
ln -s ~/faker/faker      ~/ulakbusenv/lib/python2.7/site-packages

# Necessary to use riak from zato user
touch ~/ulakbusenv/lib/python2.7/site-packages/google/__init__.py

# Copy libraries: pyoko, zengine to zengineenv
ln -s ~/pyoko/pyoko       ~/zengineenv/lib/python2.7/site-packages
ln -s ~/zengine/zengine   ~/zengineenv/lib/python2.7/site-packages
ln -s ~/zengine/tests     ~/zengineenv/lib/python2.7/site-packages

# Copy libraries: pyoko to pyokoenv
ln -s ~/pyoko/pyoko   ~/pyokoenv/lib/python2.7/site-packages
ln -s ~/pyoko/tests   ~/pyokoenv/lib/python2.7/site-packages
# end
"
# Create symbolic links for all dependecies and pyoko, zengine, ulakbus for Zato
# Since zato installations based on version numbers, I used wildcards while creating symbolic links
#
sudo su - zato sh -c "
ln -s /app/pyoko/pyoko                                                 /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/zengine/zengine                                             /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbus/ulakbus                                             /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbusenv/lib/python2.7/site-packages/riak                 /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbusenv/lib/python2.7/site-packages/redis                /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbusenv/lib/python2.7/site-packages/SpiffWorkflow        /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbusenv/lib/python2.7/site-packages/werkzeug             /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbusenv/lib/python2.7/site-packages/lazy_object_proxy    /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbusenv/lib/python2.7/site-packages/falcon               /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbusenv/lib/python2.7/site-packages/beaker               /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbusenv/lib/python2.7/site-packages/beaker_extensions    /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbusenv/lib/python2.7/site-packages/passlib              /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbusenv/lib/python2.7/site-packages/google               /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbusenv/lib/python2.7/site-packages/enum                 /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbusenv/lib/python2.7/site-packages/celery               /opt/zato/2.*.*/zato_extra_paths/
ln -s /app/ulakbusenv/lib/python2.7/site-packages/funcsigs             /opt/zato/2.*.*/zato_extra_paths/
"

# Create symbolic links for zato project to start them at login

ln -s /opt/zato/ulakbus/load-balancer /etc/zato/components-enabled/ulakbus.load-balancer
ln -s /opt/zato/ulakbus/server1 /etc/zato/components-enabled/ulakbus.server1
ln -s /opt/zato/ulakbus/web-admin /etc/zato/components-enabled/ulakbus.web-admin

# Start zato service
service zato start
# ===================================== # Zato Installation and Configuration END ======================================



# ===================================== # Riak Post Configuration BEGIN ================================================
service riak start
sleep 30

riak-admin bucket-type create pyoko_models '{"props":{"last_write_wins":true, "allow_mult":false, "n_val":1}}'
riak-admin bucket-type create zengine_models '{"props":{"last_write_wins":true, "allow_mult":false, "n_val":1}}'
riak-admin bucket-type create models '{"props":{"last_write_wins":true, "allow_mult":false, "n_val":1}}'
riak-admin bucket-type create catalog '{"props":{"last_write_wins":true, "dvv_enabled":false, "allow_mult":false, "n_val": 1}}'

riak-admin bucket-type activate pyoko_models
riak-admin bucket-type activate zengine_models
riak-admin bucket-type activate models
riak-admin bucket-type activate catalog

# ===================================== # Riak Post Configuration END ====================================================

# Rabbitmq Ulakbus Configuration
rabbitmqctl add_vhost ulakbus
rabbitmqctl add_user ulakbus 123
rabbitmqctl set_permissions -p ulakbus ulakbus ".*" ".*" ".*"

# Initial migration of ulakbus models and load fixtures
sudo su - ulakbus sh -c "
cd ~
source ~/ulakbusenv/bin/activate
pip install lxml
python ~/ulakbus/ulakbus/manage.py migrate --model all
python ~/ulakbus/ulakbus/manage.py load_data --path ~/ulakbus/tests/fixtures/
python ~/ulakbus/ulakbus/manage.py load_diagrams
python ~/ulakbus/ulakbus/manage.py load_fixture --path ~/ulakbus/ulakbus/fixtures/
python ~/ulakbus/ulakbus/manage.py preparemq
deactivate
"

# Clean up
apt-get -y autoremove
apt-get clean
rm -rf /var/lib/apt/lists/*
