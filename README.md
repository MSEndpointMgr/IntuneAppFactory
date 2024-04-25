# IntuneAppFactory
IntuneAppFactory is a set of PowerShell scripts used in an Azure DevOps Pipeline to detect, download, package and publish onboarded applications as a Win32 application to Intune, to ensure the latest version of onboarded applications are available in Intune.

Currently IntuneAppFactory supports the following repositories:
- Winget
- Evergreen
- In-house applications can also be deployed and intalled via the Storage Account created for the Pipeline Agent.

If you're new to this, have a look at the [CreateNewApp file!](CreateNewApp.md) 