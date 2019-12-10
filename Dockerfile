FROM debian:buster

ARG phpmyadmin_version="4.9.2"
ARG mysql_root_pw="test"
ARG mysql_wp_db="wordpress"
ARG mysql_wp_user="wordpress"
ARG mysql_wp_pw="test"
ARG mysql_php_user="phpadmin"
ARG mysql_php_pw="test"
ARG phpmyadmin_secret=",3Eet7Gu:O2VRV4GGSf0Wl8JI:iMXwEr"
ARG autoindex="on"

ENV DEBIAN_FRONTEND=noninteractive

# dependencies
RUN apt-get update && apt-get install -y wget unzip gnupg lsb-release ssl-cert
# nginx & php
RUN apt-get install -y nginx php-fpm php-mysql php-mbstring
RUN wget -qO /tmp/phpmyadmin.zip https://files.phpmyadmin.net/phpMyAdmin/$phpmyadmin_version/phpMyAdmin-$phpmyadmin_version-all-languages.zip
RUN cd /tmp && unzip phpmyadmin.zip && rm -f phpmyadmin.zip && mv phpMyAdmin-$phpmyadmin_version-all-languages /usr/share/phpmyadmin && chown -R www-data:www-data /usr/share/phpmyadmin && ln -s /usr/share/phpmyadmin /var/www/html
# mysql-server
RUN wget -qO /tmp/mysql.deb https://dev.mysql.com/get/mysql-apt-config_0.8.14-1_all.deb
RUN echo "4" | dpkg -i /tmp/mysql.deb && rm -f /tmp/mysql.deb && apt-get update
RUN echo "mysql-server mysql-server/root_password password $mysql_root_pw" | debconf-set-selections && echo "mysql-server mysql-server/root_password_again password $mysql_root_pw" | debconf-set-selections
RUN apt-get update && apt-get install -y mysql-server
# wordpress
RUN wget -qO /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz
RUN cd /tmp && tar xzf wordpress.tar.gz && rm -f wordpress.tar.gz && mv wordpress/* /var/www/html/ && rmdir wordpress
# nginx config
COPY srcs/nginx-default /etc/nginx/sites-enabled/default
RUN sed -i "s/autoindex off/autoindex $autoindex/" /etc/nginx/sites-enabled/default
# php config
RUN cd /usr/share/phpmyadmin && sed -e "s|cfg\['blowfish_secret'\] = ''|cfg['blowfish_secret'] = '$phpmyadmin_secret'|" config.sample.inc.php > config.inc.php
# wordpress config
RUN cd /var/www/html && sed -e "s/database_name_here/$mysql_wp_db/" -e "s/username_here/$mysql_wp_user/" -e "s/password_here/$mysql_wp_pw/" wp-config-sample.php > wp-config.php
# mysql config
COPY srcs/mysql.server /etc/init.d/mysql.server
RUN chmod a+x /etc/init.d/mysql.server
RUN service mysql.server start && mysql -e "CREATE DATABASE phpmyadmin;CREATE USER $mysql_php_user IDENTIFIED WITH mysql_native_password BY '$mysql_php_pw';GRANT ALL PRIVILEGES ON phpmyadmin.* TO '$mysql_php_user'" && service mysql.server stop
RUN service mysql.server start && mysql -e "CREATE DATABASE $mysql_wp_db;CREATE USER $mysql_wp_user IDENTIFIED WITH mysql_native_password BY '$mysql_wp_pw';GRANT ALL PRIVILEGES ON $mysql_wp_db.* TO '$mysql_wp_user'" && service mysql.server stop
# run server
CMD service mysql.server start && service php7.3-fpm start && service nginx start && tail -f /dev/null
