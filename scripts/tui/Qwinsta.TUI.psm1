#requires -Version 5.1
Set-StrictMode -Version 2.0
$script:ActiveSession = $null

# Everything except the nine exported functions is an implementation detail.
# The adapter keeps terminal I/O outside the interaction logic, so tests do not
# need a real keyboard or call administrative actions.
function New-QwLine {
    param([AllowEmptyString()][string]$Text = '', [string]$Color = 'Gray', [string]$Background = 'Black')
    [pscustomobject]@{ Text = $Text; Color = $Color; Background = $Background }
}

function Get-QwProperty {
    param($Object, [string]$Name, $Default = '')
    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
    } else {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property) { return $property.Value }
    }
    return $Default
}

function ConvertTo-QwSafeText {
    param([AllowNull()][AllowEmptyString()][string]$Text, [int]$Width)
    if ($Width -le 0) { return '' }
    $value = [regex]::Replace([string]$Text, '[\x00-\x1f\x7f-\x9f]', ' ')
    if ($value.Length -le $Width) { return $value }
    if ($Width -eq 1) { return '…' }
    $value = $value.Substring(0, $Width - 1)
    if ($value.Length -gt 0 -and [char]::IsHighSurrogate($value[$value.Length - 1])) {
        $value = $value.Substring(0, $value.Length - 1)
    }
    return $value + '…'
}

function Assert-QwSession {
    param($Session)
    if ($null -eq $Session -or -not $Session.Active) { throw 'TUI: session is not active.' }
}

function Get-QwLayout {
    param([int]$Width, [int]$Height)
    $rows = [Math]::Max(1, $Height - 1)
    $contentWidth = [Math]::Max(1, [Math]::Min(100, $Width - 5))
    [pscustomobject]@{
        Width = $Width; Height = $Height; Rows = $rows
        ContentWidth = $contentWidth
        Left = [Math]::Max(0, [int][Math]::Floor(($Width - 1 - $contentWidth) / 2))
        BodyRows = [Math]::Max(1, $rows - 10)
        CanInteract = ($Width -ge 60 -and $Height -ge 20)
    }
}

function Get-QwSessionLayout {
    param($Session)
    $size = & ($Session.Adapter.Size)
    Get-QwLayout -Width $size.Width -Height $size.Height
}

function New-QwFrame {
    param($Session, $Layout, [string]$Title, [string]$Description,
        [object[]]$Body, [string]$Footer, [string]$Detail = '')
    $lines = New-Object 'System.Collections.Generic.List[object]'
    if (-not $Layout.CanInteract) {
        $lines.Add((New-QwLine 'Увеличь окно до 60 x 20' 'Yellow'))
        $lines.Add((New-QwLine 'Esc / Ctrl+C — вернуться' 'DarkGray'))
    } else {
        $lines.Add((New-QwLine))
        $brand = $Session.Application + '   /   ' + $Session.Version
        $lines.Add((New-QwLine $brand 'Green'))
        $lines.Add((New-QwLine $Session.Status 'DarkGray'))
        $lines.Add((New-QwLine))
        $lines.Add((New-QwLine $Title 'White'))
        $lines.Add((New-QwLine $Description 'DarkGray'))
        $lines.Add((New-QwLine))
        for ($i = 0; $i -lt $Layout.BodyRows; $i++) {
            if ($i -lt $Body.Count) { $lines.Add($Body[$i]) }
            else { $lines.Add((New-QwLine)) }
        }
        $lines.Add((New-QwLine))
        $lines.Add((New-QwLine $Footer 'Gray'))
        $lines.Add((New-QwLine $Detail 'DarkGray'))
    }
    $rendered = New-Object 'System.Collections.Generic.List[object]'
    for ($i = 0; $i -lt $Layout.Rows; $i++) {
        $line = New-QwLine
        if ($i -lt $lines.Count) { $line = $lines[$i] }
        $text = (' ' * $Layout.Left) + (ConvertTo-QwSafeText $line.Text $Layout.ContentWidth)
        $rendered.Add((New-QwLine $text $line.Color $line.Background))
    }
    [pscustomobject]@{ Layout = $Layout; Lines = $rendered.ToArray() }
}

