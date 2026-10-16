#requires -Version 5.1
[CmdletBinding()]
param([string]$SnapshotPath)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1 -or $PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Run these tests in Windows PowerShell 5.1, not pwsh.'
}
$root = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $root 'Qwinsta.TUI.psd1'
Import-Module $modulePath -Force
$script:Passed = 0
$script:Failed = New-Object 'System.Collections.Generic.List[string]'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $script:Passed++
        Write-Host ('PASS ' + $Name) -ForegroundColor Green
    } catch {
        Write-Host ('FAIL ' + $Name) -ForegroundColor Red
        Write-Host $_.Exception.Message
        Write-Host $_.ScriptStackTrace
        $script:Failed.Add($Name + ': ' + $_.Exception.Message)
    }
}
function New-Key {
    param([string]$Name, [char]$Character = [char]0, [switch]$Control)
    [ConsoleKeyInfo]::new($Character, [ConsoleKey]$Name, $false, $false, [bool]$Control)
}
function New-TestSession {
    param([object[]]$Keys, [int]$Width = 100, [int]$Height = 30)
    $queue = New-Object System.Collections.Queue
    foreach ($key in $Keys) { $queue.Enqueue($key) }
    $state = [pscustomobject]@{
        Width = $Width; Height = $Height; Reads = 0; Queue = $queue
        Frames = New-Object 'System.Collections.Generic.List[object]'
    }
    $adapter = [pscustomobject]@{
        Size = { [pscustomobject]@{ Width = $state.Width; Height = $state.Height } }.GetNewClosure()
        Render = { param($s, $f) $state.Frames.Add($f) }.GetNewClosure()
        Key = {
            $state.Reads++
            if ($state.Reads -gt 1000 -or $state.Queue.Count -eq 0) { throw 'Test exhausted its input; interaction did not terminate.' }
            $event = $state.Queue.Dequeue()
            if ($event -is [hashtable]) {
                $state.Width = $event.Width; $state.Height = $event.Height
                return $null
            }
            return $event
        }.GetNewClosure()
        Pause = { }
    }
    [pscustomobject]@{
        Application = 'QWINSTA'; Version = 'TUI DEMO 0.1.0'
        Status = 'Демонстрационные данные · подключения к серверам нет'
        Active = $true; Saved = $null; PreviousFrame = $null; Adapter = $adapter; TestState = $state
    }
}
$items = @(1..40 | ForEach-Object { @{ Id = "item-$_"; Title = "Пункт $_"; Description = "Описание $_" } })
$columns = @(@{ Key = 'Name'; Title = 'Сервер'; Width = 2 }, @{ Key = 'State'; Title = 'Состояние'; Width = 1 })
$rows = @([pscustomobject]@{ Name = 'Альфа'; State = 'Работает' }, [pscustomobject]@{ Name = 'Бета'; State = 'Остановлен' })

