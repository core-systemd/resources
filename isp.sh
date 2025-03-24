
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
sudo sysctl -p

echo "
table inet nat {
    chain POSTROUTING {
        type nat hook postrouting priority srcnat;
        oifname \"ens18\" masquerade
    }
}
" | sudo tee /etc/nftables/isp.nft > /dev/null

echo 'include "/etc/nftables/isp.nft"' | sudo tee -a /etc/sysconfig/nftables.conf > /dev/null

sudo systemctl enable --now nftables
