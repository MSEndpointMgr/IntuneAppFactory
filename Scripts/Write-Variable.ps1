<#
.SYNOPSIS
    This script outputs references system and build variables used during the pipeline execution.

.DESCRIPTION
    This script outputs references system and build variables used during the pipeline execution.

.EXAMPLE
    .\Write-Variable.ps1

.NOTES
    FileName:    Write-Variable.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2022-11-29
    Updated:     2022-11-29

    Version history:
    1.0.0 - (2022-11-29) Script created
#>
Process {
    # Output referenced variables
    Write-Output -InputObject "Pipeline workspace directory: $($env:PIPELINE_WORKSPACE)"
    Write-Output -InputObject "Build binaries directory: $($env:BUILD_BINARIESDIRECTORY)"
    Write-Output -InputObject "Build artifacts staging directory: $($env:BUILD_ARTIFACTSTAGINGDIRECTORY)"
}