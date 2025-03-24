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
