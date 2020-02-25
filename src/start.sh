#!/bin/bash

# Test an IP address for validity:
# Usage:
#      valid_ip IP_ADDRESS
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
#   OR
#      if valid_ip IP_ADDRESS; then echo good; else echo bad; fi
#
function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Run script using root
if [[ `whoami` != 'root' ]]; then
  notice_user="Please Run this script with root!"
  echo -e "\033[1;36m$notice_user\033[0m"
  exit 1
fi

## mount iso and check mount ok
if [ "$(ls -l *.iso | wc -l )" -gt 1 ];
then
	echo "Only 1 iso under this folder!!!"
	exit 2
fi

mkdir -p /media/installiso
umount -f /media/installiso
mount -t iso9660 -o loop ./*.iso /media/installiso
rc=$?; if [[ $rc != 0 ]]; then echo 'Please copy the right  official iso under this folder first.' && exit 3; fi

currentDIR=`pwd`

# Get the tftp listening IP
#clear
cat << eof
$(echo -e "\033[1;36m1. Provide IP...\033[0m")
eof
read -p "IP:" tftp_http_ip
# validate ip
if valid_ip $tftp_http_ip; then stat='good'; else echo $tftp_http_ip is a wrong IP && exit 4 ; fi

# DHCP Configuration
dhcp_external_server_ip=""
cat << eof
$(echo -e "\033[1;36m2. DHCP Configuration...\033[0m")
eof
# Ask for starting dhcp server. 
read -p "Enable DHCP Server? (yes/no)" ans
while [[ "x"$ans != "xyes" && "x"$ans != "xno" ]]; do
    read -p "Enable DHCP Server? (yes/no)" ans
done
if [[ "x"$ans == "xyes" ]]; then
    read -p "dhcp start IP: " dhcp_start_ip
    if valid_ip $dhcp_start_ip; then stat='good'; else echo $dhcp_start_ip is a wrong IP && exit 4 ; fi
    read -p "dhcp  end IP: " dhcp_end_ip
    if valid_ip $dhcp_end_ip; then stat='good'; else echo $dhcp_end_ip is a wrong IP && exit 4 ; fi
    read -p "subnet  mask: " subnet_mask
    if valid_ip $subnet_mask; then stat='good'; else echo $subnet_mask is a wrong IP && exit 4 ; fi
else
    read -p "Provide existing dhcp server IP:" dhcp_external_server_ip
    if valid_ip $dhcp_external_server_ip; then stat='good'; else echo $dhcp_external_server_ip is a wrong IP && exit 4 ; fi
fi

echo "Your configuration :"
echo "======================================================="
echo "tftp/http server IP:" $tftp_http_ip
if [[ -z "$dhcp_external_server_ip" ]];
then 
	echo "DHCP Server enabled from "$dhcp_start_ip" to" $dhcp_end_ip ", with subnet mask "$subnet_mask
else
	echo "Using existing dhcp server: " $dhcp_external_server_ip 
fi
echo "======================================================="
read -p "Continue to deploy? (yes/no)" ans
while [[ "x"$ans != "xyes" && "x"$ans != "xno" ]]; do
    read -p "Continue to deploy? (yes/no)" ans
done
if [[ "x"$ans == "xyes" ]]; then
	echo "Begin to deploy, wait for about 3 minutes"
else
	echo "See U Next Time!"
	exit 0
fi

echo "Magic comes here"
## check docker exists, if not, using binary
if pgrep -x "dockerd" >/dev/null
then
    echo "dockerd is running"
else
    echo "dockerd stopped"
    tar xzvf config/docker-19.03.5.tgz --strip-components=1 -C /usr/local/bin
    export PATH=$PATH:/usr/local/bin
    echo $PATH
    /usr/local/bin/dockerd &
    sleep 15
fi

## 2.1 docker load 2 images
docker load<config/dockerimages.tar.xz
### 2.3 Run 9527 server
# todo: should check if exists
docker stop server9527
docker rm server9527
# end of todo
docker run --name server9527 -p 9527:80 -d -v /media/installiso:/usr/share/nginx/html feipyang/nginxautoindex:latest
### 2.4 using sed for replacing the ip address
# preseed cfg files should replace ip items. 
rm -rf config/preseed
rm -rf config/pxelinux.cfg
tar xzvf config/config.tar.gz -C config/
sed -i "s/192.168.57.1/$tftp_http_ip/g" config/preseed/18.04/*.cfg
sed -i "s/192.168.57.1/$tftp_http_ip/g" config/pxelinux.cfg/*
sed -i "s/192.168.57.1/$tftp_http_ip/g" config/uefi/grub/*
### 2.5 Run deploy server
# todo: should check if exists
docker stop deployserver
docker rm deployserver
if [[ -z "$dhcp_external_server_ip" ]];
then 
	docker run --name deployserver  -it --rm --net=host --entrypoint=/bin/sh -v $currentDIR/config/preseed:/var/lib/tftpboot/preseed -v /media/installiso:/var/lib/tftpboot/ubuntu -v $currentDIR/config/pxelinux.cfg/additional_menu_entries:/var/lib/tftpboot/pxelinux.cfg/additional_menu_entries -v $currentDIR/config/uefi/grubnetx64.efi:/var/lib/tftpboot/grubnetx64.efi -v $currentDIR/config/uefi/grub:/var/lib/tftpboot/grub -v $currentDIR/config/uefi/dnsmasq.conf:/etc/dnsmasq.conf ferrarimarco/pxe:latest -c "dnsmasq --no-daemon --dhcp-range=$dhcp_start_ip,$dhcp_end_ip,$subnet_mask --dhcp-broadcast --dhcp-option=6,$tftp_http_ip"
else
	docker run --name deployserver  -it --rm --net=host --entrypoint=/bin/sh -v $currentDIR/config/preseed:/var/lib/tftpboot/preseed -v /media/installiso:/var/lib/tftpboot/ubuntu -v $currentDIR/config/pxelinux.cfg/additional_menu_entries:/var/lib/tftpboot/pxelinux.cfg/additional_menu_entries -v $currentDIR/config/uefi/grubnetx64.efi:/var/lib/tftpboot/grubnetx64.efi -v $currentDIR/config/uefi/grub:/var/lib/tftpboot/grub -v $currentDIR/config/uefi/dnsmasq.conf:/etc/dnsmasq.conf ferrarimarco/pxe:latest -c "dnsmasq --no-daemon --dhcp-range=$dhcp_external_server_ip,proxy"
fi
