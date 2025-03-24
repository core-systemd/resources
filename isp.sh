nano /etc/sysctl.conf

sysctl -p

nano /etc/nftables/isp.nft

nano /etc/sysconfig/nftables.conf

systemctl enable --now nftables
 
 
 
 echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
 sudo sysctl -p > /dev/null 2>&1
 sysctl net.ipv4.ip_forward > /dev/null 2>&1

 echo "
table inet nat {
    chain POSTROUTING {
        type nat hook postrouting priority srcnat;
        oifname \"ens18\" masquerade
    }
}
" | sudo tee /etc/nftables/isp.nft > /dev/null 2>&1

 echo 'include "/etc/nftables/isp.nft"' | sudo tee -a /etc/sysconfig/nftables.conf > /dev/null 2>&1

 sudo systemctl enable --now nftables > /dev/null 2>&1