function Write-QwConsoleFrame {
    param($Session, $Frame)
    $layout = $Frame.Layout
    $previous = $Session.PreviousFrame
    $changedSize = ($null -eq $previous -or $previous.Layout.Width -ne $layout.Width -or $previous.Layout.Height -ne $layout.Height)
    try {
        if ($changedSize) {
            [Console]::BackgroundColor = [ConsoleColor]::Black
            [Console]::Clear()
        }
        for ($i = 0; $i -lt $Frame.Lines.Count; $i++) {
            $line = $Frame.Lines[$i]
            if (-not $changedSize -and $i -lt $previous.Lines.Count) {
                $old = $previous.Lines[$i]
                if ($old.Text -eq $line.Text -and $old.Color -eq $line.Color -and $old.Background -eq $line.Background) { continue }
            }
            [Console]::SetCursorPosition([Console]::WindowLeft, [Console]::WindowTop + $i)
            [Console]::ForegroundColor = [ConsoleColor]$line.Color
            [Console]::BackgroundColor = [ConsoleColor]$line.Background
            [Console]::Write($line.Text.PadRight([Math]::Max(1, $layout.Width - 1)))
        }
        $Session.PreviousFrame = $Frame
    } catch [System.ArgumentOutOfRangeException] {
        # A resize between reading dimensions and drawing is retried next frame.
        $Session.PreviousFrame = $null
    }
}

function Write-QwFrame {
    param($Session, $Frame)
    & ($Session.Adapter.Render) $Session $Frame
}

function Read-QwInput {
    param($Session)
    $key = & ($Session.Adapter.Key)
    if ($null -eq $key) { & ($Session.Adapter.Pause) }
    return $key
}

function Test-QwCancelKey {
    param($Key)
    if ($null -eq $Key) { return $false }
    return ($Key.Key -eq [ConsoleKey]::Escape -or
        ($Key.Key -eq [ConsoleKey]::C -and ($Key.Modifiers -band [ConsoleModifiers]::Control)))
}

function Move-QwSelection {
    param([int]$Index, [int]$Count, [ConsoleKey]$Key, [int]$PageSize)
    if ($Count -eq 0) { return -1 }
    switch ($Key) {
        'UpArrow' { $Index-- }
        'DownArrow' { $Index++ }
        'Home' { $Index = 0 }
        'End' { $Index = $Count - 1 }
        'PageUp' { $Index -= $PageSize }
        'PageDown' { $Index += $PageSize }
    }
    return [Math]::Max(0, [Math]::Min($Count - 1, $Index))
}

function Get-QwVisibleStart {
    param([int]$Index, [int]$Start, [int]$Count, [int]$PageSize)
    if ($Index -lt $Start) { $Start = $Index }
    if ($Index -ge ($Start + $PageSize)) { $Start = $Index - $PageSize + 1 }
    return [Math]::Max(0, [Math]::Min([Math]::Max(0, $Count - $PageSize), $Start))
}

function Get-QwTuiInfo {
    <#
    .SYNOPSIS
    Returns version, experimental API level and implemented capabilities.
    .OUTPUTS
    PSCustomObject. Does not open a console session.
    .EXAMPLE
    (Get-QwTuiInfo).Capabilities -contains 'Table.Search'
    #>
    [CmdletBinding()]
    param()
    [pscustomobject]@{
        Version = [version]'0.1.0'; Api = 'experimental'; Runtime = 'Windows PowerShell 5.1'
        Capabilities = @('Menu', 'Table', 'Table.Search', 'TextInput', 'SecureInput', 'Confirm', 'Message', 'Progress')
    }
}

