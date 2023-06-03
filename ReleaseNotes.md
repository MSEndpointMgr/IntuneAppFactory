# Release notes for IntuneAppFactory

## 1.0.1
- New attribute named `AllowAvailableUninstall` added to App.json template file.
- Updated `New-Win32App.ps1` script to support AllowAvailableUninstall attribute from App.json manifest files.
- Fixed a variable bug in `Prepare-AppPackageFolder.ps1` script where the content of the detection.ps1 script was attempted to be read from the Scripts folder, instead of the actual script file itself.
- Added new FilterOption attribute named `InstallerType` for when using Evergreen as the AppSource in the App.json manifest file. Use this new filter option attribute when Evergreen returns both machine-level and user-level setup installers of the same application. Use the `Default` value for machine-level setup installers and `User` for user-level setup installers.
- Fixed an issue in the `Test-AppList.ps1` script that would cause an issue for when using Winget as the AppSource, where it would not detect the correct download URL, as the output shown when running the winget utility now includes Installer instead of Download as for the URL string.
- Updated the code in `Test-AppList.ps1` script that handles downloads of the setup installer from a storage account, to make use of the access key rather than assuming public access is enabled and could be used. This change now includes support for making use of a storage account that has no public access.
- Improved error handling in the `Test-AppList.ps1` script for when an error occurs for any application, instead of causing the pipeline to stop, the specific application is rather skipped and other applications that are about to be processed can proceed.

## 1.0.0
- Initial release, se README.md for documentation.