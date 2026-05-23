# установка и настройка MTProxy на Ubuntu 24.04

Инструкция собиралась и проверялась на Ubuntu 24.04.

По итогу получаем:

- MTProxy для Telegram
- Fake TLS
- sponsored channel
- systemd сервис
- автозапуск

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

## 02. установка зависимостей

```bash
apt install -y git build-essential libssl-dev zlib1g-dev curl
```

## 03. установка MTProxy

```bash
cd /opt
git clone https://github.com/TelegramMessenger/MTProxy.git
cd MTProxy
```

## 04. сборка

```bash
make
```

Проверяем:

```bash
ls objs/bin/mtproto-proxy
```

## 05. конфиги Telegram

```bash
curl -s https://core.telegram.org/getProxySecret -o proxy-secret
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
```

## 06. генерация base secret

```bash
head -c 16 /dev/urandom | xxd -ps
```

Пример результата:

```text
a1b2c3d4e5f60718293a4b5c6d7e8f90
```

## 07. Fake TLS домен

```bash
echo -n "example.com" | xxd -ps
```

Пример результата:

```text
6578616d706c652e636f6d
```

## 08. пробный запуск

В примерах используется 777/tcp, но MTProxy может работать и на других TCP портах.

```bash
./objs/bin/mtproto-proxy -u nobody -p 8888 -H 777 -S a1b2c3d4e5f60718293a4b5c6d7e8f90 -D example.com --aes-pwd proxy-secret proxy-multi.conf --http-stats --allow-skip-dh -M 1
```

## 09. регистрация прокси в MTProxyBot

Открываем:

```text
@MTProxyBot
```

Команды:

```text
/start
/newproxy
```

Бот попросит:

```text
1. IP:PORT
123.45.67.89:777

2. Secret
a1b2c3d4e5f60718293a4b5c6d7e8f90
```

Важно:
- отправляется только base secret
- без `ee`

После этого бот выдаст:

- proxy tag
- ссылку подключения
- информацию о прокси

## 10. sponsored channel

В боте:

```text
/myproxies
```

Выбираем прокси → `Set Channel`

Отправляем:

```text
@your_channel
```

или:

```text
t.me/your_channel
```

Важно:

- канал должен быть публичный
- изменения применяются не сразу
- иногда обновление занимает до часа

## 11. systemd сервис

Создаем файл:

```text
/etc/systemd/system/mtproxy.service
```

Содержимое:

```ini
[Unit]
Description=MTProto Proxy
After=network.target

[Service]
WorkingDirectory=/opt/MTProxy
ExecStart=/opt/MTProxy/objs/bin/mtproto-proxy -u nobody -p 8888 -H 777 -S a1b2c3d4e5f60718293a4b5c6d7e8f90 -P abcdef1234567890abcdef1234567890 -D example.com --aes-pwd proxy-secret proxy-multi.conf --http-stats --allow-skip-dh -M 1
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

## 12. запуск

```bash
systemctl daemon-reload
systemctl enable mtproxy
systemctl start mtproxy
```

Проверяем:

```bash
systemctl status mtproxy
```

## 13. firewall

```bash
ufw allow 777/tcp
```

## 14. Fake TLS secret

Формула:

```text
ee + base_secret + hex(domain)
```

Пример:

```text
eea1b2c3d4e5f60718293a4b5c6d7e8f906578616d706c652e636f6d
```

## 15. ссылка для пользователей

```text
tg://proxy?server=123.45.67.89&port=777&secret=eea1b2c3d4e5f60718293a4b5c6d7e8f906578616d706c652e636f6d
```

## 16. диагностика

```bash
systemctl status mtproxy
journalctl -u mtproxy -n 50 --no-pager
ss -tn sport = :777
```

## 17. как это работает

- MTProxy работает на base secret
- @MTProxyBot регистрирует этот же secret
- proxy tag связывает сервер и sponsored channel
- пользователи подключаются через Fake TLS ee-secret
- домен в secret используется для TLS camouflage

## полезные ссылки

[Official MTProxy](https://github.com/TelegramMessenger/MTProxy)

[@MTProxyBot](https://t.me/MTProxyBot)