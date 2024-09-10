<#
.SYNOPSIS
    This script is responsible for installing the required PowerShell modules for the pipeline to function.

.DESCRIPTION
    This script is responsible for installing the required PowerShell modules for the pipeline to function.

.EXAMPLE
    .\Install-Modules.ps1

.NOTES
    FileName:    Install-Modules.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2022-04-04
    Updated:     2024-03-04

    Version history:
    1.0.0 - (2022-04-04) Script created
    1.0.1 - (2024-03-04) Improved module installation logic
#>
Process {
    # Ensure package provider is installed
    $PackageProvider = Install-PackageProvider -Name "NuGet" -Force

    $Modules = @("Evergreen", "IntuneWin32App", "Az.Storage", "Az.Resources", "MSGraphRequest")
    foreach ($Module in $Modules) {
        try {
            Write-Output -InputObject "Attempting to locate module: $($Module)"
            $ModuleItem = Get-InstalledModule -Name $Module -ErrorAction "SilentlyContinue" -Verbose:$false
            if ($ModuleItem -ne $null) {
                Write-Output -InputObject "$($Module) module detected, checking for latest version"
                $LatestModuleItemVersion = (Find-Module -Name $Module -ErrorAction "Stop" -Verbose:$false).Version
                if ($LatestModuleItemVersion -ne $null) {
                    if ($LatestModuleItemVersion -gt $ModuleItem.Version) {
                        Write-Output -InputObject "Latest version of $($Module) module is not installed, attempting to install: $($LatestModuleItemVersion.ToString())"
                        $UpdateModuleInvocation = Update-Module -Name $Module -Force -ErrorAction "Stop" -Confirm:$false -Verbose:$false
                    }
                    else {
                        Write-Output -InputObject "Latest version of $($Module) is already installed: $($ModuleItem.Version.ToString())"
                    }
                }
                else {
                    Write-Output -InputObject "Could not determine if module update is required, skipping update for $($Module) module"
                }
            }
            else {
                Write-Output -InputObject "Attempting to install module: $($Module)"
                $InstallModuleInvocation = Install-Module -Name $Module -Force -AllowClobber -ErrorAction "Stop" -Confirm:$false -Verbose:$false
                Write-Output -InputObject "Module $($Module) installed successfully"
            }
        }
        catch [System.Exception] {
            Write-Warning -Message "An error occurred while attempting to install $($Module) module. Error message: $($_.Exception.Message)"
        }
    }
}