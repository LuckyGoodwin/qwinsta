# OpenVPN 2.7 на Windows Server 2022 - production setup с нуля

## о серии статей

Это серия статей по OpenVPN 2.7 на Windows Server.

Разбирается:
- настройка OpenVPN
- PKI
- сертификаты
- Active Directory авторизация
- routing
- security
- диагностика проблем
- production эксплуатация

---

## что делаем в этой статье

В данной статье настраивается базовый OpenVPN сервер для постоянной рабочей эксплуатации.

В результате получаем:
- OpenVPNService с автозапуском
- split tunnel
- доступ клиентов в LAN
- routing между VPN и локальной сетью
- работу:
  - ping
  - DNS
  - RDP
- автоматический запуск после reboot

Используется:
- OpenVPN 2.7
- TAP driver
- Easy-RSA
- EC certificates
- tls-crypt
- AES-256-GCM

Конфигурация протестирована:
- Windows Server 2022
- OpenVPN 2.7.4
- MikroTik RouterOS v7

В данной статье:
- без Active Directory
- без MFA
- без паролей на сертификаты
- без hardening

Это базовая рабочая конфигурация, на основе которой дальше будут:
- AD авторизация
- защита PKI
- статические VPN IP
- revoke сертификатов
- hardening
- диагностика проблем

---

## 00. схема

```text
internet
    |
public ip
212.104.74.82
    |
MikroTik
dst-nat udp/1194
    |
Windows Server 2022
OpenVPN 2.7
192.168.2.58
    |
LAN 192.168.2.0/24
```

После настройки получаем:

- OpenVPNService автоматически стартует после reboot
- клиент получает доступ в LAN
- работает:
  - ping
  - DNS
  - RDP
- используется:
  - tls-crypt
  - AES-256-GCM
  - TLS 1.2+
- split tunnel
- конфиг полностью готов для постоянной эксплуатации

Стенд:

```text
OS: Windows Server 2022
OpenVPN: 2.7.4
Easy-RSA: 3.2.6
OpenSSL: 3.6.2
VPN subnet: 192.168.254.0/24
LAN subnet: 192.168.2.0/24
```

---

## 01. установка OpenVPN

Устанавливаем:

- OpenVPN Service - запуск OpenVPN как Windows service
- TAP driver - виртуальный сетевой интерфейс OpenVPN
- OpenSSL - openssl.exe и работа с сертификатами
- Easy-RSA - создание PKI и выпуск сертификатов

Используется именно TAP-драйвер.

`ovpn-dco-win` и DCO в данной конфигурации отключены, потому что классическая схема через TAP:
- проще диагностируется
- работает более предсказуемо
- имеет меньше проблем в Windows

```powershell
clear

#requires -RunAsAdministrator

# версия OpenVPN
$Version = "2.7.4"

# ссылка на MSI
$MsiUrl = "https://swupdate.openvpn.org/community/releases/OpenVPN-$Version-I001-amd64.msi"

# каталог для установки
$TempDir = "C:\OpenVPN-Deploy"

# путь до MSI
$MsiPath = "$TempDir\OpenVPN-$Version-amd64.msi"

# создаем каталог
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

# скачиваем MSI
Invoke-WebRequest `
    -Uri $MsiUrl `
    -OutFile $MsiPath

$Arguments = @(

    "/i"
    "`"$MsiPath`""

    # тихая установка
    "/qn"

    # путь установки
    "INSTALLDIR=C:\OpenVPN"

    # OpenVPN.Service - автозапуск OpenVPN как Windows service
    # Drivers.TAPWindows6 - TAP драйвер
    # OpenSSL - openssl.exe
    # EasyRSA - PKI и сертификаты
    "ADDLOCAL=OpenVPN,OpenVPN.GUI,OpenVPN.Service,Drivers,Drivers.TAPWindows6,OpenSSL,EasyRSA"

    # лог установки MSI
    "/L*v"
    "`"C:\OpenVPN-Deploy\openvpn-install.log`""
)

# запускаем установку
Start-Process `
    -FilePath "msiexec.exe" `
    -ArgumentList $Arguments `
    -Wait `
    -NoNewWindow
```

---

## 02. создаем структуру каталогов

Создаем рабочие каталоги OpenVPN.

`config-auto` используется для автоматического запуска `.ovpn` файлов через OpenVPNService.

