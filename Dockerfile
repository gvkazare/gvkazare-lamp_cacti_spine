FROM phusion/baseimage:0.10.2
MAINTAINER gvkazare
ENV REFRESHED_AT 2019-06-23

# based on mattrayner/lamp
# MAINTAINER Matthew Rayner <matt@mattrayner.co.uk>


ENV DOCKER_USER_ID 501 
ENV DOCKER_USER_GID 20

ENV BOOT2DOCKER_ID 1000
ENV BOOT2DOCKER_GID 50

ENV PHPMYADMIN_VERSION=4.9.0.1

# Tweaks to give Apache/PHP write permissions to the app
RUN usermod -u ${BOOT2DOCKER_ID} www-data && \
    usermod -G staff www-data && \
    useradd -r mysql && \
    usermod -G staff mysql

RUN groupmod -g $(($BOOT2DOCKER_GID + 10000)) $(getent group $BOOT2DOCKER_GID | cut -d: -f1)
RUN groupmod -g ${BOOT2DOCKER_GID} staff

# Install packages
ENV DEBIAN_FRONTEND noninteractive
RUN add-apt-repository -y ppa:ondrej/php && \
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C && \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get -y install nano mc supervisor wget git apache2 iputils-ping rrdtool librrds-perl curl \ 
		     python3-pip python-virtualenv python-netsnmp \
		     gcc make automake autoconf help2man dos2unix libtool libc-dev pkg-config \ 
		     mysql-server \
		     php php-snmp php-xdebug libapache2-mod-php php-mysql php-apcu php7.1-mcrypt php-gd php-xml php-mbstring php-gettext php-json php-net-socket php-gmp php-ldap php-zip php-curl \
		     snmp snmpd libnet-snmp-perl snmp-mibs-downloader libsnmp-dev libmysqlclient-dev \
		     pwgen zip unzip && \
  apt-get -y autoremove && \
  echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
  pip3 install --upgrade pip && \
  pip install pymysql paramiko textfsm tabulate pycurl
  

#for python 
RUN ln -s /usr/bin/python3.5 /usr/local/bin/python3.5

