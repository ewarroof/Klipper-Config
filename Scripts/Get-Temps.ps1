<#        
        .SYNOPSIS
        Polls Moonraker Extruder and Heater_Bed printer objects for their current temperature, then outputs maximum, minimum and average values.

        .DESCRIPTION
        Polls Moonraker Extruder and Heater_Bed printer objects on the provided poll rate and poll length (length of time to probe).

        Script can be used to investigate how accurate your extruder and/or heater bed temperature probes are for a given length of time.
        E.G. It could be used to investigate whether your probe is dying as it may report a minimum (or maximum) value that is not within the accuracy of the probe.

        This has been tested on a Raspberry Pi 3B with a poll rate of 1 second and it caused only a 1% increase in Moonraker load (3% to 4%). Therefore you could
        probably go with a faster poll rate for more accuracy - 1 second was used as this looks to be the rate of Fluidd/Mainsail's graphs.

        Moonraker Print Objects documentation:
        https://github.com/Arksine/moonraker/blob/9d7baa1eb643b2b41aad7eb0b116c5b16a5007ee/docs/printer_objects.md

        .PARAMETER PollRate
        The poll rate in seconds. Default is 1 second

        .PARAMETER PollLength
        How long to poll for. Default is 10 minutes

        .PARAMETER APIKey
        The API key for your Moonraker/Klipper instance

        .PARAMETER IPAddress
        IP address of your Moonraker/Klipper instance

        .EXAMPLE
        .\Get-Temps.ps1 -APIKey "123456" -IPAddress "192.168.0.200" -PollLength 15
        Polls the print for 15 minutes every 1 second (default Pollrate)

        .CHANGELOG
        NAME - Date dd/mm/yyyy - Change - Version
        EwarRoof(Discord: ewarwoowar#3210) - 14/06/2022 - Initial Creation - 1.0.0

        .TODO
            - Implement accuracy calculator. E.G. Temperature is within +/- % of target temperature. Pull target from printer objects instead of parameterizing
#>
param (
    [int32]$PollRate = 1,
    [int32]$PollLength = 10,
    [parameter (Mandatory = $true)]
    [String]$APIKey,
    [parameter (Mandatory = $true)]
    [String]$IPAddress
)
##*~~~~~~~~~~~~~~~~~~~~~~~~~~~
##* Script Variables
##*~~~~~~~~~~~~~~~~~~~~~~~~~~~
#region Script Variables
$headers =  @{'X-Api-Key' = $APIKey} # Create Headers of Invoke-WebRequest
$ProgressPreference = "SilentlyContinue" # Hide Invoke-WebRequest Progress prompt
#endregion Script Variables

##*~~~~~~~~~~~~~~~~~~~~~~~~~~~
##* Script Body
##*~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Declare Timespan to run the loop for in minutes (New-TimeSpan rounds values, E.G. 3.5 minutes will be 4)
$timeout = new-timespan -Minutes $PollLength

## Start Timer for loop
$sw = [diagnostics.stopwatch]::StartNew()

## Loop every PollRate (Seconds) until timer reaches PollLength
$Pool = $(while ($sw.elapsed -lt $timeout) {
    $results = ((Invoke-WebRequest -Uri "http://$IPAddress/printer/objects/query?&extruder&heater_bed" -Method Get -Headers $headers).Content |convertfrom-json).result.status

    [PSCustomObject]@{
    heater_bed      = $results.extruder.temperature
    Extruder        = $results.heater_bed.temperature
    }

    Start-Sleep $PollRate
})

## Output data
$ExtruderStats = $Pool | Measure-Object -Property "extruder" -Maximum -Minimum -Average | select maximum,minimum,average
Write-Output "Extruder:$($ExtruderStats| fl | Out-string)"

$BedStats = $Pool | Measure-Object -Property "heater_bed" -Maximum -Minimum -Average | select maximum,minimum,average
Write-Output "Heater Bed:$($BedStats| fl | Out-string)"
