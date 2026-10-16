@{
    RootModule = 'Qwinsta.TUI.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'cd07b2cd-67ad-4baf-bccc-1e98f2ad0051'
    Author = 'QWINSTA'
    Description = 'Experimental console UI for Windows PowerShell 5.1.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop')
    FunctionsToExport = @(
        'Get-QwTuiInfo', 'Start-QwTuiSession', 'Stop-QwTuiSession',
        'Show-QwMenu', 'Show-QwTable', 'Read-QwText',
        'Confirm-QwAction', 'Show-QwMessage', 'Show-QwProgress'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
