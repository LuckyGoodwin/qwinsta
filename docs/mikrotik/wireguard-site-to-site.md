# настройка WireGuard site-to-site VPN между MikroTik

WireGuard - современный VPN-протокол с простой настройкой и минимальным overhead.

Начиная с RouterOS v7 WireGuard встроен в систему и сейчас это один из самых удобных способов связать филиалы через интернет. WireGuard быстро устанавливает защищенный VPN tunnel между peer-ами, нормально работает за NAT и обычно требует меньше отладки, чем многие классические VPN решения.

WireGuard не требует сертификатов и PKI инфраструктуры.

Безопасность WireGuard строится на современной криптографии: Curve25519, ChaCha20, Poly1305 и Noise Protocol Framework.

WireGuard может автоматически обновлять endpoint удаленного peer-а после успешного handshake. Это удобно при динамических IP, CGNAT и резервных каналах.

!!! info

    При изменении endpoint-address tunnel может продолжать работать до следующего handshake благодаря roaming механизму WireGuard.

WireGuard не использует TCP и работает только поверх UDP.

Инструкция проверялась на RouterOS v7.

По итогу получаем:

- постоянный site-to-site VPN
- маршрутизацию между филиалами
- доступ между LAN сетями
- минимальную нагрузку на роутеры

## 00. схема

Пример:

```text
MikroTik-1
LAN: 192.168.10.0/24

MikroTik-2
LAN: 192.168.20.0/24
```

Tunnel subnet:

```text
10.0.0.0/30

MikroTik-1
10.0.0.1

MikroTik-2
10.0.0.2
```

Для point-to-point VPN tunnel обычно используют /30 или /31 subnet.

## 01. требования

Нужно:

- RouterOS v7 на обоих роутерах
- хотя бы один endpoint должен быть reachable из интернета
- доступность UDP порта WireGuard
- разные LAN подсети на филиалах

!!! warning

    1. Одинаковые LAN сети между филиалами использовать нельзя.
    2. Если оба peer находятся за CGNAT/NAT и ни один не имеет reachable endpoint, WireGuard tunnel не сможет установить handshake напрямую.

## 02. создание WireGuard интерфейсов

MikroTik-1:

```routeros
/interface wireguard
add name=wg-mikrotik-2 listen-port=51820 mtu=1420
```

MikroTik-2:

```routeros
/interface wireguard
add name=wg-mikrotik-1 listen-port=51820 mtu=1420
```

MTU 1420 обычно нормально работает через NAT, PPPoE и большинство провайдеров, но оптимальное значение зависит от сетевой схемы и провайдера.

При проблемах с packet loss, нестабильным traffic или PPPoE может потребоваться уменьшение MTU.

## 03. tunnel IP адреса

MikroTik-1:

```routeros
/ip address
add address=10.0.0.1/30 interface=wg-mikrotik-2
```

MikroTik-2:

```routeros
/ip address
add address=10.0.0.2/30 interface=wg-mikrotik-1
```

## 04. public keys

WireGuard автоматически создает private-key и public-key. Public-key используется для подключения peer-ов друг к другу, а private-key остается только на своем роутере и используется для шифрования VPN tunnel.

Посмотреть ключи:

```routeros
/interface wireguard print detail
```

Нужен параметр `public-key`.

!!! warning

    Не используйте одинаковый private-key на нескольких роутерах.

!!! info

    При изменении public-key peer-а tunnel перестанет работать до обновления peer configuration на противоположной стороне.

## 05. peer настройка

`allowed-address` в WireGuard одновременно определяет допустимые source addresses peer-а и создает маршруты к этим сетям.

!!! warning

    1. Использование 0.0.0.0/0 в allowed-address изменяет routing behavior и обычно применяется только для full-tunnel VPN.

    2. WireGuard peer идентифицируется по public-key и allowed-address. Неправильные или пересекающиеся allowed-address могут приводить к выбору неправильного peer.

    3. endpoint-address должен быть доступен из интернета по UDP порту WireGuard.

    4. Если IP динамический - лучше использовать DDNS.

    5. allowed-address не должен пересекаться между разными peers.

    endpoint-address поддерживает:
	
    - IP адрес
    - DNS имя
    - MikroTik DDNS hostname

!!! info

    В RouterOS WireGuard peers обрабатываются сверху вниз. При пересекающихся allowed-address может использоваться первый подходящий peer.

MikroTik-1:

```routeros
/interface wireguard peers
add interface=wg-mikrotik-2 public-key="MIKROTIK_2_PUBLIC_KEY" endpoint-address=MIKROTIK_2_IP endpoint-port=51820 allowed-address=10.0.0.2/32,192.168.20.0/24 persistent-keepalive=25s
```

MikroTik-2:

```routeros
/interface wireguard peers
add interface=wg-mikrotik-1 public-key="MIKROTIK_1_PUBLIC_KEY" endpoint-address=MIKROTIK_1_IP endpoint-port=51820 allowed-address=10.0.0.1/32,192.168.10.0/24 persistent-keepalive=25s
```

persistent-keepalive=25s обычно используют для NAT traversal при NAT, CGNAT и динамических подключениях.

Для peer-ов с публичным статическим IP без NAT persistent-keepalive обычно не нужен.

Для динамических IP на MikroTik можно использовать встроенный DDNS:

```routeros
/ip cloud set ddns-enabled=yes
```

Проверить адрес:

```routeros
/ip cloud print
```

При использовании dynamic routing (OSPF/BGP) allowed-address обычно ограничивают только tunnel IP адресами.

## 06. firewall

Разрешаем входящий WireGuard:

