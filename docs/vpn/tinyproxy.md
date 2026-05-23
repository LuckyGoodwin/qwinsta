# установка и настройка Tinyproxy на Ubuntu 24.04

Tinyproxy - легкий HTTP/HTTPS proxy сервер с минимальным потреблением ресурсов.

Подходит для:

- Telegram
- curl
- API запросов
- скриптов
- браузеров
- временного proxy через VPS

Инструкция собиралась и проверялась на Ubuntu 24.04.

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
apt install -y tinyproxy apache2-utils
```

## 03. создание логина и пароля

Создаем файл паролей:

```bash
htpasswd -c /etc/tinyproxy/passwd myuser
```

Вводим пароль.

## 04. настройка Tinyproxy

Редактируем:

```bash
nano /etc/tinyproxy/tinyproxy.conf
```

Минимальный пример:

```text
Port 7777

Timeout 600

Allow 0.0.0.0/0

BasicAuth myuser mypassword
```

Важно:

- `7777` - порт proxy
- `myuser` и `mypassword` заменить на свои
- `Allow` ограничивает доступ по IP
- `0.0.0.0/0` разрешает доступ всем

Пример ограничения по IP:

```text
Allow 1.2.3.4
Allow 5.6.7.0/24
```

Если авторизация не нужна - строку `BasicAuth` можно удалить.

## 05. запуск

```bash
systemctl enable tinyproxy
systemctl restart tinyproxy
```

Проверяем:

```bash
systemctl status tinyproxy
```

## 06. firewall (опционально)

```bash
ufw allow 7777/tcp
```

## 07. проверка порта

```bash
ss -lntp | grep 7777
```

## 08. подключение

Пример proxy:

```text
http://myuser:mypassword@123.45.67.89:7777
```

## 09. использование в Telegram Desktop

Telegram Desktop умеет работать через HTTP proxy.

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

## 10. диагностика

```bash
systemctl status tinyproxy
journalctl -u tinyproxy -n 50 --no-pager
ss -lntp | grep 7777
```

## 11. как это работает

- Tinyproxy поднимает обычный HTTP proxy
- Telegram Desktop умеет работать через HTTP proxy
- трафик идет через ваш VPS
- Telegram видит подключение как обычный HTTPS трафик

## полезные ссылки

[Tinyproxy GitHub](https://github.com/tinyproxy/tinyproxy)

[Tinyproxy Documentation](https://tinyproxy.github.io/)