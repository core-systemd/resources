# Проверка, запущен ли скрипт с root-правами
if [ "$(id -u)" -ne 0 ]; then
    echo "Ошибка: Скрипт должен быть запущен с правами root!"
    exit 1
fi

# Создание пользователя net_admin
echo "Создание пользователя net_admin..."
useradd net_admin -U

# Установка пароля для net_admin (замените 'YourSecurePassword' на нужный пароль)
echo "Установка пароля для net_admin..."
echo "net_admin:YourSecurePassword" | chpasswd

# Добавление пользователя в группу wheel
echo "Добавление пользователя net_admin в группу wheel..."
usermod -aG wheel net_admin

# Настройка sudo для net_admin (добавление в sudoers без пароля)
echo "Настройка sudo для net_admin..."
echo "net_admin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

echo "Пользователь net_admin успешно создан и настроен!"

# Проверка, запущен ли скрипт с root-правами
if [ "$(id -u)" -ne 0 ]; then
    echo "Ошибка: Скрипт должен быть запущен с правами root!"
    exit 1
fi

# Определяем параметры соединения
PROFILE_NAME="gre-tunnel-br-rtr"
DEVICE_NAME="tun1"
PARENT_IF="ens18"
LOCAL_IP="172.16.5.2"
REMOTE_IP="172.16.4.2"
TUNNEL_IP="10.10.0.2/30"

echo "Создание GRE-туннеля $PROFILE_NAME на BR-RTR..."

# Удаляем существующее соединение с таким же именем (если есть)
nmcli connection delete $PROFILE_NAME 2>/dev/null

# Создаём новое GRE-соединение
nmcli connection add type ip-tunnel ifname $DEVICE_NAME con-name $PROFILE_NAME \
    mode gre parent $PARENT_IF local $LOCAL_IP remote $REMOTE_IP

# Настраиваем IPv4-адрес туннеля
nmcli connection modify $PROFILE_NAME ipv4.addresses $TUNNEL_IP ipv4.method manual

# Устанавливаем TTL для поддержки динамической маршрутизации
nmcli connection modify $PROFILE_NAME ip-tunnel.ttl 64

# Активируем соединение
nmcli connection up $PROFILE_NAME

echo "GRE-туннель $PROFILE_NAME успешно настроен и активирован!"




# Проверка, запущен ли скрипт с root-правами
if [ "$(id -u)" -ne 0 ]; then
    echo "Ошибка: Скрипт должен быть запущен с правами root!"
    exit 1
fi

# Устанавливаем FRR (если не установлен)
echo "Установка FRR..."
dnf install -y frr

# Включаем FRR и OSPF
echo "Включаем и запускаем FRR..."
systemctl enable --now frr

# Включаем поддержку OSPF в FRR
echo "Включаем OSPF..."
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons
systemctl restart frr

# Открываем конфигурационный файл OSPF
echo "Настройка OSPF..."
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
echo "Перезапуск FRR..."
systemctl restart frr

echo "OSPFv2 успешно настроен на BR-RTR!"

# Проверяем соседей OSPF
echo "Получение информации о соседях OSPF..."
vtysh -c "show ip ospf neighbor"

# Проверяем маршруты OSPF
echo "Получение маршрутов OSPF..."
vtysh -c "show ip route ospf"


# Проверка, запущен ли скрипт с root-правами
if [ "$(id -u)" -ne 0 ]; then
    echo "Ошибка: Скрипт должен быть запущен с правами root!"
    exit 1
fi

# Устанавливаем nftables (если не установлен)
echo "Установка nftables..."
dnf install -y nftables

# Создаем файл конфигурации для BR-RTR
echo "Создание файла конфигурации /etc/nftables/br-rtr.nft..."
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
    echo "Добавление конфигурации BR-RTR в /etc/sysconfig/nftables.conf..."
    echo "$INCLUDE_STRING" >> "$NFT_CONFIG"
fi

# Включаем и запускаем nftables
echo "Запуск и добавление в автозагрузку nftables..."
systemctl enable --now nftables

# Проверка конфигурации
echo "Проверка загруженной конфигурации nftables..."
nft list ruleset

echo "Настройка NAT на BR-RTR завершена!"



timedatectl set-timezone Europe/Samara