function Start-QwTuiSession {
    <#
    .SYNOPSIS
    Opens one interactive console session and remembers console settings.
    .PARAMETER Application
    Application name shown in the header.
    .PARAMETER Version
    Application version shown in the header.
    .PARAMETER Status
    Short application-provided status, not a system health check.
    .OUTPUTS
    Session object. Always pass it to Stop-QwTuiSession in finally.
    .EXAMPLE
    $ui = Start-QwTuiSession -Application 'My tool' -Version '0.1.0'
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Application,
        [ValidateNotNullOrEmpty()][string]$Version = '0.1.0', [string]$Status = '')
    if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1 -or $PSVersionTable.PSEdition -ne 'Desktop') {
        throw 'TUI requires Windows PowerShell 5.1 (powershell.exe).'
    }
    if ($Host.Name -ne 'ConsoleHost' -or [Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        throw 'TUI requires an interactive console. Run Start-Demo.cmd, not PowerShell ISE or a pipeline.'
    }
    if ($null -ne $script:ActiveSession) { throw 'TUI: a session is already active. Close it first.' }
    $saved = [pscustomobject]@{
        Foreground = [Console]::ForegroundColor; Background = [Console]::BackgroundColor
        CursorVisible = [Console]::CursorVisible; ControlC = [Console]::TreatControlCAsInput
    }
    $session = [pscustomobject]@{
        Application = $Application; Version = $Version; Status = $Status
        Active = $true; Saved = $saved; PreviousFrame = $null
        Adapter = [pscustomobject]@{
            Size = { [pscustomobject]@{ Width = [Console]::WindowWidth; Height = [Console]::WindowHeight } }
            Render = { param($s, $f) Write-QwConsoleFrame $s $f }
            Key = { if ([Console]::KeyAvailable) { [Console]::ReadKey($true) } }
            Pause = { Start-Sleep -Milliseconds 35 }
        }
    }
    try {
        [Console]::TreatControlCAsInput = $true
        [Console]::CursorVisible = $false
        [Console]::BackgroundColor = [ConsoleColor]::Black
        [Console]::Clear()
        $script:ActiveSession = $session
        return $session
    } catch {
        Stop-QwTuiSession $session
        throw
    }
}

function Stop-QwTuiSession {
    <#
    .SYNOPSIS
    Restores console settings and closes the session. Safe to call twice.
    .PARAMETER Session
    Session returned by Start-QwTuiSession; null is accepted for finally blocks.
    .OUTPUTS
    None.
    .EXAMPLE
    Stop-QwTuiSession -Session $ui
    #>
    [CmdletBinding()]
    param([Parameter(Position = 0)][AllowNull()]$Session)
    if ($null -eq $Session -or -not $Session.Active) { return }
    $Session.Active = $false
    try {
        if ($null -ne $Session.Saved) {
            [Console]::ForegroundColor = $Session.Saved.Foreground
            [Console]::BackgroundColor = $Session.Saved.Background
            [Console]::Clear()
        }
    } finally {
        try {
            if ($null -ne $Session.Saved) { [Console]::CursorVisible = $Session.Saved.CursorVisible }
        } finally {
            try {
                if ($null -ne $Session.Saved) { [Console]::TreatControlCAsInput = $Session.Saved.ControlC }
            } finally {
                if ([object]::ReferenceEquals($script:ActiveSession, $Session)) { $script:ActiveSession = $null }
            }
        }
    }
}

function Show-QwMenu {
    <#
    .SYNOPSIS
    Displays a menu; returns an item Id, or null on Escape / Ctrl+C.
    .PARAMETER Session
    Active TUI session.
    .PARAMETER Title
    Screen title.
    .PARAMETER Items
    Objects or dictionaries with unique nonempty Id, Title and optional Description.
    .PARAMETER Description
    One-line explanation of the screen.
    .OUTPUTS
    String Id or null. Does not execute application callbacks.
    .EXAMPLE
    $id = Show-QwMenu $ui 'Actions' @(@{ Id = 'list'; Title = 'Servers' })
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)]$Session,
        [Parameter(Mandatory, Position = 1)][string]$Title,
        [Parameter(Mandatory, Position = 2)][AllowEmptyCollection()][object[]]$Items,
        [string]$Description = '')
    Assert-QwSession $Session
    $ids = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $Items) {
        $id = [string](Get-QwProperty $item 'Id')
        if ([string]::IsNullOrWhiteSpace($id) -or -not $ids.Add($id)) { throw 'Menu Id must be nonempty and unique.' }
        if ([string]::IsNullOrWhiteSpace([string](Get-QwProperty $item 'Title'))) { throw 'Menu Title must be nonempty.' }
    }
    $index = 0; $start = 0
    while ($Session.Active) {
        $layout = Get-QwSessionLayout $Session
        $page = [Math]::Max(1, [int][Math]::Floor($layout.BodyRows / 2))
        $start = Get-QwVisibleStart $index $start $Items.Count $page
        $body = New-Object 'System.Collections.Generic.List[object]'
        if ($Items.Count -eq 0) { $body.Add((New-QwLine '  Здесь пока нет действий.' 'DarkGray')) }
        for ($i = $start; $i -lt [Math]::Min($Items.Count, $start + $page); $i++) {
            $item = $Items[$i]
            $label = '  {0}   {1}' -f ($i + 1), (Get-QwProperty $item 'Title')
            if ($i -eq $index) { $body.Add((New-QwLine $label 'Black' 'Green')) }
            else { $body.Add((New-QwLine $label 'Gray')) }
            $body.Add((New-QwLine ('      ' + (Get-QwProperty $item 'Description')) 'DarkGray'))
        }
        $detail = '{0} из {1}   ·   Home / End   PgUp / PgDn' -f ([Math]::Min($Items.Count, $index + 1)), $Items.Count
        $frame = New-QwFrame $Session $layout $Title $Description $body.ToArray() '↑↓ выбрать   Enter открыть   Esc назад   1–9 быстрый выбор' $detail
        Write-QwFrame $Session $frame
        $key = Read-QwInput $Session
        if ($null -eq $key) { continue }
        if (Test-QwCancelKey $key) { return $null }
        if (-not $layout.CanInteract) { continue }
        if ($key.Key -eq [ConsoleKey]::Enter -and $Items.Count -gt 0) { return [string](Get-QwProperty $Items[$index] 'Id') }
        $digit = [int]$key.KeyChar - [int][char]'1'
        if ($digit -ge 0 -and $digit -lt 9 -and $digit -lt $Items.Count) { return [string](Get-QwProperty $Items[$digit] 'Id') }
        $index = Move-QwSelection $index $Items.Count $key.Key $page
    }
}

