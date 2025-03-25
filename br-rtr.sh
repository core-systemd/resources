
if [ "$(id -u)" -ne 0 ]; then
    echo "Ошибка: Скрипт должен быть запущен с правами root!"
    exit 1
fi



useradd net_admin -U



echo "net_admin:P@ssw0rd" | chpasswd



usermod -aG wheel net_admin



echo "net_admin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers







dnf install -y frr



systemctl enable --now frr


echo "Включаем OSPF..."
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons
systemctl restart frr



cat <<EOT > /etc/frr/frr.conf
frr defaults traditional
hostname BR-RTR
log file /var/log/frr.log
service integrated-vtysh-config
!
router ospf
 ospf router-id 10.10.0.2
 network 192.168.100.64/28 area 0
 network 10.10.0.0/30 area 0
!
line vty
EOT

# Перезапускаем FRR для применения конфигурации

systemctl restart frr





vtysh -c "show ip ospf neighbor"



vtysh -c "show ip route ospf"



if [ "$(id -u)" -ne 0 ]; then
    echo "Ошибка: Скрипт должен быть запущен с правами root!"
    exit 1
fi

# Устанавливаем nftables (если не установлен)

dnf install -y nftables

# Создаем файл конфигурации для BR-RTR

cat <<EOT > /etc/nftables/br-rtr.nft
table inet nat {
    chain POSTROUTING {
        type nat hook postrouting priority srcnat;
        oifname "ens18" masquerade
    }
}
EOT

# Добавляем include в конфигурацию nftables, если его там нет
NFT_CONFIG="/etc/sysconfig/nftables.conf"
INCLUDE_STRING='include "/etc/nftables/br-rtr.nft"'

if ! grep -qF "$INCLUDE_STRING" "$NFT_CONFIG"; then
   
    echo "$INCLUDE_STRING" >> "$NFT_CONFIG"
fi

# Включаем и запускаем nftables

systemctl enable --now nftables

# Проверка конфигурации

nft list ruleset





timedatectl set-timezone Europe/Samara