```routeros
/ip firewall address-list
add list=WG_PEERS address=X.X.X.X

/ip firewall filter
add chain=input action=accept protocol=udp dst-port=51820 src-address-list=WG_PEERS comment="WireGuard"
```

Разрешаем трафик между филиалами:

```routeros
/ip firewall filter
add chain=forward action=accept src-address=192.168.10.0/24 dst-address=192.168.20.0/24 comment="WG site-to-site"

add chain=forward action=accept src-address=192.168.20.0/24 dst-address=192.168.10.0/24 comment="WG site-to-site"
```

Если используется default masquerade:

```routeros
/ip firewall nat
add chain=srcnat action=accept src-address=192.168.10.0/24 dst-address=192.168.20.0/24 comment="WG bypass"

add chain=srcnat action=accept src-address=192.168.20.0/24 dst-address=192.168.10.0/24 comment="WG bypass"
```

Эти правила нужны только если используется srcnat/masquerade.

!!! info

    Правила NAT bypass должны стоять выше masquerade.

RouterOS v7 обычно автоматически создает dynamic routes (динамические маршруты) через `allowed-address`, проверить можно так:

```routeros
/ip route print
```

При multi-WAN конфигурациях может потребоваться policy routing или routing rules для WireGuard traffic.

В сложных схемах с VRF, policy routing или multi-WAN может потребоваться ручная маршрутизация.

## 07. проверка

Проверяем peer:

```routeros
/interface wireguard peers print
```

Если VPN tunnel поднялся - появится `last-handshake` и начнут увеличиваться `rx/tx counters`, например:

```text
last-handshake: 10s ago
rx: 12.3 MiB
tx: 8.5 MiB
```

WireGuard peer не имеет отдельного `connected/disconnected` состояния.

WireGuard интерфейс не имеет отдельного tunnel state, как IPsec/OpenVPN. Основной индикатор работы - успешный handshake и traffic counters.

WireGuard не выполняет постоянную проверку доступности peer-а.

Tunnel считается активным только при успешном обмене traffic между peer-ами.

WireGuard инициирует handshake при наличии traffic или persistent-keepalive traffic. Отсутствие handshake при полном отсутствии traffic не всегда означает проблему.

Проверяем ping между LAN.

MikroTik-1 → MikroTik-2:

```routeros
ping 192.168.20.1
```

MikroTik-2 → MikroTik-1:

```routeros
ping 192.168.10.1
```

## 08. диагностика

Подробный peer status:

```routeros
/interface wireguard peers print detail
```

Мониторинг интерфейса:

```routeros
/interface wireguard monitor wg-mikrotik-2
```

`monitor` показывает current endpoint, latest handshake и rx/tx counters.

Статистика peer:

```routeros
/interface wireguard peers print stats
```

Счетчики обновляются только при наличии traffic.

Логи:

```routeros
/log print where topics~"wireguard"
```

Torch traffic capture:

```routeros
/tool torch interface=wg-mikrotik-2
```

Torch может показывать не весь traffic при FastTrack или hardware offload.

Hardware offload также может влиять на диагностику traffic и rx/tx counters.

Альтернативно можно использовать sniffer:

```routeros
/tool/sniffer quick interface=wg-mikrotik-2
```

Проверка tunnel IP:

```routeros
/ping 10.0.0.2 interface=wg-mikrotik-2
```

Connections:

```routeros
/ip firewall connection print where dst-port=51820
```

Routes:

```routeros
/ip route print
```

## 09. типовые проблемы

### handshake есть, но трафик не идет

Причины:

- firewall режет forward
- отсутствует NAT bypass
- конфликт подсетей
- неправильный allowed-address
- проблемы маршрутизации

### tunnel постоянно reconnect

Причины:

- CGNAT
- ISP filtering
- нестабильный интернет
- отсутствует persistent-keepalive

### пингуется только tunnel IP

Причины:

- LAN сеть не входит в allowed-address
- firewall режет forward
- NAT masquerade ломает routing
- конфликт маршрутов

### не поднимается handshake

Проверить:

- доступность UDP 51820
- внешний IP
- endpoint-address
- NAT/port-forward
- правильность public-key

## 10. FastTrack и WireGuard

FastTrack обходит часть обработки firewall, connection tracking и queue processing.

FastTrack может вызывать проблемы в VPN схемах, где используются:

- mangle
- policy routing
- queue tree
- traffic accounting

Для диагностики VPN проблем FastTrack лучше временно отключить, либо исключить VPN traffic до FastTrack rules:

```routeros
/ip firewall filter
add chain=forward action=accept src-address=192.168.10.0/24 dst-address=192.168.20.0/24 place-before=[find action=fasttrack-connection]

add chain=forward action=accept src-address=192.168.20.0/24 dst-address=192.168.10.0/24 place-before=[find action=fasttrack-connection]
```

## 11. итог

WireGuard в RouterOS v7 - простой и быстрый способ построить site-to-site VPN между филиалами.

При правильной настройке VPN tunnel стабильно работает через NAT, динамические IP, резервные каналы и обычных интернет провайдеров.

При этом WireGuard создает минимальную нагрузку на роутер, быстро устанавливает VPN tunnel, просто диагностируется и не требует сложной инфраструктуры.

## полезные ссылки

[WireGuard](https://www.wireguard.com/)  
https://www.wireguard.com/

[MikroTik WireGuard](https://help.mikrotik.com/docs/display/ROS/WireGuard)  
https://help.mikrotik.com/docs/display/ROS/WireGuard

[MikroTik Connection Tracking](https://help.mikrotik.com/docs/display/ROS/Connection+tracking)  
https://help.mikrotik.com/docs/display/ROS/Connection+tracking