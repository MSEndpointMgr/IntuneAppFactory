# Release notes for IntuneAppFactory

## 1.1.0
- A new required property in the appList.json file called `IntuneAppNamingConvention` has been added, with the following possible values: `PublisherAppNameAppVersion`, `PublisherAppName`, `AppNameAppVersion` or `AppName`. This property controls how the application published to Intune will be named. For example, if the `IntuneAppNamingConvention` property is set to `PublisherAppName`, the name of the application in Intune would be a combination of the `AppPublisher` and the `IntuneAppName` properties, resulting in e.g. 'Igor Pavlov 7-Zip'.
- Fixed a bug in the `Get-EvergreenAppItem` function referenced in issue #18.
- Added support for downloading icons from a URL, instead of adding them to the app specific package folder. In the `App.json` file, a new property named `IconURL` can now be used to leverage this new functionality. Simply, just add the direct URL to the image file to be used as the icon for the application.
- Fixed a bug referenced in issue #14.
- Property `AppSetupFileName` in the `appList.json` file is now obsolete. The file name is now automatically determined and reflected in the preparation phase.
- Improvements added to the `Install-Modules.ps1` script file, it's now a bit faster.
- A new phase in the `publish.yml` file named `assign_apps` has been added, to handle the assignment configuration defined in the `App.json` files.
- Additional filter options for applications using Evergreen as source has been added. New supported values includes: `ImageType`, `Release`, `Edition`, `Ring` and `Language`.
- Template file `Icon.png` has been moved from the Framework folder to the Application folder in the Template folder structure.
- Function `Save-Installer` has been updated to better support redirections, that might occur for sites such as SourceForge.
- Function `Save-Installer` has been updated to handle retries when attempting to download the setup files.
- Winget supports installer type of Zip, which translates to a setup installer being compressed into an archive file. Added functionality to automatically expand the downloaded archive file and detect the proper setup file within the archive.
- Scope Tag support has been added, by using a new property named `ScopeTagName` in the App.json file under the `Information` section.
- Any string matching `###ProductCode###` specified in the `Deploy-Application.ps1` script file is automatically replaced with the Product Code value of the MSI, similar to how the Product Code can be inserted into detection rule logic or the setup app file name.
- Added a few more detection rule templates to the `App.json` template file.

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