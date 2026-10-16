#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'Qwinsta.TUI.psd1') -Force
$ui = $null
try {
    $ui = Start-QwTuiSession -Application 'Мой инструмент' -Version '0.1.0' -Status 'Локальный запуск'
    while ($true) {
        $id = Show-QwMenu $ui 'Главное меню' @(
            @{ Id = 'hello'; Title = 'Показать сообщение'; Description = 'Минимальный пример подключения каркаса' }
        )
        if ($null -eq $id) { break }
        if ($id -eq 'hello') { Show-QwMessage $ui 'Готово' -Message 'Проект получил выбранный пункт и сам обработал действие.' }
    }
} finally {
    Stop-QwTuiSession $ui
}