Test-Case 'All PowerShell sources parse in 5.1 and have a UTF-8 BOM' {
    foreach ($file in Get-ChildItem $root -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.psm1', '.psd1') }) {
        $tokens = $null; $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
        Assert-True ($errors.Count -eq 0) ("Parse failed: $($file.Name): $errors")
        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        Assert-True ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) ("Missing UTF-8 BOM: $($file.Name)")
    }
}
Test-Case 'Manifest, export boundary and version agree' {
    $manifest = Test-ModuleManifest $modulePath
    $expected = @('Get-QwTuiInfo', 'Start-QwTuiSession', 'Stop-QwTuiSession', 'Show-QwMenu', 'Show-QwTable', 'Read-QwText', 'Confirm-QwAction', 'Show-QwMessage', 'Show-QwProgress')
    $actual = @((Get-Command -Module Qwinsta.TUI).Name)
    Assert-True (@(Compare-Object $expected $actual).Count -eq 0) 'Unexpected public API.'
    Assert-True ($manifest.Version -eq (Get-QwTuiInfo).Version) 'Version mismatch.'
}
Test-Case 'Every public function has help, parameter descriptions and an example' {
    $common = @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable')
    foreach ($command in Get-Command -Module Qwinsta.TUI) {
        $help = Get-Help $command.Name -Full
        Assert-True (-not [string]::IsNullOrWhiteSpace([string]$help.Synopsis)) ("Missing synopsis: $($command.Name)")
        Assert-True ($null -ne $help.examples) ("Missing example: $($command.Name)")
        $documented = @()
        if ($null -ne $help.PSObject.Properties['parameters'] -and
            $null -ne $help.parameters.PSObject.Properties['parameter']) {
            $documented = @($help.parameters.parameter | ForEach-Object { $_.name })
        }
        foreach ($name in $command.Parameters.Keys) {
            if ($name -notin $common) { Assert-True ($name -in $documented) ("Undocumented parameter: $($command.Name) / $name") }
        }
    }
}
Test-Case 'Menu scrolls to End and returns only selected Id' {
    $s = New-TestSession @((New-Key End), (New-Key Enter)) -Height 20
    $result = @(Show-QwMenu $s 'Меню' $items)
    Assert-True ($result.Count -eq 1 -and $result[0] -eq 'item-40') 'Wrong result or rendering leaked into pipeline.'
    $last = $s.TestState.Frames[$s.TestState.Frames.Count - 1]
    Assert-True (($last.Lines.Text -join '\n') -match 'Пункт 40') 'Last item is not visible.'
}
Test-Case 'Menu PageDown and digit shortcuts select correctly' {
    $s = New-TestSession @((New-Key PageDown), (New-Key Enter)) -Height 20
    Assert-True ((Show-QwMenu $s 'Меню' $items) -eq 'item-5') 'Wrong page step.'
    $s = New-TestSession @((New-Key D9 '9'))
    Assert-True ((Show-QwMenu $s 'Меню' $items) -eq 'item-9') 'Digit shortcut failed.'
}
Test-Case 'Escape and Ctrl+C cancel without selecting' {
    foreach ($key in @((New-Key Escape), (New-Key C ([char]3) -Control))) {
        $s = New-TestSession @($key)
        Assert-True ($null -eq (Show-QwMenu $s 'Меню' $items)) 'Cancellation selected an item.'
    }
}
Test-Case 'Empty menu ignores Enter; duplicate Id is rejected' {
    $s = New-TestSession @((New-Key Enter), (New-Key Escape))
    Assert-True ($null -eq (Show-QwMenu $s 'Меню' @())) 'Empty menu produced a selection.'
    $thrown = $false
    try { $null = Show-QwMenu $s 'Меню' @(@{ Id = 'x'; Title = 'A' }, @{ Id = 'X'; Title = 'B' }) }
    catch { $thrown = $true }
    Assert-True $thrown 'Duplicate Id was accepted.'
}
Test-Case 'Too-small console ignores Enter and recovers after resize' {
    $s = New-TestSession @((New-Key Enter), @{ Width = 80; Height = 25 }, (New-Key Enter)) -Width 40 -Height 10
    Assert-True ((Show-QwMenu $s 'Меню' $items) -eq 'item-1') 'Resize recovery failed.'
    Assert-True (-not $s.TestState.Frames[0].Layout.CanInteract) 'Small window accepted interaction.'
    Assert-True ($s.TestState.Reads -eq 3) 'Enter was accepted before resize.'
}
Test-Case 'Table search is case-insensitive and preserves row identity' {
    $keys = @((New-Key Oem2 '/'))
    $keys += @('БЕТА'.ToCharArray() | ForEach-Object { New-Key A $_ })
    $keys += @((New-Key Enter), (New-Key Enter))
    $s = New-TestSession $keys
    $result = Show-QwTable $s 'Серверы' $rows $columns
    Assert-True ([object]::ReferenceEquals($result, $rows[1])) 'Search returned a copy or wrong row.'
}
Test-Case 'Empty table ignores Enter and can be closed' {
    $s = New-TestSession @((New-Key Enter), (New-Key Escape))
    Assert-True ($null -eq (Show-QwTable $s 'Серверы' @() $columns)) 'Empty table returned a row.'
}
Test-Case 'Text editing, deletion and cursor position' {
    $s = New-TestSession @((New-Key LeftArrow), (New-Key X 'x'), (New-Key Delete), (New-Key Enter))
    Assert-True ((Read-QwText $s 'Имя' -Value 'ab') -eq 'ax') 'Text editing failed.'
}
Test-Case 'Required text and MaxLength are enforced' {
    $s = New-TestSession @((New-Key Enter), (New-Key A 'a'), (New-Key B 'b'), (New-Key Enter))
    Assert-True ((Read-QwText $s 'Имя' -MaxLength 1) -eq 'a') 'Length or required validation failed.'
    Assert-True ($s.TestState.Reads -eq 4) 'Empty input was submitted.'
}
Test-Case 'Empty string is distinct from cancel; Ctrl+U clears text' {
    $s = New-TestSession @((New-Key U ([char]21) -Control), (New-Key Enter))
    $result = Read-QwText $s 'Имя' -Value 'abc' -AllowEmpty
    Assert-True ($null -ne $result -and $result.Length -eq 0) 'Empty result became cancellation.'
    $s = New-TestSession @((New-Key Escape))
    Assert-True ($null -eq (Read-QwText $s 'Имя')) 'Cancel did not return null.'
}
Test-Case 'Secret is read-only SecureString and never appears in frames' {
    $keys = @('testsecret'.ToCharArray() | ForEach-Object { New-Key A $_ }) + @((New-Key Enter))
    $s = New-TestSession $keys
    $secret = Read-QwText $s 'Пароль' -AsSecureString
    try {
        Assert-True ($secret -is [Security.SecureString] -and $secret.Length -eq 10 -and $secret.IsReadOnly()) 'Wrong secret result.'
        foreach ($frame in $s.TestState.Frames) {
            Assert-True (($frame.Lines.Text -join '') -notmatch 'testsecret') 'Secret leaked into rendered frame.'
        }
    } finally { $secret.Dispose() }
}
Test-Case 'Confirmation defaults to No and requires explicit Yes' {
    $s = New-TestSession @((New-Key Enter))
    Assert-True (-not (Confirm-QwAction $s 'Продолжить?')) 'Default confirmation is unsafe.'
    $s = New-TestSession @((New-Key DownArrow), (New-Key Enter))
    Assert-True (Confirm-QwAction $s 'Продолжить?') 'Explicit confirmation failed.'
    $s = New-TestSession @((New-Key Escape))
    Assert-True (-not (Confirm-QwAction $s 'Продолжить?')) 'Cancel confirmed the action.'
}
Test-Case 'Message wraps and scrolls without emitting results' {
    $s = New-TestSession @((New-Key End), (New-Key Enter)) -Width 60 -Height 20
    $result = @(Show-QwMessage $s 'Сообщение' -Message @('x' * 200, 'LAST-LINE'))
    Assert-True ($result.Count -eq 0) 'Message leaked output.'
    $last = $s.TestState.Frames[$s.TestState.Frames.Count - 1]
    Assert-True (($last.Lines.Text -join '') -match 'LAST-LINE') 'Message End did not show last line.'
}
Test-Case 'Progress reports cancellation to caller' {
    $s = New-TestSession @((New-Key Escape))
    Assert-True (-not (Show-QwProgress $s 'Проверка' -PercentComplete 20)) 'Progress ignored cancellation.'
    $s = New-TestSession @((New-Key A 'a'))
    Assert-True (Show-QwProgress $s 'Проверка' -PercentComplete 100) 'Non-cancel key aborted progress.'
}
Test-Case 'Control characters cannot inject console escapes; frame fits viewport' {
    $s = New-TestSession @((New-Key Enter)) -Width 60 -Height 20
    $null = Show-QwMenu $s 'Title' @(@{ Id = 'a'; Title = "Привет`n$([char]27)[31m"; Description = 'x' * 1000 })
    foreach ($frame in $s.TestState.Frames) {
        Assert-True ($frame.Lines.Count -eq 19) 'Frame could scroll the console.'
        foreach ($line in $frame.Lines) {
            Assert-True ($line.Text.Length -le 59) 'Frame exceeds viewport width.'
            Assert-True ($line.Text -notmatch '[\x00-\x1f\x7f-\x9f]') 'Control character leaked.'
        }
    }
}
Test-Case 'Session cleanup is idempotent and closed session rejects actions' {
    $s = New-TestSession @((New-Key Enter))
    Stop-QwTuiSession $s
    Stop-QwTuiSession $s
    $thrown = $false
    try { $null = Show-QwMenu $s 'Menu' $items } catch { $thrown = $true }
    Assert-True $thrown 'Closed session accepted a new action.'
    Stop-QwTuiSession $null
}

