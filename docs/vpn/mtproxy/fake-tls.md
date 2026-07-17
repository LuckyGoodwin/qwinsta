# MTProxy на Ubuntu 24.04: установка и настройка

В этой статье рассмотрим установку и настройку MTProxy на Ubuntu 24.04.

MTProxy — официальный прокси-сервер Telegram. Он разработан командой Telegram, работает только с клиентами Telegram и не заменяет VPN.

В статье используется режим **Fake TLS**, который позволяет маскировать соединение под обычный HTTPS.

Инструкция проверена на Ubuntu 24.04.

## Что получится в результате

После выполнения всех шагов будут настроены:

- MTProxy;
- режим Fake TLS;
- Telegram Sponsored Channel;
- автоматический запуск службы;
- работа через выбранный TCP-порт.

---

## 1. Подготавливаем сервер

В примерах используется сервер с адресом `123.45.67.89`. Замените его на IP-адрес своего сервера.

Подключаемся:

```bash
ssh root@123.45.67.89
```

Создаём пользователя:

```bash
adduser deployuser
```

Добавляем его в группу `sudo`:

```bash
usermod -aG sudo deployuser
```

Настраиваем вход по SSH-ключу.

На локальном компьютере создаём ключ:

```bash
ssh-keygen
```

Копируем его на сервер:

```bash
ssh-copy-id deployuser@123.45.67.89
```

Проверяем вход без пароля:

```bash
ssh deployuser@123.45.67.89
```

Обновляем систему:

```bash
sudo apt update && sudo apt full-upgrade -y
```

Перезагружаем сервер:

```bash
sudo reboot
```

Дальнейшую настройку будем выполнять уже под пользователем `deployuser`.

Чтобы запретить вход по SSH под пользователем `root`, открываем файл:

```bash
sudo nano /etc/ssh/sshd_config
```

Изменяем параметры:

```text
PermitRootLogin no
PasswordAuthentication no
```

Перезапускаем SSH:

```bash
sudo systemctl restart ssh
```

> Перед отключением входа по паролю обязательно убедитесь, что вход по SSH-ключу работает.

---

## 2. Устанавливаем MTProxy

Подключаемся к серверу:

```bash
ssh deployuser@123.45.67.89
sudo -i
```

Устанавливаем необходимые пакеты:

```bash
apt install -y git build-essential libssl-dev zlib1g-dev curl
```

Загружаем исходный код MTProxy:

```bash
cd /opt
git clone https://github.com/TelegramMessenger/MTProxy.git
mkdir -p /opt/MTProxy/data
chmod 755 /opt/MTProxy
cd MTProxy
```

Репозиторий регулярно обновляется, поэтому параметры запуска могут изменяться между версиями.

Собираем MTProxy:

```bash
make
```

После сборки исполняемый файл должен находиться здесь:

```text
/opt/MTProxy/objs/bin/mtproto-proxy
```

---

## 3. Получаем параметры Telegram

Скачиваем служебные файлы Telegram:

```bash
curl -s https://core.telegram.org/getProxySecret -o proxy-secret
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
```

Назначаем владельца каталога:

```bash
chown -R nobody:nogroup /opt/MTProxy
```

---

## 4. Создаём секрет сервера

Генерируем секрет:

```bash
head -c 16 /dev/urandom | xxd -ps
```

Будет получена строка длиной 32 шестнадцатеричных символа.

Например:

```text
a1b2c3d4e5f60718293a4b5c6d7e8f90
```

Сохраните её. Она понадобится при запуске MTProxy и регистрации прокси в `@MTProxyBot`.

---

## 5. Выбираем домен для Fake TLS

Получаем шестнадцатеричное представление доменного имени:

```bash
echo -n "example.com" | xxd -ps
```

Например:

```text
6578616d706c652e636f6d
```

Для Fake TLS рекомендуется использовать существующий сайт, доступный по HTTPS.

Не рекомендуется использовать домены Telegram, Google или Cloudflare без понимания возможных последствий.

---

## 6. Проверяем запуск MTProxy

В примере используется порт `777/tcp`.

```bash
./objs/bin/mtproto-proxy -p 8888 -H 777 -S a1b2c3d4e5f60718293a4b5c6d7e8f90 -D example.com --aes-pwd proxy-secret proxy-multi.conf --http-stats --allow-skip-dh -M 1
```

Если MTProxy успешно запустился, можно переходить к регистрации прокси в Telegram.

---

## 7. Регистрируем прокси

Открываем:

```text
@MTProxyBot
```

Выполняем команды:

```text
/start
/newproxy
```