```powershell
clear

$Dirs = @(

    # конфиги для OpenVPNService
    "C:\OpenVPN\config-auto",

    # client-config-dir
    "C:\OpenVPN\ccd",

    # готовые ovpn клиентов
    "C:\OpenVPN\clients-configs",

    # вспомогательные скрипты
    "C:\OpenVPN\scripts",

    # backup PKI
    "C:\OpenVPN\pki-backup",

    # логи OpenVPN
    "C:\ProgramData\OpenVPN\Log"
)

foreach ($Dir in $Dirs) {

    New-Item `
        -ItemType Directory `
        -Path $Dir `
        -Force | Out-Null
}
```

---

## 03. Easy-RSA runner

Easy-RSA в Windows использует unix tools через `sh.exe`.

Без runner:
- automation ломается
- `cat`
- `printf`

не находятся.

Runner нужен для:
- автоматического выпуска сертификатов
- автоматического создания PKI
- последующей автоматизации через PowerShell

```powershell
clear

@'
@echo off
setlocal EnableExtensions

set "ER=C:\OpenVPN\easy-rsa"

REM openssl.exe + unix tools Easy-RSA
set "PATH=C:\OpenVPN\bin;%ER%\bin;%PATH%"

REM запуск Easy-RSA через sh.exe
"%ER%\bin\sh.exe" -lc "cd 'C:/OpenVPN/easy-rsa' || exit 111; ./easyrsa %*; exit $?" 2>&1

exit /b %errorlevel%
'@ | Out-File `
    -Encoding ascii `
    -Force `
    "C:\OpenVPN\easy-rsa\easyrsa-run.cmd"
```

---

## 04. vars

Используется:
- EC certificates
- curve `prime256v1`
- SHA256

Вместо RSA используется EC.

Что это дает:
- меньше размер ключей
- быстрее работа TLS
- меньше нагрузка на CPU

```powershell
clear

@'
set_var EASYRSA_DN "cn_only"

# elliptic curve certificates
set_var EASYRSA_ALGO "ec"

# elliptic curve
set_var EASYRSA_CURVE "prime256v1"

# hash algorithm
set_var EASYRSA_DIGEST "sha256"

# срок жизни CA
set_var EASYRSA_CA_EXPIRE 3650

# срок жизни сертификатов
set_var EASYRSA_CERT_EXPIRE 825

# CRL validity
set_var EASYRSA_CRL_DAYS 30

# certificate fields
set_var EASYRSA_REQ_COUNTRY    "RU"
set_var EASYRSA_REQ_PROVINCE   "RU"
set_var EASYRSA_REQ_CITY       "RU"
set_var EASYRSA_REQ_ORG        "OpenVPN"
set_var EASYRSA_REQ_EMAIL      "admin@example.local"
set_var EASYRSA_REQ_OU         "VPN"
'@ | Out-File `
    -Encoding ascii `
    -Force `
    "C:\OpenVPN\easy-rsa\vars"
```

---

## 05. создаем PKI

Создается:

```text
CA
server certificate
CRL
```

В данной статье CA создается без пароля (`nopass`).

Это упрощает автоматизацию, но имеет риски.

Для более защищенной схемы рекомендуется:
- пароль на CA
- offline CA
- backup private key
- отдельный issuing host

Это будет рассмотрено в отдельной статье.

```powershell
clear

# путь до Easy-RSA
$EasyRsaPath = "C:\OpenVPN\easy-rsa"

# PKI каталог
$PkiPath = "$EasyRsaPath\pki"

# удаляем старую PKI
Remove-Item `
    -Recurse `
    -Force `
    -ErrorAction SilentlyContinue `
    $PkiPath

# создаем PKI
cmd.exe /c "`"$EasyRsaPath\easyrsa-run.cmd`" init-pki"

# создаем CA
cmd.exe /c "`"$EasyRsaPath\easyrsa-run.cmd`" --batch build-ca nopass"

