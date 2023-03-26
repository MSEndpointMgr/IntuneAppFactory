<#
.SYNOPSIS
    This script processes the AppsPackageList.json file in the pipeline working folder to create the app package folder and download the installer executable.

.DESCRIPTION
    This script processes the AppsPackageList.json file in the pipeline working folder to create the app package folder and download the installer executable.

.EXAMPLE
    .\Save-Installer.ps1

.NOTES
    FileName:    Save-Installer.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2022-04-04
    Updated:     2022-04-04

    Version history:
    1.0.0 - (2022-04-04) Script created
#>
Process {
    # Functions
    function Save-InstallerFile {
        param (
            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$URI,
    
            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$Path,

            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$Name
        )
        Begin {
            # Force usage of TLS 1.2 connection
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            # Disable the Invoke-WebRequest progress bar for faster downloads
            $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
        }
        Process {
            # Create path if it doesn't exist
            if (-not(Test-Path -Path $Path -PathType "Container")) {
                Write-Output -InputObject "Attempting to create provided path: $($Path)"

                try {
                    $NewPath = New-Item -Path $Path -ItemType "Container" -ErrorAction "Stop"
                }
                catch [System.Exception] {
                    throw "$($MyInvocation.MyCommand): Failed to create '$($Path)' with error message: $($_.Exception.Message)"
                }
            }

            # Download installer file
            try {
                $OutFilePath = Join-Path -Path $Path -ChildPath $Name
                Invoke-WebRequest -Uri $URI -OutFile $OutFilePath -UseBasicParsing -ErrorAction "Stop"
            }
            catch [System.Exception] {
                throw "$($MyInvocation.MyCommand): Failed to download file from '$($URI)' with error message: $($_.Exception.Message)"
            }
        }
    }

    # Intitialize variables
    $AppsPrepareListFileName = "AppsPrepareList.json"
    $AppsPrepareListFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $AppsPrepareListFileName

    # Read content from AppsDownloadList.json file created in previous stage
    $AppsDownloadListFileName = "AppsDownloadList.json"
    $AppsDownloadListFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsDownloadList") -ChildPath $AppsDownloadListFileName
    if (Test-Path -Path $AppsDownloadListFilePath) {
        # Construct list of applications to be processed in the next stage
        $AppsPrepareList = New-Object -TypeName "System.Collections.ArrayList"
        
        # Read content from AppsDownloadList.json file and convert from JSON format
        Write-Output -InputObject "Reading contents from: $($AppsDownloadListFilePath)"
        $AppsDownloadList = Get-Content -Path $AppsDownloadListFilePath | ConvertFrom-Json
        
        # Process each application in list and download installer
        foreach ($App in $AppsDownloadList) {
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Initializing"

            # Construct directory structure for current app item based on pipeline workspace directory path and app package folder name property
            $AppSetupFolderPath = Join-Path -Path $env:PIPELINE_WORKSPACE -ChildPath "Installers\$($App.AppFolderName)"

            try {
                # Save installer
                Write-Output -InputObject "Attempting to download '$($App.AppSetupFileName)' from: $($App.URI)"
                Save-InstallerFile -URI $App.URI -Path $AppSetupFolderPath -Name $App.AppSetupFileName -ErrorAction "Stop"
                Write-Output -InputObject "Successfully downloaded installer"

                # Construct new application custom object with required properties
                $AppListItem = [PSCustomObject]@{
                    "IntuneAppName" = $App.IntuneAppName
                    "AppPublisher" = $App.AppPublisher
                    "AppFolderName" = $App.AppFolderName
                    "AppSetupFileName" = $App.AppSetupFileName
                    "AppSetupFolderPath" = $AppSetupFolderPath
                    "AppSetupVersion" = $App.AppSetupVersion
                }

                # Add to list of applications to be published
                $AppsPrepareList.Add($AppListItem) | Out-Null

                # Handle current application output completed message
                Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Completed"
            }
            catch [System.Exception] {
                Write-Warning -Message "Failed to prepare download content for application: $($App.IntuneAppName)"
                Write-Warning -Message "Application will not be added to app prepare list"
            }
        }

        # Construct new json file with new applications to be published
        if ($AppsPrepareList.Count -ge 1) {
            $AppsPrepareListJSON = $AppsPrepareList | ConvertTo-Json -Depth 3
            Write-Output -InputObject "Creating '$($AppsPrepareListFileName)' in: $($AppsPrepareListFilePath)"
            Write-Output -InputObject "App list file contains the following items: $($AppsPrepareList.IntuneAppName -join ", ")"
            Out-File -InputObject $AppsPrepareListJSON -FilePath $AppsPrepareListFilePath -NoClobber -Force
        }

        # Handle next stage execution or not if no new applications are to be published
        if ($AppsDownloadList.Count -eq 0) {
            # Don't allow pipeline to continue
            Write-Output -InputObject "No new applications to be prepared, aborting pipeline"
            Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
        }
        else {
            # Allow pipeline to continue
            Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]true"
        }
    }
    else {
        Write-Output -InputObject "Failed to locate required $($AppsDownloadListFileName) file in build artifacts staging directory, aborting pipeline"
        Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
    }
}