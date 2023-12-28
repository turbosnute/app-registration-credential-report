

$uri = 'https://graph.microsoft.com/v1.0/applications?$select=id,appId,displayName,description,keyCredentials'
$ownersUri = 'https://graph.microsoft.com/v1.0/applications/{id}/owners?$select=id,displayName,mail,userPrincipalName'

Write-Host "Getting all app registrations that have key credentials..."

$all_apps = do {
    $res = Invoke-MgGraphRequest -Uri $uri
    $res.value
    $URI = $res.'@odata.nextLink'
} while ($res.'@odata.nextLink')

Write-Host -f Cyan "[Done]" -NoNewline; Write-Host " Found $($all_apps.count) app registrations."

$apps_with_creds = $all_apps | Where-Object { $_.keyCredentials } # Unfortunately keyCredentials kan not be filtered in the Graph Uri.

Write-Host "$($apps_with_creds.count) of the apps got key credentials..."
Write-Host "Checking status and getting owners..."

foreach ($app in $apps_with_creds) {

        # Get and add owners ...
        $appOwnersUri = $ownersUri -replace '{id}', $app.id
        $appOwners = (Invoke-MgGraphRequest -Uri $appOwnersUri).Value
        $app['Owners'] = $appOwners
        
        # Foreach credential
        # ...
}


<#
.SYNOPSIS
    Takes in two datetimes and tells the percentage on the progress at the given moment to the endDateTime.
.DESCRIPTION
    Takes in two datetimes and tells the percentage on the progress at the given moment to the endDateTime. Returns 100 if the endDateTime has passed.
#>
function Get-TickTickPercent {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)][datetime]$startDateTime,
        [Parameter(Mandatory=$true)][datetime]$endDateTime
    )
    
    process {
        $start = $startDateTime.Ticks
        $now = ([datetime]::Now).Ticks - $start
        $end = $endDateTime.Ticks - $start

        $percentage = [int]($now / $end * 100)
        
        if ($percentage -gt 100) {
            $percentalge = 100
        }

        $percentage
    }
}
