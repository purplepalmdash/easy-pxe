#!/bin/bash
echo "Make sure you have docker、xz installed"
# Run script using root
if [[ `whoami` != 'root' ]]; then
  notice_user="Please Run this script with root!"
  echo -e "\033[1;36m$notice_user\033[0m"
  exit 1
fi
rm -rf ./easypxe
mkdir -p ./easypxe/config
cp -r src/preseed ./easypxe/config/
cp -r src/pxelinux.cfg ./easypxe/config/
cp -r src/start.sh ./easypxe
cp -r src/clean.sh ./easypxe
cd ./easypxe/config
tar czvf config.tar.gz preseed/ pxelinux.cfg/
docker pull feipyang/nginxautoindex:latest
docker pull ferrarimarco/pxe:latest
docker save -o dockerimages.tar feipyang/nginxautoindex:latest ferrarimarco/pxe:latest
xz -T4 dockerimages.tar
wget https://download.docker.com/linux/static/stable/x86_64/docker-19.03.5.tgz
rm -rf preseed
rm -rf pxelinux.cfg
echo "Done"
