<#
.SYNOPSIS
    This script processes each onboarded application in the appList.json file to determine if the app doesn't exist or if a newer version should be published.

.DESCRIPTION
    This script processes each onboarded application in the appList.json file to determine if the app doesn't exist or if a newer version should be published.

.EXAMPLE
    .\Test-AppList.ps1

.NOTES
    FileName:    Test-AppList.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2022-03-29
    Updated:     2023-05-29

    Version history:
    1.0.0 - (2022-03-29) Script created
    1.0.1 - (2022-10-26) Added support for Azure Storage Account source
    1.0.2 - (2023-05-29) Fixed bugs mention in release notes for Intune App Factory 1.0.1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantID,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientID,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientSecret,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountAccessKey
)
Process {
    # Functions
    function Get-EvergreenAppItem {
        param (
            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$AppId,
    
            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [System.Object[]]$FilterOptions
        )
        # Construct array list to build the dynamic filter list
        $FilterList = New-Object -TypeName "System.Collections.ArrayList"
    
        # Process known filter properties and add them to array list if present on current object
        if ($FilterOptions.Architecture) {
            $FilterList.Add("`$PSItem.Architecture -eq ""$($FilterOptions.Architecture)""") | Out-Null
        }
        if ($FilterOptions.Platform) {
            $FilterList.Add("`$PSItem.Platform -eq ""$($FilterOptions.Platform)""") | Out-Null
        }
        if ($FilterOptions.Channel) {
            $FilterList.Add("`$PSItem.Channel -eq ""$($FilterOptions.Channel)""") | Out-Null
        }
        if ($FilterOptions.Type) {
            $FilterList.Add("`$PSItem.Type -eq ""$($FilterOptions.Type)""") | Out-Null
        }
        if ($FilterOptions.InstallerType) {
            $FilterList.Add("`$PSItem.InstallerType -eq ""$($FilterOptions.InstallerType)""") | Out-Null
        }
    
        # Construct script block from filter list array
        $FilterExpression = [scriptblock]::Create(($FilterList -join " -and "))
        
        # Get the evergreen app based on dynamic filter list
        $EvergreenApp = Get-EvergreenApp -Name $AppId | Where-Object -FilterScript $FilterExpression
        
        # Handle return value
        return $EvergreenApp
    }

    function Get-WindowsPackageManagerItem {
        param (
            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$AppId
        )
        process {
            # Initialize variables
            $AppResult = $true
        
            # Test if provided id exists in the winget repo
            [string[]]$WinGetArguments = @("search", "$($AppId)")
            [string[]]$WinGetStream = & "winget" $WinGetArguments | Out-String -Stream
            foreach ($RowItem in $WinGetStream) {
                if ($RowItem -eq "No package found matching input criteria.") {
                    $AppResult = $false
                }
            }
        
            if ($AppResult -eq $true) {
                # Show winget package details for provided id and capture output
                [string[]]$WinGetArguments = @("show", "$($AppId)")
                [string[]]$WinGetStream = & "winget" $WinGetArguments | Out-String -Stream
        
                # Construct custom object for return value
                $PSObject = [PSCustomObject]@{
                    "Id" = $AppId
                    "Version" = ($WinGetStream | Where-Object { $PSItem -match "^Version\:.*(?<AppVersion>(\d+(\.\d+){0,3}))$" }).Replace("Version:", "").Trim()
                    "URI" = (($WinGetStream | Where-Object { $PSItem -match "^.*(Download|Installer) Url\:.*$" }) -replace "(Download|Installer) Url:", "").Trim()
                }
        
                # Handle return value
                return $PSObject
            }
            else {
                Write-Warning -Message "No package found matching specified id: $($AppId)"
            }
        }
    }

    function Get-AzureBlobContent {
        param(
            [parameter(Mandatory = $true, HelpMessage = "Existing context of the Azure Storage Account.")]
            [ValidateNotNullOrEmpty()]
            [System.Object]$StorageAccountContext,
    
            [parameter(Mandatory = $true, HelpMessage = "Name of the Azure Storage Blob container.")]
            [ValidateNotNullOrEmpty()]
            [string]$ContainerName
        )
        try {   
            # Construct array list for return value containing file names
            $BlobList = New-Object -TypeName "System.Collections.ArrayList"
    
            try {
                # Retrieve content from storage account blob
                $StorageBlobContents = Get-AzStorageBlob -Container $ContainerName -Context $StorageAccountContext -ErrorAction Stop
                if ($StorageBlobContents -ne $null) {
                    foreach ($StorageBlobContent in $StorageBlobContents) {
                        Write-Output -InputObject "Adding content file to return list: $($StorageBlobContent.Name)"
                        $BlobList.Add($StorageBlobContent) | Out-Null
                    }
                }
    
                # Handle return value
                return $BlobList
            }
            catch [System.Exception] {
                Write-Warning -Message "Failed to retrieve storage account blob contents. Error message: $($_.Exception.Message)"
            }
        }
        catch [System.Exception] {
            Write-Warning -Message "Failed to retrieve storage account context. Error message: $($_.Exception.Message)"
        }
    }

    function Get-StorageAccountAppItem {
        param (
            [parameter(Mandatory = $true, HelpMessage = "Specify the storage account name.")]
            [ValidateNotNullOrEmpty()]
            [string]$StorageAccountName,
    
            [parameter(Mandatory = $true, HelpMessage = "Specify the storage account container name.")]
            [ValidateNotNullOrEmpty()]
            [string]$ContainerName
        )
        process {
            # Create storage account context using access key
            $StorageAccountContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountAccessKey
    
            # Retrieve all storage account blob items in container
            $BlobItems = Get-AzureBlobContent -StorageAccountContext $StorageAccountContext -ContainerName $ContainerName
            if ($BlobItems -ne $null) {
                # Read the contents of the latest.json file
                $LatestFile = $BlobItems | Where-Object { $PSItem.Name -like "latest.json" }
                if ($LatestFile -ne $null) {
                    # Construct temporary latest.json file destination
                    $LatestSetupFileDestination = Join-Path -Path $env:PIPELINE_WORKSPACE -ChildPath (Join-Path -Path "LatestFiles" -ChildPath $ContainerName)
                    if (-not(Test-Path -Path $LatestSetupFileDestination)) {
                        New-Item -Path $LatestSetupFileDestination -ItemType "Directory" | Out-Null
                    }
    
                    # Retrieve the latest.json file content and convert from JSON
                    $LatestSetupFile = Get-AzStorageBlobContent -Context $StorageAccountContext -Container $ContainerName -Blob "latest.json" -Destination $LatestSetupFileDestination -Force
                    $LatestSetupFilePath = Join-Path -Path $LatestSetupFileDestination -ChildPath "latest.json"
                    if (Test-Path -Path $LatestSetupFilePath) {
                        $LatestSetupFileContent = Get-Content -Path $LatestSetupFilePath | ConvertFrom-Json
    
                        # Get the latest modified setup file
                        $BlobItem = $BlobItems | Where-Object { (([System.IO.Path]::GetExtension($PSItem.Name)) -match ".msi|.exe|.zip") -and ($PSItem.Name -like $LatestSetupFileContent.SetupName) } | Sort-Object -Property "LastModified" -Descending | Select-Object -First 1
                        if ($BlobItem -ne $null) {
                            # Construct custom object for return value
                            $PSObject = [PSCustomObject]@{
                                "Version" = $LatestSetupFileContent.SetupVersion
                                "URI" = -join@($StorageAccountContext.BlobEndPoint, $ContainerName, "/", $BlobItem.Name)
                            }
            
                            # Handle return value
                            return $PSObject
                        }
                        else {
                            Write-Warning -Message "Could not find blob file in container with name from latest.json: $($LatestSetupFileContent.SetupName)"
                        }
                    }
                    else {
                        Write-Warning -Message "Could not locate latest.json file after attempted download from storage account container"
                    }
                }
                else {
                    Write-Warning -Message "Could not find latest.json file in container: $($ContainerName)"
                }
            }
            else {
                Write-Warning -Message "Could not find a setup file in container: $($ContainerName)"
            }
        }
    }

    # Intitialize variables
    $AppsDownloadListFileName = "AppsDownloadList.json"
    $AppsDownloadListFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $AppsDownloadListFileName

    try {
        # Retrieve authentication token using client secret from key vault
        $AuthToken = Connect-MSIntuneGraph -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -ErrorAction "Stop"

        # Construct list of applications to be processed in the next stage
        $AppsDownloadList = New-Object -TypeName "System.Collections.ArrayList"

        # Read content from AppsProcessList.json file created in previous stage
        $AppsProcessListFileName = "AppsProcessList.json"
        $AppsProcessListFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsProcessList") -ChildPath $AppsProcessListFileName

        # Foreach application in appList.json, check existence in Intunem and determine if new application / version should be published
        $AppsProcessList = Get-Content -Path $AppsProcessListFilePath -ErrorAction "Stop" | ConvertFrom-Json
        foreach ($App in $AppsProcessList) {
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Initializing"

            # Set application publish value to false, will change to true if determined in logic below that an application should be published
            $AppDownload = $false

            try {
                # Get app details based on app source
                switch ($App.AppSource) {
                    "Winget" {
                        $AppItem = Get-WindowsPackageManagerItem -AppId $App.AppId
                    }
                    "Evergreen" {
                        $AppItem = Get-EvergreenAppItem -AppId $App.AppId -FilterOptions $App.FilterOptions
                    }
                    "StorageAccount" {
                        $AppItem = Get-StorageAccountAppItem -StorageAccountName $App.StorageAccountName -ContainerName $App.StorageAccountContainerName
                    }
                }

                # Continue if app details could be retrieved from current app source
                if ($AppItem -ne $null) {
                    Write-Output -InputObject "Found app details based on '$($App.AppSource)' query:"
                    Write-Output -InputObject "Version: $($AppItem.Version)"
                    Write-Output -InputObject "URI: $($AppItem.URI)"

                    try {
                        # Attempt to locate the application in Intune
                        Write-Output -InputObject "Attempting to find application in Intune"
                        $Win32Apps = Get-IntuneWin32App -DisplayName "$($App.IntuneAppName)" -ErrorAction "Stop"
                        if ($Win32Apps -ne $null) {
                            # Handle correct output based on Win32 apps count
                            $Win32AppsCount = ($Win32Apps | Measure-Object).Count
                            switch ($Win32AppsCount) {
                                1 {
                                    Write-Output -InputObject "Found '$($Win32AppsCount)' Intune Win32 application object"
                                }
                                default {
                                    Write-Output -InputObject "Found '$($Win32AppsCount)' Intune Win32 application objects"
                                }
                            }

                            # Filter for the latest version published in Intune, if multiple applications objects was detected
                            $Win32AppLatestPublishedVersion = $Win32Apps.displayVersion | Where-Object { $PSItem -as [System.Version] } | Sort-Object { [System.Version]$PSItem } -Descending | Select-Object -First 1

                            # Version check
                            Write-Output -InputObject "Performing version comparison check to determine if a newer version of the application exists"
                            if ([System.Version]$AppItem.Version -gt [System.Version]$Win32AppLatestPublishedVersion) {
                                Write-Output -InputObject "Newer version exists for application, version details:"
                                Write-Output -InputObject "Latest version: $($AppItem.Version)"
                                Write-Output -InputObject "Published version: $($Win32AppLatestPublishedVersion)"
                                Write-Output -InputObject "Adding application to download list"
                                
                                # Mark new application version to be published
                                $AppDownload = $true
                            }
                            else {
                                Write-Output -InputObject "Latest version of application is already published"
                            }
                        }
                        else {
                            Write-Output -InputObject "Application with defined name '$($App.IntuneAppName)' was not found, adding to download list"

                            # Mark new application to be published
                            $AppDownload = $true
                        }

                        # Add current app to list if publishing is required
                        if ($AppDownload -eq $true) {
                            # Construct new application custom object with required properties
                            $AppListItem = [PSCustomObject]@{
                                "IntuneAppName" = $App.IntuneAppName
                                "AppPublisher" = $App.AppPublisher
                                "AppId" = $App.AppId
                                "AppFolderName" = $App.AppFolderName
                                "AppSetupFileName" = $App.AppSetupFileName
                                "AppSetupVersion" = $AppItem.Version
                                "URI" = $AppItem.URI
                            }

                            # Add to list of applications to be published
                            $AppsDownloadList.Add($AppListItem) | Out-Null
                        }
                    }
                    catch [System.Exception] {
                        Write-Warning -Message "Failed to retrieve Win32 app object from Intune for app: $($App.IntuneAppName)"
                    }
                }
                else {
                    Write-Warning -Message "App details could not be found from app source: $($App.AppSource)"
                }

                # Handle current application output completed message
                Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Completed"
            }
            catch [System.Exception] {
                Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
                Write-Warning -Message "Failed to retrieve app source details using method '$($App.AppSource)' for app: $($App.IntuneAppName). Error message: $($_.Exception.Message)"
                
                # Handle current application output completed message
                Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Skipped"
            }
        }

        # Construct new json file with new applications to be published
        if ($AppsDownloadList.Count -ge 1) {
            $AppsDownloadListJSON = $AppsDownloadList | ConvertTo-Json -Depth 3
            Write-Output -InputObject "Creating '$($AppsDownloadListFileName)' in: $($AppsDownloadListFilePath)"
            Write-Output -InputObject "App list file contains the following items: $($AppsDownloadList.IntuneAppName -join ", ")"
            Out-File -InputObject $AppsDownloadListJSON -FilePath $AppsDownloadListFilePath -NoClobber -Force
        }

        # Handle next stage execution or not if no new applications are to be published
        if ($AppsDownloadList.Count -eq 0) {
            # Don't allow pipeline to continue
            Write-Output -InputObject "No new applications to be published, aborting pipeline"
            Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
        }
        else {
            # Allow pipeline to continue
            Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]true"
        }
    }
    catch [System.Exception] {
        Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
        throw "$($MyInvocation.MyCommand): Failed to retrieve authentication token with error message: $($_.Exception.Message)"
    }
}