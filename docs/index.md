# QWINSTA

real infrastructure notes:
windows / mikrotik / vpn / terminal services / powershell

без маркетинговой воды и "enterprise best practices" ради галочки.

## разделы

- [Windows]
- [MikroTik]
- [VPN](vpn/mtproxy/fake-tls.md)
- [Toolkit]

## QWINSTA Toolkit

быстрый запуск:

```powershell
irm https://get.qwinsta.ru | iex
```

!!! warning

    `irm | iex` означает выполнение удаленного PowerShell кода с правами текущего пользователя.

    Перед запуском рекомендуется:

    - прочитать содержимое script
    - проверить URL
    - запускать только из доверенного source

## последние статьи

<!-- latest:start -->
- [RDP ошибка 0x4 при рабочем порте 3389. Диагностика Schannel 36870 и Event ID 1057](windows/rdp/event-id-4625.md)
- [MTProxy на Ubuntu 24.04: установка и настройка](vpn/mtproxy/fake-tls.md)
- [Tinyproxy на Ubuntu 24.04: установка и настройка HTTP-прокси](vpn/tinyproxy/install.md)
- [WireGuard между MikroTik: VPN между филиалами](vpn/wireguard/wireguard-site-to-site-mikrotik.md)
- [OpenVPN на Windows Server 2022: ручная установка и настройка с нуля](vpn/openvpn/install-windows-server.md)
- [Xray: VLESS + REALITY + 3x-ui и сайт на Caddy](vpn/xray/xray-reality.md)
- [как бесплатно поднять документацию на GitHub Pages через MkDocs](github-pages-mkdocs.md)
<!-- latest:end -->

## about

QWINSTA - заметки о реальной инфраструктуре и ее эксплуатации.

Windows, MikroTik, VPN, Terminal Services, PowerShell, troubleshooting и production incidents без маркетинговой воды и пересказа документации.