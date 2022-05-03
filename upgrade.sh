systemctl stop gitea
rm -f /root/gitea
rm -f /usr/local/bin/gitea

version=1.16.7
wget -O gitea https://dl.gitea.io/gitea/$version/gitea-$version-linux-amd64
chmod +x gitea
cp gitea /usr/local/bin/gitea
systemctl start gitea