# Add image configuration and scripts
ADD supporting_files/start-apache2.sh /start-apache2.sh
ADD supporting_files/start-mysqld.sh /start-mysqld.sh
ADD supporting_files/run.sh /run.sh
RUN chmod 755 /*.sh

ADD supporting_files/supervisord-apache2.conf /etc/supervisor/conf.d/supervisord-apache2.conf
ADD supporting_files/supervisord-mysqld.conf /etc/supervisor/conf.d/supervisord-mysqld.conf
#ADD supporting_files/mysqld_innodb.cnf /etc/mysql/conf.d/mysqld_innodb.cnf

# Allow mysql to bind on 0.0.0.0
RUN sed -i "s/.*bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/my.cnf && \
    sed -i "s/.*bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf

# Set PHP timezones to Europe/London
RUN sed -i "s/;date.timezone =/date.timezone = Europe\/Moscow/g" /etc/php/7.3/apache2/php.ini
RUN sed -i "s/;date.timezone =/date.timezone = Europe\/Moscow/g" /etc/php/7.3/cli/php.ini

# Remove pre-installed database
RUN rm -rf /var/lib/mysql

# Add MySQL utils
ADD supporting_files/create_mysql_users.sh /create_mysql_users.sh
ADD supporting_files/create_mysql_cacti.sh /create_mysql_cacti.sh
RUN chmod 755 /*.sh


# #to fix error relate to ip address of container apache2
RUN echo "ServerName localhost" | tee /etc/apache2/conf-available/fqdn.conf
RUN ln -s /etc/apache2/conf-available/fqdn.conf /etc/apache2/conf-enabled/fqdn.conf

# Add phpmyadmin
RUN wget -O /tmp/phpmyadmin.tar.gz https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz
RUN tar xfvz /tmp/phpmyadmin.tar.gz -C /var/www
RUN ln -s /var/www/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages /var/www/phpmyadmin
RUN mv /var/www/phpmyadmin/config.sample.inc.php /var/www/phpmyadmin/config.inc.php

# Add composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer

ENV MYSQL_PASS:-$(pwgen -s 12 1)

# config to enable .htaccess
ADD supporting_files/apache_default /etc/apache2/sites-available/000-default.conf
RUN a2enmod rewrite

# Configure /app folder with sample app
RUN mkdir -p /app && rm -fr /var/www/html && ln -s /app /var/www/html && \
  mkdir /hlam
ADD app/ /app

#Environment variables to configure php
ENV PHP_UPLOAD_MAX_FILESIZE 10M
ENV PHP_POST_MAX_SIZE 10M


#---------------------------------------------------------------------------------------

#Install cacti
RUN cd /opt/ \
    && wget https://www.cacti.net/downloads/cacti-latest.tar.gz \
    && ver=$(tar -tf cacti-latest.tar.gz | head -n1 | tr -d /) \
    && tar -xvf cacti-latest.tar.gz && mv $ver cacti \
    && rm cacti-latest.tar.gz \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/*  \
    && rm -rf /var/lib/apt/lists/*

#Install spine
RUN cd /opt/ \
  && wget http://www.cacti.net/downloads/spine/cacti-spine-latest.tar.gz \
  && ver=$(tar -tf cacti-spine-latest.tar.gz | head -n1 | tr -d /) \
  && tar -xvf /opt/cacti-spine-latest.tar.gz \ 
  && cd /opt/$ver/ \
  && ./bootstrap \
#  && ./configure --with-mysql=/usr/bin \
  && ./configure \
  && make \
  && make install \
  && chown root:root /usr/local/spine/bin/spine \
  && chmod +s /usr/local/spine/bin/spine


# cacti logs
RUN touch /opt/cacti/log/cacti.log
RUN touch /opt/cacti/log/cacti_stderr.log
RUN chown -R www-data:www-data /opt/cacti/


# to create a link for the cacti web directory
RUN mkdir -p /usr/share/cacti/scripts
RUN ln -s /opt/cacti/scripts /usr/share/cacti/scripts
RUN ln -s /opt/cacti/ /var/www/html/cacti

#configure poller Crontab
RUN echo "*/5 * * * * www-data php /opt/cacti/poller.php > /dev/null 2>&1" >> /etc/crontab
#/usr/bin/php -q /opt/cacti/poller.php --force

# Ensure cron is allowed to run
RUN sed -i 's/^\(session\s\+required\s\+pam_loginuid\.so.*$\)/# \1/g' /etc/pam.d/cron


#tuning mysql from pre-config
#RUN mv /etc/mysql/my.cnf /etc/mysql/my.cnf-bkup
#COPY cacti_files/my.cnf /etc/mysql/my.cnf

##Get Mibs
RUN /usr/bin/download-mibs
RUN echo 'mibs +ALL' >> /etc/snmp/snmp.conf
COPY cacti_files/SNMPv2-PDU /usr/share/mibs/ietf/SNMPv2-PDU
COPY cacti_files/IPATM-IPMC-MIB /usr/share/mibs/ietf/IPATM-IPMC-MIB
COPY cacti_files/IANA-IPPM-METRICS-REGISTRY-MIB /usr/share/mibs/iana/IANA-IPPM-METRICS-REGISTRY-MIB



#include config files
COPY cacti_files/snmpd.conf /etc/snmp/snmpd.conf
COPY cacti_files/cacti_conf.conf /opt/cacti/include/config.php
COPY cacti_files/spine.conf /usr/local/spine/etc/spine.conf
COPY cacti_files/spine.conf /etc/spine.conf
RUN chmod 777 /usr/local/spine/etc/spine.conf && \ 
    chmod 777 /etc/spine.conf

##scritp that can be running from the outside using docker-bash tool ...
COPY cacti_files/backup.sh /sbin/backup
COPY cacti_files/restore.sh /sbin/restore
RUN chmod +x /sbin/backup /sbin/restore

# Add volumes for the app and MySql
VOLUME  ["/var/backups", "/etc/mysql", "/var/lib/mysql", "/app", "/var/log", "/hlam" ]

EXPOSE 80 3306
#CMD ["/run.sh"]