function Get-QwColumnWidths {
    param([object[]]$Columns, [int]$Width)
    $available = [Math]::Max($Columns.Count * 4, $Width - 3 - 2 * ($Columns.Count - 1))
    $weights = @($Columns | ForEach-Object { [Math]::Max(1, [int](Get-QwProperty $_ 'Width' 1)) })
    $sum = ($weights | Measure-Object -Sum).Sum
    $remaining = $available - 4 * $Columns.Count
    $widths = @($weights | ForEach-Object { 4 + [int][Math]::Floor($remaining * $_ / $sum) })
    $widths[$widths.Count - 1] += $available - [int](($widths | Measure-Object -Sum).Sum)
    return $widths
}

function Format-QwTableRow {
    param($Row, [object[]]$Columns, [int[]]$Widths, [switch]$Header)
    $parts = New-Object 'System.Collections.Generic.List[string]'
    for ($i = 0; $i -lt $Columns.Count; $i++) {
        if ($Header) { $value = Get-QwProperty $Columns[$i] 'Title' }
        else { $value = Get-QwProperty $Row ([string](Get-QwProperty $Columns[$i] 'Key')) }
        $parts.Add((ConvertTo-QwSafeText ([string]$value) $Widths[$i]).PadRight($Widths[$i]))
    }
    return '   ' + ($parts.ToArray() -join '  ')
}

