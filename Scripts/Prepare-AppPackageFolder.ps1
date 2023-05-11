<#
.SYNOPSIS
    This script processes the AppsPrepareList.json file in the pipeline working folder to perform the following tasks:
    - Create app package folder to contain source files to be published to Intune
    - Copy the contents of the Framework root folder to package folder
    - Copy app-specific App.json to package folder
    - Copy app-specific Deploy-Application.ps1 to package folder
    - Copy app-specific installer to Source folder in package folder 

.DESCRIPTION
    This script processes the AppsPrepareList.json file in the pipeline working folder to prepare them to be published to Intune.

.EXAMPLE
    .\Prepare-AppPackageFolder.ps1

.NOTES
    FileName:    Prepare-AppPackageFolder.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2022-04-04
    Updated:     2023-05-11

    Version history:
    1.0.0 - (2022-04-04) Script created
    1.0.1 - (2023-05-11) Fixed a bug where Script detection rule was attempting to read the folder instead of the file when amended version info into the script file
#>
Process {
    # Intitialize variables
    $AppsPublishListFileName = "AppsPublishList.json"
    $AppsPublishListFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $AppsPublishListFileName
    $AppsPublishRootPath = Join-Path -Path $env:PIPELINE_WORKSPACE -ChildPath "Publish"
    $SourceDirectory = $env:BUILD_SOURCESDIRECTORY
    $FrameworkPath = Join-Path -Path $SourceDirectory -ChildPath "Templates\Framework"

    # Read content from AppsPrepareList.json file created in previous stage and process each application
    $AppsPrepareListFileName = "AppsPrepareList.json"
    $AppsPrepareListFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsPrepareList") -ChildPath $AppsPrepareListFileName
    if (Test-Path -Path $AppsPrepareListFilePath) {
        # Construct list of applications to be processed in the next stage
        $AppsPublishList = New-Object -TypeName "System.Collections.ArrayList"
        
        # Read content from AppsPrepareList.json file and convert from JSON format
        Write-Output -InputObject "Reading contents from: $($AppsPrepareListFilePath)"
        $AppsPrepareList = Get-Content -Path $AppsPrepareListFilePath | ConvertFrom-Json

        # Process each application in list
        foreach ($App in $AppsPrepareList) {
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Initializing"

            # Attempt to create app package folder in publish root folder
            $AppPublishFolderPath = Join-Path -Path $AppsPublishRootPath -ChildPath $App.AppFolderName
            if (-not(Test-Path -Path $AppPublishFolderPath)) {
                Write-Output -InputObject "Attempting to create app package folder in publish root"
                Write-Output -InputObject "App package folder path: $($AppPublishFolderPath)"
                New-Item -Path $AppPublishFolderPath -ItemType "Directory" -Force -Confirm:$false | Out-Null
            }

            # Copy Framework folder to app package folder in publish root
            Write-Output -InputObject "Copying Framework folder contents to app package folder"
            Copy-Item -Path "$($FrameworkPath)\*" -Destination $AppPublishFolderPath -Recurse -Force -Confirm:$false

            # Create Files folder in Source folder if not found
            $AppsPublishSourceFilesPath = Join-Path -Path $AppsPublishRootPath -ChildPath "$($App.AppFolderName)\Source\Files"
            if (-not(Test-Path -Path $AppsPublishSourceFilesPath)) {
                New-Item -Path $AppsPublishSourceFilesPath -ItemType "Directory" -Force -Confirm:$false | Out-Null
            }

            # Copy app specific installer from downloaded app package path to publish folder
            $AppInstallerPath = Join-Path -Path $App.AppSetupFolderPath -ChildPath $App.AppSetupFileName
            $AppInstallerDestinationPath = Join-Path -Path $AppPublishFolderPath -ChildPath "Source\Files\$($App.AppSetupFileName)"
            Write-Output -InputObject "Copying installer file from app package download folder"
            Write-Output -InputObject "Source path: $($AppInstallerPath)"
            Write-Output -InputObject "Destination path: $($AppInstallerDestinationPath)"
            Copy-Item -Path $AppInstallerPath -Destination $AppInstallerDestinationPath -Force -Confirm:$false

            # Copy all required app specific files from app package folder in Apps root folder to publish folder
            $AppPackageFolderPath = Join-Path -Path $SourceDirectory -ChildPath "Apps\$($App.AppFolderName)"
            $AppFileNames = $AppFileNames = @("App.json", "Deploy-Application.ps1", "Icon.png")
            foreach ($AppFileName in $AppFileNames) {
                Write-Output -InputObject "[FILE:$($AppFileName)] - Processing"

                # Define path for current app specific file within app package folder in Apps root folder
                $AppFilePath = Join-Path -Path $AppPackageFolderPath -ChildPath $AppFileName

                # Define default destination path including file name for current processed item
                $AppFileDestinationPath = Join-Path -Path $AppPublishFolderPath -ChildPath $AppFileName

                # Specific actions required for given app specific file
                switch ($AppFileName) {
                    "Deploy-Application.ps1" {
                        # Read file and update hardcoded variables with specific variable value from app details
                        $AppFileContent = Get-Content -Path $AppFilePath
                        Write-Output -InputObject "Reading content of app specific file $($AppFileName)"
                        Write-Output -InputObject "File path: $($AppFilePath)"
                        Write-Output -InputObject "Setting Intune app name to: $($App.IntuneAppName)"
                        $AppFileContent = $AppFileContent -replace "###INTUNEAPPNAME###", $App.IntuneAppName
                        Write-Output -InputObject "Setting app publisher to: $($App.AppPublisher)"
                        $AppFileContent = $AppFileContent -replace "###APPPUBLISHER###", $App.AppPublisher
                        Write-Output -InputObject "Setting app version to: $($App.AppSetupVersion)"
                        $AppFileContent = $AppFileContent -replace "###VERSION###", $App.AppSetupVersion
                        Write-Output -InputObject "Setting timestamp to: $((Get-Date).ToShortDateString())"
                        $AppFileContent = $AppFileContent -replace "###DATETIME###", (Get-Date).ToShortDateString()
                        Write-Output -InputObject "Setting setup file name to: $($App.AppSetupFileName)"
                        $AppFileContent = $AppFileContent -replace "###SETUPFILENAME###", $($App.AppSetupFileName)
                        $AppsPublishSourcePath = Join-Path -Path $AppsPublishRootPath -ChildPath "$($App.AppFolderName)\Source"
                        $AppDestinationFilePath = Join-Path -Path $AppsPublishSourcePath -ChildPath $AppFileName
                        Write-Output -InputObject "Creating '$($AppFileName)' in: $($AppDestinationFilePath)"
                        Out-File -InputObject $AppFileContent -FilePath $AppDestinationFilePath -Encoding "utf8" -Force -Confirm:$false
                    }
                    "App.json" {
                        # Read file App.json content
                        Write-Output -InputObject "Reading content of app specific file $($AppFileName)"
                        Write-Output -InputObject "File path: $($AppFilePath)"
                        $AppFileContent = Get-Content -Path $AppFilePath | ConvertFrom-Json
                        
                        # Update version specific property values
                        $AppFileContent.Information.DisplayName = $App.IntuneAppName
                        $AppFileContent.Information.AppVersion = $App.AppSetupVersion
                        $AppFileContent.Information.Publisher = $App.AppPublisher
                        foreach ($DetectionRuleItem in $AppFileContent.DetectionRule) {
                            switch ($DetectionRuleItem.Type) {
                                "MSI" {
                                    # Retrieve MSI meta data from setup file
                                    Write-Output -InputObject "Retrieving MSI meta data"
                                    $ProductCode = Get-MSIMetaData -Path $AppInstallerPath -Property "ProductCode"
                                    $ProductCode = ($ProductCode -as [string]).Trim()
                                    Write-Output -InputObject "MSI meta data value for ProductCode: $($ProductCode)"
                                    $ProductVersion = Get-MSIMetaData -Path $AppInstallerPath -Property "ProductVersion"
                                    $ProductVersion = ($ProductVersion -as [string]).Trim()
                                    Write-Output -InputObject "MSI meta data value for ProductVersion: $($ProductVersion)"

                                    # Update App.json detection rule with MSI meta data for ProductCode
                                    if ($ProductCode -ne $null) {
                                        Write-Output -InputObject "Setting DetectionRule.ProductCode to: $($ProductCode)"
                                        $DetectionRuleItem.ProductCode = $ProductCode
                                    }
                                    else {
                                        Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
                                        throw "$($MyInvocation.MyCommand): Failed to retrieve MSI meta data value for ProductCode"
                                    }

                                    # Update App.json detection rule with MSI meta data for ProductVersion
                                    if ($ProductVersion -ne $null) {
                                        Write-Output -InputObject "Setting DetectionRule.ProductVersion to: $($ProductVersion)"
                                        $DetectionRuleItem.ProductVersion = $ProductVersion
                                    }
                                    else {
                                        Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
                                        throw "$($MyInvocation.MyCommand): Failed to retrieve MSI meta data value for ProductVersion"
                                    }
                                }
                                "Registry" {
                                    if ($DetectionRuleItem.KeyPath -match "(\#{3})PRODUCTCODE(\#{3})") {
                                        Write-Output -InputObject "ProductCode update required in app specific file $($AppFileName)"
                                        $ProductCode = Get-MSIMetaData -Path $AppInstallerPath -Property "ProductCode"
                                        if ($ProductCode -ne $null) {
                                            Write-Output -InputObject "Updating hardcoded variable with new ProductCode value: $(($ProductCode -as [string]).Trim())"
                                            $DetectionRuleItem.KeyPath = $DetectionRuleItem.KeyPath -replace "###PRODUCTCODE###", ($ProductCode -as [string]).Trim()
                                        }
                                        else {
                                            Write-Output -InputObject "ProductCode could not be determined, hardcoded variable was not updated"
                                        }
                                    }
                                    switch ($DetectionRuleItem.DetectionMethod) {
                                        "VersionComparison" {
                                            $DetectionRuleItem.Value = $App.AppSetupVersion
                                        }
                                        "StringComparison" {
                                            $DetectionRuleItem.Value = $App.AppSetupVersion
                                        }
                                    }
                                }
                                "File" {
                                    switch ($DetectionRuleItem.DetectionMethod) {
                                        "Version" {
                                            $DetectionRuleItem.VersionValue = $App.AppSetupVersion
                                        }
                                    }
                                }
                                "Script" {
                                    # Create the Scripts folder in the app package folder in the publish root folder
                                    $AppPublishScriptsFolderPath = Join-Path -Path $AppPublishFolderPath -ChildPath "Scripts"
                                    if (-not(Test-Path -Path $AppPublishScriptsFolderPath)) {
                                        New-Item -Path $AppPublishScriptsFolderPath -ItemType "Directory" -Force -Confirm:$false | Out-Null
                                    }

                                    # Construct the detection script file path from the app package folder and destination path for copy operation
                                    $AppDetectionScriptFile = Join-Path -Path $AppPackageFolderPath -ChildPath $AppFileContent.DetectionRule.ScriptFile
                                    $AppDetectionScriptFileDestinationPath = Join-Path -Path $AppPublishScriptsFolderPath -ChildPath $AppFileContent.DetectionRule.ScriptFile

                                    # Copy detection script file to Script folder in app package folder in the publish root folder
                                    Write-Output -InputObject "Copying detection script file $($AppFileContent.DetectionRule.ScriptFile) to app package folder in publish root"
                                    Write-Output -InputObject "File path: $($AppDetectionScriptFile)"
                                    Write-Output -InputObject "Destination path: $($AppDetectionScriptFileDestinationPath)"
                                    Copy-Item -Path $AppDetectionScriptFile -Destination $AppDetectionScriptFileDestinationPath -Force -Confirm:$false

                                    # Read detection script file and update hardcoded variables with specific variable value from app details
                                    Write-Output -InputObject "Reading content of detection script file $($AppFileContent.DetectionRule.ScriptFile)"
                                    Write-Output -InputObject "File path: $($AppPublishScriptsFolderPath)"
                                    $AppDetectionScriptFileContent = Get-Content -Path $AppDetectionScriptFileDestinationPath
                                    Write-Output -InputObject "Setting detection version to: $($App.AppSetupVersion)"
                                    $AppDetectionScriptFileContent = $AppDetectionScriptFileContent -replace "###VERSION###", $App.AppSetupVersion

                                    # Update detection script file in app package folder in publish folder root
                                    Write-Output -InputObject "Updating '$($AppFileContent.DetectionRule.ScriptFile)' in: $($AppPublishScriptsFolderPath)"
                                    Out-File -InputObject $AppDetectionScriptFileContent -FilePath $AppDetectionScriptFileDestinationPath -Encoding "utf8" -Force -Confirm:$false
                                }
                            }
                        }

                        # Save changes made to App.json in app package folder in publish root folder
                        $AppFileDestinationPath = Join-Path -Path $AppPublishFolderPath -ChildPath $AppFileName
                        Write-Output -InputObject "Creating '$($AppFileName)' in: $($AppFileDestinationPath)"
                        Out-File -InputObject ($AppFileContent | ConvertTo-Json) -FilePath $AppFileDestinationPath -Encoding "utf8" -Force -Confirm:$false
                    }
                    "Icon.png" {
                        # Copy file to app package folder in publish root folder
                        Write-Output -InputObject "Copying app specific file $($AppFileName) to app package folder in publish root"
                        Write-Output -InputObject "File path: $($AppFilePath)"
                        Write-Output -InputObject "Destination path: $($AppFileDestinationPath)"
                        Copy-Item -Path $AppFilePath -Destination $AppFileDestinationPath -Force -Confirm:$false
                    }
                }

                Write-Output -InputObject "[FILE:$($AppFileName)] - Completed"
            }

            # Create Package and Source folders in the app package folder root
            $AppRootFolderPackagePath = Join-Path -Path $AppPublishFolderPath -ChildPath "Package"
            if (-not(Test-Path -Path $AppRootFolderPackagePath)) {
                Write-Output -InputObject "Creating Package folder for .intunewin file location"
                New-Item -Path $AppRootFolderPackagePath -ItemType "Directory" -Force -Confirm:$false | Out-Null
            }

            # Construct new application custom object with required properties
            $AppListItem = [PSCustomObject]@{
                "IntuneAppName" = $App.IntuneAppName
                "AppSetupFileName" = $App.AppSetupFileName
                "AppSetupVersion" = $App.AppSetupVersion
                "AppPublishFolderPath" = $AppPublishFolderPath
            }

            # Add to list of applications to be published
            $AppsPublishList.Add($AppListItem) | Out-Null

            # Handle current application output completed message
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Completed"
        }

        # Construct new json file with new applications to be published
        if ($AppsPublishList.Count -ge 1) {
            $AppsPublishListJSON = $AppsPublishList | ConvertTo-Json -Depth 3
            Write-Output -InputObject "Creating '$($AppsPublishListFileName)' in: $($AppsPublishListFilePath)"
            Write-Output -InputObject "App list file contains the following items: $($AppsPublishList.IntuneAppName -join ", ")"
            Out-File -InputObject $AppsPublishListJSON -FilePath $AppsPublishListFilePath -NoClobber -Force
        }

        # Handle next stage execution or not if no new applications are to be published
        if ($AppsPublishList.Count -eq 0) {
            # Don't allow pipeline to continue
            Write-Output -InputObject "No new applications to be published, aborting pipeline"
            Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
        }
        else {
            # Allow pipeline to continue
            Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]true"
        }
    }
    else {
        Write-Output -InputObject "Failed to locate required $($AppsPrepareListFileName) file in build artifacts staging directory, aborting pipeline"
        Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
    }
}