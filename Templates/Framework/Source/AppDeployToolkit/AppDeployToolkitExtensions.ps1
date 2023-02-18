<#
.SYNOPSIS
	This script is a template that allows you to extend the toolkit with your own custom functions.
    # LICENSE #
    PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows. 
    Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
    This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. 
    You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is automatically dot-sourced by the AppDeployToolkitMain.ps1 script.
.NOTES
    Toolkit Exit Code Ranges:
    60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
    69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
    70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK 
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
)

##*===============================================
##* VARIABLE DECLARATION
##*===============================================

# Variables: Script
[string]$appDeployToolkitExtName = 'PSAppDeployToolkitExt'
[string]$appDeployExtScriptFriendlyName = 'App Deploy Toolkit Extensions'
[version]$appDeployExtScriptVersion = [version]'1.5.0'
[string]$appDeployExtScriptDate = '02/12/2017'
[hashtable]$appDeployExtScriptParameters = $PSBoundParameters

##*===============================================
##* FUNCTION LISTINGS
##*===============================================

# Add-ScheduledTask - Function that creates a scheduled task
function Add-ScheduledTask {
    param(
        [parameter(Mandatory = $true, ParameterSetName = "Interval", HelpMessage = "Specify the scheduled task should be based on an interval trigger.")]
        [parameter(Mandatory = $true, ParameterSetName = "Daily")]
        [parameter(Mandatory = $true, ParameterSetName = "Hourly")]
        [parameter(Mandatory = $true, ParameterSetName = "Minutes")]
        [switch]$Interval,

        [parameter(Mandatory = $true, ParameterSetName = "Event", HelpMessage = "Specify the scheduled task should be based on an event trigger.")]
        [switch]$Event,

        [parameter(Mandatory = $true, ParameterSetName = "Daily", HelpMessage = "Specify the interval trigger type as daily.")]
        [switch]$Daily,

        [parameter(Mandatory = $true, ParameterSetName = "Hourly", HelpMessage = "Specify the interval trigger type as hourly.")]
        [switch]$Hourly,

        [parameter(Mandatory = $true, ParameterSetName = "Minutes", HelpMessage = "Specify the interval trigger type as minutes.")]
        [switch]$Minutes,

        [parameter(Mandatory = $true, ParameterSetName = "Event", HelpMessage = "Specify the event based trigger type.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("AtWorkstationUnlock", "AtLogon", "AtStartup")]
        [string[]]$Trigger,

        [parameter(Mandatory = $true, ParameterSetName = "Interval", HelpMessage = "Set the interval trigger frequency.")]
        [parameter(Mandatory = $true, ParameterSetName = "Daily")]
        [parameter(Mandatory = $true, ParameterSetName = "Hourly")]
        [parameter(Mandatory = $true, ParameterSetName = "Minutes")]
        [ValidateNotNullOrEmpty()]
        [int]$Frequency,

        [parameter(Mandatory = $false, ParameterSetName = "Interval", HelpMessage = "Set the start time of the interval trigger, only required when daily interval is used.")]
        [parameter(Mandatory = $true, ParameterSetName = "Daily")]
        [ValidateNotNullOrEmpty()]
        [datetime]$Time,

        [parameter(Mandatory = $true, ParameterSetName = "Interval", HelpMessage = "Specify the name of the scheduled task.")]
        [parameter(Mandatory = $true, ParameterSetName = "Daily")]
        [parameter(Mandatory = $true, ParameterSetName = "Hourly")]
        [parameter(Mandatory = $true, ParameterSetName = "Minutes")]
        [parameter(Mandatory = $true, ParameterSetName = "Event")]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [parameter(Mandatory = $true, ParameterSetName = "Interval", HelpMessage = "Specify the path of the scheduled task, e.g. '\' when using the root path.")]
        [parameter(Mandatory = $true, ParameterSetName = "Daily")]
        [parameter(Mandatory = $true, ParameterSetName = "Hourly")]
        [parameter(Mandatory = $true, ParameterSetName = "Minutes")]
        [parameter(Mandatory = $true, ParameterSetName = "Event")]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [parameter(Mandatory = $true, ParameterSetName = "Interval", HelpMessage = "Specify the process name of the action the scheduled task triggers.")]
        [parameter(Mandatory = $true, ParameterSetName = "Daily")]
        [parameter(Mandatory = $true, ParameterSetName = "Hourly")]
        [parameter(Mandatory = $true, ParameterSetName = "Minutes")]
        [parameter(Mandatory = $true, ParameterSetName = "Event")]
        [ValidateNotNullOrEmpty()]
        [string]$ProcessName,

        [parameter(Mandatory = $true, ParameterSetName = "Interval", HelpMessage = "Specify arguments for the process triggered by the action.")]
        [parameter(Mandatory = $true, ParameterSetName = "Daily")]
        [parameter(Mandatory = $true, ParameterSetName = "Hourly")]
        [parameter(Mandatory = $true, ParameterSetName = "Minutes")]
        [parameter(Mandatory = $true, ParameterSetName = "Event")]
        [ValidateNotNullOrEmpty()]
        [string]$Arguments,

        [parameter(Mandatory = $true, ParameterSetName = "Interval", HelpMessage = "Specify whether the scheduled task will run in System or User context.")]
        [parameter(Mandatory = $true, ParameterSetName = "Daily")]
        [parameter(Mandatory = $true, ParameterSetName = "Hourly")]
        [parameter(Mandatory = $true, ParameterSetName = "Minutes")]
        [parameter(Mandatory = $true, ParameterSetName = "Event")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("System", "User")]
        [string]$Principal,

        [parameter(Mandatory = $false, ParameterSetName = "Interval", HelpMessage = "Specify whether a random delay of the scheduled task trigger should occurr.")]
        [parameter(Mandatory = $false, ParameterSetName = "Daily")]
        [parameter(Mandatory = $false, ParameterSetName = "Hourly")]
        [parameter(Mandatory = $false, ParameterSetName = "Minutes")]
        [parameter(Mandatory = $false, ParameterSetName = "Event")]
        [ValidateNotNullOrEmpty()]
        [int]$RandomDelayInMinutes
    )
    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        try {
            # Construct scheduled task action
            $TaskAction = New-ScheduledTaskAction -Execute $ProcessName -Argument $Arguments -ErrorAction Stop

            # Construct the scheduled task principal
            switch ($Principal) {
                "System" {
                    $TaskPrincipal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType "ServiceAccount" -RunLevel "Highest" -ErrorAction Stop
                }
                "User" {
                    $TaskPrincipal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel "Highest" -ErrorAction
                }
            }

            # Construct array list for scheduled task triggers
            $TaskTriggerList = New-Object -TypeName "System.Collections.ArrayList"

            if ($PSBoundParameters["Interval"]) {
                # Construct the scheduled task trigger for interval selection
                switch ($PSCmdlet.ParameterSetName) {
                    "Daily" {
                        $TaskTriggerArgs = @{
                            "At" = $Time
                            "Daily" = $true
                            "DaysInterval" = $Frequency
                        }
                        if ($PSBoundParameters["RandomDelayInMinutes"]) {
                            $TaskTriggerArgs.Add("RandomDelay", (New-TimeSpan -Minutes $RandomDelayInMinutes))
                        }
                        $TaskTrigger = New-ScheduledTaskTrigger @TaskTriggerArgs
                    }
                    "Hourly" {
                        $TaskTriggerArgs = @{
                            "Once" = $true
                            "At" = $Time
                            "RepetitionInterval" = (New-TimeSpan -Hours $Frequency)
                        }
                        if ($PSBoundParameters["RandomDelayInMinutes"]) {
                            $TaskTriggerArgs.Add("RandomDelay", (New-TimeSpan -Minutes $RandomDelayInMinutes))
                        }
                        $TaskTrigger = New-ScheduledTaskTrigger @TaskTriggerArgs
                    }
                    "Minutes" {
                        $TaskTriggerArgs = @{
                            "Once" = $true
                            "At" = $Time
                            "RepetitionInterval" = (New-TimeSpan -Minutes $Frequency)
                        }
                        if ($PSBoundParameters["RandomDelayInMinutes"]) {
                            $TaskTriggerArgs.Add("RandomDelay", (New-TimeSpan -Minutes $RandomDelayInMinutes))
                        }
                        $TaskTrigger = New-ScheduledTaskTrigger @TaskTriggerArgs
                    }
                }

                # Add scheduled task trigger to list
                $TaskTriggerList.Add($TaskTrigger) | Out-Null
            }

            if ($PSBoundParameters["Event"]) {
                # Construct the scheduled task trigger for each event-based selection
                foreach ($EventItem in $Trigger) {
                    switch ($EventItem) {
                        "AtWorkstationUnlock" {
                            $StateChangeTrigger = Get-CimClass -Namespace "root\Microsoft\Windows\TaskScheduler" -ClassName "MSFT_TaskSessionStateChangeTrigger"
                            $TaskTrigger = New-CimInstance -CimClass $StateChangeTrigger -Property @{ StateChange = 8 } -ClientOnly
                        }
                        "AtLogon" {
                            $TaskTrigger = New-ScheduledTaskTrigger -AtLogOn
                        }
                        "AtStartup" {
                            $TaskTrigger = New-ScheduledTaskTrigger -AtStartup
                        }
                    }

                    # Add scheduled task trigger to list
                    $TaskTriggerList.Add($TaskTrigger) | Out-Null
                }
            }

            # Construct the scheduled task settings
            $TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -Hidden -DontStopIfGoingOnBatteries -Compatibility "Win8" -RunOnlyIfNetworkAvailable -MultipleInstances "IgnoreNew" -ErrorAction Stop

            # Construct the scheduled task XML data
            $ScheduledTask = New-ScheduledTask -Action $TaskAction -Principal $TaskPrincipal -Settings $TaskSettings -Trigger $TaskTriggerList -ErrorAction Stop

            # Register the scheduled task
            $Task = Register-ScheduledTask -InputObject $ScheduledTask -TaskName $Name -TaskPath $Path -ErrorAction Stop
        }
        catch [System.Exception] {
            Write-Log -Message "Failed to create notification scheduled task. Error message: $($_.Exception.Message)." -Source ${CmdletName}
        }
    }
}

# Get-LatestGoogleChromeInstaller (added to support direct download of the latest stable Google Chrome browser Enterprise MSI setup file)
function Get-LatestGoogleChromeInstaller {
    param(
        [parameter(Mandatory = $false, HelpMessage = "Select the desired channel, either Stable, Beta or Dev.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Stable", "Beta", "Dev")]
        [string]$Channel = "Stable"
    )
    $ChromeReleasesURI = "https://omahaproxy.appspot.com/all.json"
    $ChromeReleasesContentJSON = Invoke-WebRequest -Uri $ChromeReleasesURI -UseBasicParsing
    $ChromeReleasesContent = $ChromeReleasesContentJSON | ConvertFrom-Json
    $ChromeReleasesOSContent = $ChromeReleasesContent | Where-Object { $_.os -like "win64" }
    foreach ($ChromeVersion in $ChromeReleasesOSContent.versions) {
        if ($ChromeVersion.channel -like $Channel.ToLower()) {
            switch ($Channel) {
                "Stable" {
                    $ChannelURI = "/dl/chrome/install/googlechromestandaloneenterprise64.msi"
                }
                "Beta" {
                    $ChannelURI = "/dl/chrome/install/beta/googlechromebetastandaloneenterprise64.msi"
                }
                "Dev" {
                    $ChannelURI = "/dl/chrome/install/dev/googlechromedevstandaloneenterprise64.msi"
                }
            }

            $PSObject = [PSCustomObject]@{
                Channel = $Channel
                Version = $ChromeVersion.current_version
                Date = ([DateTime]::ParseExact($ChromeVersion.current_reldate.Trim(), 'MM/dd/yy', [CultureInfo]::InvariantCulture))
                URL = -join@("https://dl.google.com", $ChannelURI)
                FileName = "googlechrome{0}standaloneenterprise64.msi" -f $Channel.ToLower()
            }
            Write-Output -InputObject $PSObject
        }
    }
}

# Remove-MSIApplicationsEx (added to support removal of MSI applications that doesn't contain an Uninstall value in the registry)
Function Remove-MSIApplicationsEx {
    <#
    .SYNOPSIS
        Removes all MSI applications matching the specified application name.
    .DESCRIPTION
        Removes all MSI applications matching the specified application name.
        Enumerates the registry for installed applications matching the specified application name and uninstalls that application using the product code, provided the uninstall string matches "msiexec".
    .PARAMETER Name
        The name of the application to uninstall. Performs a contains match on the application display name by default.
    .PARAMETER Exact
        Specifies that the named application must be matched using the exact name.
    .PARAMETER WildCard
        Specifies that the named application must be matched using a wildcard search.
    .PARAMETER Parameters
        Overrides the default parameters specified in the XML configuration file. Uninstall default is: "REBOOT=ReallySuppress /QN".
    .PARAMETER AddParameters
        Adds to the default parameters specified in the XML configuration file. Uninstall default is: "REBOOT=ReallySuppress /QN".
    .PARAMETER FilterApplication
        Two-dimensional array that contains one or more (property, value, match-type) sets that should be used to filter the list of results returned by Get-InstalledApplication to only those that should be uninstalled.
        Properties that can be filtered upon: ProductCode, DisplayName, DisplayVersion, UninstallString, InstallSource, InstallLocation, InstallDate, Publisher, Is64BitApplication
    .PARAMETER ExcludeFromUninstall
        Two-dimensional array that contains one or more (property, value, match-type) sets that should be excluded from uninstall if found.
        Properties that can be excluded: ProductCode, DisplayName, DisplayVersion, UninstallString, InstallSource, InstallLocation, InstallDate, Publisher, Is64BitApplication
    .PARAMETER IncludeUpdatesAndHotfixes
        Include matches against updates and hotfixes in results.
    .PARAMETER LoggingOptions
        Overrides the default logging options specified in the XML configuration file. Default options are: "/L*v".
    .PARAMETER LogName
        Overrides the default log file name. The default log file name is generated from the MSI file name. If LogName does not end in .log, it will be automatically appended.
        For uninstallations, by default the product code is resolved to the DisplayName and version of the application.
    .PARAMETER PassThru
        Returns ExitCode, STDOut, and STDErr output from the process.
    .PARAMETER ContinueOnError
        Continue if an exit code is returned by msiexec that is not recognized by the App Deploy Toolkit. Default is: $true.
    .EXAMPLE
        Remove-MSIApplications -Name 'Adobe Flash'
        Removes all versions of software that match the name "Adobe Flash"
    .EXAMPLE
        Remove-MSIApplications -Name 'Adobe'
        Removes all versions of software that match the name "Adobe"
    .EXAMPLE
        Remove-MSIApplications -Name 'Java 8 Update' -FilterApplication ('Is64BitApplication', $false, 'Exact'),('Publisher', 'Oracle Corporation', 'Exact')
        Removes all versions of software that match the name "Java 8 Update" where the software is 32-bits and the publisher is "Oracle Corporation".
    .EXAMPLE
        Remove-MSIApplications -Name 'Java 8 Update' -FilterApplication (,('Publisher', 'Oracle Corporation', 'Exact')) -ExcludeFromUninstall (,('DisplayName', 'Java 8 Update 45', 'Contains'))
        Removes all versions of software that match the name "Java 8 Update" and also have "Oracle Corporation" as the Publisher; however, it does not uninstall "Java 8 Update 45" of the software. 
        NOTE: if only specifying a single row in the two-dimensional arrays, the array must have the extra parentheses and leading comma as in this example.
    .EXAMPLE
        Remove-MSIApplications -Name 'Java 8 Update' -ExcludeFromUninstall (,('DisplayName', 'Java 8 Update 45', 'Contains'))
        Removes all versions of software that match the name "Java 8 Update"; however, it does not uninstall "Java 8 Update 45" of the software. 
        NOTE: if only specifying a single row in the two-dimensional array, the array must have the extra parentheses and leading comma as in this example.
    .EXAMPLE
        Remove-MSIApplications -Name 'Java 8 Update' -ExcludeFromUninstall 
                ('Is64BitApplication', $true, 'Exact'),
                ('DisplayName', 'Java 8 Update 45', 'Exact'),
                ('DisplayName', 'Java 8 Update 4*', 'WildCard'),
                ('DisplayName', 'Java \d Update \d{3}', 'RegEx'),
                ('DisplayName', 'Java 8 Update', 'Contains')		
        Removes all versions of software that match the name "Java 8 Update"; however, it does not uninstall 64-bit versions of the software, Update 45 of the software, or any Update that starts with 4.
    .NOTES
        More reading on how to create arrays if having trouble with -FilterApplication or -ExcludeFromUninstall parameter: http://blogs.msdn.com/b/powershell/archive/2007/01/23/array-literals-in-powershell.aspx
    .LINK
        http://psappdeploytoolkit.com
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string]$Name,
        [Parameter(Mandatory=$false)]
        [switch]$Exact = $false,
        [Parameter(Mandatory=$false)]
        [switch]$WildCard = $false,
        [Parameter(Mandatory=$false)]
        [Alias('Arguments')]
        [ValidateNotNullorEmpty()]
        [string]$Parameters,
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$AddParameters,
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [array]$FilterApplication = @(@()),
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [array]$ExcludeFromUninstall = @(@()),
        [Parameter(Mandatory=$false)]
        [switch]$IncludeUpdatesAndHotfixes = $false,
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$LoggingOptions,
        [Parameter(Mandatory=$false)]
        [Alias('LogName')]
        [string]$private:LogName,
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [switch]$PassThru = $false,
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [boolean]$ContinueOnError = $true
    )
    
    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        ## Build the hashtable with the options that will be passed to Get-InstalledApplication using splatting
        [hashtable]$GetInstalledApplicationSplat = @{ Name = $name }
        If ($Exact) { $GetInstalledApplicationSplat.Add( 'Exact', $Exact) }
        ElseIf ($WildCard) { $GetInstalledApplicationSplat.Add( 'WildCard', $WildCard) }
        If ($IncludeUpdatesAndHotfixes) { $GetInstalledApplicationSplat.Add( 'IncludeUpdatesAndHotfixes', $IncludeUpdatesAndHotfixes) }
        
        [psobject[]]$installedApplications = Get-InstalledApplication @GetInstalledApplicationSplat 
                        
        Write-Log -Message "Found [$($installedApplications.Count)] application(s) that matched the specified criteria [$Name]." -Source ${CmdletName}
        
        ## Filter the results from Get-InstalledApplication
        [Collections.ArrayList]$removeMSIApplications = New-Object -TypeName 'System.Collections.ArrayList'
        If (($null -ne $installedApplications) -and ($installedApplications.Count)) {
            ForEach ($installedApplication in $installedApplications) {
                If ([string]::IsNullOrEmpty($installedApplication.ProductCode)) {
                    Write-Log -Message "Skipping removal of application [$($installedApplication.DisplayName)] because unable to discover MSI ProductCode from application's registry Uninstall subkey [$($installedApplication.UninstallSubkey)]." -Severity 2 -Source ${CmdletName}
                    Continue
                }
                
                #  Filter the results from Get-InstalledApplication to only those that should be uninstalled
                If (($null -ne $FilterApplication) -and ($FilterApplication.Count)) {
                    Write-Log -Message "Filter the results to only those that should be uninstalled as specified in parameter [-FilterApplication]." -Source ${CmdletName}
                    [boolean]$addAppToRemoveList = $false
                    ForEach ($Filter in $FilterApplication) {
                        If ($Filter[2] -eq 'RegEx') {
                            If ($installedApplication.($Filter[0]) -match $Filter[1]) {
                                [boolean]$addAppToRemoveList = $true
                                Write-Log -Message "Preserve removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of regex match against [-FilterApplication] criteria." -Source ${CmdletName}
                            }
                        }
                        ElseIf ($Filter[2] -eq 'Contains') {
                            If ($installedApplication.($Filter[0]) -match [regex]::Escape($Filter[1])) {
                                [boolean]$addAppToRemoveList = $true
                                Write-Log -Message "Preserve removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of contains match against [-FilterApplication] criteria." -Source ${CmdletName}
                            }
                        }
                        ElseIf ($Filter[2] -eq 'WildCard') {
                            If ($installedApplication.($Filter[0]) -like $Filter[1]) {
                                [boolean]$addAppToRemoveList = $true
                                Write-Log -Message "Preserve removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of wildcard match against [-FilterApplication] criteria." -Source ${CmdletName}
                            }
                        }
                        ElseIf ($Filter[2] -eq 'Exact') {
                            If ($installedApplication.($Filter[0]) -eq $Filter[1]) {
                                [boolean]$addAppToRemoveList = $true
                                Write-Log -Message "Preserve removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of exact match against [-FilterApplication] criteria." -Source ${CmdletName}
                            }
                        }
                    }
                }
                Else {
                    [boolean]$addAppToRemoveList = $true
                }
                
                #  Filter the results from Get-InstalledApplication to remove those that should never be uninstalled
                If (($null -ne $ExcludeFromUninstall) -and ($ExcludeFromUninstall.Count)) {
                    ForEach ($Exclude in $ExcludeFromUninstall) {
                        If ($Exclude[2] -eq 'RegEx') {
                            If ($installedApplication.($Exclude[0]) -match $Exclude[1]) {
                                [boolean]$addAppToRemoveList = $false
                                Write-Log -Message "Skipping removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of regex match against [-ExcludeFromUninstall] criteria." -Source ${CmdletName}
                            }
                        }
                        ElseIf ($Exclude[2] -eq 'Contains') {
                            If ($installedApplication.($Exclude[0]) -match [regex]::Escape($Exclude[1])) {
                                [boolean]$addAppToRemoveList = $false
                                Write-Log -Message "Skipping removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of contains match against [-ExcludeFromUninstall] criteria." -Source ${CmdletName}
                            }
                        }
                        ElseIf ($Exclude[2] -eq 'WildCard') {
                            If ($installedApplication.($Exclude[0]) -like $Exclude[1]) {
                                [boolean]$addAppToRemoveList = $false
                                Write-Log -Message "Skipping removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of wildcard match against [-ExcludeFromUninstall] criteria." -Source ${CmdletName}
                            }
                        }
                        ElseIf ($Exclude[2] -eq 'Exact') {
                            If ($installedApplication.($Exclude[0]) -eq $Exclude[1]) {
                                [boolean]$addAppToRemoveList = $false
                                Write-Log -Message "Skipping removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of exact match against [-ExcludeFromUninstall] criteria." -Source ${CmdletName}
                            }
                        }
                    }
                }
                
                If ($addAppToRemoveList) {
                    Write-Log -Message "Adding application to list for removal: [$($installedApplication.DisplayName) $($installedApplication.Version)]." -Source ${CmdletName}
                    $removeMSIApplications.Add($installedApplication)
                }
            }
        }
        
        ## Build the hashtable with the options that will be passed to Execute-MSI using splatting
        [hashtable]$ExecuteMSISplat =  @{ Action = 'Uninstall'; Path = '' }
        If ($ContinueOnError) { $ExecuteMSISplat.Add( 'ContinueOnError', $ContinueOnError) }
        If ($Parameters) { $ExecuteMSISplat.Add( 'Parameters', $Parameters) }
        ElseIf ($AddParameters) { $ExecuteMSISplat.Add( 'AddParameters', $AddParameters) }
        If ($LoggingOptions) { $ExecuteMSISplat.Add( 'LoggingOptions', $LoggingOptions) }
        If ($LogName) { $ExecuteMSISplat.Add( 'LogName', $LogName) }
        If ($PassThru) { $ExecuteMSISplat.Add( 'PassThru', $PassThru) }
        If ($IncludeUpdatesAndHotfixes) { $ExecuteMSISplat.Add( 'IncludeUpdatesAndHotfixes', $IncludeUpdatesAndHotfixes) }
        
        If (($null -ne $removeMSIApplications) -and ($removeMSIApplications.Count)) {
            ForEach ($removeMSIApplication in $removeMSIApplications) {
                Write-Log -Message "Remove application [$($removeMSIApplication.DisplayName) $($removeMSIApplication.Version)]." -Source ${CmdletName}
                $ExecuteMSISplat.Path = $removeMSIApplication.ProductCode
                If ($PassThru) {
                    [psobject[]]$ExecuteResults += Execute-MSI @ExecuteMSISplat
                }
                Else {
                    Execute-MSI @ExecuteMSISplat
                }
            }
        }
        Else {
            Write-Log -Message 'No applications found for removal. Continue...' -Source ${CmdletName}
        }
    }
    End {
        If ($PassThru) { Write-Output -InputObject $ExecuteResults }
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}

##*===============================================
##* END FUNCTION LISTINGS
##*===============================================

##*===============================================
##* SCRIPT BODY
##*===============================================

If ($scriptParentPath) {
	Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] dot-source invoked by [$(((Get-Variable -Name MyInvocation).Value).ScriptName)]" -Source $appDeployToolkitExtName
}
Else {
	Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] invoked directly" -Source $appDeployToolkitExtName
}

##*===============================================
##* END SCRIPT BODY
##*===============================================