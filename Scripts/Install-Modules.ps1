# Ensure package provider is installed
$PackageProvider = Install-PackageProvider -Name "NuGet" -Force

# Install required modules
$Modules = @("Evergreen", "IntuneWin32App", "MSGraphRequest", "Az.Storage", "Az.Resources")
foreach ($Module in $Modules) {
    Write-Output -InputObject "Attempting to install the following module: $($Module)"
    Install-Module -Name $Module -Force -Confirm:$false -AllowClobber
}