Бот попросит указать:

```text
IP:PORT
123.45.67.89:777

Secret
a1b2c3d4e5f60718293a4b5c6d7e8f90
```

Передаётся только секрет сервера.

Без префикса:

```text
ee
```

После регистрации бот выдаст:

- Proxy Tag;
- ссылку подключения;
- информацию о прокси.

Proxy Tag понадобится при создании службы.

## 8. Настраиваем Telegram Sponsored Channel

Если прокси будет использовать Telegram Sponsored Channel, открываем в боте:

```text
/myproxies
```

Выбираем зарегистрированный MTProxy и нажимаем:

```text
Set Channel
```

Указываем публичный канал:

```text
@your_channel
```

или

```text
t.me/your_channel
```

Канал должен быть публичным.

Изменения применяются не сразу. Обычно это занимает несколько минут, но иногда обновление может занять до часа.

---

## 9. Создаём службу systemd

Создаём файл:

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

В этой команде необходимо заменить:

- `-S` — на секрет сервера;
- `-P` — на Proxy Tag, полученный от `@MTProxyBot`;
- `-D` — на домен, выбранный для Fake TLS.

---

## 10. Запускаем службу

Обновляем конфигурацию systemd:

```bash
systemctl daemon-reload
```

Включаем автоматический запуск и сразу запускаем службу:

```bash
systemctl enable --now mtproxy
```

Проверяем состояние:

```bash
systemctl status mtproxy
```

Служба должна перейти в состояние:

```text
active (running)
```

После изменения параметров службы достаточно выполнить:

```bash
systemctl restart mtproxy
```

---

## 11. Настраиваем межсетевой экран

Перед включением UFW обязательно разрешаем SSH, иначе можно потерять доступ к серверу.

```bash
ufw allow OpenSSH
ufw allow 777/tcp
ufw enable
```

Если используется другой порт MTProxy, откройте именно его.

---

## 12. Формируем Fake TLS Secret

Пользователи подключаются не по секрету сервера, а по специальному Fake TLS Secret.

Он состоит из трёх частей:

```text
ee + secret + hex(domain)
```

где:

- `ee` — признак режима Fake TLS;
- `secret` — секрет сервера;
- `hex(domain)` — домен в шестнадцатеричном виде.

Например:

```text
eea1b2c3d4e5f60718293a4b5c6d7e8f906578616d706c652e636f6d
```

Все символы должны идти подряд, без пробелов.

---

## 13. Формируем ссылку для подключения

Готовая ссылка выглядит так:

```text
tg://proxy?server=123.45.67.89&port=777&secret=eea1b2c3d4e5f60718293a4b5c6d7e8f906578616d706c652e636f6d
```

Достаточно передать её пользователю или преобразовать в QR-код.

После открытия ссылки Telegram автоматически предложит добавить прокси.

---

## 14. Проверяем работу

Проверяем состояние службы:

```bash
systemctl status mtproxy
```

Просматриваем последние сообщения журнала:

```bash
journalctl -u mtproxy -n 50 --no-pager
```

Если требуется наблюдать журнал в реальном времени:

```bash
journalctl -u mtproxy -f
```

Проверяем, что MTProxy прослушивает нужный порт:

```bash
ss -tnlp | grep :777
```

---

## 15. Как это работает

MTProxy работает только с клиентами Telegram.

На сервере используется секрет, который задаётся параметром `-S`. Этот же секрет передаётся в `@MTProxyBot` при регистрации прокси.

После регистрации бот выдаёт Proxy Tag. Он добавляется в параметры запуска (`-P`) и связывает прокси с Telegram Sponsored Channel.

Пользователи подключаются уже не по секрету сервера, а по Fake TLS Secret, который начинается с `ee`.

Fake TLS делает соединение похожим на обычный HTTPS-трафик выбранного сайта, но не превращает MTProxy в VPN.

Через MTProxy работает только трафик Telegram.

---

## 16. Резервная копия

После завершения настройки рекомендуется сохранить:

```text
/opt/MTProxy/proxy-secret
/opt/MTProxy/proxy-multi.conf
/etc/systemd/system/mtproxy.service
```

Если используется собственный скрипт запуска или изменены параметры MTProxy, сохраните и их.

При потере этих файлов придётся заново настраивать службу и параметры запуска.

Не храните единственную резервную копию на этом же сервере. Сохраните её на другом сервере, NAS или внешнем носителе.

---

## Полезные ссылки

[Official MTProxy](https://github.com/TelegramMessenger/MTProxy)

[@MTProxyBot](https://t.me/MTProxyBot)
