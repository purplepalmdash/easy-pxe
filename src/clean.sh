#!/bin/bash
echo "Begin Clean your environment"
docker stop server9527
docker rm server9527
docker stop deployserver
docker rm deployserver
docker rmi feipyang/nginxautoindex:latest
docker rmi ferrarimarco/pxe:latest
umount -f /media/installiso
rm -rf /media/installiso
echo "You can choose manually remove your easypxe folder for saving spaces!"
