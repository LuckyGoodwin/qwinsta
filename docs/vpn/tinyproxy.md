# установка и настройка Tinyproxy на Ubuntu 24.04

Tinyproxy - lightweight HTTP proxy server с поддержкой HTTPS CONNECT tunneling и минимальным потреблением ресурсов.

Tinyproxy не является SOCKS proxy.
Инструкция собиралась и проверялась на Ubuntu 24.04.

По итогу получаем:

- HTTP/HTTPS proxy server
- HTTP CONNECT tunneling
- systemd сервис
- автозапуск
- минимальное потребление ресурсов

!!! info

    Tinyproxy подходит для:
	
    - Telegram Desktop
    - curl
    - браузеров
    - API запросов
    - временного proxy доступа

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

Обновляем систему:

```bash
sudo apt update && sudo apt full-upgrade -y
```

Перезагружаем:

```bash
sudo reboot
```

Запрещаем root login:

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

## 01. подключение

```bash
ssh deployuser@123.45.67.89
sudo -i
```

## 02. установка Tinyproxy

```bash
apt install -y tinyproxy
```

## 03. настройка авторизации

Редактируем:

```bash
nano /etc/tinyproxy/tinyproxy.conf
```

Минимальный production-friendly пример:

```text
User tinyproxy
Group tinyproxy

Port 7777
Listen 0.0.0.0

Timeout 600

DefaultErrorFile "/usr/share/tinyproxy/default.html"
StatFile "/usr/share/tinyproxy/stats.html"
LogFile "/var/log/tinyproxy/tinyproxy.log"
LogLevel Info

PidFile "/run/tinyproxy/tinyproxy.pid"

MaxClients 100

DisableViaHeader Yes

BasicAuth myuser mypassword

Allow 1.2.3.4
```

Важно:

- `7777` - порт proxy server
- `Listen 0.0.0.0` - слушать все интерфейсы
- `myuser` и `mypassword` заменить на свои
- `Allow` ограничивает доступ по IP
- `DisableViaHeader Yes` уменьшает disclosure proxy headers
- `LogLevel Info` включает predictable logging

Пример ограничения по IP:

```text
Allow 1.2.3.4
Allow 5.6.7.0/24
Allow 10.0.0.0/8
```

Если авторизация не нужна - строку `BasicAuth` можно удалить.

!!! warning

    1. Proxy без авторизации рекомендуется использовать только вместе с ограничением доступа через `Allow`.
	2. Не оставляйте open proxy доступным всему интернету без необходимости.

## 04. запуск

```bash
systemctl enable --now tinyproxy
```

Проверяем:

```bash
systemctl status tinyproxy
```

## 05. firewall

!!! warning

    Перед включением UFW убедитесь, что разрешен OpenSSH, иначе можно потерять SSH доступ.

```bash
ufw allow OpenSSH
ufw allow 7777/tcp
ufw enable
```

## 06. проверка порта

```bash
ss -lntp | grep :7777
```

## 07. проверка proxy

Пример proxy URL:

```text
http://myuser:mypassword@123.45.67.89:7777
```

Проверка через curl:

```bash
curl -x http://myuser:mypassword@127.0.0.1:7777 https://ifconfig.me
```

## 08. использование в Telegram Desktop

Telegram Desktop поддерживает HTTP proxy.

Настройки:

```text
Settings → Advanced → Connection type → Use custom proxy
```

Тип proxy:

```text
HTTP
```

Заполняем:

```text
Server: 123.45.67.89
Port: 7777
Username: myuser
Password: mypassword
```

## 09. диагностика

```bash
systemctl status tinyproxy
journalctl -u tinyproxy -n 50 --no-pager
tail -f /var/log/tinyproxy/tinyproxy.log
ss -lntp | grep :7777
```

## 10. как это работает

- Tinyproxy поднимает HTTP proxy server с поддержкой CONNECT tunneling
- HTTPS traffic проходит через HTTP CONNECT proxy
- Telegram Desktop умеет работать через HTTP proxy
- traffic маршрутизируется через ваш proxy server

Tinyproxy не предоставляет полноценный VPN и не шифрует traffic между client и proxy server.

!!! info

    HTTP proxy видит destination hostnames и может видеть незашифрованный HTTP traffic.

!!! warning

    Не используйте HTTP proxy для передачи чувствительных данных через незашифрованный HTTP.

## полезные ссылки

[Tinyproxy GitHub](https://github.com/tinyproxy/tinyproxy/)  
https://github.com/tinyproxy/tinyproxy/

[Tinyproxy Documentation](https://tinyproxy.github.io/)  
https://tinyproxy.github.io/