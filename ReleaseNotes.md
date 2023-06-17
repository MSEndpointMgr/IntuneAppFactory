# Release notes for IntuneAppFactory

## 1.0.2
- Switched download method used for app source type of StorageAccount from using Invoke-WebRequest to Az.Storage module in the `Save-Installer.ps1` script. This was forgotten when 1.0.1 was released, and would not work if public access to the Storage Account was disabled. This change also requires an update to the publish.yml pipeline file, where the Storage Account Key is passed in as parameter.
- Application version comparison code in `Test-AppList.ps1` is now using the functions from the MSGraphRequest module instead on relying on the IntuneWin32App module, for better error handling and stability.
- Documentation for how to setup Intune App Factory has been updated with more details around required app registration permissions necessary to now also include `DeviceManagementRBAC.ReadWrite.All`.

### Files updated with this release:
- Install-Modules.ps1
- publish.yml
- Save-Installer.ps1
- Test-AppList.ps1

## 1.0.1
- New attribute named `AllowAvailableUninstall` added to App.json template file.
- Updated `New-Win32App.ps1` script to support AllowAvailableUninstall attribute from App.json manifest files.
- Fixed a variable bug in `Prepare-AppPackageFolder.ps1` script where the content of the detection.ps1 script was attempted to be read from the Scripts folder, instead of the actual script file itself.
- Added new FilterOption attribute named `InstallerType` for when using Evergreen as the AppSource in the App.json manifest file. Use this new filter option attribute when Evergreen returns both machine-level and user-level setup installers of the same application. Use the `Default` value for machine-level setup installers and `User` for user-level setup installers.
- Fixed an issue in the `Test-AppList.ps1` script that would cause an issue for when using Winget as the AppSource, where it would not detect the correct download URL, as the output shown when running the winget utility now includes Installer instead of Download as for the URL string.
- Updated the code in `Test-AppList.ps1` script that handles downloads of the setup installer from a storage account, to make use of the access key rather than assuming public access is enabled and could be used. This change now includes support for making use of a storage account that has no public access.
- Improved error handling in the `Test-AppList.ps1` script for when an error occurs for any application, instead of causing the pipeline to stop, the specific application is rather skipped and other applications that are about to be processed can proceed.

### Files updated with this release:
- New-Win32App.ps1
- Prepare-AppPackageFolder.ps1
- Test-AppList.ps1

## 1.0.0
- Initial release, se README.md for documentation.