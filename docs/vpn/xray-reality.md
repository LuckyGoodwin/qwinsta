# установка и настройка XRay (VLESS + Reality) + 3x-ui

Инструкция собираалась и проверялась на Ubuntu 24.04.

По итогу получаем:

- VLESS + Reality
- 3x-ui панель
- один inbound для всех клиентов
- Reality camouflage
- QR и ссылки для клиентов
- systemd сервис
- работу через 443/tcp

## 00. установка 3x-ui

```bash
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```

## 01. настройка при установке

Выбираем:

```text
Do you want to customize the Panel Port? → y
Port → 2053

Choose SSL certificate:
2 (Let's Encrypt for IP Address)

IPv6 → Enter

Port for ACME → 80
```

## 02. данные панели

После установки получаем:

```text
Username: XXXXX
Password: XXXXX
Port: 2053
WebBasePath: XXXXX
```

## 03. вход в панель

```text
https://IP:2053/WEBBASEPATH
```

## 04. создание inbound

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

## 05. настройка клиента

Внутри inbound:

```text
Добавить клиента
```

Настройки:

```text
Email → имя устройства
ID → Generate
Flow → пусто
```

Остальное не трогаем.

## 06. транспорт

```text
TCP (RAW)
```

## 07. безопасность

```text
Reality
```

## 08. Reality настройки

```text
Target:
cloudflare.com:443

SNI:
cloudflare.com
```

## 09. генерация ключей

```text
Get New Cert
```

## 10. Short ID

Можно оставить автоматически сгенерированный.

Или указать свой:

```text
abc123
```

## 11. создание inbound

```text
Создать подключение
```

## 12. добавление новых пользователей

Новых пользователей добавляем внутрь существующего inbound:

```text
Подключения → inbound → Клиенты → Добавить
```

Новый inbound создавать не нужно.

## 13. получение ссылки

```text
Клиенты → QR / ссылка
```

## 14. клиенты

Windows / Android:

```text
v2rayTun
```

iPhone:

```text
v2rayTun
Shadowrocket
Streisand
```

## 15. импорт

```text
Import URL
```

Вставляем:

```text
vless://
```

## 16. firewall (опционально)

```bash
ufw allow 443/tcp
ufw allow 2053/tcp
```

## 17. проверка

```bash
ss -tulpen | grep 443
systemctl status x-ui
```

## 18. проверка подключения

```text
https://whatismyip.com
```

## 19. как это работает

- inbound один (443)
- клиентов может быть сколько угодно
- каждый клиент получает свой ID
- Reality маскирует трафик под HTTPS
- 3x-ui управляет XRay через web panel

## полезные ссылки

[3x-ui GitHub](https://github.com/MHSanaei/3x-ui)

[XRay Documentation](https://xtls.github.io/)

[V2RayTun](https://github.com/2dust/v2rayN)