exec >/dev/null 2>&1

# Создание пользователя sshuser с домашним каталогом и оболочкой bash
useradd -m -s /bin/bash sshuser

# Установка пароля (замените 'password' на свой)
echo "sshuser:password" | chpasswd

# Добавление пользователя в группу wheel
usermod -aG wheel sshuser

# Настройка sudo без пароля
echo "sshuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sshuser
chmod 440 /etc/sudoers.d/sshuser

# Перезапуск службы sudo (на всякий случай)
systemctl restart sudo 2>/dev/null

# Проверка
if id "sshuser" &>/dev/null; then
    echo "Пользователь sshuser успешно создан и добавлен в группу wheel."
    echo "Настроено использование sudo без пароля."
else
    echo "Ошибка: пользователь sshuser не создан." >&2
    exit 1
fi


#!/bin/bash

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт должен быть запущен от root" 
   exit 1
fi

# Установка SELinux в режим permissive (если требуется)
if sestatus | grep -q "enabled"; then
    echo "SELinux включен, разрешаем порт 2024 для SSH"
    semanage port -a -t ssh_port_t -p tcp 2024 2>/dev/null || semanage port -m -t ssh_port_t -p tcp 2024
    setenforce 0
    sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
fi

# Настройка SSH
SSHD_CONFIG="/etc/ssh/sshd_config"

# Изменение порта SSH
sed -i 's/^#Port 22/Port 2024/' $SSHD_CONFIG

# Ограничение входа только для пользователя sshuser
if ! grep -q "^AllowUsers sshuser" $SSHD_CONFIG; then
    echo "AllowUsers sshuser" >> $SSHD_CONFIG
fi

# Установка максимального количества попыток входа
sed -i 's/^#MaxAuthTries.*/MaxAuthTries 2/' $SSHD_CONFIG

# Настройка баннера
sed -i 's|^#Banner none|Banner /etc/ssh-banner|' $SSHD_CONFIG

echo "Authorized access only" > /etc/ssh-banner
chmod 644 /etc/ssh-banner

# Открытие порта в firewall
if command -v firewall-cmd &>/dev/null; then
    firewall-cmd --add-port=2024/tcp --permanent
    firewall-cmd --reload
fi

# Перезапуск SSH
systemctl restart sshd

# Вывод информации
echo "Настройка безопасного SSH-доступа завершена. Теперь используйте порт 2024."


sudo dnf install -y bind bind-utils

# Резервное копирование оригинального конфигурационного файла
cp /etc/named.conf /etc/named.conf.backup

# Настройка named.conf
cat > /etc/named.conf <<EOF
options {
    listen-on port 53 { 127.0.0.1; 192.168.0.0/26; 192.168.100.64/28; any; };
    listen-on-v6 port 53 { none; };
    directory "/var/named";
    dump-file "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    allow-query { any; };
    recursion yes;
    forwarders { 77.88.8.8; 77.88.8.1; };
    dnssec-validation no;
};

zone "au-team.irpo" IN {
    type master;
    file "master/au-team.db";
};

zone "100.168.192.in-addr.arpa" IN {
    type master;
    file "master/au-team_rev.db";
};
EOF

# Проверка конфигурации
named-checkconf

# Создаем каталог для мастер-зон
mkdir -p /var/named/master

# Создание файла зоны прямого просмотра
cp /var/named/named.localhost /var/named/master/au-team.db
cat > /var/named/master/au-team.db <<EOF
\$TTL 86400
@   IN  SOA au-team.irpo. root.au-team.irpo. (
        2024032501 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400      ; Minimum TTL
    )
@   IN  NS  ns.au-team.irpo.
ns  IN  A   192.168.0.1
EOF

# Создание файла зоны обратного просмотра
cp /var/named/named.loopback /var/named/master/au-team_rev.db
cat > /var/named/master/au-team_rev.db <<EOF
\$TTL 86400
@   IN  SOA au-team.irpo. root.au-team.irpo. (
        2024032501 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400      ; Minimum TTL
    )
@   IN  NS  ns.au-team.irpo.
1   IN  PTR ns.au-team.irpo.
EOF

# Установка прав доступа
chown -R root:named /var/named/master
chmod 0640 /var/named/master/*

# Проверка конфигурации с зонами
named-checkconf -z

# Перезапуск службы DNS
systemctl restart named
systemctl enable named
systemctl enable --now named
echo "Настройка BIND завершена."
