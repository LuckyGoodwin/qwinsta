# как бесплатно поднять документацию на GitHub Pages

Всё делаем из командной строки Windows.

cmd желательно запускать от имени администратора.

Когда у тебя куча заметок, конфигов, команд, инструкций и "временных" txt-файлов, которые живут уже 3 года, рано или поздно ловишь себя на мысли: пора сделать нормальную документацию.

Но платить ни за что не хочется, поднимать отдельный сервер лень, а городить Wordpress - преступление.

В итоге оказывается, что GitHub Pages + MkDocs Material закрывают почти всё бесплатно.

Всё собиралось на обычной Windows 10 22H2 через cmd, Python, Git, MkDocs и GitHub Pages.

По итогу получаем:

- свой сайт
- свой домен
- Markdown
- поиск
- нормальную навигацию
- git versioning
- auto deploy
- бесплатно

И всё это без:

- VPS
- Docker
- Nginx
- сертификатов
- баз данных

## что будем использовать

- GitHub Pages
- MkDocs
- Material for MkDocs
- Git
- Python
- winget

## 1. проверяем winget

```cmd
winget --version
```

Если команда не найдена - нужно установить App Installer из Microsoft Store.

## 2. установка Python

```cmd
winget install --id Python.Python.3 --exact
```

Закрываем `cmd`, открываем заново и проверяем:

```cmd
python --version
pip --version
```

## 3. установка Git

```cmd
winget install --id Git.Git --exact
```

Закрываем `cmd`, открываем заново и проверяем:

```cmd
git --version
```

## 4. установка MkDocs

```cmd
pip install mkdocs mkdocs-material
```

Проверяем:

```cmd
mkdocs --version
```

## 5. создание проекта

```cmd
cd C:\
mkdocs new mydocs
cd C:\mydocs
```

## 6. локальный запуск

```cmd
mkdocs serve
```

После этого сайт будет доступен:

```text
http://127.0.0.1:8000
```

Все изменения в `.md` файлах обновляются автоматически.

Остановить сервер:

```text
Ctrl + C
```

## 7. структура проекта

Минимально:

```text
mydocs/
├─ docs/
│  ├─ index.md
│  └─ stylesheets/
│     └─ extra.css
├─ mkdocs.yml
```

## 8. настройка mkdocs.yml

Редактируем файл:

```text
C:\mydocs\mkdocs.yml
```

Содержимое:

```yaml
site_name: "mydocs"
site_url: https://mydocs.example.com/

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

## 9. опционально: убираем содержание справа и меняем списки

Создаем файл:

```text
C:\mydocs\docs\stylesheets\extra.css
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

## 10. GitHub Pages

Создаем репозиторий на GitHub.

Замените:
- `USERNAME` на свой GitHub username
- `REPO` на название репозитория

Дальше в `cmd`:

```cmd
cd C:\mydocs
git init
git add .
git commit -m "initial commit"
git branch -M main
git remote add origin https://github.com/USERNAME/REPO.git
git push -u origin main
```

## 11. GitHub Actions Deploy

Создаем файл:

```text
C:\mydocs\.github\workflows\deploy.yml
```

Если папок `.github` и `workflows` нет - создаем их вручную.

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

      - run: pip install mkdocs-material

      - run: mkdocs gh-deploy --force
```

## 12. публикация изменений

После изменений:

```cmd
git add .
git commit -m "update docs"
git push
```

GitHub Actions соберет сайт и обновит GitHub Pages.

## 13. свой домен

Для домена нужно создать DNS записи.

Пример:

```text
A      @       185.199.108.153
A      @       185.199.109.153
A      @       185.199.110.153
A      @       185.199.111.153

CNAME www     USERNAME.github.io
```

где:
- `USERNAME` - ваш GitHub username
- `@` - корень домена

После этого в GitHub:

```text
Settings -> Pages
```

указываем свой домен.

## итог

На всё ушло:

- пара часов
- один домен
- ноль рублей за хостинг

Собственно, если вы читаете эту статью - значит всё получилось.

Этот сайт собран через MkDocs, деплоится через GitHub Actions, опубликован на GitHub Pages и создан ровно по инструкции выше.