echo "Создание GRE-туннеля..."

# Добавляем туннель с нужными параметрами
nmcli connection add type tun name "HQ-RTR-GRE" ifname "tun1" con-name "HQ-RTR-GRE" \
    ipv4.method manual ipv4.addresses 10.10.0.1/30 ipv4.gateway 10.10.0.1

# Настроим параметры туннеля: родительский интерфейс (ens18), режим GRE, локальный и удаленный IP
nmcli connection modify "HQ-RTR-GRE" \
    ipv4.local 172.16.4.2 ipv4.remote 172.16.5.2 \
    ipv4.dns "" ipv4.never-default yes \
    tunnel.remote 172.16.5.2 tunnel.local 172.16.4.2 \
    tunnel.mode gre

# Указываем интерфейс ens18 как родительский
nmcli connection modify "HQ-RTR-GRE" connection.interface-name tun1 \
    connection.id "HQ-RTR-GRE" ipv4.method manual ipv4.addresses "10.10.0.1/30" \
    ipv4.gateway "10.10.0.1" ipv4.dns "" ipv4.never-default yes

# Активируем созданное подключение
echo "Активируем GRE-туннель..."
nmcli connection up "HQ-RTR-GRE"

echo "GRE-туннель настроен и активирован успешно!"
nmcli connection modify tun1 ip-tunnel.ttl 64

# Устанавливаем Open vSwitch и NetworkManager-ovs
echo "Установка Open vSwitch и NetworkManager-ovs..."
dnf install openvswitch NetworkManager-ovs -y

# Добавляем Open vSwitch в автозагрузку и запускаем
echo "Добавление Open vSwitch в автозагрузку и запуск..."
systemctl enable --now openvswitch

# Создаем виртуальный мост hq-sw
echo "Создание моста hq-sw..."
ovs-vsctl add-br hq-sw

# Добавляем порты с VLAN
echo "Добавление портов ens19, ens20, ens21 с VLAN..."
ovs-vsctl add-port hq-sw ens19 tag=100
ovs-vsctl add-port hq-sw ens20 tag=200
ovs-vsctl add-port hq-sw ens21 tag=999

# Добавляем внутренние интерфейсы VLAN
echo "Добавление внутренних интерфейсов для VLAN 100, 200 и 999..."
ovs-vsctl add-port hq-sw vlan100 tag=100 -- set interface vlan100 type=internal
ovs-vsctl add-port hq-sw vlan200 tag=200 -- set interface vlan200 type=internal
ovs-vsctl add-port hq-sw vlan999 tag=999 -- set interface vlan999 type=internal

# Перезагружаем Open vSwitch и NetworkManager
echo "Перезагрузка Open vSwitch и NetworkManager..."
systemctl restart openvswitch
systemctl restart NetworkManager

# Включаем мост
echo "Включение моста hq-sw..."
ip link set hq-sw up

# Настройка IP-адресов для VLAN интерфейсов
echo "Настройка IP-адресов для VLAN интерфейсов..."
ip a add 192.168.100.1/26 dev vlan100
ip a add 192.168.100.65/28 dev vlan200
ip a add 192.168.100.81/29 dev vlan999

# Создание конфигурации для интерфейсов в /etc/sysconfig/network-scripts
echo "Создание конфигураций для интерфейсов..."

cat <<EOL > /etc/sysconfig/network-scripts/ifcfg-vlan100
DEVICE=vlan100
BOOTPROTO=none
ONBOOT=yes
IPADDR=192.168.100.1
NETMASK=255.255.255.192
EOL

cat <<EOL > /etc/sysconfig/network-scripts/ifcfg-vlan200
DEVICE=vlan200
BOOTPROTO=none
ONBOOT=yes
IPADDR=192.168.100.65
NETMASK=255.255.255.240
EOL

cat <<EOL > /etc/sysconfig/network-scripts/ifcfg-vlan999
DEVICE=vlan999
BOOTPROTO=none
ONBOOT=yes
IPADDR=192.168.100.81
NETMASK=255.255.255.248
EOL

# Перезагружаем сеть, чтобы применить конфигурацию
echo "Перезагрузка сетевых интерфейсов..."
systemctl restart network

# Уведомление об успешном завершении
echo "Настройка завершена успешно. Мосты и VLAN настроены, IP-адреса назначены."



# Устанавливаем пакет frr
echo "Установка FRR..."
dnf install -y frr

# Включаем протокол OSPFv2 в конфигурации daemons
echo "Включение OSPFv2 в конфигурации FRR..."
sed -i 's/^ospfd=.*/ospfd=yes/' /etc/frr/daemons

# Включаем и запускаем службу FRR
echo "Добавление FRR в автозагрузку и запуск..."
systemctl enable --now frr

# Переходим в интерфейс управления FRR с помощью vtysh
echo "Запуск vtysh для настройки OSPFv2..."
vtysh <<EOF
configure terminal
router ospf
passive-interface default
network 192.168.100.0/26 area 0
network 192.168.100.64/28 area 0
network 10.10.0.0/30 area 0
area 0 authentication
exit
interface tun1
no ip ospf network broadcast
no ip ospf passive
ip ospf authentication
ip ospf authentication-key password
exit
exit
write
EOF

# Перезапускаем FRR для применения изменений
echo "Перезагрузка FRR..."
systemctl restart frr

echo "OSPFv2 настроен успешно!"

# Проверка текущей конфигурации
echo "Просмотр текущей конфигурации FRR..."
vtysh -c "show running-config"


# Устанавливаем DHCP-сервер
echo "Установка DHCP-сервера..."
dnf install -y dhcp-server

# Создаём резервную копию оригинального файла конфигурации, если он существует
if [ -f /etc/dhcp/dhcpd.conf ]; then
    echo "Создание резервной копии dhcpd.conf..."
    cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak
fi

# Копируем пример конфигурационного файла
echo "Копирование примера конфигурационного файла DHCP..."
cp /usr/share/doc/dhcp-server/dhcpd.conf.example /etc/dhcp/dhcpd.conf

# Записываем конфигурацию в файл dhcpd.conf
echo "Настройка DHCP-пула..."
cat > /etc/dhcp/dhcpd.conf <<EOL
subnet 192.168.100.64 netmask 255.255.255.240 {
  range 192.168.100.66 192.168.100.78;
  option domain-name-servers 192.168.100.2;
  option domain-name "au-team.irpo";
  option routers 192.168.100.65;
  default-lease-time 600;
  max-lease-time 7200;
}
EOL

# Перезапускаем службу DHCP и добавляем в автозагрузку
echo "Запуск DHCP-сервера и добавление в автозагрузку..."
systemctl enable --now dhcpd

# Проверяем статус службы DHCP
echo "Проверка статуса DHCP-сервера..."
systemctl status dhcpd --no-pager

echo "Настройка DHCP-сервера завершена!"