function Show-QwTable {
    <#
    .SYNOPSIS
    Displays a selectable, searchable table of application-provided rows.
    .PARAMETER Session
    Active TUI session.
    .PARAMETER Title
    Screen title.
    .PARAMETER Rows
    Original objects or dictionaries; the selected row is returned unchanged.
    .PARAMETER Columns
    One to six objects: Key (row property), Title and optional positive Width weight.
    .PARAMETER Description
    One-line explanation.
    .OUTPUTS
    Selected row, or null on Escape / Ctrl+C. Search uses displayed columns.
    .EXAMPLE
    $row = Show-QwTable $ui 'Servers' $servers @(@{ Key = 'Name'; Title = 'Server' })
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)]$Session,
        [Parameter(Mandatory, Position = 1)][string]$Title,
        [Parameter(Mandatory, Position = 2)][AllowEmptyCollection()][object[]]$Rows,
        [Parameter(Mandatory, Position = 3)][ValidateCount(1, 6)][object[]]$Columns,
        [string]$Description = '')
    Assert-QwSession $Session
    foreach ($column in $Columns) {
        if ([string]::IsNullOrWhiteSpace([string](Get-QwProperty $column 'Key')) -or
            [string]::IsNullOrWhiteSpace([string](Get-QwProperty $column 'Title'))) { throw 'Column Key and Title are required.' }
        if ([int](Get-QwProperty $column 'Width' 1) -le 0) { throw 'Column Width must be positive.' }
    }
    $query = ''; $index = 0; $start = 0; $filtered = @($Rows)
    while ($Session.Active) {
        $layout = Get-QwSessionLayout $Session
        $page = [Math]::Max(1, $layout.BodyRows - 2)
        $start = Get-QwVisibleStart $index $start $filtered.Count $page
        $widths = @(Get-QwColumnWidths $Columns $layout.ContentWidth)
        $body = New-Object 'System.Collections.Generic.List[object]'
        $body.Add((New-QwLine (Format-QwTableRow $null $Columns $widths -Header) 'Green'))
        $body.Add((New-QwLine))
        if ($filtered.Count -eq 0) { $body.Add((New-QwLine '   Ничего не найдено. Нажми /, чтобы изменить поиск.' 'DarkGray')) }
        for ($i = $start; $i -lt [Math]::Min($filtered.Count, $start + $page); $i++) {
            $text = Format-QwTableRow $filtered[$i] $Columns $widths
            if ($i -eq $index) { $body.Add((New-QwLine $text 'Black' 'Green')) }
            else { $body.Add((New-QwLine $text)) }
        }
        $detail = '{0} из {1}   ·   Всего: {2}' -f ([Math]::Min($filtered.Count, $index + 1)), $filtered.Count, $Rows.Count
        if ($query.Length -gt 0) { $detail += '   ·   Поиск: ' + $query }
        Write-QwFrame $Session (New-QwFrame $Session $layout $Title $Description $body.ToArray() '↑↓ выбрать   Enter подробнее   / поиск   Esc назад' $detail)
        $key = Read-QwInput $Session
        if ($null -eq $key) { continue }
        if (Test-QwCancelKey $key) { return $null }
        if (-not $layout.CanInteract) { continue }
        if ($key.Key -eq [ConsoleKey]::Enter -and $filtered.Count -gt 0) { return ,$filtered[$index] }
        if ($key.KeyChar -eq [char]'/') {
            $newQuery = Read-QwText $Session 'Поиск по таблице' -Value $query -AllowEmpty -Description 'Пустое поле покажет все строки.'
            if ($null -ne $newQuery) {
                $query = $newQuery
                $filtered = @($Rows | Where-Object {
                    $row = $_; $match = ($query.Length -eq 0)
                    foreach ($column in $Columns) {
                        $value = [string](Get-QwProperty $row ([string](Get-QwProperty $column 'Key')))
                        if ($value.IndexOf($query, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $match = $true }
                    }
                    $match
                })
                $index = 0; $start = 0
            }
        } else { $index = Move-QwSelection $index $filtered.Count $key.Key $page }
    }
}

