#!/bin/bash
# Gitea Installer By Istiak Ferdous
# Author: Istiak Ferdous
# Website: https://istiakferdous.com
# Email: hello@istiakferdous.com

# Take all input
echo -e "Please enter new root password for MySQL: "
read mysqlrootpass
echo -e "Please enter database name you want to use for Gitea: "
read giteadbname
echo -e "Please enter database username you want to use for Gitea Database($giteadbname): "
read giteadbuser
echo -e "Please enter database password you want to use for Gitea($giteadbuser): "
read giteadbpass
echo -e "Please enter system username you want to use for Gitea: "
read giteauser

# Update everything first
dnf update -y

# Install EPEL
dnf -y install wget

# Install Nginx & MariaDB 10.4 Repo
dnf config-manager --add-repo https://hostboxcp.com/nginx/nginx.repo
dnf config-manager --add-repo https://hostboxcp.com/mariadb/MariaDB-10.6-RHEL-x86_64.repo

# Install required packages
dnf -y install git mariadb-server nginx

# Enable MariaDB & Nginx on boot and start the server
systemctl enable --now mariadb nginx

# MySQL Secure Installation
mysql -u root <<-EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$mysqlrootpass';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOF

# Restart MariaDB now
systemctl restart mariadb.service

# Create database and assign a user
echo "Creating database and assigning user..."
mysql -u root -p"$mysqlrootpass" <<-EOF
CREATE DATABASE $giteadbname;
CREATE USER '$giteadbuser'@'localhost' IDENTIFIED BY '$giteadbpass';
GRANT ALL ON $giteadbname.* TO '$giteadbuser'@'localhost' IDENTIFIED BY '$giteadbpass' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# Add user for Gitea
adduser --system --shell /bin/bash --comment 'Git Version Control' --user-group --home-dir /home/$giteauser -m $giteauser

# Create directory structure
mkdir -p /var/lib/gitea/{custom,data,indexers,public,log}
chown $giteauser:$giteauser /var/lib/gitea/{data,indexers,log}
chmod 750 /var/lib/gitea/{data,indexers,log}
mkdir /etc/gitea
chown root:$giteauser /etc/gitea
chmod 770 /etc/gitea

# Download & Install Gitea
version=1.17.3
wget -O gitea.xz https://dl.gitea.io/gitea/$version/gitea-$version-linux-amd64.xz
xz -d gitea.xz
chmod +x gitea
cp gitea /usr/local/bin/gitea

# Create Gitea Service
touch /etc/systemd/system/gitea.service
# wget https://raw.githubusercontent.com/istiak101/gitea-quick-installer/master/gitea.service

cat > /etc/systemd/system/gitea.service <<EOF
[Unit]
Description=Gitea (Git with a cup of tea)
After=network.target
After=mariadb.service

[Service]
# Modify these two values and uncomment them if you have
# repos with lots of files and get an HTTP error 500 because
# of that
###
#LimitMEMLOCK=infinity
#LimitNOFILE=65535
RestartSec=2s
Type=simple
User=$giteauser
Group=$giteauser
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/local/bin/gitea web -c /etc/gitea/app.ini
Restart=always
Environment=USER=$giteauser HOME=/home/$giteauser GITEA_WORK_DIR=/var/lib/gitea
# If you want to bind Gitea to a port below 1024 uncomment
# the two values below
###
#CapabilityBoundingSet=CAP_NET_BIND_SERVICE
#AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# Enable & Start Gitea at boot
systemctl daemon-reload
systemctl enable --now gitea

# Check if Gitea is running
systemctl status gitea

# Create Nginx config
wget https://raw.githubusercontent.com/istiak101/gitea-quick-installer/master/gitea.conf -P /etc/nginx/conf.d/

# Restart Nginx
systemctl restart nginx

# Firewall setup
sudo firewall-cmd --add-port 80/tcp --permanent
sudo firewall-cmd --add-port 3000/tcp --permanent
sudo firewall-cmd --reload

# SELinux permission
setsebool -P httpd_can_network_connect 1

# Print all password and necessary instructions needed later
echo "******************************************************"
echo "MySQL root password: $mysqlrootpass"
echo "Gitea database name: $giteadbname"
echo "Gitea database username: $giteadbuser"
echo "Gitea database password: $giteadbpass"
echo "Gitea user: $giteauser"
echo "******************************************************"

# Get IP
ip=$(hostname -I)
echo "Now go to browser and type: http://$ip:3000/install"

exit 0