if ($SnapshotPath) {
    $s = New-TestSession @((New-Key Escape)) -Width 100 -Height 28
    $demoItems = @(
        @{ Id = 'servers'; Title = 'Список серверов'; Description = 'Таблица, поиск, прокрутка и просмотр выбранной строки' }
        @{ Id = 'input'; Title = 'Ввод данных'; Description = 'Текстовое поле, редактирование и скрытый ввод пароля' }
        @{ Id = 'confirm'; Title = 'Подтверждение действия'; Description = 'Согласие, отказ и безопасное значение по умолчанию' }
        @{ Id = 'progress'; Title = 'Ход выполнения'; Description = 'Прогресс операции и отмена во время работы' }
        @{ Id = 'messages'; Title = 'Результаты и ошибки'; Description = 'Сообщения об успехе, справочная информация и ошибка' }
        @{ Id = 'nested'; Title = 'Вложенное меню'; Description = 'Переход между экранами и возврат назад' }
    )
    $null = Show-QwMenu $s 'Главное меню' $demoItems -Description 'Выбери элемент интерфейса, который хочешь проверить.'
    $s.TestState.Frames[0] | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $SnapshotPath -Encoding UTF8
}
Write-Host ('Passed {0} test groups in {1} / {2}' -f $script:Passed, $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)
if ($script:Failed.Count -gt 0) { throw ($script:Failed.ToArray() -join [Environment]::NewLine) }
