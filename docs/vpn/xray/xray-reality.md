# XRay: VLESS + Reality + 3x-ui

3x-ui — веб-панель для управления XRay core.

XRay поддерживает VLESS, Reality, Trojan, Shadowsocks и VMess. Reality прячет трафик за TLS camouflage — DPI его не распознаёт.

Инструкция проверена на Ubuntu 24.04.

После настройки получишь:

- XRay core
- VLESS + Reality
- 3x-ui panel
- один inbound для всех клиентов
- TLS camouflage
- QR-коды и ссылки для клиентов
- systemd-сервис
- вход через `443/tcp`

## 00. подготовка сервера

Подключаемся:

```bash
ssh root@123.45.67.89
```

Создаём пользователя:

```bash
adduser deployuser
```

Даём sudo:

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

> **Внимание.** Скрипт выполняется напрямую с GitHub. Прочитай `install.sh` перед запуском.

## 05. настройка при установке

```text
Do you want to customize the Panel Port? → y
Port → 2053

Choose SSL certificate:
2 (Let's Encrypt for IP Address)

IPv6 → Enter

Port for ACME → 80
```

> **Внимание.** Пункты скрипта меняются между версиями 3x-ui.

Ставь нестандартный порт для панели — стандартный сканируют.

## 06. данные панели

После установки скрипт выведет:

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

> **Внимание.** Боты постоянно сканируют 3x-ui: брутфорсят пароли, перебирают стандартные пути, пробуют утёкшие credentials.
>
> Защита минимум:
> - нестандартный порт
> - сложный пароль
> - ограничение по IP через firewall
> - reverse proxy или WAF при публичном доступе

## 08. создание inbound

Inbound создаёшь один раз. Все пользователи идут через него.

```text
Подключения → Создать подключение
```

```text
Протокол: VLESS
Порт: 443
Примечание: vpn
```

## 09. добавление клиента

```text
Добавить клиента
```

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

## 11. Reality: target и SNI

```text
Target:
example.com:443

SNI:
example.com
```

> **Внимание.** Target должен работать по HTTPS, отвечать по TLS и совпадать с SNI. Выбирай домен, который выглядит правдоподобно — именно его трафик будет имитировать Reality.

## 12. генерация ключей Reality

```text
Get New Keys
```

Reality работает на паре public/private key. Генерируй прямо в панели.

## 13. Short ID

Short ID — 8–16 hex-символов. Оставь автоматический или задай свой:

```text
abc123
```

## 14. сохранение inbound

```text
Создать подключение
```

## 15. новые пользователи

Добавляй пользователей внутрь существующего inbound — новый создавать не нужно:

```text
Подключения → inbound → Клиенты → Добавить
```

## 16. ссылка и QR-код

```text
Клиенты → QR / ссылка
```

Импортируй через Import URL или сканирование QR.

## 17. клиенты

Windows — v2rayN  
Android — v2rayNG  
iPhone — Shadowrocket или Streisand

## 18. firewall

> **Внимание.** Сначала разреши OpenSSH — иначе после включения UFW потеряешь SSH.

```bash
ufw allow OpenSSH
ufw allow 443/tcp
ufw allow 2053/tcp
ufw enable
```

## 19. проверка сервисов

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

Один inbound на `443/tcp`, сколько угодно клиентов. Каждый получает свой UUID. Reality имитирует TLS-трафик легитимного сайта — DPI видит обычный HTTPS.

3x-ui — не VPN и не proxy. Это интерфейс управления XRay core.

## ссылки

[3x-ui GitHub](https://github.com/MHSanaei/3x-ui/)  
[XRay Documentation](https://xtls.github.io/)  
[v2rayN](https://github.com/2dust/v2rayN/)