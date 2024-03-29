# ~/.config/powershell/setup.ps1
# =============================================================================
# Idempotent manual setup script to install or update Powershell dependencies.
#
# On Windows, this file will be copied over to these locations after
# running `chezmoi apply` by the script `../../run_powershell.bat.tmpl`:
#     - %USERPROFILE%\Documents\PowerShell
#     - %USERPROFILE%\Documents\WindowsPowerShell
#
# TODO: Convert this to `~/dotfiles.ps1`

# Requires that PowerShell be running with elevated privileges to be able to
# change system properties.
#Disabled Requires -RunAsAdministrator

# Create missing $IsWindows if running Powershell 5 or below.
if (!(Test-Path variable:global:IsWindows)) {
    Set-Variable "IsWindows" -Scope "Global" -Value ([System.Environment]::OSVersion.Platform -eq "Win32NT")
}

if ($null -eq (Get-Variable "ColorInfo" -ErrorAction "Ignore")) {
    Set-Variable -Name ColorInfo -Value "DarkYellow"
}
Set-Variable -Name count -Value 0 -Scope Script

function eos {
    <#
    .SYNOPSIS
        Terminates the script and counts the actions taken.
    .INPUTS
        None
    .OUTPUTS
        None
    #>
    if ($count) {
        Write-Host "Done! $count modification(s) applied." -ForegroundColor $ColorInfo
    }
    else {
        Write-Host "No modifications performed." -ForegroundColor $ColorInfo
    }
    Remove-Variable -Name count -Scope Script
}

# Ask for confirmation.
$hereString = "
    This script will perform the following non-destructive adjustements to the system (if required):
        - Install package provider NuGet
        - Install/update Powershell modules"
if ($IsWindows) {
    $hereString += "
        - Enable LongPaths support for file paths above 260 characters"
}
$hereString += [Environment]::NewLine
Write-Host $hereString -ForegroundColor $ColorInfo
$confirmation = Read-Host -Prompt "Do you want to proceed? [y/N]"
if ($confirmation -notMatch '^y(es)?$') {
    eos
    exit
}
Remove-Variable -Name ("confirmation", "hereString")

# Dependencies
# -----------------------------------------------------------------------------

# Install Winget packages
Invoke-Command -ScriptBlock { winget install JanDeDobbeleer.OhMyPosh }
if ($IsWindows) {
    if (Get-Command "winget" -ErrorAction "Ignore") {
        Write-Host "Verifying the state of Winget..." -ForegroundColor $ColorInfo
        Invoke-Command -ScriptBlock { winget --info }

        # Install any missing apps.
        $appList = Invoke-Command -ScriptBlock { winget list }
        $apps = (
            "Git.Git",
            "DEVCOM.JetBrainsMonoNerdFont",
            "twpayne.chezmoi",
            "JanDeDobbeleer.OhMyPosh",
            "nepnep.neofetch-win",
            "gerardog.gsudo",
            "junegunn.fzf",
            "BurntSushi.ripgrep.MSVC",
            "Starship.Starship"
        )
        $apps | ForEach-Object {
            if (!$appList.Contains($_)) {
                Invoke-Command -ScriptBlock { winget install -e --id  $_ }
                count++
            }
        }
    }
}


# Install NuGet package manager required to install WSL Interop and others.
# See https://www.nuget.org/
if (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction "Ignore") {
    Write-Host "NuGet already installed, skipping." -ForegroundColor $ColorInfo
}
else {
    Write-Host "Installing NuGet..." -ForegroundColor $ColorInfo
    Install-PackageProvider -Name NuGet -Force
    $count++
}

$AllowPrerelease = ($null -ne (Get-Command Install-Module -Syntax | Select-String "AllowPrerelease"))

