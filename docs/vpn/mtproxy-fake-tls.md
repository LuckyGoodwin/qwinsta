# установка и настройка MTProxy на Ubuntu 24.04

MTProxy - lightweight proxy для Telegram с поддержкой Fake TLS camouflage. Прокси разрабатывается командой Telegram и используется как официальный proxy-протокол для Telegram clients. Работает только поверх TCP и предназначен только для Telegram clients.

Инструкция собиралась и проверялась на Ubuntu 24.04.

По итогу получаем:

- MTProxy server для Telegram
- Fake TLS camouflage
- Telegram sponsored channel
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

## 01. настройка SSH ключей

На локальном ПК:

```bash
ssh-keygen
```

Копируем ключ:

```bash
ssh-copy-id deployuser@123.45.67.89
```

Проверяем вход без пароля:

```bash
ssh deployuser@123.45.67.89
```

## 02. обновление системы

```bash
sudo apt update && sudo apt full-upgrade -y
```

Перезагружаем:

```bash
sudo reboot
```

## 03. отключение root login

Редактируем:

```bash
sudo nano /etc/ssh/sshd_config
```

Меняем:

```text
PermitRootLogin no
```

Рекомендуется также отключить password authentication:

```text
PasswordAuthentication no
```

Перезапускаем SSH:

```bash
sudo systemctl restart ssh
```

!!! info

    На Ubuntu service может называться `ssh` или `sshd`.

## 04. подключение

```bash
ssh deployuser@123.45.67.89
sudo -i
```

## 05. установка зависимостей

```bash
apt install -y git build-essential libssl-dev zlib1g-dev curl
```

## 06. установка MTProxy

```bash
cd /opt
git clone https://github.com/TelegramMessenger/MTProxy.git
mkdir -p /opt/MTProxy/data
chmod 755 /opt/MTProxy
cd MTProxy
```

!!! warning

    Репозиторий MTProxy обновляется. Поведение и параметры могут изменяться между версиями.

## 07. сборка

```bash
make
```

Проверяем бинарник:

```bash
test -f objs/bin/mtproto-proxy && echo OK
```

Проверяем зависимости:

```bash
ldd objs/bin/mtproto-proxy
```

## 08. конфиги Telegram

```bash
curl -s https://core.telegram.org/getProxySecret -o proxy-secret
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
```

Назначаем права:

```bash
chown -R nobody:nogroup /opt/MTProxy
```

## 09. генерация base secret

```bash
head -c 16 /dev/urandom | xxd -ps
```

Secret должен содержать ровно 32 hex символа.

Пример результата:

```text
a1b2c3d4e5f60718293a4b5c6d7e8f90
```

## 10. Fake TLS домен

```bash
echo -n "example.com" | xxd -ps
```

Для Fake TLS обычно используют:

- существующий домен
- HTTPS сайт
- правдоподобный TLS endpoint

Пример результата:

```text
6578616d706c652e636f6d
```

!!! warning

    Не используйте домены Telegram, Google или Cloudflare без понимания возможных последствий DPI/filtering.

## 11. пробный запуск

В примерах используется `777/tcp`.

MTProxy может работать практически на любом TCP порту, но некоторые провайдеры могут фильтровать нестандартные порты.

```bash
./objs/bin/mtproto-proxy -p 8888 -H 777 -S a1b2c3d4e5f60718293a4b5c6d7e8f90 -D example.com --aes-pwd proxy-secret proxy-multi.conf --http-stats --allow-skip-dh -M 1
```

## 12. регистрация MTProxy server в MTProxyBot

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

- proxy tag (`-P`)
- ссылку подключения
- информацию о MTProxy server

## 13. Telegram sponsored channel

В боте:

```text
/myproxies
```

Выбираем MTProxy server → `Set Channel`

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

## 14. systemd сервис

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
User=nobody
Group=nogroup
WorkingDirectory=/opt/MTProxy

ExecStart=/opt/MTProxy/objs/bin/mtproto-proxy -p 8888 -H 777 -S a1b2c3d4e5f60718293a4b5c6d7e8f90 -P abcdef1234567890abcdef1234567890 -D example.com --aes-pwd proxy-secret proxy-multi.conf --http-stats --allow-skip-dh -M 1

Restart=always
RestartSec=3
LimitNOFILE=65535

NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

## 15. запуск

```bash
systemctl daemon-reload
systemctl enable --now mtproxy
```

Проверяем:

```bash
systemctl status mtproxy
```

Для применения изменений:

```bash
systemctl restart mtproxy
```

## 16. firewall

!!! warning

    Перед включением UFW убедитесь, что разрешен OpenSSH, иначе можно потерять SSH доступ.

```bash
ufw allow OpenSSH
ufw allow 777/tcp
ufw enable
```

## 17. Fake TLS secret

Формула:

```text
ee + base_secret + hex(domain)
```

Fake TLS secret всегда начинается с `ee`.

Secret чувствителен к регистру и должен передаваться без пробелов.

Пример:

```text
eea1b2c3d4e5f60718293a4b5c6d7e8f906578616d706c652e636f6d
```

## 18. ссылка для пользователей

```text
tg://proxy?server=123.45.67.89&port=777&secret=eea1b2c3d4e5f60718293a4b5c6d7e8f906578616d706c652e636f6d
```

## 19. диагностика

```bash
systemctl status mtproxy
journalctl -u mtproxy -n 50 --no-pager
journalctl -u mtproxy -f
ss -tnlp | grep :777
```

## 20. как это работает

- MTProxy server работает на base secret
- `@MTProxyBot` регистрирует этот же secret
- proxy tag связывает MTProxy server с Telegram sponsored channel
- пользователи подключаются через Fake TLS ee-secret
- домен в Fake TLS secret используется для TLS camouflage


!!! info

    MTProxy не шифрует весь интернет traffic пользователя и не заменяет VPN.

## полезные ссылки

[Official MTProxy](https://github.com/TelegramMessenger/MTProxy)  
https://github.com/TelegramMessenger/MTProxy/

[@MTProxyBot](https://t.me/MTProxyBot)  
https://t.me/MTProxyBot/