function Read-QwText {
    <#
    .SYNOPSIS
    Edits a text field, or a masked SecureString field, with cancellation.
    .PARAMETER Session
    Active TUI session.
    .PARAMETER Title
    Field title.
    .PARAMETER Description
    One-line explanation.
    .PARAMETER Value
    Initial plain text. Cannot be combined with AsSecureString.
    .PARAMETER MaxLength
    Maximum length, from 1 to 4096; default 256.
    .PARAMETER AllowEmpty
    Allows Enter to return an empty string or SecureString.
    .PARAMETER AsSecureString
    Masks characters and returns a read-only SecureString; caller must dispose it.
    .OUTPUTS
    String or SecureString; null on Escape / Ctrl+C.
    .EXAMPLE
    $name = Read-QwText $ui 'Server name' -Value 'srv-01'
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)]$Session,
        [Parameter(Mandatory, Position = 1)][string]$Title, [string]$Description = '',
        [AllowEmptyString()][string]$Value = '', [ValidateRange(1, 4096)][int]$MaxLength = 256,
        [switch]$AllowEmpty, [switch]$AsSecureString)
    Assert-QwSession $Session
    if ($AsSecureString -and $PSBoundParameters.ContainsKey('Value')) { throw 'Secure input cannot have a plain-text initial value.' }
    if ($Value.Length -gt $MaxLength) { throw 'Initial Value exceeds MaxLength.' }
    $buffer = New-Object System.Text.StringBuilder
    [void]$buffer.Append($Value)
    $secret = $null; $returnedSecret = $false
    if ($AsSecureString) { $secret = New-Object System.Security.SecureString }
    $cursor = $Value.Length; $errorText = ''
    try {
        while ($Session.Active) {
            $layout = Get-QwSessionLayout $Session
            if ($AsSecureString) { $length = $secret.Length; $display = '*' * $length }
            else { $length = $buffer.Length; $display = $buffer.ToString() }
            $fieldWidth = [Math]::Max(1, $layout.ContentWidth - 7)
            $offset = [Math]::Max(0, $cursor - $fieldWidth + 1)
            $display = $display.Insert($cursor, '|')
            $shown = $display.Substring($offset, [Math]::Min($fieldWidth, $display.Length - $offset))
            $body = @((New-QwLine), (New-QwLine ('  > ' + $shown) 'White' 'DarkGray'),
                (New-QwLine), (New-QwLine ('  Символов: {0} / {1}' -f $length, $MaxLength) 'DarkGray'),
                (New-QwLine $errorText 'Yellow'))
            Write-QwFrame $Session (New-QwFrame $Session $layout $Title $Description $body 'Enter принять   Esc отмена   ←→ курсор   Ctrl+U очистить' '')
            $key = Read-QwInput $Session
            if ($null -eq $key) { continue }
            if (Test-QwCancelKey $key) { return $null }
            if (-not $layout.CanInteract) { continue }
            $errorText = ''
            if ($key.Key -eq [ConsoleKey]::Enter) {
                if ($length -eq 0 -and -not $AllowEmpty) { $errorText = '  Заполни поле или нажми Esc.'; continue }
                if ($AsSecureString) {
                    $secret.MakeReadOnly(); $returnedSecret = $true
                    return $secret
                }
                return $buffer.ToString()
            }
            if ($key.Key -eq [ConsoleKey]::U -and ($key.Modifiers -band [ConsoleModifiers]::Control)) {
                if ($AsSecureString) { $secret.Clear() } else { [void]$buffer.Clear() }
                $cursor = 0; continue
            }
            switch ($key.Key) {
                'LeftArrow' { $cursor = [Math]::Max(0, $cursor - 1); continue }
                'RightArrow' { $cursor = [Math]::Min($length, $cursor + 1); continue }
                'Home' { $cursor = 0; continue }
                'End' { $cursor = $length; continue }
                'Backspace' {
                    if ($cursor -gt 0) {
                        $cursor--
                        if ($AsSecureString) { $secret.RemoveAt($cursor) } else { [void]$buffer.Remove($cursor, 1) }
                    }
                    continue
                }
                'Delete' {
                    if ($cursor -lt $length) {
                        if ($AsSecureString) { $secret.RemoveAt($cursor) } else { [void]$buffer.Remove($cursor, 1) }
                    }
                    continue
                }
            }
            if (-not [char]::IsControl($key.KeyChar) -and -not ($key.Modifiers -band [ConsoleModifiers]::Control)) {
                if ($length -lt $MaxLength) {
                    if ($AsSecureString) { $secret.InsertAt($cursor, $key.KeyChar) }
                    else { [void]$buffer.Insert($cursor, $key.KeyChar) }
                    $cursor++
                } else { $errorText = '  Достигнута максимальная длина.' }
            }
        }
    } finally {
        [void]$buffer.Clear()
        if ($null -ne $secret -and -not $returnedSecret) { $secret.Dispose() }
    }
}

function Confirm-QwAction {
    <#
    .SYNOPSIS
    Asks for confirmation. No is the default; cancellation returns false.
    .PARAMETER Session
    Active TUI session.
    .PARAMETER Title
    Question describing the action.
    .PARAMETER Description
    Explains consequences. The caller performs the action after a true result.
    .OUTPUTS
    Boolean; true only after explicit confirmation.
    .EXAMPLE
    if (Confirm-QwAction $ui 'Continue?' -Description 'Test action') { Write-Verbose 'Confirmed' }
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)]$Session,
        [Parameter(Mandatory, Position = 1)][string]$Title, [string]$Description = '')
    $items = @(
        @{ Id = 'cancel'; Title = 'Нет, вернуться'; Description = 'Ничего не выполнять' }
        @{ Id = 'confirm'; Title = 'Да, продолжить'; Description = 'Подтвердить действие' }
    )
    return ((Show-QwMenu $Session $Title $items -Description $Description) -eq 'confirm')
}