# Install or update Powershell modules.
$modules = @{
    "WslInterop"     = @{
        Info               = "Linux commands import";
        Repo               = "https://github.com/mikebattista/PowerShell-WSL-Interop";
        Install            = $IsWindows;
        Force              = $false;
        Prerelease         = $false;
        IsCoreCLR          = $true;
        AllowClobber       = $false;
        SkipPublisherCheck = $false;
    };
    "PSReadLine"     = @{
        Info               = "command line editing";
        Repo               = "https://github.com/PowerShell/PSReadLine";
        Install            = $true;
        Force              = $true;
        Prerelease         = $true;
        IsCoreCLR          = $false;
        AllowClobber       = $false;
        SkipPublisherCheck = $true;
    };
    "z"              = @{
        Info               = "navigate file system from command history";
        Repo               = "https://github.com/badmotorfinger/z";
        Install            = $true;
        Force              = $false;
        Prerelease         = $false;
        IsCoreCLR          = $false;
        AllowClobber       = $false;
        SkipPublisherCheck = $false;
    };
    "PSFzf"          = @{
        Info               = "fuzzy searching";
        Repo               = "https://github.com/junegunn/fzf";
        Install            = $true;
        Force              = $false;
        Prerelease         = $false;
        IsCoreCLR          = $false;
        AllowClobber       = $false;
        SkipPublisherCheck = $false;
    };
    "Terminal-Icons" = @{
        Info               = "colorized file listings";
        Repo               = "https://github.com/devblackops/Terminal-Icons";
        Install            = $true;
        Force              = $false;
        Prerelease         = $false;
        IsCoreCLR          = $false;
        AllowClobber       = $false;
        SkipPublisherCheck = $false;
    };
    "FastPing"       = @{
        Info               = "speed up ping requests";
        Repo               = "https://github.com/austoonz/FastPing";
        Install            = $true;
        Force              = $false;
        Prerelease         = $false;
        IsCoreCLR          = $false;
        AllowClobber       = $false;
        SkipPublisherCheck = $false;
    };
    "ClipboardText"  = @{
        Info               = "Clipboard text support";
        Repo               = "https://github.com/mklement0/ClipboardText";
        Install            = $true;
        Force              = $false;
        Prerelease         = $false;
        IsCoreCLR          = $false;
        AllowClobber       = $false;
        SkipPublisherCheck = $false;
    };
}
($modules.GetEnumerator() | Sort-Object -Property name) | ForEach-Object {
    if (!$_.Value.Install -or (!$IsCoreCLR -and $_.Value.IsCoreCLR)) {
        continue
    }

    if (Get-Module -ListAvailable -Name $_.Name -ErrorAction "Ignore") {
        Write-Host "Checking for $($_.Name) updates ($($_.Value.Info))..." -ForegroundColor $ColorInfo
        Update-Module $_.Name
    }
    else {
        Write-Host "Installing $($_.Name) ($($_.Value.Info))..." -ForegroundColor $ColorInfo
        if ($AllowPrerelease -and $_.Value.Prerelease) {
            Install-Module $_.Name -Scope CurrentUser -Force:$_.Value.Force -SkipPublisherCheck:$_.Value.SkipPublisherCheck -AllowClobber:$_.Value.AllowClobber -AllowPrerelease:$_.Value.Prerelease
        }
        else {
            Install-Module $_.Name -Scope CurrentUser -Force:$_.Value.Force -SkipPublisherCheck:$_.Value.SkipPublisherCheck -AllowClobber:$_.Value.AllowClobber
        }
        Get-Module -ListAvailable -Name $_.Name
        $count++
    }
}


# System tweaks
# -----------------------------------------------------------------------------

# Enable LongPaths support for file paths above 260 characters.
# See https://social.msdn.microsoft.com/Forums/en-US/fc85630e-5684-4df6-ad2f-5a128de3deef
if ($IsWindows) {
    $property = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
    $name = 'LongPathsEnabled'
    if ((Get-ItemPropertyValue $property -Name $name) -ne 0) {
        Write-Host "LongPaths support already enabled, skipping." -ForegroundColor $ColorInfo
    }
    else {
        Write-Host "Enabling LongPaths support for file paths above 260 characters." -ForegroundColor $ColorInfo
        Set-ItemProperty $property -Name $name -Value 1
        $count++
    }
}

# Display termination message.
eos
