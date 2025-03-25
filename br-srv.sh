#!/bin/bash

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
