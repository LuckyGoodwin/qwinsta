# как бесплатно поднять документацию на GitHub Pages через MkDocs

Когда заметки, конфиги, инструкции и txt-файлы начинают жить годами - их обычно собирают в документацию.

GitHub Pages + MkDocs + Material theme позволяют сделать это бесплатно, без VPS, Docker, Nginx и отдельного сервера.

Инструкция проверялась на Windows 10 22H2 через cmd.exe.

По итогу получаем:

- сайт с документацией
- публикацию через GitHub Pages
- Markdown статьи
- поиск
- навигацию
- git versioning
- auto deploy через GitHub Actions
- возможность подключить свой домен
- бесплатный хостинг

## 00. требования

Нужно:

- Windows
- GitHub аккаунт
- интернет
- winget

!!! warning

    Для работы GitHub Pages нужен публичный GitHub repository либо тариф/настройки, которые позволяют публиковать Pages из private repository.

Проверяем winget:

```cmd
winget --version
```

Если команда не найдена - установите App Installer из Microsoft Store и перезапустите cmd.

## 01. установка Python

```cmd
winget install --id Python.Python.3 --exact
```

Перезапускаем `cmd` и проверяем:

```cmd
python --version
pip --version
```

!!! info

    Если python или pip не находятся после установки - перезапустите cmd или проверьте PATH.

## 02. установка Git

```cmd
winget install --id Git.Git --exact
```

Перезапускаем `cmd` и проверяем:

```cmd
git --version
```

## 03. установка MkDocs

```cmd
python -m pip install mkdocs mkdocs-material
```

Проверяем:

```cmd
python -m mkdocs --version
```

Если `mkdocs` доступен в PATH, можно использовать короткие команды:

```cmd
mkdocs serve
mkdocs build
```

## 04. создание проекта

```cmd
cd C:\
python -m mkdocs new infra-docs
cd C:\infra-docs
```

## 05. локальный запуск

```cmd
python -m mkdocs serve
```

Сайт будет доступен:

```text
http://127.0.0.1:8000
```

Изменения в `.md` файлах обычно применяются автоматически после сохранения файла.

Остановить сервер:

```text
Ctrl+C
```

## 06. структура проекта

Минимальная структура:

```text
infra-docs/
├─ docs/
│  ├─ index.md
│  ├─ github-pages-mkdocs.md
│  └─ stylesheets/
│     └─ extra.css
├─ mkdocs.yml
```

Создаем статью:

```cmd
notepad C:\infra-docs\docs\github-pages-mkdocs.md
```

## 07. настройка mkdocs.yml

Редактируем:

```text
C:\infra-docs\mkdocs.yml
```

Содержимое:

```yaml
site_name: "infra docs"
site_url: https://USERNAME.github.io/REPO/

theme:
  name: material
  language: ru

  icon:
    logo: material/console

  palette:
    scheme: slate
    primary: black
    accent: green

  features:
    - navigation.tabs
    - navigation.tabs.sticky
    - navigation.top
    - search.suggest
    - search.highlight
    - content.code.copy

plugins:
  - search

markdown_extensions:
  - admonition
  - pymdownx.details
  - pymdownx.superfences
  - pymdownx.highlight
  - tables

extra:
  generator: false

extra_css:
  - stylesheets/extra.css

nav:
  - "Главная": index.md

  - "Guides":
      - "GitHub Pages + MkDocs": github-pages-mkdocs.md
```

!!! warning

    site_url должен соответствовать реальному URL сайта. Для GitHub Pages обычно используется:
    https://USERNAME.github.io/REPO/

## 08. кастомный CSS

Создаем файл:

```text
C:\infra-docs\docs\stylesheets\extra.css
```

Содержимое:

