#requires -Version 5.1
[CmdletBinding()]
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ($Check) {
    & (Join-Path $root 'tests\Test-QwTui.ps1')
    return
}
Import-Module (Join-Path $root 'Qwinsta.TUI.psd1') -Force
$ui = $null
try {
    $ui = Start-QwTuiSession -Application 'QWINSTA' -Version 'TUI DEMO 0.1.0' -Status 'Демонстрационные данные · подключения к серверам нет'
    $main = @(
        @{ Id = 'servers'; Title = 'Список серверов'; Description = 'Таблица, поиск, прокрутка и просмотр выбранной строки' }
        @{ Id = 'input'; Title = 'Ввод данных'; Description = 'Текстовое поле, редактирование и скрытый ввод пароля' }
        @{ Id = 'confirm'; Title = 'Подтверждение действия'; Description = 'Согласие, отказ и безопасное значение по умолчанию' }
        @{ Id = 'progress'; Title = 'Ход выполнения'; Description = 'Прогресс операции и отмена во время работы' }
        @{ Id = 'messages'; Title = 'Результаты и ошибки'; Description = 'Сообщения об успехе, справочная информация и ошибка' }
        @{ Id = 'nested'; Title = 'Вложенное меню'; Description = 'Переход между экранами и возврат назад' }
    )
    $servers = @(1..32 | ForEach-Object {
        $state = 'Работает'
        if ($_ % 7 -eq 0) { $state = 'Остановлен' }
        if ($_ % 11 -eq 0) { $state = 'Нет связи' }
        [pscustomobject]@{
            Name = ('srv-demo-{0:00}' -f $_)
            Role = @('Файлы', 'Терминал', 'Базы данных')[($_ - 1) % 3]
            State = $state
            Address = ('192.0.2.{0}' -f $_)
        }
    })
    $columns = @(
        @{ Key = 'Name'; Title = 'Сервер'; Width = 25 }
        @{ Key = 'Role'; Title = 'Назначение'; Width = 23 }
        @{ Key = 'State'; Title = 'Состояние'; Width = 22 }
        @{ Key = 'Address'; Title = 'Адрес'; Width = 20 }
    )
    while ($true) {
        $choice = Show-QwMenu $ui 'Главное меню' $main -Description 'Выбери элемент интерфейса, который хочешь проверить.'
        if ($null -eq $choice) { break }
        switch ($choice) {
            'servers' {
                while ($true) {
                    $server = Show-QwTable $ui 'Список серверов' $servers $columns -Description '32 тестовые строки. Никаких сетевых запросов.'
                    if ($null -eq $server) { break }
                    Show-QwMessage $ui $server.Name -Message @(
                        ('Назначение: ' + $server.Role)
                        ('Состояние: ' + $server.State)
                        ('Адрес: ' + $server.Address)
                        ''
                        'Это карточка демонстрационного сервера.'
                        'Реальные подключения и административные действия не выполняются.'
                    )
                }
            }
            'input' {
                while ($true) {
                    $field = Show-QwMenu $ui 'Ввод данных' @(
                        @{ Id = 'text'; Title = 'Имя сервера'; Description = 'Редактирование текста, курсор, Home / End и удаление' }
                        @{ Id = 'secret'; Title = 'Пароль'; Description = 'Скрытый ввод. Значение не сохраняется и не показывается' }
                    ) -Description 'Esc отменяет ввод и возвращает в меню.'
                    if ($null -eq $field) { break }
                    if ($field -eq 'text') {
                        $value = Read-QwText $ui 'Имя сервера' -Value 'srv-demo-01' -MaxLength 80 -Description 'Измени название и нажми Enter.'
                        if ($null -ne $value) { Show-QwMessage $ui 'Значение принято' -Message @($value, '', 'Данные остались только в памяти демо.') -Kind Success }
                    } else {
                        $secret = Read-QwText $ui 'Пароль' -AsSecureString -Description 'Введи тестовое значение. Настоящий пароль здесь не нужен.'
                        if ($null -ne $secret) {
                            try { Show-QwMessage $ui 'Пароль принят' -Message 'Тестовое значение не показывается и не сохраняется.' -Kind Success }
                            finally { $secret.Dispose() }
                        }
                    }
                }
            }
            'confirm' {
                $confirmed = Confirm-QwAction $ui 'Выполнить тестовое действие?' -Description 'Проверка диалога. Ничего в системе не изменится.'
                if ($confirmed) { Show-QwMessage $ui 'Действие подтверждено' -Message 'Получен результат: Да. Реальное действие не выполнялось.' -Kind Success }
                else { Show-QwMessage $ui 'Действие отменено' -Message 'Получен результат: Нет. Ничего не выполнено.' }
            }
            'progress' {
                $completed = $true
                for ($percent = 0; $percent -le 100; $percent++) {
                    $stage = 'Подготовка тестовых данных'
                    if ($percent -ge 25) { $stage = 'Проверка демонстрационного списка' }
                    if ($percent -ge 80) { $stage = 'Подготовка результата' }
                    if (-not (Show-QwProgress $ui 'Проверка данных' -PercentComplete $percent -Description $stage)) {
                        $completed = $false; break
                    }
                    Start-Sleep -Milliseconds 40
                }
                if ($completed) { Show-QwMessage $ui 'Проверка завершена' -Message 'Все тестовые этапы пройдены.' -Kind Success }
                else { Show-QwMessage $ui 'Проверка отменена' -Message 'Демо остановилось по запросу пользователя.' }
            }
            'messages' {
                while ($true) {
                    $kind = Show-QwMenu $ui 'Результаты и ошибки' @(
                        @{ Id = 'Success'; Title = 'Успешное завершение'; Description = 'Результат выполненного действия' }
                        @{ Id = 'Error'; Title = 'Ошибка'; Description = 'Причина и понятный следующий шаг' }
                        @{ Id = 'Info'; Title = 'Длинное сообщение'; Description = 'Перенос строк и вертикальная прокрутка' }
                    ) -Description 'Это примеры сообщений, а не результаты диагностики системы.'
                    if ($null -eq $kind) { break }
                    switch ($kind) {
                        'Success' { Show-QwMessage $ui 'Настройки сохранены' -Message @('Пример успешного результата.', '', 'В демо запись на диск не выполняется.') -Kind Success }
                        'Error' { Show-QwMessage $ui 'Не удалось подключиться' -Message @('Пример: сервер не ответил.', '', 'Проверь адрес и доступность сети, затем повтори подключение.', '', 'Это демонстрационная ошибка. Сетевой запрос не выполнялся.') -Kind Error }
                        'Info' {
                            $lines = @('Проверь прокрутку стрелками, PgUp / PgDn, Home / End.', '')
                            $lines += @(1..40 | ForEach-Object { 'Строка {0:00}. Здесь может находиться результат операции или пояснение для пользователя. Длинный текст переносится по ширине окна.' -f $_ })
                            Show-QwMessage $ui 'Подробный результат' -Message $lines
                        }
                    }
                }
            }
            'nested' {
                while ($true) {
                    $item = Show-QwMenu $ui 'Вложенное меню' @(
                        @{ Id = 'about'; Title = 'О прототипе'; Description = 'Версия и текущие ограничения' }
                        @{ Id = 'empty'; Title = 'Пустой список'; Description = 'Как выглядит экран без данных' }
                    ) -Description 'Esc вернет в главное меню.'
                    if ($null -eq $item) { break }
                    if ($item -eq 'about') {
                        Show-QwMessage $ui 'О прототипе' -Message @(
                            'Qwinsta.TUI 0.1.0 · Windows PowerShell 5.1'
                            ''
                            'Это прототип внешнего вида и управления.'
                            'API еще экспериментальный.'
                            ''
                            'Автоматическое обновление, кеш и загрузка с сайта появятся на следующем этапе.'
                        )
                    } else { $null = Show-QwTable $ui 'Пустой список' @() $columns -Description 'У приложения пока нет данных для отображения.' }
                }
            }
        }
    }
} finally {
    Stop-QwTuiSession $ui
}
