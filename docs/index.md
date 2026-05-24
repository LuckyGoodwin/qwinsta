# QWINSTA

real infrastructure notes:
windows / mikrotik / vpn / terminal services / powershell

без маркетинговой воды и "enterprise best practices" ради галочки.

---

## разделы

- [Windows]
- [MikroTik]
- [VPN](vpn/mtproxy-fake-tls.md)
- [Toolkit]

---

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
- [как бесплатно поднять документацию на GitHub Pages через MkDocs](github-pages-mkdocs.md)
- [установка и настройка MTProxy на Ubuntu 24.04](vpn/mtproxy-fake-tls.md)
- [установка и настройка Tinyproxy на Ubuntu 24.04](vpn/tinyproxy.md)
- [установка и настройка XRay (VLESS + Reality) + 3x-ui](vpn/xray-reality.md)
- [настройка WireGuard site-to-site VPN между MikroTik](mikrotik/wireguard-site-to-site.md)
<!-- latest:end -->

## about

QWINSTA - заметки о реальной инфраструктуре и ее эксплуатации.

Windows, MikroTik, VPN, Terminal Services, PowerShell, troubleshooting и production incidents без маркетинговой воды и пересказа документации.