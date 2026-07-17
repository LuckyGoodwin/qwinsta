# Tinyproxy на Ubuntu 24.04: установка и настройка HTTP-прокси

В этой статье рассмотрим установку и настройку Tinyproxy на Ubuntu 24.04.

Tinyproxy — небольшой HTTP-прокси-сервер с поддержкой HTTPS через метод `CONNECT`. Он потребляет минимум ресурсов и подходит для случаев, когда не требуется полноценный VPN или SOCKS-прокси.

Инструкция проверена на Ubuntu 24.04.

## Что получится в результате

После выполнения всех шагов будут настроены:

- HTTP-прокси;
- поддержка HTTPS через `CONNECT`;
- авторизация по логину и паролю;
- ограничение доступа по IP-адресам;
- автоматический запуск службы Tinyproxy.

Tinyproxy подходит для браузеров, `curl` и большинства программ, поддерживающих HTTP-прокси.

Tinyproxy не является SOCKS-прокси и не заменяет VPN.

---

## 1. Подготавливаем сервер

В примерах используется сервер с адресом `123.45.67.89`, замените его на IP-адрес своего сервера.

Подключаемся к серверу под пользователем `root`:

```bash
ssh root@123.45.67.89
```

Создаём отдельного пользователя:

```bash
adduser deployuser
```

Добавляем его в группу `sudo`:

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

Перезагружаем сервер:

```bash
sudo reboot
```

Дальнейшую настройку будем выполнять уже под пользователем `deployuser`.

Чтобы запретить вход по SSH под пользователем `root`, открываем файл:

```bash
sudo nano /etc/ssh/sshd_config
```

Изменяем параметр:

```text
PermitRootLogin no
```

После сохранения файла перезапускаем SSH:

```bash
sudo systemctl restart ssh
```

> Перед отключением входа под `root` обязательно убедитесь, что пользователь `deployuser` может выполнять команды через `sudo`.

---

## 2. Устанавливаем Tinyproxy

Подключаемся к серверу:

```bash
ssh deployuser@123.45.67.89
```

Получаем права `root`:

```bash
sudo -i
```

Устанавливаем Tinyproxy:

```bash
apt install -y tinyproxy
```

После установки стоит запомнить два пути:

```text
/etc/tinyproxy/tinyproxy.conf
```

Основной конфигурационный файл.

```text
/var/log/tinyproxy/
```

Журналы работы Tinyproxy.

---

## 3. Настраиваем Tinyproxy

Открываем конфигурационный файл:

```bash
nano /etc/tinyproxy/tinyproxy.conf
```

Минимальная рабочая конфигурация:

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

Перед сохранением замените:

```text
myuser
mypassword
1.2.3.4
```

на свои значения.

Наиболее важные параметры:

- `Port` — порт, на котором работает прокси;
- `Listen` — сетевой интерфейс, на котором Tinyproxy принимает подключения;
- `BasicAuth` — имя пользователя и пароль;
- `Allow` — список IP-адресов, которым разрешено подключение.

Можно разрешить сразу несколько адресов или подсетей:

```text
Allow 1.2.3.4
Allow 5.6.7.0/24
Allow 10.0.0.0/8
```

Если авторизация не требуется, строку `BasicAuth` можно удалить.

В этом случае обязательно ограничьте доступ по IP-адресам с помощью параметра `Allow`.

> **Не оставляйте прокси открытым всему Интернету. Используйте авторизацию, ограничение по IP-адресам или оба механизма одновременно.**

---

## 4. Запускаем Tinyproxy

Включаем автоматический запуск службы и сразу запускаем её:

```bash
systemctl enable --now tinyproxy
```

Проверяем состояние:

```bash
systemctl status tinyproxy
```

Служба должна перейти в состояние `active (running)`. Если этого не произошло, причину обычно можно увидеть в выводе команды `systemctl status` или в журнале Tinyproxy.