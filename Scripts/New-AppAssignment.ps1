<#
.SYNOPSIS
    This script creates assignment for the published application according to what's defined in the app specific App.json file.

.DESCRIPTION
    This script creates assignment for the published application according to what's defined in the app specific App.json file.

.EXAMPLE
    .\New-AppAssignment.ps1

.NOTES
    FileName:    New-AppAssignment.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2023-10-08
    Updated:     2023-10-08

    Version history:
    1.0.0 - (2023-10-08) Script created
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true, ParameterSetName = "ClientSecret")]
    [parameter(Mandatory = $true, ParameterSetName = "ClientCertificate")]
    [ValidateNotNullOrEmpty()]
    [string]$TenantID,

    [parameter(Mandatory = $true, ParameterSetName = "ClientSecret")]
    [parameter(Mandatory = $true, ParameterSetName = "ClientCertificate")]
    [ValidateNotNullOrEmpty()]
    [string]$ClientID,

    [parameter(Mandatory = $true, ParameterSetName = "ClientSecret")]
    [ValidateNotNullOrEmpty()]
    [string]$ClientSecret,
    
    [parameter(Mandatory = $true, ParameterSetName = "ClientCertificate")]
    [ValidateNotNullOrEmpty()]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$ClientCertificate
)
Process {
    # Construct path for AppsAssignList.json file created in previous stage
    $AppsAssignListFileName = "AppsAssignList.json"
    $AppsAssignListFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsPublishedList") -ChildPath $AppsAssignListFileName

    # Retrieve authentication token using client secret from key vault or client certificate
    switch ($PSCmdlet.ParameterSetName) {
        "ClientSecret" {
            $AuthToken = Connect-MSIntuneGraph -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -ErrorAction "Stop"
        }
        "ClientCertificate" {
            $AuthToken = Connect-MSIntuneGraph -TenantID $TenantID -ClientID $ClientID -ClientCert $ClientCertificate -ErrorAction "Stop"
        }
    }

    if (Test-Path -Path $AppsAssignListFilePath) {
        # Read content from AppsAssignList.json file and convert from JSON format
        Write-Output -InputObject "Reading contents from: $($AppsAssignListFilePath)"
        $AppsAssignList = Get-Content -Path $AppsAssignListFilePath | ConvertFrom-Json

        # Process each application in list and create assignment according to what's defined in the app specific App.json file
        foreach ($App in $AppsAssignList) {
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Initializing"

            # Read app specific App.json manifest and convert from JSON
            $AppDataFile = Join-Path -Path $App.AppPublishFolderPath -ChildPath "App.json"
            if (Test-Path -Path $AppDataFile) {
                Write-Output -InputObject "Reading contents from: $($AppDataFile)"
                $AppData = Get-Content -Path $AppDataFile | ConvertFrom-Json

                # Detect if current in list has assignment configuration in it's app specific App.json file
                Write-Output -InputObject "Checking for application assignment configuration"
                if ($AppData.Assignment -ne $null) {
                    $AppAssignmentCount = ($AppData.Assignment | Measure-Object).Count
                    Write-Output -InputObject "Found $($AppAssignmentCount) assignment(s) in application manifest"
                    if ($AppAssignmentCount -ge 1) {
                        foreach ($AppAssignmentItem in $AppData.Assignment) {
                            switch ($AppAssignmentItem.Type) {
                                "VirtualGroup" {
                                    Write-Output -InputObject "Preparing assignment parameters for: '$($AppAssignmentItem.GroupName)'"

                                    # Construct required part of parameter input data for assignment
                                    $AppAssignmentArgs = @{
                                        "ID" = $App.IntuneAppObjectID
                                        "Intent" = $AppAssignmentItem.Intent
                                        "ErrorAction" = "Stop"
                                    }

                                    # Add optional part of parameter input data for assignment
                                    if (-not([string]::IsNullOrEmpty($AppAssignmentItem.UseLocalTime))) {
                                        $AppAssignmentArgs.Add("UseLocalTime", [System.Convert]::ToBoolean($AppAssignmentItem.UseLocalTime))
                                    }
                                    if (-not([string]::IsNullOrEmpty($AppAssignmentItem.Notification))) {
                                        $AppAssignmentArgs.Add("Notification", $AppAssignmentItem.Notification)
                                    }
                                    if (-not([string]::IsNullOrEmpty($AppAssignmentItem.AvailableTime))) {
                                        $AppAssignmentArgs.Add("AvailableTime", $AppAssignmentItem.AvailableTime)
                                    }
                                    if (-not([string]::IsNullOrEmpty($AppAssignmentItem.DeadlineTime))) {
                                        $AppAssignmentArgs.Add("DeadlineTime", $AppAssignmentItem.DeadlineTime)
                                    }
                                    if (-not([string]::IsNullOrEmpty($AppAssignmentItem.DeliveryOptimizationPriority))) {
                                        $AppAssignmentArgs.Add("DeliveryOptimizationPriority", $AppAssignmentItem.DeliveryOptimizationPriority)
                                    }
                                    if (-not([string]::IsNullOrEmpty($AppAssignmentItem.EnableRestartGracePeriod))) {
                                        $AppAssignmentArgs.Add("EnableRestartGracePeriod", [System.Convert]::ToBoolean($AppAssignmentItem.EnableRestartGracePeriod))
                                    }
                                    if (-not([string]::IsNullOrEmpty($AppAssignmentItem.RestartGracePeriodInMinutes))) {
                                        $AppAssignmentArgs.Add("RestartGracePeriod", $AppAssignmentItem.RestartGracePeriodInMinutes)
                                    }
                                    if (-not([string]::IsNullOrEmpty($AppAssignmentItem.RestartCountDownDisplayInMinutes))) {
                                        $AppAssignmentArgs.Add("RestartCountDownDisplay", $AppAssignmentItem.RestartCountDownDisplayInMinutes)
                                    }
                                    if (-not([string]::IsNullOrEmpty($AppAssignmentItem.RestartNotificationSnoozeInMinutes))) {
                                        $AppAssignmentArgs.Add("RestartNotificationSnooze", $AppAssignmentItem.RestartNotificationSnoozeInMinutes)
                                    }
                                    if (-not([string]::IsNullOrEmpty($AppAssignmentItem.FilterName))) {
                                        $AppAssignmentArgs.Add("FilterName", $AppAssignmentItem.FilterName)
                                    }
                                    if (-not([string]::IsNullOrEmpty($AppAssignmentItem.FilterMode))) {
                                        $AppAssignmentArgs.Add("FilterMode", $AppAssignmentItem.FilterMode)
                                    }

                                    try {
                                        # Create application assignment based on virtual group name
                                        Write-Output -InputObject "Adding assignment with intent '$($AppAssignmentItem.Intent.ToLower())' for virtual group: '$($AppAssignmentItem.GroupName)'"
                                        switch ($AppAssignmentItem.GroupName) {
                                            "AllDevices" {
                                                $Win32AppAssignment = Add-IntuneWin32AppAssignmentAllDevices @AppAssignmentArgs
                                            }
                                            "AllUsers" {
                                                $Win32AppAssignment = Add-IntuneWin32AppAssignmentAllUsers @AppAssignmentArgs
                                            }
                                        }
                                    }
                                    catch [System.Exception] {
                                        Write-Warning -Message "An error occurred while attempting to create assignment for virtual group: '$($AppAssignmentItem.GroupName)'. Error message: $($_.Exception.Message)"
                                    }
                                }
                                "Group" {
                                    Write-Output -InputObject "Preparing assignment parameters for group with ID: '$($AppAssignmentItem.GroupID)'"

                                    # Construct required part of parameter input data for assignment
                                    switch ($AppAssignmentItem.GroupMode.ToLower()) {
                                        "include" {
                                            # Construct required part of parameter input data for assignment
                                            $AppAssignmentArgs = @{
                                                "Include" = $true
                                                "ID" = $App.IntuneAppObjectID
                                                "GroupID" = $AppAssignmentItem.GroupID
                                                "Intent" = $AppAssignmentItem.Intent
                                                "ErrorAction" = "Stop"
                                            }

                                            # Add optional part of parameter input data for assignment
                                            if (-not([string]::IsNullOrEmpty($AppAssignmentItem.UseLocalTime))) {
                                                $AppAssignmentArgs.Add("UseLocalTime", [System.Convert]::ToBoolean($AppAssignmentItem.UseLocalTime))
                                            }
                                            if (-not([string]::IsNullOrEmpty($AppAssignmentItem.Notification))) {
                                                $AppAssignmentArgs.Add("Notification", $AppAssignmentItem.Notification)
                                            }
                                            if (-not([string]::IsNullOrEmpty($AppAssignmentItem.AvailableTime))) {
                                                $AppAssignmentArgs.Add("AvailableTime", $AppAssignmentItem.AvailableTime)
                                            }
                                            if (-not([string]::IsNullOrEmpty($AppAssignmentItem.DeadlineTime))) {
                                                $AppAssignmentArgs.Add("DeadlineTime", $AppAssignmentItem.DeadlineTime)
                                            }
                                            if (-not([string]::IsNullOrEmpty($AppAssignmentItem.DeliveryOptimizationPriority))) {
                                                $AppAssignmentArgs.Add("DeliveryOptimizationPriority", $AppAssignmentItem.DeliveryOptimizationPriority)
                                            }
                                            if (-not([string]::IsNullOrEmpty($AppAssignmentItem.EnableRestartGracePeriod))) {
                                                $AppAssignmentArgs.Add("EnableRestartGracePeriod", $AppAssignmentItem.EnableRestartGracePeriod)
                                            }
                                            if (-not([string]::IsNullOrEmpty($AppAssignmentItem.RestartGracePeriodInMinutes))) {
                                                $AppAssignmentArgs.Add("RestartGracePeriod", [System.Convert]::ToBoolean($AppAssignmentItem.RestartGracePeriodInMinutes))
                                            }
                                            if (-not([string]::IsNullOrEmpty($AppAssignmentItem.RestartCountDownDisplayInMinutes))) {
                                                $AppAssignmentArgs.Add("RestartCountDownDisplay", $AppAssignmentItem.RestartCountDownDisplayInMinutes)
                                            }
                                            if (-not([string]::IsNullOrEmpty($AppAssignmentItem.RestartNotificationSnoozeInMinutes))) {
                                                $AppAssignmentArgs.Add("RestartNotificationSnooze", $AppAssignmentItem.RestartNotificationSnoozeInMinutes)
                                            }
                                            if (-not([string]::IsNullOrEmpty($AppAssignmentItem.FilterName))) {
                                                $AppAssignmentArgs.Add("FilterName", $AppAssignmentItem.FilterName)
                                            }
                                            if (-not([string]::IsNullOrEmpty($AppAssignmentItem.FilterMode))) {
                                                $AppAssignmentArgs.Add("FilterMode", $AppAssignmentItem.FilterMode)
                                            }

                                            try {
                                                # Create application assignment
                                                Write-Output -InputObject "Adding '$($AppAssignmentItem.GroupMode.ToLower())' assignment with intent '$($AppAssignmentItem.Intent.ToLower())' for group with ID: '$($AppAssignmentItem.GroupID)'"
                                                $Win32AppAssignment = Add-IntuneWin32AppAssignmentGroup @AppAssignmentArgs
                                            }
                                            catch [System.Exception] {
                                                Write-Warning -Message "An error occurred while attempting to create assignment for group with ID: '$($AppAssignmentItem.GroupID)'. Error message: $($_.Exception.Message)"
                                            }
                                        }
                                        "exclude" {
                                            # Construct required part of parameter input data for assignment
                                            $AppAssignmentArgs = @{
                                                "Exclude" = $true
                                                "ID" = $App.IntuneAppObjectID
                                                "GroupID" = $AppAssignmentItem.GroupID
                                                "Intent" = $AppAssignmentItem.Intent
                                                "ErrorAction" = "Stop"
                                            }

                                            try {
                                                # Create application assignment
                                                Write-Output -InputObject "Adding '$($AppAssignmentItem.GroupMode.ToLower())' assignment with intent '$($AppAssignmentItem.Intent.ToLower())' for group with ID '$($AppAssignmentItem.GroupID)'"
                                                $Win32AppAssignment = Add-IntuneWin32AppAssignmentGroup @AppAssignmentArgs
                                            }
                                            catch [System.Exception] {
                                                Write-Warning -Message "An error occurred while attempting to create assignment for group with ID: '$($AppAssignmentItem.GroupID)'. Error message: $($_.Exception.Message)"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    else {
                        Write-Output -InputObject "No eligible assignments found, skipping assignment configuration"
                    }
                }
                else {
                    Write-Output -InputObject "No assignment configuration found, skipping assignment configuration"
                }
            }
            else {
                Write-Output -InputObject "Could not find app specific App.json manifest in: $($App.AppPublishFolderPath)"
            }

            # Handle current application output completed message
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Completed"
        }
    }
    else {
        Write-Output -InputObject "Attempted to read contents from: $($AppsAssignListFilePath)"
        Write-Output -InputObject "No application assignment list found, skipping assignment configuration"
    }
}