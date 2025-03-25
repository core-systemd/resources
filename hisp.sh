# Устанавливаем nftables (если не установлен)
echo "Установка nftables..."
dnf install -y nftables

# Создаем файл конфигурации для ISP
echo "Создание файла конфигурации /etc/nftables/isp.nft..."
cat <<EOT > /etc/nftables/isp.nft
table inet nat {
    chain POSTROUTING {
        type nat hook postrouting priority srcnat;
        oifname "ens18" masquerade
    }
}
EOT

# Добавляем include в конфигурацию nftables, если его там нет
NFT_CONFIG="/etc/sysconfig/nftables.conf"
INCLUDE_STRING='include "/etc/nftables/isp.nft"'

if ! grep -qF "$INCLUDE_STRING" "$NFT_CONFIG"; then
    echo "Добавление конфигурации ISP в /etc/sysconfig/nftables.conf..."
    echo "$INCLUDE_STRING" >> "$NFT_CONFIG"
fi

# Включаем и запускаем nftables
echo "Запуск и добавление в автозагрузку nftables..."
systemctl enable --now nftables

# Проверка конфигурации
echo "Проверка загруженной конфигурации nftables..."
nft list ruleset

echo "Настройка NAT на ISP завершена!"
