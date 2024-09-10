<#
.SYNOPSIS
    This script processes the AppsPublishList.json manifest file and creates a new Win32 application for each application that should be published.

.DESCRIPTION
    This script processes the AppsPublishList.json manifest file and creates a new Win32 application for each application that should be published.

.EXAMPLE
    .\New-Win32App.ps1

.NOTES
    FileName:    New-Win32App.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2022-04-20
    Updated:     2024-03-04

    Version history:
    1.0.0 - (2020-09-26) Script created
    1.0.1 - (2023-05-29) Fixed bugs mention in release notes for Intune App Factory 1.0.1
    1.0.2 - (2024-03-04) Added support for ScopeTagName parameter, added Assignment handling
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
    [string]$WorkspaceID,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SharedKey
)
Process {
    # Functions
    function Send-LogAnalyticsPayload {
        <#
        .SYNOPSIS
            Send data to Log Analytics Collector API through a web request.
            
        .DESCRIPTION
            Send data to Log Analytics Collector API through a web request.
            
        .PARAMETER WorkspaceID
            Specify the Log Analytics workspace ID.
    
        .PARAMETER SharedKey
            Specify either the Primary or Secondary Key for the Log Analytics workspace.
    
        .PARAMETER Body
            Specify a JSON representation of the data objects.
    
        .PARAMETER LogType
            Specify the name of the custom log in the Log Analytics workspace.
    
        .PARAMETER TimeGenerated
            Specify a custom date time string to be used as TimeGenerated value instead of the default.
            
        .NOTES
            Author:      Nickolaj Andersen
            Contact:     @NickolajA
            Created:     2021-04-20
            Updated:     2021-04-20
    
            Version history:
            1.0.0 - (2021-04-20) Function created
        #>  
        param(
            [parameter(Mandatory = $true, HelpMessage = "Specify the Log Analytics workspace ID.")]
            [ValidateNotNullOrEmpty()]
            [string]$WorkspaceID,
    
            [parameter(Mandatory = $true, HelpMessage = "Specify either the Primary or Secondary Key for the Log Analytics workspace.")]
            [ValidateNotNullOrEmpty()]
            [string]$SharedKey,
    
            [parameter(Mandatory = $true, HelpMessage = "Specify a JSON representation of the data objects.")]
            [ValidateNotNullOrEmpty()]
            [string]$Body,
    
            [parameter(Mandatory = $true, HelpMessage = "Specify the name of the custom log in the Log Analytics workspace.")]
            [ValidateNotNullOrEmpty()]
            [string]$LogType,
    
            [parameter(Mandatory = $false, HelpMessage = "Specify a custom date time string to be used as TimeGenerated value instead of the default.")]
            [ValidateNotNullOrEmpty()]
            [string]$TimeGenerated = [string]::Empty
        )
        Process {
            # Construct header string with RFC1123 date format for authorization
            $RFC1123Date = [DateTime]::UtcNow.ToString("r")
            $Header = -join@("x-ms-date:", $RFC1123Date)
    
            # Convert authorization string to bytes
            $ComputeHashBytes = [Text.Encoding]::UTF8.GetBytes(-join@("POST", "`n", $Body.Length, "`n", "application/json", "`n", $Header, "`n", "/api/logs"))
    
            # Construct cryptographic SHA256 object
            $SHA256 = New-Object -TypeName "System.Security.Cryptography.HMACSHA256"
            $SHA256.Key = [System.Convert]::FromBase64String($SharedKey)
    
            # Get encoded hash by calculated hash from bytes
            $EncodedHash = [System.Convert]::ToBase64String($SHA256.ComputeHash($ComputeHashBytes))
    
            # Construct authorization string
            $Authorization = 'SharedKey {0}:{1}' -f $WorkspaceID, $EncodedHash
    
            # Construct Uri for API call
            $Uri = -join@("https://", $WorkspaceID, ".ods.opinsights.azure.com/", "api/logs", "?api-version=2016-04-01")
    
            # Construct headers table
            $HeaderTable = @{
                "Authorization" = $Authorization
                "Log-Type" = $LogType
                "x-ms-date" = $RFC1123Date
                "time-generated-field" = $TimeGenerated
            }
    
            # Invoke web request
            $WebResponse = Invoke-WebRequest -Uri $Uri -Method "POST" -ContentType "application/json" -Headers $HeaderTable -Body $Body -UseBasicParsing
    
            $ReturnValue = [PSCustomObject]@{
                StatusCode = $WebResponse.StatusCode
                PayloadSizeKB = ($Body.Length/1024).ToString("#.#")
            }
            
            # Handle return value
            return $ReturnValue
        }
    }

    # Construct path for AppsAssignList.json
    $AppsAssignListFileName = "AppsAssignList.json"
    $AppsAssignListFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $AppsAssignListFileName

    # Construct list of applications to be assigned in the next stage
    $AppsAssignList = New-Object -TypeName "System.Collections.ArrayList"

    # Construct path for AppsPublishList.json file created in previous stage
    $AppsPublishListFileName = "AppsPublishList.json"
    $AppsPublishListFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsPublishList") -ChildPath $AppsPublishListFileName

    # Retrieve authentication token using client secret from key vault
    $AuthToken = Connect-MSIntuneGraph -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -ErrorAction "Stop"

    if (Test-Path -Path $AppsPublishListFilePath) {
        # Read content from AppsPublishList.json file and convert from JSON format
        Write-Output -InputObject "Reading contents from: $($AppsPublishListFilePath)"
        $AppsPublishList = Get-Content -Path $AppsPublishListFilePath | ConvertFrom-Json

        # Process each application in list and publish them to Intune
        foreach ($App in $AppsPublishList) {
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Initializing"

            # Read app specific App.json manifest and convert from JSON
            $AppDataFile = Join-Path -Path $App.AppPublishFolderPath -ChildPath "App.json"
            $AppData = Get-Content -Path $AppDataFile | ConvertFrom-Json

            # Required packaging variables
            $SourceFolder = Join-Path -Path $App.AppPublishFolderPath -ChildPath $AppData.PackageInformation.SourceFolder
            Write-Output -InputObject "Using Source folder path: $($SourceFolder)"
            $OutputFolder = Join-Path -Path $App.AppPublishFolderPath -ChildPath $AppData.PackageInformation.OutputFolder
            Write-Output -InputObject "Using Output folder path: $($OutputFolder)"
            $ScriptsFolder = Join-Path -Path $App.AppPublishFolderPath -ChildPath "Scripts"
            Write-Output -InputObject "Using Scripts folder path: $($ScriptsFolder)"
            $AppIconFile = Join-Path -Path $App.AppPublishFolderPath -ChildPath $App.IconFileName
            Write-Output -InputObject "Using icon file path: $($AppIconFile)"

            # Create required .intunewin package from source folder
            Write-Output -InputObject "Creating .intunewin package file from source folder"
            $IntuneAppPackage = New-IntuneWin32AppPackage -SourceFolder $SourceFolder -SetupFile $AppData.PackageInformation.SetupFile -OutputFolder $OutputFolder

            # Create default requirement rule
            Write-Output -InputObject "Creating default requirement rule"
            $RequirementRule = New-IntuneWin32AppRequirementRule -Architecture $AppData.RequirementRule.Architecture -MinimumSupportedWindowsRelease $AppData.RequirementRule.MinimumSupportedWindowsRelease

            # Create additional custom requirement rules
            Write-Output -InputObject "Creating additional custom requirement rules"
            $CustomRequirementRuleCount = ($AppData.CustomRequirementRule | Measure-Object).Count
            if ($CustomRequirementRuleCount -ge 1) {
                $RequirementRules = New-Object -TypeName "System.Collections.ArrayList"
                foreach ($RequirementRuleItem in $AppData.CustomRequirementRule) {
                    switch ($RequirementRuleItem.Type) {
                        "File" {
                            switch ($RequirementRuleItem.DetectionMethod) {
                                "Existence" {
                                    # Create a custom file based requirement rule
                                    $RequirementRuleArgs = @{
                                        "Existence" = $true
                                        "Path" = $RequirementRuleItem.Path
                                        "FileOrFolder" = $RequirementRuleItem.FileOrFolder
                                        "DetectionType" = $RequirementRuleItem.DetectionType
                                        "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                                    }
                                }
                                "DateModified" {
                                    # Create a custom file based requirement rule
                                    $RequirementRuleArgs = @{
                                        "DateModified" = $true
                                        "Path" = $RequirementRuleItem.Path
                                        "FileOrFolder" = $RequirementRuleItem.FileOrFolder
                                        "Operator" = $RequirementRuleItem.Operator
                                        "DateTimeValue" = $RequirementRuleItem.DateTimeValue
                                        "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                                    }
                                }
                                "DateCreated" {
                                    # Create a custom file based requirement rule
                                    $RequirementRuleArgs = @{
                                        "DateCreated" = $true
                                        "Path" = $RequirementRuleItem.Path
                                        "FileOrFolder" = $RequirementRuleItem.FileOrFolder
                                        "Operator" = $RequirementRuleItem.Operator
                                        "DateTimeValue" = $RequirementRuleItem.DateTimeValue
                                        "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                                    }
                                }
                                "Version" {
                                    # Create a custom file based requirement rule
                                    $RequirementRuleArgs = @{
                                        "Version" = $true
                                        "Path" = $RequirementRuleItem.Path
                                        "FileOrFolder" = $RequirementRuleItem.FileOrFolder
                                        "Operator" = $RequirementRuleItem.Operator
                                        "VersionValue" = $RequirementRuleItem.VersionValue
                                        "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                                    }
                                }
                                "Size" {
                                    # Create a custom file based requirement rule
                                    $RequirementRuleArgs = @{
                                        "Size" = $true
                                        "Path" = $RequirementRuleItem.Path
                                        "FileOrFolder" = $RequirementRuleItem.FileOrFolder
                                        "Operator" = $RequirementRuleItem.Operator
                                        "SizeInMBValue" = $RequirementRuleItem.SizeInMBValue
                                        "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                                    }
                                }
                            }

                            # Create file based requirement rule
                            $CustomRequirementRule = New-IntuneWin32AppRequirementRuleFile @RequirementRuleArgs
                        }
                        "Registry" {
                            switch ($RequirementRuleItem.DetectionMethod) {
                                "Existence" {
                                    # Create a custom registry based requirement rule
                                    $RequirementRuleArgs = @{
                                        "Existence" = $true
                                        "KeyPath" = $RequirementRuleItem.KeyPath
                                        "ValueName" = $RequirementRuleItem.ValueName
                                        "DetectionType" = $RequirementRuleItem.DetectionType
                                        "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                                    }
                                }
                                "StringComparison" {
                                    # Create a custom registry based requirement rule
                                    $RequirementRuleArgs = @{
                                        "StringComparison" = $true
                                        "KeyPath" = $RequirementRuleItem.KeyPath
                                        "ValueName" = $RequirementRuleItem.ValueName
                                        "StringComparisonOperator" = $RequirementRuleItem.Operator
                                        "StringComparisonValue" = $RequirementRuleItem.Value
                                        "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                                    }
                                }
                                "VersionComparison" {
                                    # Create a custom registry based requirement rule
                                    $RequirementRuleArgs = @{
                                        "VersionComparison" = $true
                                        "KeyPath" = $RequirementRuleItem.KeyPath
                                        "ValueName" = $RequirementRuleItem.ValueName
                                        "VersionComparisonOperator" = $RequirementRuleItem.Operator
                                        "VersionComparisonValue" = $RequirementRuleItem.Value
                                        "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                                    }
                                }
                                "IntegerComparison" {
                                    # Create a custom registry based requirement rule
                                    $RequirementRuleArgs = @{
                                        "IntegerComparison" = $true
                                        "KeyPath" = $RequirementRuleItem.KeyPath
                                        "ValueName" = $RequirementRuleItem.ValueName
                                        "IntegerComparisonOperator" = $RequirementRuleItem.Operator
                                        "IntegerComparisonValue" = $RequirementRuleItem.Value
                                        "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                                    }
                                }
                            }

                            # Create registry based requirement rule
                            $CustomRequirementRule = New-IntuneWin32AppRequirementRuleRegistry @RequirementRuleArgs
                        }
                        "Script" {
                            switch ($RequirementRuleItem.DetectionMethod) {
                                "StringOutput" {
                                    # Create a custom script based requirement rule
                                    $RequirementRuleArgs = @{
                                        "StringOutputDataType" = $true
                                        "ScriptFile" = (Join-Path -Path $ScriptsFolder -ChildPath $RequirementRuleItem.ScriptFile)
                                        "ScriptContext" = $RequirementRuleItem.ScriptContext
                                        "StringComparisonOperator" = $RequirementRuleItem.Operator
                                        "StringValue" = $RequirementRuleItem.Value
                                        "RunAs32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.RunAs32BitOn64System)
                                        "EnforceSignatureCheck" = [System.Convert]::ToBoolean($RequirementRuleItem.EnforceSignatureCheck)
                                    }
                                }
                                "IntegerOutput" {
                                    # Create a custom script based requirement rule
                                    $RequirementRuleArgs = @{
                                        "IntegerOutputDataType" = $true
                                        "ScriptFile" = $RequirementRuleItem.ScriptFile
                                        "ScriptContext" = $RequirementRuleItem.ScriptContext
                                        "IntegerComparisonOperator" = $RequirementRuleItem.Operator
                                        "IntegerValue" = $RequirementRuleItem.Value
                                        "RunAs32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.RunAs32BitOn64System)
                                        "EnforceSignatureCheck" = [System.Convert]::ToBoolean($RequirementRuleItem.EnforceSignatureCheck)
                                    }
                                }
                                "BooleanOutput" {
                                    # Create a custom script based requirement rule
                                    $RequirementRuleArgs = @{
                                        "BooleanOutputDataType" = $true
                                        "ScriptFile" = $RequirementRuleItem.ScriptFile
                                        "ScriptContext" = $RequirementRuleItem.ScriptContext
                                        "BooleanComparisonOperator" = $RequirementRuleItem.Operator
                                        "BooleanValue" = $RequirementRuleItem.Value
                                        "RunAs32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.RunAs32BitOn64System)
                                        "EnforceSignatureCheck" = [System.Convert]::ToBoolean($RequirementRuleItem.EnforceSignatureCheck)
                                    }
                                }
                                "DateTimeOutput" {
                                    # Create a custom script based requirement rule
                                    $RequirementRuleArgs = @{
                                        "DateTimeOutputDataType" = $true
                                        "ScriptFile" = $RequirementRuleItem.ScriptFile
                                        "ScriptContext" = $RequirementRuleItem.ScriptContext
                                        "DateTimeComparisonOperator" = $RequirementRuleItem.Operator
                                        "DateTimeValue" = $RequirementRuleItem.Value
                                        "RunAs32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.RunAs32BitOn64System)
                                        "EnforceSignatureCheck" = [System.Convert]::ToBoolean($RequirementRuleItem.EnforceSignatureCheck)
                                    }
                                }
                                "FloatOutput" {
                                    # Create a custom script based requirement rule
                                    $RequirementRuleArgs = @{
                                        "FloatOutputDataType" = $true
                                        "ScriptFile" = $RequirementRuleItem.ScriptFile
                                        "ScriptContext" = $RequirementRuleItem.ScriptContext
                                        "FloatComparisonOperator" = $RequirementRuleItem.Operator
                                        "FloatValue" = $RequirementRuleItem.Value
                                        "RunAs32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.RunAs32BitOn64System)
                                        "EnforceSignatureCheck" = [System.Convert]::ToBoolean($RequirementRuleItem.EnforceSignatureCheck)
                                    }
                                }
                                "VersionOutput" {
                                    # Create a custom script based requirement rule
                                    $RequirementRuleArgs = @{
                                        "VersionOutputDataType" = $true
                                        "ScriptFile" = $RequirementRuleItem.ScriptFile
                                        "ScriptContext" = $RequirementRuleItem.ScriptContext
                                        "VersionComparisonOperator" = $RequirementRuleItem.Operator
                                        "VersionValue" = $RequirementRuleItem.Value
                                        "RunAs32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.RunAs32BitOn64System)
                                        "EnforceSignatureCheck" = [System.Convert]::ToBoolean($RequirementRuleItem.EnforceSignatureCheck)
                                    }
                                    
                                }
                            }

                            # Create script based requirement rule
                            $CustomRequirementRule = New-IntuneWin32AppRequirementRuleScript @RequirementRuleArgs
                        }
                    }

                    # Add requirement rule to list
                    $RequirementRules.Add($CustomRequirementRule) | Out-Null
                }
            }
            
            # Create detection rules
            Write-Output -InputObject "Creating detection rules"
            $DetectionRules = New-Object -TypeName "System.Collections.ArrayList"
            foreach ($DetectionRuleItem in $AppData.DetectionRule) {
                switch ($DetectionRuleItem.Type) {
                    "MSI" {
                        # Create a MSI installation based detection rule
                        $DetectionRuleArgs = @{
                            "ProductCode" = $DetectionRuleItem.ProductCode
                            "ProductVersionOperator" = $DetectionRuleItem.ProductVersionOperator
                        }
                        if (-not([string]::IsNullOrEmpty($DetectionRuleItem.ProductVersion))) {
                            $DetectionRuleArgs.Add("ProductVersion", $DetectionRuleItem.ProductVersion)
                        }

                        # Create MSI based detection rule
                        $DetectionRule = New-IntuneWin32AppDetectionRuleMSI @DetectionRuleArgs
                    }
                    "Script" {
                        # Create a PowerShell script based detection rule
                        $DetectionRuleArgs = @{
                            "ScriptFile" = (Join-Path -Path $ScriptsFolder -ChildPath $DetectionRuleItem.ScriptFile)
                            "EnforceSignatureCheck" = [System.Convert]::ToBoolean($DetectionRuleItem.EnforceSignatureCheck)
                            "RunAs32Bit" = [System.Convert]::ToBoolean($DetectionRuleItem.RunAs32Bit)
                        }

                        # Create script based detection rule
                        $DetectionRule = New-IntuneWin32AppDetectionRuleScript @DetectionRuleArgs
                    }
                    "Registry" {
                        switch ($DetectionRuleItem.DetectionMethod) {
                            "Existence" {
                                # Construct registry existence detection rule parameters
                                $DetectionRuleArgs = @{
                                    "Existence" = $true
                                    "KeyPath" = $DetectionRuleItem.KeyPath
                                    "DetectionType" = $DetectionRuleItem.DetectionType
                                    "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                                }
                                if (-not([string]::IsNullOrEmpty($DetectionRuleItem.ValueName))) {
                                    $DetectionRuleArgs.Add("ValueName", $DetectionRuleItem.ValueName)
                                }
                            }
                            "VersionComparison" {
                                # Construct registry version comparison detection rule parameters
                                $DetectionRuleArgs = @{
                                    "VersionComparison" = $true
                                    "KeyPath" = $DetectionRuleItem.KeyPath
                                    "ValueName" = $DetectionRuleItem.ValueName
                                    "VersionComparisonOperator" = $DetectionRuleItem.Operator
                                    "VersionComparisonValue" = $DetectionRuleItem.Value
                                    "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                                }
                            }
                            "StringComparison" {
                                # Construct registry string comparison detection rule parameters
                                $DetectionRuleArgs = @{
                                    "StringComparison" = $true
                                    "KeyPath" = $DetectionRuleItem.KeyPath
                                    "ValueName" = $DetectionRuleItem.ValueName
                                    "StringComparisonOperator" = $DetectionRuleItem.Operator
                                    "StringComparisonValue" = $DetectionRuleItem.Value
                                    "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                                }
                            }
                            "IntegerComparison" {
                                # Construct registry integer comparison detection rule parameters
                                $DetectionRuleArgs = @{
                                    "IntegerComparison" = $true
                                    "KeyPath" = $DetectionRuleItem.KeyPath
                                    "ValueName" = $DetectionRuleItem.ValueName
                                    "IntegerComparisonOperator" = $DetectionRuleItem.Operator
                                    "IntegerComparisonValue" = $DetectionRuleItem.Value
                                    "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                                }
                            }
                        }

                        # Create registry based detection rule
                        $DetectionRule = New-IntuneWin32AppDetectionRuleRegistry @DetectionRuleArgs
                    }
                    "File" {
                        switch ($DetectionRuleItem.DetectionMethod) {
                            "Existence" {
                                # Create a custom file based requirement rule
                                $DetectionRuleArgs = @{
                                    "Existence" = $true
                                    "Path" = $DetectionRuleItem.Path
                                    "FileOrFolder" = $DetectionRuleItem.FileOrFolder
                                    "DetectionType" = $DetectionRuleItem.DetectionType
                                    "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                                }
                            }
                            "DateModified" {
                                # Create a custom file based requirement rule
                                $DetectionRuleArgs = @{
                                    "DateModified" = $true
                                    "Path" = $DetectionRuleItem.Path
                                    "FileOrFolder" = $DetectionRuleItem.FileOrFolder
                                    "Operator" = $DetectionRuleItem.Operator
                                    "DateTimeValue" = $DetectionRuleItem.DateTimeValue
                                    "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                                }
                            }
                            "DateCreated" {
                                # Create a custom file based requirement rule
                                $DetectionRuleArgs = @{
                                    "DateCreated" = $true
                                    "Path" = $DetectionRuleItem.Path
                                    "FileOrFolder" = $DetectionRuleItem.FileOrFolder
                                    "Operator" = $DetectionRuleItem.Operator
                                    "DateTimeValue" = $DetectionRuleItem.DateTimeValue
                                    "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                                }
                            }
                            "Version" {
                                # Create a custom file based requirement rule
                                $DetectionRuleArgs = @{
                                    "Version" = $true
                                    "Path" = $DetectionRuleItem.Path
                                    "FileOrFolder" = $DetectionRuleItem.FileOrFolder
                                    "Operator" = $DetectionRuleItem.Operator
                                    "VersionValue" = $DetectionRuleItem.VersionValue
                                    "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                                }
                            }
                            "Size" {
                                # Create a custom file based requirement rule
                                $DetectionRuleArgs = @{
                                    "Size" = $true
                                    "Path" = $DetectionRuleItem.Path
                                    "FileOrFolder" = $DetectionRuleItem.FileOrFolder
                                    "Operator" = $DetectionRuleItem.Operator
                                    "SizeInMBValue" = $DetectionRuleItem.SizeInMBValue
                                    "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                                }
                            }
                        }

                        # Create file based detection rule
                        $DetectionRule = New-IntuneWin32AppDetectionRuleFile @DetectionRuleArgs
                    }
                }

                # Add detection rule to list
                $DetectionRules.Add($DetectionRule) | Out-Null
            }

            # Add icon
            if (Test-Path -Path $AppIconFile) {
                Write-Output -InputObject "Constructing an icon object"
                $Icon = New-IntuneWin32AppIcon -FilePath $AppIconFile
            }

            # Determine the DisplayName for the Win32 app depending on the IntuneAppNamingConvention setting
            switch ($App.IntuneAppNamingConvention) {
                "PublisherAppNameAppVersion" {
                    $DisplayName = -join@($AppData.Information.Publisher, " ", $AppData.Information.DisplayName, " ", $AppData.Information.AppVersion)
                }
                "PublisherAppName" {
                    $DisplayName = -join@($AppData.Information.Publisher, " ", $AppData.Information.DisplayName)
                }
                "AppNameAppVersion" {
                    $DisplayName = -join@($AppData.Information.DisplayName, " ", $AppData.Information.AppVersion)
                }
                "AppName" {
                    $DisplayName = $AppData.Information.DisplayName
                }
                default {
                    $DisplayName = $AppData.Information.DisplayName
                }
            }

            # Handle DisplayName fallback if DisplayName is empty
            if ($App.IntuneAppNamingConvention -eq $null) {
                $DisplayName = $AppData.Information.DisplayName
            }

            # Construct a table of default parameters for Win32 app
            $Win32AppArgs = @{
                "FilePath" = $IntuneAppPackage.Path
                "DisplayName" = $DisplayName
                "AppVersion" = $AppData.Information.AppVersion
                "Description" = $AppData.Information.Description
                "Publisher" = $AppData.Information.Publisher
                "InstallExperience" = $AppData.Program.InstallExperience
                "RestartBehavior" = $AppData.Program.DeviceRestartBehavior
                "DetectionRule" = $DetectionRules
                "RequirementRule" = $RequirementRule
                "ErrorAction" = "Stop"
            }

            # Dynamically add additional parameters for Win32 app
            if ($RequirementRules -ne $null) {
                $Win32AppArgs.Add("AdditionalRequirementRule", $RequirementRules)
            }
            if (Test-Path -Path $AppIconFile) {
                $Win32AppArgs.Add("Icon", $Icon)
            }
            if (-not([string]::IsNullOrEmpty($AppData.Information.Owner))) {
                $Win32AppArgs.Add("Owner", $AppData.Information.Owner)
            }
            if (-not([string]::IsNullOrEmpty($AppData.Information.Notes))) {
                $Win32AppArgs.Add("Notes", $AppData.Information.Notes)
            }
            if (-not([string]::IsNullOrEmpty($AppData.Program.InstallCommand))) {
                $Win32AppArgs.Add("InstallCommandLine", $AppData.Program.InstallCommand)
            }
            if (-not([string]::IsNullOrEmpty($AppData.Program.UninstallCommand))) {
                $Win32AppArgs.Add("UninstallCommandLine", $AppData.Program.UninstallCommand)
            }
            if (-not([string]::IsNullOrEmpty($AppData.Program.AllowAvailableUninstall))) {
                if ($AppData.Program.AllowAvailableUninstall -eq $true) {
                    $Win32AppArgs.Add("AllowAvailableUninstall", $true)
                }
            }
            if (-not([string]::IsNullOrEmpty($AppData.Information.ScopeTagName))) {
                $Win32AppArgs.Add("ScopeTagName", $AppData.Information.ScopeTagName)
            }

            try {
                # Create Win32 app
                Write-Output -InputObject "Creating Win32 application"
                Write-Output -InputObject $Win32AppArgs
                $Win32App = Add-IntuneWin32App @Win32AppArgs

                try {
                    # Send Log Analytics payload with published app details
                    Write-Output -InputObject "Sending Log Analytics payload with published app details"
                    $PayloadBody = @{
                        "AppName" = $AppData.Information.DisplayName
                        "AppVersion" = $AppData.Information.AppVersion
                        "AppPublisher" = $AppData.Information.Publisher
                    }
                    Send-LogAnalyticsPayload -WorkspaceID $WorkspaceID -SharedKey $SharedKey -Body ($PayloadBody | ConvertTo-Json) -LogType "IntuneAppFactory" -ErrorAction "Stop"
                }
                catch [System.Exception] {
                    Write-Output -InputObject "Failed to send Win32 application publication message to Log Analytics workspace"
                }

                try {
                    # Construct new application custom object with required properties
                    $AppListItem = [PSCustomObject]@{
                        "IntuneAppName" = $App.IntuneAppName
                        "IntuneAppObjectID" = $Win32App.id
                        "AppPublishFolderPath" = $App.AppPublishFolderPath
                        "AppSetupFileName" = $App.AppSetupFileName
                        "AppPublishPackageFolder" = $OutputFolder
                        "AppPublishPackageFileName" = $IntuneAppPackage.FileName
                    }

                    # Add to list of applications to be assigned
                    $AppsAssignList.Add($AppListItem) | Out-Null
                }
                catch [System.Exception] {
                    Write-Output -InputObject "Failed to create AppsAssignList.json file. Error: $($_.Exception.Message)"
                }
            }
            catch [System.Exception] {
                Write-Output -InputObject "Failed to publish Win32 application. Error: $($_.Exception.Message)"
            }

            # Handle current application output completed message
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Completed"
        }

        # Construct new json file with new applications to be assigned
        if ($AppsAssignList.Count -ge 1) {
            $AppsAssignListJSON = $AppsAssignList | ConvertTo-Json -Depth 3
            Write-Output -InputObject "Creating '$($AppsAssignListFileName)' in: $($AppsAssignListFilePath)"
            Write-Output -InputObject "App list file contains the following items: $($AppsAssignList.IntuneAppName -join ", ")"
            Out-File -InputObject $AppsAssignListJSON -FilePath $AppsAssignListFilePath -NoClobber -Force -ErrorAction "Stop"
        }

        # Handle next stage execution or not if no new applications are to be assigned
        if ($AppsAssignList.Count -eq 0) {
            # Don't allow pipeline to continue
            Write-Output -InputObject "No new applications to be assigned, aborting pipeline"
            Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
        }
        else {
            # Allow pipeline to continue
            Write-Output -InputObject "Allowing pipeline to continue execution"
            Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]true"
        }
    }
    else {
        Write-Output -InputObject "Failed to locate required $($AppsPublishListFileName) file in build artifacts staging directory, aborting pipeline"
        Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
    }
}