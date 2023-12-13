#!/bin/bash

#Stop Wireguard
echo "Stopping Wireguard"
sudo wg-quick down wg0
cd /etc/wireguard

#Generate client keys
sudo rm -rf /etc/wireguard/keys
sudo mkdir keys && cd keys
wg genkey | tee client_privatekey | wg pubkey > client_publickey

#Add client to Wireguard
allowed_ips=$(tail -n 1 /etc/wireguard/wg0.conf)
ip_number_subnet=$(echo "$allowed_ips" | sed 's/AllowedIPs = //')
ip_number=$(echo "$ip_number_subnet" | sed 's/\/32$//')
IFS='.' read -ra ip_parts <<< "$ip_number"
ip_parts[3]=$((${ip_parts[3]}+1))
ip_number=$(echo "${ip_parts[0]}.${ip_parts[1]}.${ip_parts[2]}.${ip_parts[3]}")
if [ ${ip_parts[3]} -eq 254 ]
then
    echo "No more clients can be added"
    exit 1
else
    echo "Adding client: $ip_number"  
    datetime=$(date +"%Y-%m-%d %H:%M:%S")
    printf "\n\n#Client added on $datetime" >> /etc/wireguard/wg0.conf 
    printf "\n[Peer]\nPublicKey = $(cat /etc/wireguard/keys/client_publickey)\nAllowedIPs = $ip_number/32" >> /etc/wireguard/wg0.conf
    echo "Client added"
fi

#Create client config
echo "Creating client config"
touch client.conf
printf "[Interface]\nPrivateKey = $(cat /etc/wireguard/keys/client_privatekey)\nAddress = $ip_number/32\nDNS = 1.1.1.1\n" >> client.conf
printf "\n[Peer]\nPublicKey = $(cat /etc/wireguard/server_publickey)\nEndpoint = 139.162.227.113:51820\nAllowedIPs = 0.0.0.0/0, ::/0\n">> client.conf
echo "Client config created"

#Start Wireguard
echo "Starting Wireguard"
sudo wg-quick up wg0
