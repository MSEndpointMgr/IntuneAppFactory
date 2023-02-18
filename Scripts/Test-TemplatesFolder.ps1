<#
.SYNOPSIS
    This script validates that the required files in the Templates folder and both sub-folders Application and Framework are present, to ensure the pipeline will execute successfully.

.DESCRIPTION
    This script validates that the required files in the Templates folder and both sub-folders Application and Framework are present, to ensure the pipeline will execute successfully.

    Application folder must contain the following files:
    - ..\App.json
    - ..\Deploy-Application.ps1
    - ..\Detection.ps1
    - ..\latest.json

    Framework folder must contain the following files and folders:
    - ..\Source\AppDeployToolkit\<related-files-and-folders>
    - ..\Source\Files
    - ..\Source\SupportFiles
    - ..\Source\Deploy-Application.exe
    - ..\Source\Deploy-Application.config.exe
    - ..\Source\Deploy-Application.ps1
    - ..\Icon.png

.EXAMPLE
    .\Test-TemplatesFolder.ps1

.NOTES
    FileName:    Test-TemplatesFolder.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2022-11-16
    Updated:     2022-11-16

    Version history:
    1.0.0 - (2022-11-16) Script created
#>
Process {
    # Initialize variables
    $TemplatesFolderNames = @("Application", "Framework")
    $ApplicationFolderFileNames = @("App.json", "Deploy-Application.ps1", "Detection.ps1", "latest.json")
    $FrameworkSourceFolderNames = @("AppDeployToolkit")
    $FrameworkSourceFileNames = @("Deploy-Application.exe", "Deploy-Application.exe.config", "Deploy-Application.ps1")
    $FrameworkFolderFileNames = @("Icon.png")

    # Define source directory variable
    $SourceDirectory = $env:BUILD_SOURCESDIRECTORY

    # Define variable that controls whether the pipeline is allowed to continue or not depending on the required files are present
    $PipelineAllowed = $true

    # Verify that Templates folder is present
    $TemplatesFolderPath = Join-Path -Path $SourceDirectory -ChildPath "Templates"
    if (Test-Path -Path $TemplatesFolderPath) {
        Write-Output -InputObject "Testing for Templates folder path in source directory"

        # Verify each required subfolders in the Templates folder are present
        foreach ($TemplatesFolderName in $TemplatesFolderNames) {
            # Determine the path to the current subfolder of the Templates folder
            $CurrentTemplateFolderNamePath = Join-Path -Path $TemplatesFolderPath -ChildPath $TemplatesFolderName

            # Verify the current subfolder exist
            if (Test-Path -Path $CurrentTemplateFolderNamePath) {
                switch ($TemplatesFolderName) {
                    "Application" {
                        Write-Output -InputObject "Testing for $($TemplatesFolderName) subfolder required files"

                        foreach ($ApplicationFolderFileName in $ApplicationFolderFileNames) {
                            # Determine the path to the current required file in the application folder
                            $CurrentApplicationFolderFileNamePath = Join-Path -Path $CurrentTemplateFolderNamePath -ChildPath $ApplicationFolderFileName

                            if (-not(Test-Path -Path $CurrentApplicationFolderFileNamePath)) {
                                Write-Warning -Message "Could not detect the $($ApplicationFolderFileName) file in the $($TemplatesFolderName), expected at: $($CurrentApplicationFolderFileNamePath)"
                                $PipelineAllowed = $false
                            }
                        }
                    }
                    "Framework" {
                        Write-Output -InputObject "Testing for $($TemplatesFolderName) subfolder required folder and files"

                        foreach ($FrameworkSourceFolderName in $FrameworkSourceFolderNames) {
                            # Determine the path to the current required folder in the framework source folder
                            $CurrentFrameworkSourceFolderPath = Join-Path -Path $CurrentTemplateFolderNamePath -ChildPath "Source\$($FrameworkSourceFolderName)"

                            if (-not(Test-Path -Path $CurrentFrameworkSourceFolderPath)) {
                                Write-Warning -Message "Could not detect the $($FrameworkSourceFolderName) file in the $($TemplatesFolderName), expected at: $($CurrentFrameworkSourceFolderPath)"
                                $PipelineAllowed = $false
                            }
                        }

                        foreach ($FrameworkSourceFileName in $FrameworkSourceFileNames) {
                            # Determine the path to the current required file in the framework source folder
                            $CurrentFrameworkSourceFolderFilePath = Join-Path -Path $CurrentTemplateFolderNamePath -ChildPath "Source\$($FrameworkSourceFileName)"

                            if (-not(Test-Path -Path $CurrentFrameworkSourceFolderFilePath)) {
                                Write-Warning -Message "Could not detect the $($FrameworkSourceFileName) file in the $($TemplatesFolderName), expected at: $($CurrentFrameworkSourceFolderFilePath)"
                                $PipelineAllowed = $false
                            }
                        }

                        foreach ($FrameworkFolderFileName in $FrameworkFolderFileNames) {
                            # Determine the path to the current required file in the framework folder
                            $CurrentFrameworkFolderFilePath = Join-Path -Path $CurrentTemplateFolderNamePath -ChildPath $FrameworkFolderFileName

                            if (-not(Test-Path -Path $CurrentFrameworkFolderFilePath)) {
                                Write-Warning -Message "Could not detect the $($FrameworkFolderFileName) file in the $($TemplatesFolderName), expected at: $($CurrentFrameworkFolderFilePath)"
                                $PipelineAllowed = $false
                            }
                        }
                    }
                }
            }
            else {
                Write-Warning -Message "Could not detect the $($TemplatesFolderName) folder, expected at: $($TemplatesFolderPath)"
                $PipelineAllowed = $false
            }
        }
    }
    else {
        Write-Warning -Message "Could not detect the Templates folder, expected at: $($TemplatesFolderPath)"
        $PipelineAllowed = $false
    }

    # Handle next stage execution or not if no applications are allowed to be processed
    if ($PipelineAllowed -eq $false) {
        # Don't allow pipeline to continue
        Write-Output -InputObject "Required files are missing, aborting pipeline"
        Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
    }
    else {
        # Allow pipeline to continue
        Write-Output -InputObject "Required files are present, pipeline can continue"
        Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]true"
    }
}