```css
/* убрать содержание справа */
.md-sidebar--secondary {
  display: none !important;
}

/* расширить контент */
.md-content {
  max-width: none;
}

/* списки через дефис */
.md-typeset ul {
  list-style: none;
  padding-left: 1.2em;
}

.md-typeset ul li {
  position: relative;
  margin: 0.08em 0;
  line-height: 1.25;
}

.md-typeset ul li::marker {
  content: "";
}

.md-typeset ul li::before {
  content: "- ";
  color: var(--md-default-fg-color--light);
  margin-left: -1.2em;
  position: absolute;
}
```

## 09. GitHub repository

Создаем repository на GitHub.

Замените:

- `USERNAME` на свой GitHub username
- `REPO` на название repository

Дальше в `cmd`:

```cmd
cd C:\infra-docs
git init
git add .
git commit -m "initial commit"
git branch -M main
git remote add origin https://github.com/USERNAME/REPO.git
git push -u origin main
```

## 10. GitHub Actions deploy

Создаем файл:

```text
C:\infra-docs\.github\workflows\deploy.yml
```

Если `.github` и `workflows` отсутствуют - создаем вручную.

Содержимое:

```yaml
name: deploy mkdocs

on:
  push:
    branches:
      - main

permissions:
  contents: write

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: 3.x

      - run: pip install mkdocs mkdocs-material

      - run: mkdocs gh-deploy --force
```

`mkdocs gh-deploy` публикует сайт в branch `gh-pages`.

!!! info

    После первого deploy branch `gh-pages` создается автоматически.

## 11. публикация изменений

После изменений:

```cmd
git add .
git commit -m "update docs"
git push
```

GitHub Actions автоматически соберет сайт и опубликует его в branch `gh-pages`.

В GitHub Pages source должен быть выбран:

- branch: `gh-pages`
- folder: `/(root)`

Проверить сайт можно по адресу:

```text
https://USERNAME.github.io/REPO/
```

Даже если собственный домен еще не настроен.

!!! info

    GitHub Pages обновляется не мгновенно.
    Первый deploy иногда занимает несколько минут.

## 12. свой домен

Для домена создаем DNS записи.

Пример:

```text
A      @       185.199.108.153
A      @       185.199.109.153
A      @       185.199.110.153
A      @       185.199.111.153

CNAME  www     USERNAME.github.io
```

!!! warning

    DNS записи GitHub Pages лучше периодически сверять с официальной документацией GitHub.

!!! info

    - `USERNAME` - GitHub username
    - `@` - корень домена

После этого в GitHub:

```text
Settings -> Pages -> Custom domain
```

указываем свой домен.

После настройки домена желательно включить:

- Enforce HTTPS

## 13. проверка

Локальный запуск:

```cmd
python -m mkdocs serve
```

Проверка сборки:

```cmd
python -m mkdocs build
```

Проверка deploy:

```cmd
git push
```

Если deploy успешен - workflow в GitHub Actions завершится со статусом `Success`.

## 14. типовые проблемы

### mkdocs не найден

Проверить:

```cmd
python -m mkdocs --version
```

Если команда не работает - обычно помогает перезапуск `cmd`.

### сайт не обновляется

Проверить:

- git push
- GitHub Actions
- branch main
- workflow status

### GitHub Actions успешен, но сайт не обновляется

Проверить:

- source branch gh-pages
- cache браузера
- custom domain
- DNS propagation
- GitHub Pages status

### CSS не применяется

Проверить:

- путь `docs/stylesheets/extra.css`
- extra_css в mkdocs.yml
- обновление страницы через `Ctrl + F5`

### GitHub Pages открывает 404

Проверить:

- включен ли GitHub Pages
- успешен ли deploy
- правильный ли repository URL

### www домен не открывается

Проверить:

- CNAME запись
- Custom domain в GitHub Pages
- DNS propagation

## 15. итог

На базовую настройку обычно уходит:

- пара часов
- один домен
- ноль рублей за хостинг

Если сайт успешно открывается через GitHub Pages URL или собственный домен - документация настроена корректно.

Сайт собран через Material for MkDocs, деплоится через GitHub Actions, опубликован на GitHub Pages и создан ровно по инструкции выше.