# создаем server certificate
cmd.exe /c "`"$EasyRsaPath\easyrsa-run.cmd`" --batch build-server-full server nopass"

# создаем CRL
cmd.exe /c "`"$EasyRsaPath\easyrsa-run.cmd`" --batch gen-crl"
```

---

## 06. создаем server.ovpn

### topology subnet

Современный режим адресации OpenVPN.

Каждый клиент получает обычный IP внутри VPN-подсети.

### tls-crypt

Шифрует служебный TLS-трафик OpenVPN.

Что дает:
- скрывает процесс установки VPN-сессии
- уменьшает количество мусорных подключений
- усложняет обнаружение OpenVPN

### data-ciphers

Список разрешенных алгоритмов шифрования.

Используются только современные AEAD cipher:
- AES-256-GCM
- AES-128-GCM
- CHACHA20-POLY1305

CBC cipher не используются.

### disable-dco

Отключает `ovpn-dco-win`.

Используется классическая схема через TAP-драйвер.

Что это дает:
- более стабильную работу
- проще диагностику
- меньше проблем с Windows firewall и routing

### persist-tun

Не пересоздает TAP interface при reconnect/restart.

Это уменьшает:
- проблемы с маршрутами
- пересоздание интерфейса
- проблемы после reconnect

```powershell
clear

# базовый каталог OpenVPN
$BasePath = "C:\OpenVPN"

# UDP порт OpenVPN
$Port = 1194

# протокол OpenVPN
$Proto = "udp4"

# VPN подсеть
$VpnNet = "192.168.254.0"

# маска VPN подсети
$VpnMask = "255.255.255.0"

# локальная LAN
$LanNet = "192.168.2.0"

# маска LAN
$LanMask = "255.255.255.0"

# DNS который push клиентам
$Dns = "192.168.2.5"

# tls-crypt key
$TlsCryptKey = "$BasePath\easy-rsa\tls-crypt.key"

# удаляем старый tls-crypt key
Remove-Item `
    -Force `
    -ErrorAction SilentlyContinue `
    $TlsCryptKey

# генерируем tls-crypt key
& "$BasePath\bin\openvpn.exe" `
    --genkey `
    secret `
    $TlsCryptKey

@"
port $Port
proto $Proto

# routed TUN mode
dev tun

# отключаем ovpn-dco-win
disable-dco

# normal subnet addressing
topology subnet

# VPN subnet
server $VpnNet $VpnMask

# PKI
ca "C:/OpenVPN/easy-rsa/pki/ca.crt"
cert "C:/OpenVPN/easy-rsa/pki/issued/server.crt"
key "C:/OpenVPN/easy-rsa/pki/private/server.key"

# certificate revoke list
crl-verify "C:/OpenVPN/easy-rsa/pki/crl.pem"

# tls-crypt protection
tls-crypt "C:/OpenVPN/easy-rsa/tls-crypt.key"

# modern AEAD ciphers
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305

# compatibility fallback
cipher AES-256-GCM

# HMAC auth
auth SHA256

# minimum TLS version
tls-version-min 1.2

# проверка client certificate
remote-cert-tls client

# keepalive
keepalive 10 60

# UDP notify on disconnect
explicit-exit-notify 1

# не пересоздаем TAP interface
persist-tun

# route LAN to clients
push "route $LanNet $LanMask"

# DNS to clients
push "dhcp-option DNS $Dns"

# client-config-dir
client-config-dir "C:/OpenVPN/ccd"

# status log
status-version 3
status "C:/ProgramData/OpenVPN/Log/status.log" 10

# server log
log-append "C:/ProgramData/OpenVPN/Log/server.log"

# log verbosity
verb 3
"@ | Out-File `
    -Encoding ascii `
    -Force `
    "$BasePath\config-auto\server.ovpn"
```

---

## 07. firewall + routing

### IPEnableRouter

Включает IPv4 routing в Windows.

Без него:
- VPN tunnel может подниматься
- клиент может подключаться
- но доступа в LAN не будет

### reboot обязателен

Важный момент.

Windows применяет IP routing не полностью сразу после изменения registry.

Без reboot:
- OpenVPN может выглядеть рабочим
- клиент может подключаться
- но маршрутизация между VPN и LAN может не работать

После reboot:
- сетевой стек Windows полностью активирует routing
- доступ в LAN начинает работать нормально

```powershell
clear

# включаем IPv4 routing в Windows
Set-ItemProperty `
    -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" `
    -Name "IPEnableRouter" `
    -Type DWord `
    -Value 1

# удаляем старое firewall rule
Get-NetFirewallRule `
    -DisplayName "OpenVPN Server UDP 1194" `
    -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule

