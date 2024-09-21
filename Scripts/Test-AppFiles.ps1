<#
.SYNOPSIS
    This script validates that the required files per application package in the 'Apps' root folder are present, to ensure stages in the pipeline will execute successfully.

.DESCRIPTION
    This script validates that the required files per application package in the 'Apps' root folder are present, to ensure stages in the pipeline will execute successfully.

.EXAMPLE
    .\Test-AppFiles.ps1

.NOTES
    FileName:    Test-AppFiles.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2022-03-29
    Updated:     2024-03-27

    Version history:
    1.0.0 - (2022-03-29) Script created
    1.1.0 - (2022-11-16) Added tests for incorrect detection rule logic and detection of given detection rule script file
    1.1.1 - (2024-03-27) Added test for icon URL accessibility
#>
Process {
    # Intitialize variables
    $AppsProcessListFileName = "AppsProcessList.json"
    $AppsProcessListFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $AppsProcessListFileName
    $AppFileNames = @("App.json", "Deploy-Application.ps1")

    # Define source directory and build path to appList.json
    $SourceDirectory = $env:BUILD_SOURCESDIRECTORY
    $AppListPath = Join-Path -Path $SourceDirectory -ChildPath "appList.json"

    # Construct list of applications to be processed in the next stage
    $AppsProcessList = New-Object -TypeName "System.Collections.ArrayList"

    try {
        # Foreach application in appList.json, check for required files to allow pipeline execution
        Write-Output -InputObject "Reading content of 'appList.json'"
        $AppList = Get-Content -Path $AppListPath -ErrorAction "Stop" | ConvertFrom-Json
        foreach ($App in $AppList.Apps) {
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Initializing"

            # Define variable for app process allowed
            $AppAllowed = $true

            # Define variable for icon URL availability
            $IconURLAvailable = $false

            # Build directory path for current app and the package folder for file validation
            $AppPackageFolderPath = Join-Path -Path $SourceDirectory -ChildPath "Apps\$($App.AppFolderName)"
            if (-not(Test-Path -Path $AppPackageFolderPath)) {
                Write-Warning -Message "Could not find expected application directory path: $($AppPackageFolderPath)"
                $AppAllowed = $false
            }
            else {
                Write-Output -InputObject "Found application directory path: $($AppPackageFolderPath)"

                # Test if all required app package files are present
                foreach ($AppFileName in $AppFileNames) {
                    # Build full path to current app file
                    $AppFileNamePath = Join-Path -Path $AppPackageFolderPath -ChildPath $AppFileName

                    # Handle current app file output start message
                    Write-Output -InputObject "[File: $($AppFileName)] - Start validation"
                    
                    # Test if file is present
                    if (-not(Test-Path -Path $AppFileNamePath)) {
                        Write-Warning -Message "Could not find required file: $($AppFileNamePath)"
                        $AppAllowed = $false
                    }
                    else {
                        Write-Output -InputObject "Found required file: $($AppFileNamePath)"

                        switch ($AppFileName) {
                            "App.json" {    
                                # Read content of App.json file
                                $AppFileContent = Get-Content -Path $AppFileNamePath | ConvertFrom-Json
        
                                # Test for detection rule presence
                                Write-Output -InputObject "Testing for detection rule presence on App.json file"
                                if ($AppFileContent.DetectionRule.Count -eq 0) {
                                    Write-Warning -Message "Could not find any detection rule defined, ensure App.json contains atleast one detection rule element"
                                    $AppAllowed = $false
                                }
        
                                # Test for icon URL accessibility, if not available check for local Icon.png file in app specific folder
                                if ($AppFileContent.PackageInformation.IconURL -ne $null) {
                                    if (-not([string]::IsNullOrEmpty($AppFileContent.PackageInformation.IconURL))) {
                                        try {
                                            $IconURL = $AppFileContent.PackageInformation.IconURL
                                            Write-Output -InputObject "Testing if icon URL is accessible: $($IconURL)"
                                            $IconResponse = Invoke-WebRequest -Uri $IconURL -Method "HEAD" -UseBasicParsing -UserAgent "wget" -ErrorAction "Stop"
                                            if ($IconResponse.StatusCode -eq 200) {
                                                Write-Output -InputObject "Successfully accessed icon URL: $($IconURL)"
                                                $IconURLAvailable = $true
                                            }
                                        }
                                        catch [System.Exception] {
                                            Write-Warning -Message "Could not access icon URL: $($IconURL)"
                                            $AppAllowed = $false
                                        }
                                    }
                                    else {
                                        $IconFile = $AppFileContent.PackageInformation.IconFile
                                        Write-Warning -Message "Icon URL was defined but value was empty, checking for local $IconFile file"
                                        $IconFilePath = Join-Path -Path $AppPackageFolderPath -ChildPath $IconFile
                                        if (-not(Test-Path -Path $IconFilePath)) {
                                            Write-Warning -Message "Could not detect local $IconFile file in app folder"
                                            $AppAllowed = $false
                                        }
                                        else {
                                            Write-Output -InputObject "Found local $IconFile file in app folder"
                                        }
                                    }
                                }
                                else {
                                    $IconFile = $AppFileContent.PackageInformation.IconFile
                                    Write-Output -InputObject "Icon URL was not defined, testing for local $IconFile file"
                                    $IconFilePath = Join-Path -Path $AppPackageFolderPath -ChildPath $IconFile
                                    if (-not(Test-Path -Path $IconFilePath)) {
                                        Write-Warning -Message "Could not detect local $IconFile file in app folder"
                                        $AppAllowed = $false
                                    }
                                    else {
                                        Write-Output -InputObject "Found local $IconFile file in app folder"
                                    }
                                }
        
                                # Test for detection rule type of 'Script' and presence of script file
                                if ($AppFileContent.DetectionRule.Count -eq 1) {
                                    if ($AppFileContent.DetectionRule.Type -like "Script") {
                                        Write-Output -InputObject "Testing required files presence for detection rule type of 'Script'"
                                        $DetectionScriptFilePath = Join-Path -Path $AppPackageFolderPath -ChildPath $AppFileContent.DetectionRule.ScriptFile
                                        if (-not(Test-Path -Path $DetectionScriptFilePath)) {
                                            Write-Warning -Message "Could not detect given detection script file in app folder: $($AppFileContent.DetectionRule.ScriptFile)"
                                            $AppAllowed = $false
                                        }
                                    }
                                }
        
                                # Test for incorrect detection rule logic
                                Write-Output -InputObject "Testing for incorrect detection rule logic"
                                if ($AppFileContent.DetectionRule.Count -ge 2) {
                                    if ("Script" -in $AppFileContent.DetectionRule.Type) {
                                        Write-Warning -Message "Multiple detection rule types are defined in App.json, where at least one of them are of type 'Script', which is not a supported configuration in Intune"
                                        $AppAllowed = $false
                                    }
                                }
                            }
                            "Deploy-Application.ps1" {
                                # Not currently in use
                            }
                        }
                    }

                    # Handle current app file output completed message
                    Write-Output -InputObject "[File: $($AppFileName)] - End validation"
                }
            }

            # Add current app to list for processing if required files test was successful
            if ($AppAllowed -eq $true) {
                # Construct new application custom object with required properties
                $AppListItem = [PSCustomObject]@{
                    "IntuneAppName" = $App.IntuneAppName
                    "IntuneAppNamingConvention" = $App.IntuneAppNamingConvention
                    "AppPublisher" = $App.AppPublisher
                    "AppSource" = $App.AppSource
                    "AppId" = if (-not([string]::IsNullOrEmpty($App.AppId))) { $App.AppId } else { [string]::Empty }
                    "AppFolderName" = $App.AppFolderName
                    "FilterOptions" =  $App.FilterOptions
                    "StorageAccountName" = if (-not([string]::IsNullOrEmpty($App.StorageAccountName))) { $App.StorageAccountName } else { [string]::Empty }
                    "StorageAccountContainerName" = if (-not([string]::IsNullOrEmpty($App.StorageAccountContainerName))) { $App.StorageAccountContainerName } else { [string]::Empty }
                    "IconURL" = if ($IconURLAvailable -eq $true) { $AppFileContent.PackageInformation.IconURL } else { [string]::Empty }
                }

                # Add to list of applications to be processed
                Write-Output -InputObject "Application allowed to be processed, adding to list"
                $AppsProcessList.Add($AppListItem) | Out-Null
            }
            else {
                Write-Warning -Message "Application was not allowed to be processed, skipping"
            }

            # Handle current application output completed message
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Completed"
        }

        # Construct new json file with applications allowed to be processed
        if ($AppsProcessList.Count -ge 1) {
            $AppsProcessListJSON = $AppsProcessList | ConvertTo-Json -Depth 3
            Write-Output -InputObject "Creating '$($AppsProcessListFileName)' in: $($AppsProcessListFilePath)"
            Write-Output -InputObject "App list file contains the following items: $($AppsProcessList.IntuneAppName -join ", ")"
            Out-File -InputObject $AppsProcessListJSON -FilePath $AppsProcessListFilePath -NoClobber -Force
        }

        # Handle next stage execution or not if no applications are allowed to be processed
        if ($AppsProcessList.Count -eq 0) {
            # Don't allow pipeline to continue
            Write-Output -InputObject "No applications allowed to be processed, aborting pipeline"
            Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
        }
        else {
            # Allow pipeline to continue
            Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]true"
        }
    }
    catch [System.Exception] {
        Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
        throw "$($MyInvocation.MyCommand): Failed to access '$($AppListPath)' with error message: $($_.Exception.Message)"
    }
}