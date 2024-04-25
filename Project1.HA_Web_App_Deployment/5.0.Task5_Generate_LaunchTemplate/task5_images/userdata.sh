#!/bin/bash -xe

# import variables from ssm  

EFSHOST=$(aws ssm get-parameters --region us-east-1 --names EFS_HOST --query Parameters[0].Value)
EFSHOST=`echo $EFSHOST | sed -e 's/^"//' -e 's/"$//'`

DBPASSWORD=$(aws ssm get-parameters --region us-east-1 --names DB_PASSWORD --with-decryption --query Parameters[0].Value)
DBPASSWORD=`echo $DBPASSWORD | sed -e 's/^"//' -e 's/"$//'`

DBUSER=$(aws ssm get-parameters --region us-east-1 --names DB_USER --query Parameters[0].Value)
DBUSER=`echo $DBUSER | sed -e 's/^"//' -e 's/"$//'`

DBNAME=$(aws ssm get-parameters --region us-east-1 --names DB_NAME --query Parameters[0].Value)
DBNAME=`echo $DBNAME | sed -e 's/^"//' -e 's/"$//'`

DBHOST=$(aws ssm get-parameters --region us-east-1 --names DB_HOST --query Parameters[0].Value)
DBHOST=`echo $DBHOST | sed -e 's/^"//' -e 's/"$//'`

LBHOST=$(aws ssm get-parameters --region us-east-1 --names LB_HOST --query Parameters[0].Value)
LBHOST=`echo $LBHOST | sed -e 's/^"//' -e 's/"$//'`


yum update -y

#install apache server 
yum install -y httpd

#install php
sudo amazon-linux-extras enable php7.4
clean metadata 
yum install php-cli php-pdo php-fpm php-json php-mysqlnd -y
yum install php php-devel -y
sudo amazon-linux-extras install -y php7.4
yum install amazon-efs-utils -y

systemctl start httpd
systemctl enable httpd

#mount efs filesystem
mkdir -p /var/www/html/wp-content
chown -R ec2-user:apache /var/www/
echo -e "$EFSHOST:/ /var/www/html/wp-content efs _netdev,tls,iam 0 0" >> /etc/fstab
sudo mount -t efs -o tls $EFSHOST:/ /var/www/html/wp-content

#install wordpress
cd /var/www/html
wget https://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
cp -rvf wordpress/* .
rm -R wordpress
rm latest.tar.gz
cp ./wp-config-sample.php ./wp-config.php

#set wp-config with database details
sudo sed -i "s/'database_name_here'/'$DBNAME'/g" wp-config.php
sudo sed -i "s/'username_here'/'$DBUSER'/g" wp-config.php
sudo sed -i "s/'password_here'/'$DBPASSWORD'/g" wp-config.php
sudo sed -i "s/'localhost'/'$DBHOST'/g" wp-config.php

# enable .htaccess files in Apache config 
sudo sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf


# fix permission for directory /var/www
chown -R apache /var/www
sudo chgrp -R apache /var/www
sudo chmod 2775 /var/www
sudo find /var/www -type d -exec chmod 2775 {} \;
sudo find /var/www -type f -exec chmod 0664 {} \;
echo "<?php phpinfo(); ?>" > /var/www/html/phpinfo.php

systemctl enable httpd
systemctl start httpd


