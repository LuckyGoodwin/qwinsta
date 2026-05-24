# установка и настройка XRay (VLESS + Reality) + 3x-ui

3x-ui - web panel для управления XRay core.

XRay поддерживает:

- VLESS
- Reality
- Trojan
- Shadowsocks
- VMess

Reality использует TLS camouflage для обхода DPI/filtering.

Инструкция собиралась и проверялась на Ubuntu 24.04.

По итогу получаем:

- XRay core
- VLESS + Reality
- 3x-ui panel
- один inbound для всех клиентов
- TLS camouflage
- QR и ссылки для клиентов
- systemd сервис
- работу через `443/tcp`

## 00. подготовка сервера

Подключаемся:

```bash
ssh root@123.45.67.89
```

Создаем пользователя:

```bash
adduser deployuser
```

Даем sudo:

```bash
usermod -aG sudo deployuser
```

Проверяем вход:

```bash
ssh deployuser@123.45.67.89
```

## 01. обновление системы

```bash
sudo apt update && sudo apt full-upgrade -y
```

Перезагружаем:

```bash
sudo reboot
```

## 02. отключение root login

Редактируем:

```bash
sudo nano /etc/ssh/sshd_config
```

Меняем:

```text
PermitRootLogin no
```

Перезапускаем SSH:

```bash
sudo systemctl restart ssh
```

## 03. подключение

```bash
ssh deployuser@123.45.67.89
sudo -i
```

## 04. установка 3x-ui

```bash
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```

!!! warning

    Установка выполняется через remote install script. Перед использованием рекомендуется проверить содержимое `install.sh`.

## 05. настройка при установке

Выбираем:

```text
Do you want to customize the Panel Port? → y
Port → 2053

Choose SSL certificate:
2 (Let's Encrypt for IP Address)

IPv6 → Enter

Port for ACME → 80
```

!!! warning

    Пункты install script могут отличаться между версиями 3x-ui.

Используйте нестандартный port для 3x-ui panel.

## 06. данные панели

После установки получаем:

```text
Username: XXXXX
Password: XXXXX
Port: 2053
WebBasePath: XXXXX
```

## 07. вход в панель

```text
https://IP:2053/WEBBASEPATH
```

!!! warning

    3x-ui panel регулярно сканируется ботами и может стать целью: 
	
    - brute-force атак
    - mass scanning
    - попыток подбора стандартных URL/path
    - попыток входа с утекшими паролями

    Рекомендуется:
	
    - использовать нестандартный port
    - использовать сложный password для panel
    - ограничить доступ по IP через firewall
    - не публиковать panel без необходимости
    - использовать reverse proxy/WAF при публичном доступе

## 08. создание inbound

Создаем inbound только один раз.

Переходим:

```text
Подключения → Создать подключение
```

Настройки:

```text
Протокол: VLESS
Порт: 443
Примечание: vpn
```

## 09. настройка клиента

Внутри inbound:

```text
Добавить клиента
```

Настройки:

```text
Email → имя устройства
ID → Generate
Flow → оставить пустым
```

## 10. transport и security

```text
Network → TCP
Security → Reality
```

## 11. Reality настройки

Пример:

```text
Target:
example.com:443

SNI:
example.com
```

!!! warning

    Reality target должен:
	
    - поддерживать HTTPS
    - отвечать по TLS
    - соответствовать SNI
    - выглядеть правдоподобно для TLS camouflage

## 12. генерация Reality keys

В панели:

```text
Get New Keys
```

Reality использует public/private key pair.

## 13. Short ID

Short ID обычно содержит 8-16 hex символов.

Можно оставить автоматически сгенерированный.

Или указать свой:

```text
abc123
```

## 14. создание inbound

```text
Создать подключение
```

## 15. добавление новых пользователей

Новых пользователей добавляем внутрь существующего inbound:

```text
Подключения → inbound → Клиенты → Добавить
```

Новый inbound создавать не нужно.

## 16. получение ссылки

```text
Клиенты → QR / ссылка
```

Импорт через:

- Import URL
- Scan QR code

## 17. клиенты

Windows:

```text
v2rayN
```

Android:

```text
v2rayNG
```

iPhone:

```text
Shadowrocket
Streisand
```

## 18. firewall

!!! warning

    Перед включением UFW убедитесь, что разрешен OpenSSH, иначе можно потерять SSH доступ.

```bash
ufw allow OpenSSH
ufw allow 443/tcp
ufw allow 2053/tcp
ufw enable
```

## 19. проверка

```bash
ss -tulpen | grep :443
ss -tulpen | grep :2053

systemctl status x-ui
journalctl -u x-ui -n 50 --no-pager
```

## 20. проверка подключения

```text
https://ipinfo.io
```

## 21. как это работает

- inbound обычно один (`443/tcp`)
- клиентов может быть сколько угодно
- каждый клиент получает свой ID
- Reality использует TLS camouflage для обхода DPI/filtering
- 3x-ui управляет XRay core через web panel

3x-ui не является самим VPN/proxy server.

Панель управляет XRay core.

## полезные ссылки

[3x-ui GitHub](https://github.com/MHSanaei/3x-ui/)  
https://github.com/MHSanaei/3x-ui/

[XRay Documentation](https://xtls.github.io/)  
https://xtls.github.io/

[v2rayN](https://github.com/2dust/v2rayN/)  
https://github.com/2dust/v2rayN/