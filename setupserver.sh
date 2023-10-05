#!/bin/bash

#install wireguard
sudo apt-get update && sudo apt-get upgrade -y  
sudo apt-get install wireguard -y   

#enable ipv4 forwarding & configure firewall rules
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sysctl -p
sudo apt install ufw
sudo ufw allow ssh
sudo ufw allow 51820/udp
sudo ufw enable -y
sudo ufw status

#generate keys
cd /etc/wireguard
umask 077
wg genkey | tee server_private_key | wg pubkey > server_public_key
wg genkey | tee client_private_key | wg pubkey > client_public_key

#generate server config
touch wg0.conf
echo "[Interface]" >> wg0.conf
echo "PrivateKey = $(cat server_private_key)" >> wg0.conf
echo "Address = 10.0.0.1/24" >> wg0.conf
echo "PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE" >> wg0.conf
echo "PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE" >> wg0.conf
echo "ListenPort = 51820" >> wg0.conf

#add client
echo "[Peer]" >> wg0.conf
echo "PublicKey = $(cat client_public_key)" >> wg0.conf
echo "AllowedIPs = 10.0.0.2/32" >> wg0.conf

#get public ip
sudo apt-get install curl
server_ip=$(curl -4 icanhazip.com)

#generate client config
touch client.conf
echo "[Interface]" >> client.conf
echo "PrivateKey = $(cat client_private_key)" >> client.conf
echo "DNS = 1.1.1.1" >> client.conf

echo "[Peer]" >> client.conf
echo "PublicKey = $(cat server_public_key)" >> client.conf
echo "Endpoint = $server_ip:51820" >> client.conf
echo "AllowedIPs = 0.0.0.0/0, ::/0" >> client.conf

#start wireguard
wg-quick up wg0
wg show
systemctl enable wg-quick@wg0
