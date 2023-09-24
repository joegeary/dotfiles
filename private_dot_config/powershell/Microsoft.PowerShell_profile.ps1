# ~/.config/powershell/profile.ps1
# =============================================================================
# Executed when PowerShell starts.
#
# On Windows, this file will be copied over to these locations after
# running `chezmoi apply` by the script `../../run_powershell.bat.tmpl`:
#     - %USERPROFILE%\Documents\PowerShell
#     - %USERPROFILE%\Documents\WindowsPowerShell
#
# See https://docs.microsoft.com/en/powershell/module/microsoft.powershell.core/about/about_profiles

$ColorInfo = "DarkYellow"
$ColorWarn = "DarkRed"

# Imports
# -----------------------------------------------------------------------------

# Setup a pretty development-oriented PowerShell prompt.
$modules = (
    "Terminal-Icons",
    "FastPing",
    "PSFzf",
    "z"
)
$modules | ForEach-Object {
    if (Get-Module -ListAvailable -Name $_) {
        Import-Module $_
    }
}

# Initialize oh-my-posh
oh-my-posh --init --shell pwsh --config '~\.config\ohmyposh\ohmyposh.json' | Invoke-Expression

# Import popular commands from Linux.
# if (Get-Command Import-WslCommand -errorAction Ignore) {
#     $WslCommands = @(
#         "chmod",
#         "grep",
#         "head",
#         "less",
#         "ls",
#         "man",
#         "ssh",
#         "tail",
#         "touch"
#     )
#     $WslImportedCommands = @()
#     $WslDefaultParameterValues = @{
#         grep = "-E";
#         less = "-i";
#         ls   = "-AFhl --color=auto"
#     }

#     $WslCommands | ForEach-Object {
#         if (!(Get-Command $_ -errorAction Ignore)) {
#             wsl command -v $_ > null
#             if ($?) {
#                 $WslImportedCommands += $_
#                 Import-WslCommand "$_"
#             }
#             else {
#                 $Global:Error.RemoveAt($Global:Error.Count - 1)
#             }
#         }
#     }
# }

# Includes
# -----------------------------------------------------------------------------

# Determine user profile parent directory.
$ProfilePath = Split-Path -parent $profile

# Load functions declarations from separate configuration file.
if (Test-Path $ProfilePath/functions.ps1) {
    . $ProfilePath/functions.ps1
}

# Load alias definitions from separate configuration file.
if (Test-Path $ProfilePath/aliases.ps1) {
    . $ProfilePath/aliases.ps1
}

# Load custom code from separate configuration file.
if (Test-Path $ProfilePath/extras.ps1) {
    . $ProfilePath/extras.ps1
}

# Varia
# -----------------------------------------------------------------------------

# PowerShell parameter completion shim for the winget CLI
Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

# PowerShell parameter completion shim for the dotnet CLI
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

# Fzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'

# PowerLine
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -BellStyle None
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Point ripgrep to its configuration file.
# See https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md
$Env:RIPGREP_CONFIG_PATH = "$HOME/.ripgreprc"


# Finalization
# -----------------------------------------------------------------------------

# Run the neofetch display on open
# & "$env:USERPROFILE\scoop\shims\neofetch.cmd"

# Display if/which WSL Interop commands are imported.
if ($WslImportedCommands) {
    Write-Host "Windows Subsystem for Linux (WSL) Interop enabled." -ForegroundColor $ColorInfo
    Write-Host "WSL commands available:`n`t$($WslImportedCommands | sort)" -ForegroundColor $ColorInfo
}