# разрешаем входящий UDP/1194
New-NetFirewallRule `
    -DisplayName "OpenVPN Server UDP 1194" `
    -Direction Inbound `
    -Action Allow `
    -Protocol UDP `
    -LocalPort 1194 `
    -Profile Any `
    -Program "C:\OpenVPN\bin\openvpn.exe"

# restart OpenVPNService on failure
sc.exe failure OpenVPNService reset= 86400 actions= restart/60000/restart/60000/restart/60000

# включаем recovery actions
sc.exe failureflag OpenVPNService 1
```

---

## 08. перезапускаем OpenVPNService

OpenVPNService автоматически запускает все `.ovpn` файлы из:

```text
C:\OpenVPN\config-auto
```

Это production-вариант для Windows.

Не требуется:
- GUI
- ручной запуск
- scheduled tasks

```powershell
clear

# перезапускаем OpenVPNService
Restart-Service OpenVPNService -Force

# ждем поднятия OpenVPN
Start-Sleep -Seconds 15
```

---

## 09. создаем клиента

Создается единый `.ovpn` файл с embedded:
- CA
- client cert
- private key
- tls-crypt

Такой файл удобно:
- импортировать в OpenVPN Connect
- переносить между устройствами
- хранить как готовый client profile

```powershell
clear

# базовый каталог OpenVPN
$BasePath = "C:\OpenVPN"

# каталог Easy-RSA
$EasyRsaPath = "$BasePath\easy-rsa"

# каталог PKI
$PkiPath = "$EasyRsaPath\pki"

# имя клиента
$ClientName = "test1"

# внешний IP MikroTik
$RemoteHost = "212.104.74.82"

# OpenVPN port
$Port = 1194

# OpenVPN protocol
$Proto = "udp4"

# создаем client certificate
cmd.exe /c "`"$EasyRsaPath\easyrsa-run.cmd`" --batch build-client-full $ClientName nopass"

# обновляем CRL
cmd.exe /c "`"$EasyRsaPath\easyrsa-run.cmd`" --batch gen-crl"

# читаем CA
$ca = Get-Content "$PkiPath\ca.crt" -Raw

# читаем client cert
$cert = Get-Content "$PkiPath\issued\$ClientName.crt" -Raw

# читаем private key
$key = Get-Content "$PkiPath\private\$ClientName.key" -Raw

# читаем tls-crypt key
$tc = Get-Content "$EasyRsaPath\tls-crypt.key" -Raw

@"
client
dev tun
proto $Proto

# внешний IP MikroTik
remote $RemoteHost $Port

nobind
resolv-retry infinite

# проверка server certificate
remote-cert-tls server

# modern AEAD ciphers
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305

# compatibility fallback
cipher AES-256-GCM

# HMAC auth
auth SHA256

# minimum TLS version
tls-version-min 1.2

# log verbosity
verb 3

<ca>
$ca
</ca>

<cert>
$cert
</cert>

<key>
$key
</key>

<tls-crypt>
$tc
</tls-crypt>
"@ | Out-File `
    -Encoding ascii `
    -Force `
    "$BasePath\clients-configs\$ClientName.ovpn"
```

---

## 10. MikroTik

### dst-nat

```routeros
/ip firewall nat

add chain=dstnat \
    protocol=udp \
    dst-port=1194 \
    action=dst-nat \
    to-addresses=192.168.2.58 \
    to-ports=1194 \
    comment="OpenVPN UDP 1194"
```

### route

Без статического маршрута MikroTik не будет знать:
- куда отправлять VPN подсеть
- через какой gateway доступен OpenVPN subnet

```routeros
/ip route

add dst-address=192.168.254.0/24 gateway=192.168.2.58
```

---

## 11. reboot

### reboot обязателен

Без reboot:
- OpenVPN может выглядеть рабочим
- клиент может подключаться
- но маршрутизация между VPN и LAN может не работать

```powershell
Restart-Computer
```

---

## 12. результат

После reboot:

- OpenVPNService автоматически стартует
- VPN поднимается автоматически
- routing работает
- LAN доступен
- RDP работает
- DNS работает

---

## production notes

### confirmed

```text
- OpenVPN 2.7.4 production-tested на Windows Server 2022
- TAP predictable
- disable-dco predictable
- config-auto подходит для production
- IPEnableRouter требует reboot
```

### важно

```text
- windows-driver wintun может вести себя нестабильно в некоторых сценариях на Windows Server 2022
- persist-key не используется в данной конфигурации
```

В OpenVPN 2.7 это вызывает deprecated behavior или нестабильную работу.