function Show-QwMessage {
    <#
    .SYNOPSIS
    Shows scrollable information, success or error text without logging it.
    .PARAMETER Session
    Active TUI session.
    .PARAMETER Title
    Message title.
    .PARAMETER Message
    Lines of message text. Long lines are wrapped; newlines are accepted.
    .PARAMETER Kind
    Info (default), Success or Error; selects text color only.
    .OUTPUTS
    None. Enter, Escape or Ctrl+C closes the message.
    .EXAMPLE
    Show-QwMessage $ui 'Done' -Message 'Test completed' -Kind Success
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)]$Session,
        [Parameter(Mandatory, Position = 1)][string]$Title,
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Message,
        [ValidateSet('Info', 'Success', 'Error')][string]$Kind = 'Info')
    Assert-QwSession $Session
    $color = 'Gray'
    if ($Kind -eq 'Success') { $color = 'Green' }
    if ($Kind -eq 'Error') { $color = 'Yellow' }
    $offset = 0
    while ($Session.Active) {
        $layout = Get-QwSessionLayout $Session
        $wrapped = New-Object 'System.Collections.Generic.List[object]'
        foreach ($part in $Message) {
            foreach ($line in ($part -split '\r?\n')) {
                $text = [regex]::Replace($line, '[\x00-\x1f\x7f-\x9f]', ' ')
                if ($text.Length -eq 0) { $wrapped.Add((New-QwLine)) }
                while ($text.Length -gt 0) {
                    $count = [Math]::Min($layout.ContentWidth - 2, $text.Length)
                    $count = [Math]::Max(1, $count)
                    $wrapped.Add((New-QwLine ('  ' + $text.Substring(0, $count)) $color))
                    $text = $text.Substring($count)
                }
            }
        }
        $offset = [Math]::Max(0, [Math]::Min($offset, [Math]::Max(0, $wrapped.Count - $layout.BodyRows)))
        $body = @($wrapped.ToArray() | Select-Object -Skip $offset -First $layout.BodyRows)
        Write-QwFrame $Session (New-QwFrame $Session $layout $Title '' $body 'Enter / Esc закрыть   ↑↓ / PgUp / PgDn прокрутка' '')
        $key = Read-QwInput $Session
        if ($null -eq $key) { continue }
        if (Test-QwCancelKey $key) { return }
        if (-not $layout.CanInteract) { continue }
        if ($key.Key -eq [ConsoleKey]::Enter) { return }
        switch ($key.Key) {
            'DownArrow' { $offset++ }
            'UpArrow' { $offset-- }
            'PageDown' { $offset += $layout.BodyRows }
            'PageUp' { $offset -= $layout.BodyRows }
            'Home' { $offset = 0 }
            'End' { $offset = $wrapped.Count }
        }
    }
}

function Show-QwProgress {
    <#
    .SYNOPSIS
    Renders one progress frame and reports whether the caller should continue.
    .PARAMETER Session
    Active TUI session.
    .PARAMETER Title
    Operation title.
    .PARAMETER PercentComplete
    Integer from 0 to 100; supplied by the application.
    .PARAMETER Description
    Current stage, supplied by the application.
    .OUTPUTS
    Boolean. False means Escape / Ctrl+C requested cancellation; caller handles it.
    .EXAMPLE
    $continue = Show-QwProgress $ui 'Checking' -PercentComplete 25 -Description 'Test data'
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)]$Session,
        [Parameter(Mandatory, Position = 1)][string]$Title,
        [Parameter(Mandatory)][ValidateRange(0, 100)][int]$PercentComplete,
        [string]$Description = '')
    Assert-QwSession $Session
    $layout = Get-QwSessionLayout $Session
    $width = [Math]::Max(5, $layout.ContentWidth - 12)
    $filled = [int][Math]::Floor($width * $PercentComplete / 100)
    $bar = ('█' * $filled) + ('░' * ($width - $filled))
    $body = @((New-QwLine), (New-QwLine ('  {0}  {1,3}%' -f $bar, $PercentComplete) 'Green'))
    Write-QwFrame $Session (New-QwFrame $Session $layout $Title $Description $body 'Esc / Ctrl+C запросить отмену' '')
    $key = & ($Session.Adapter.Key)
    return (-not (Test-QwCancelKey $key))
}

Export-ModuleMember -Function Get-QwTuiInfo, Start-QwTuiSession, Stop-QwTuiSession,
    Show-QwMenu, Show-QwTable, Read-QwText, Confirm-QwAction, Show-QwMessage, Show-QwProgress
