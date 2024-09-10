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
    Updated:     2024-03-04

    Version history:
    1.0.0 - (2022-04-04) Script created
    1.0.1 - (2023-06-14) Added support for download setup files from storage account
    1.0.2 - (2024-03-04) Added support for decompressing downloaded setup archive files and finding setup file within archive
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountAccessKey
)
Process {
    # Functions
    function Save-File {
        param (
            [parameter(Mandatory = $true, HelpMessage = "Specify the download URL.")]
            [ValidateNotNullOrEmpty()]
            [string]$URI,
    
            [parameter(Mandatory = $true, HelpMessage = "Specify the download path.")]
            [ValidateNotNullOrEmpty()]
            [string]$Path,

            [parameter(Mandatory = $true, HelpMessage = "Specify the output file name of downloaded file.")]
            [ValidateNotNullOrEmpty()]
            [string]$Name
        )
        Begin {
            # Force usage of TLS 1.2 connection
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            # Disable the Invoke-WebRequest progress bar for faster downloads
            $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue

            # Initialize download retry variables
            $RetryCount = 0
            $RetryLimit = 3
            $RetryDelay = 5
        }
        Process {
            # Create path if it doesn't exist
            if (-not(Test-Path -Path $Path -PathType "Container")) {
                Write-Output -InputObject "Attempting to create provided path: $($Path)"

                try {
                    $NewPath = New-Item -Path $Path -ItemType "Container" -ErrorAction "Stop"
                }
                catch [System.Exception] {
                    Write-Warning -Message "Failed to create '$($Path)' with error message: $($_.Exception.Message)"
                }
            }

            # Download installer file with retry logic
            do {
                try {
                    $OutFilePath = Join-Path -Path $Path -ChildPath $Name
                    Invoke-WebRequest -Uri $URI -OutFile $OutFilePath -UseBasicParsing -UserAgent "wget" -ErrorAction "Stop"
                }
                catch [System.Exception] {
                    Write-Warning -Message "Failed to download file from '$($URI)' with error message: $($_.Exception.Message)"
                    Write-Warning -Message "Retrying in $($RetryDelay) seconds"
                    Start-Sleep -Seconds $RetryDelay
                    $RetryCount++
                }
            }
            while ($RetryCount -lt $RetryLimit -and -not(Test-Path -Path $OutFilePath))
        }
    }

    function Get-StorageAccountBlobContent {
        param (
            [parameter(Mandatory = $true, HelpMessage = "Specify the storage account name.")]
            [ValidateNotNullOrEmpty()]
            [string]$StorageAccountName,
    
            [parameter(Mandatory = $true, HelpMessage = "Specify the storage account container name.")]
            [ValidateNotNullOrEmpty()]
            [string]$ContainerName,

            [parameter(Mandatory = $true, HelpMessage = "Specify the name of the blob.")]
            [ValidateNotNullOrEmpty()]
            [string]$BlobName,

            [parameter(Mandatory = $true, HelpMessage = "Specify the download path.")]
            [ValidateNotNullOrEmpty()]
            [string]$Path,

            [parameter(Mandatory = $true, HelpMessage = "Specify the output file name of downloaded file.")]
            [ValidateNotNullOrEmpty()]
            [string]$NewName
        )
        process {
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

            # Create storage account context using access key
            $StorageAccountContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountAccessKey
    
            try {
                # Retrieve the setup installer file from storage account
                Write-Output -InputObject "Downloading '$($BlobName)' in container '$($ContainerName)' from storage account: $($StorageAccountName)"
                $SetupFile = Get-AzStorageBlobContent -Context $StorageAccountContext -Container $ContainerName -Blob $BlobName -Destination $Path -Force -ErrorAction "Stop"

                # Rename downloaded file
                $SetupFilePath = Join-Path -Path $Path -ChildPath $BlobName
                if (Test-Path -Path $SetupFilePath) {
                    try {
                        Write-Output -InputObject "Renaming downloaded setup file to: $($NewName)"
                        Rename-Item -Path $SetupFilePath -NewName $NewName -Force -ErrorAction "Stop"
                    }
                    catch [System.Exception] {
                        throw "$($MyInvocation.MyCommand): Failed to rename downloaded setup file with error message: $($_.Exception.Message)"
                    }
                }
                else {
                    throw "$($MyInvocation.MyCommand): Could not find file after attempted download operation from storage account"
                }
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

            # Construct directory structure for setup installers of the current app item based on pipeline workspace directory path and app package folder name property
            $AppSetupFolderPath = Join-Path -Path $env:PIPELINE_WORKSPACE -ChildPath "Installers\$($App.AppFolderName)"

            # Construct directory structure for downloaded icons of current app item based on pipeline workspace directory path and app package folder name property
            $AppIconFolderPath = Join-Path -Path $env:PIPELINE_WORKSPACE -ChildPath "Icons\$($App.AppFolderName)"

            try {
                # Save installer based on the source type
                switch ($App.AppSource) {
                    "StorageAccount" {
                        Write-Output -InputObject "Attempting to download '$($App.BlobName)' from: $($App.URI)"
                        Get-StorageAccountBlobContent -StorageAccountName $App.StorageAccountName -ContainerName $App.StorageAccountContainerName -BlobName $App.BlobName -Path $AppSetupFolderPath -NewName $App.AppSetupFileName -ErrorAction "Stop"
                    }
                    default {
                        Write-Output -InputObject "Attempting to download '$($App.AppSetupFileName)' from: $($App.URI)"
                        Save-File -URI $App.URI -Path $AppSetupFolderPath -Name $App.AppSetupFileName -ErrorAction "Stop"
                    }
                }
                Write-Output -InputObject "Successfully downloaded installer"

                try {
                    # Save icon file if provided
                    if ($App.IconURI) {
                        Write-Output -InputObject "Attempting to download icon file from: $($App.IconURI)"
                        Save-File -URI $App.IconURI -Path $AppIconFolderPath -Name "Icon.png" -ErrorAction "Stop"
                        Write-Output -InputObject "Successfully downloaded icon file"
                    }

                    try {
                        # Construct path to downloaded setup file
                        $AppSetupFilePath = Join-Path -Path $AppSetupFolderPath -ChildPath $App.AppSetupFileName
    
                        # Expand compressed installer file if required
                        Write-Output -InputObject "Checking if downloaded file is a zip file"
                        if (($App.FileExtension -like "zip") -or ([System.IO.Path]::GetExtension($AppSetupFilePath).TrimStart(".") -like "zip")) {
                            Write-Output -InputObject "Attempting to expand downloaded zip file"
                            Expand-Archive -Path $AppSetupFilePath -DestinationPath $AppSetupFolderPath -ErrorAction "Stop"
                            Write-Output -InputObject "Successfully expanded zip file"
    
                            try {
                                # Find applicable setup file name based on known extensions within extracted archive
                                $AppSetupFileName = Get-ChildItem -Path $AppSetupFolderPath -File | Where-Object { $PSItem.Extension -like ".exe" -or $PSItem.Extension -like ".msi" } | Select-Object -ExpandProperty "Name"
                            }
                            catch [System.Exception] {
                                Write-Warning -Message "Failed to find valid setup file within expanded zip file with error message: $($_.Exception.Message)"
                            }
    
                            try {
                                # Remove downloaded zip file after successful expansion
                                Write-Output -InputObject "Removing downloaded zip file"
                                Remove-Item -Path $AppSetupFilePath -Force -ErrorAction "Stop" -Confirm:$false
                            }
                            catch [System.Exception] {
                                Write-Warning -Message "Failed to remove downloaded zip file with error message: $($_.Exception.Message)"
                            }
                        }
                        else {
                            Write-Output -InputObject "No need to expand downloaded file, file extension is not a zip file"
    
                            # Handle setup file name variable
                            $AppSetupFileName = $App.AppSetupFileName
                        }
                    }
                    catch [System.Exception] {
                        Write-Warning -Message "Failed to expand downloaded zip file with error message: $($_.Exception.Message)"
                    }
    
                    # Validate setup installer was successfully downloaded
                    $AppSetupFilePath = Join-Path -Path $AppSetupFolderPath -ChildPath $AppSetupFileName
                    if (Test-Path -Path $AppSetupFilePath) {
                        # Construct new application custom object with required properties
                        $AppListItem = [PSCustomObject]@{
                            "IntuneAppName" = $App.IntuneAppName
                            "IntuneAppNamingConvention" = $App.IntuneAppNamingConvention
                            "AppPublisher" = $App.AppPublisher
                            "AppFolderName" = $App.AppFolderName
                            "AppSetupFileName" = $AppSetupFileName
                            "AppSetupFolderPath" = $AppSetupFolderPath
                            "AppSetupVersion" = $App.AppSetupVersion
                            "IconURL" = $App.IconURL
                        }
    
                        # Add to list of applications to be published
                        $AppsPrepareList.Add($AppListItem) | Out-Null
                    }
                    else {
                        Write-Warning -Message "Could not detect downloaded setup installer"
                        Write-Warning -Message "Application will not be added to app prepare list"
                    }
    
                    # Handle current application output completed message
                    Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Completed"
                }
                catch [System.Exception] {
                    Write-Warning -Message "Failed to download icon file with error message: $($_.Exception.Message)"
                }
            }
            catch [System.Exception] {
                Write-Warning -Message "Failed to download content for application: $($App.IntuneAppName)"
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
        if ($AppsPrepareList.Count -eq 0) {
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