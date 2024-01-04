param(
    [Parameter(Mandatory=$true)][string]$FilePath
)

Connect-MgGraph

#
# Variable initializations
#

$uri = 'https://graph.microsoft.com/v1.0/applications?$select=id,appId,displayName,description,keyCredentials,passwordCredentials'
$ownersUri = 'https://graph.microsoft.com/v1.0/applications/{id}/owners?$select=id,displayName,mail,userPrincipalName'

#
# Functions 
#


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


<#
.SYNOPSIS
    Exports a html report of the app registrations.
.DESCRIPTION
    Exports a html report of the app registrations.
#>
function Export-AppRegistrationCertificateReport {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]$apps_with_creds
    )
    
    begin {
    }
    
    process {
        $html = New-Object System.Collections.Generic.List[System.String]
        $html.Add('<html>')
        $html.Add('<head>')
        $html.Add('<title>App Registration Report</title>')
        $html.Add('<style>')
        #$html.Add('progress { background-color: #f3f3f3; border: 0; height: 18px; border-radius: 9px; }')
        $html.Add('table { padding: 5px; margin: 5px; }')
        $html.Add('.cert { background-color:#ffd899; }')
        $html.Add('.sec { background-color:#f0b6b6; }')
        $html.Add('body { font-family: Arial, Helvetica, sans-serif; }')
        $html.Add('</style>')
        $html.Add('<body>')

        foreach ($app in $apps_with_creds) {
            $html.Add("<h1>$($app.displayName)</h1>")
            $html.Add("<p><strong>id: </strong>$($app.id)<br />")
            $html.Add("<strong>App id: </strong>$($app.AppId)<br />")
            if ($null -ne $app.decription -and $app.description -ne "") {
                $html.Add("<strong>description: </strong>$($app.description)<br />")
            }
            if ($null -ne $app.Owners.mail -and $app.Owners.mail -ne "") {
                $ownerlist = New-Object System.Collections.Generic.List[System.String]
                foreach ($Owner in $app.Owners) {
                    $ownerlist.Add("<a href='mailto:$($Owner.mail)'>$($Owner.displayName)</a>")
                }
                $owenerlistString = $ownerlist -join ', '
                $html.Add("<strong>Owners: </strong>$owenerlistString<br />")
            }
            $html.Add('</p>')
            # Client Secrets
            foreach ($sec in $app.passwordCredentials) {
                $html.Add('<table class="sec">')
                $html.Add("<tr><th colspan='2'>Client Secret</th></tr>")
                $html.Add("<tr><th>Name</th><td>$($sec.displayName)</td></tr>")
                $html.Add("<tr><th>KeyId</th><td>$($sec.keyId)</td></tr>")
                if ($sec.Expired) {
                    $html.Add("<tr><th>Valid until</th><td><span style=`"color:red; font-weight: bold;`">$($sec.endDateTime.toString('yyyy-MM-dd HH:mm:ss'))</span></td></tr>")
                } else {
                    $html.Add("<tr><th>Valid until</th><td>$($sec.endDateTime.toString('yyyy-MM-dd HH:mm:ss'))</td></tr>")
                }
                $Percentage = $sec.Percentage
                $certlifetime = "<progress value='$Percentage' max='100'></progress>"
                $html.Add("<tr><th>Lifetime</th><td>$certlifetime</td></tr>")
                $html.Add('</table>')
            }

            # Certificates
            foreach ($key in $app.keyCredentials) {
                $html.Add('<table class="cert">')
                $html.Add("<tr><th colspan='2'>Certificate</th></tr>")
                $html.Add("<tr><th>Name</th><td>$($key.displayName)</td></tr>")
                $html.Add("<tr><th>KeyId</th><td>$($key.keyId)</td></tr>")
                if ($key.Expired) {
                    $html.Add("<tr><th>Valid until</th><td><span style=`"color:red; font-weight: bold;`">$($key.endDateTime.toString('yyyy-MM-dd HH:mm:ss'))</span></td></tr>")
                } else {
                    $html.Add("<tr><th>Valid until</th><td>$($key.endDateTime.toString('yyyy-MM-dd HH:mm:ss'))</td></tr>")
                }
                $Percentage = $key.Percentage
                $certlifetime = "<progress value='$Percentage' max='100'></progress>"
                $html.Add("<tr><th>Lifetime</th><td>$certlifetime</td></tr>")
                $html.Add('</table>')
            }
            
        }

    }
    
    end {
        $html
    }
}

#
# Script
#

Write-Host "Getting all app registrations that have key credentials..."

$all_apps = do {
    $res = Invoke-MgGraphRequest -Uri $uri
    $res.value
    $URI = $res.'@odata.nextLink'
} while ($res.'@odata.nextLink')

Write-Host -f Cyan "[Done]" -NoNewline; Write-Host " Found $($all_apps.count) app registrations."

$apps_with_creds = $all_apps | Where-Object { $_.keyCredentials -or $_.passwordCredentials } # Unfortunately keyCredentials kan not be filtered in the Graph Uri.

Write-Host "$($apps_with_creds.count) of the apps got certificates or client secrets..."
Write-Host "Checking status and getting owners..."

foreach ($app in $apps_with_creds) {

        # Get and add owners ...
        $appOwnersUri = $ownersUri -replace '{id}', $app.id
        $appOwners = (Invoke-MgGraphRequest -Uri $appOwnersUri).Value
        $app['Owners'] = $appOwners
        
        # Foreach client secret
        foreach ($sec in $app.passwordCredentials) {
            $sec['Expired'] = [bool]((Get-Date) -gt $sec.endDateTime)
            $percentage = Get-TickTickPercent -startDateTime $sec.startDateTime -endDateTime $sec.endDateTime
            $sec['Percentage'] = $percentage
        }

        # Foreach certificate credential
        foreach ($cert in $app.keyCredentials) {
            $cert['Expired'] = [bool]((Get-Date) -gt $cert.endDateTime)
            
            $percentage = Get-TickTickPercent -startDateTime $cert.startDateTime -endDateTime $cert.endDateTime
            $cert['Percentage'] = $percentage
        }
}


Export-AppRegistrationCertificateReport -apps_with_creds $apps_with_creds | Out-File -FilePath $FilePath -Encoding utf8; 
Write-Host "Saved to '$FilePath'"