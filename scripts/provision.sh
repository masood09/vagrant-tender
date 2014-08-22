#!/bin/bash

echo ">>>> Configuring Swap space"
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
sysctl vm.swappiness=10 > /dev/null
echo "vm.swappiness=10" >> /etc/sysctl.conf
sysctl vm.vfs_cache_pressure=50 > /dev/null
echo "vm.vfs_cache_pressure = 50" >> /etc/sysctl.conf

echo ">>>> Adding required repos"
apt-get install -y --force-yes -qq software-properties-common > /dev/null
apt-add-repository -y ppa:nginx/stable > /dev/null
apt-add-repository -y ppa:rwky/redis > /dev/null
apt-add-repository -y ppa:ondrej/php5 > /dev/null

echo ">>>> Updating the system"
apt-get -qq update > /dev/null
apt-get -qq upgrade > /dev/null

echo ">>>> Installing base software"
apt-get install -y --force-yes -qq build-essential curl dos2unix gcc git libmcrypt4 libpcre3-dev make unattended-upgrades whois vim > /dev/null

echo ">>>> Setting Timezone (UTC)"
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

echo ">>>> Installing PHP5"
apt-get install -y --force-yes -qq php5-cli php5-dev php-pear php5-mysqlnd php5-sqlite php5-apcu php5-json php5-curl php5-gd php5-gmp php5-imap php5-mcrypt php5-xdebug php5-redis > /dev/null
php5enmod mcrypt
pecl install mailparse > /dev/null
echo "extension=mailparse.so" > /etc/php5/mods-available/mailparse.ini
ln -sf /etc/php5/mods-available/mailparse.ini /etc/php5/cli/conf.d/20-mailparse.ini

echo ">>>> Installing Composer"
curl -sS https://getcomposer.org/installer | php > /dev/null
mv composer.phar /usr/local/bin/composer
printf "\nPATH=\"/home/vagrant/.composer/vendor/bin:\$PATH\"\n" | tee -a /home/vagrant/.profile

echo ">>>> Configuring PHP5 CLI"
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/cli/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/cli/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php5/cli/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php5/cli/php.ini

echo ">>>> Installing Nginx and PHP-FPM"
apt-get install -y --force-yes -qq nginx php5-fpm > /dev/null
rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
service nginx restart

echo ">>>> Configuring Nginx and PHP-FPM"
ln -s /etc/php5/mods-available/mailparse.ini /etc/php5/fpm/conf.d/20-mailparse.ini
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php5/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php5/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php5/fpm/php.ini
sed -i "s/user www-data;/user vagrant;/" /etc/nginx/nginx.conf
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf
sed -i "s/user = www-data/user = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/;listen\.owner.*/listen.owner = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/;listen\.group.*/listen.group = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php5/fpm/pool.d/www.conf
service nginx restart
service php5-fpm restart

echo ">>>> Creating SSL certificates"
mkdir -pv /etc/nginx/ssl/
openssl genrsa -passout pass:secret -des3 -out /etc/nginx/ssl/server.key 1024
openssl req -passin pass:secret -new -key /etc/nginx/ssl/server.key -subj "/C=UK/ST=/L=Manchester/O=Murvo Technologies/CN=tender.app" -out /etc/nginx/ssl/server.csr
cp /etc/nginx/ssl/server.key /etc/nginx/ssl/server.key.org
openssl rsa -passin pass:secret -in /etc/nginx/ssl/server.key.org -out /etc/nginx/ssl/server.key
openssl x509 -req -days 365 -in /etc/nginx/ssl/server.csr -signkey /etc/nginx/ssl/server.key -out /etc/nginx/ssl/server.crt

echo ">>>> Adding vagrant user to group www-data"
usermod -a -G www-data vagrant

echo ">>>> Installing sqlite3"
apt-get install -y --force-yes -qq sqlite3 libsqlite3-dev > /dev/null

echo ">>>> Installing MySQL"
debconf-set-selections <<< "mysql-server mysql-server/root_password password secret"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password secret"
apt-get install -y --force-yes -qq mysql-server > /dev/null

echo ">>>> Configuring MySQL"
sed -i '/^bind-address/s/bind-address.*=.*/bind-address = 10.0.2.15/' /etc/mysql/my.cnf
mysql --user="root" --password="secret" -e "GRANT ALL ON *.* TO root@'10.0.2.2' IDENTIFIED BY 'secret' WITH GRANT OPTION;"
service mysql restart > /dev/null

echo ">>>> Creating murvolocal MySQL user"
mysql --user="root" --password="secret" -e "CREATE USER 'murvolocal'@'10.0.2.2' IDENTIFIED BY 'secret';"
mysql --user="root" --password="secret" -e "GRANT ALL ON *.* TO 'murvolocal'@'10.0.2.2' IDENTIFIED BY 'secret' WITH GRANT OPTION;"
mysql --user="root" --password="secret" -e "GRANT ALL ON *.* TO 'murvolocal'@'%' IDENTIFIED BY 'secret' WITH GRANT OPTION;"
mysql --user="root" --password="secret" -e "FLUSH PRIVILEGES;"
mysql --user="root" --password="secret" -e "CREATE DATABASE murvolocal;"
service mysql restart > /dev/null

echo ">>>> Installing Redis"
apt-get install -y --force-yes -qq redis-server > /dev/null

echo ">>>> Installing Mailcacher"
apt-get -y --force-yes -qq install ruby-dev > /dev/null
gem install --no-rdoc --no-ri mailcatcher > /dev/null
echo "@reboot $(which mailcatcher) --ip=0.0.0.0" >> /etc/crontab
update-rc.d cron defaults

echo ">>>> Starting Mailcacher"
/usr/bin/env $(which mailcatcher) --ip=0.0.0.0

echo ">>>> Copying bash aliases"
cp /vagrant/aliases /home/vagrant/.bash_aliases

echo ">>>> Cleaning Up"
apt-get -qq clean > /dev/null
apt-get -qq autoclean > /dev/null
apt-get -qq autoremove > /dev/null

echo ">>>> Updating composer"
/usr/local/bin/composer self-update > /dev/null
