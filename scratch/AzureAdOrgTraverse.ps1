#Requires -Module AzureAD

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [String]
    $SearchString
)

$ct = 0

function orgtrav
{
    [CmdletBinding()]
    param (
        [String]
        $MailNickName
    )

    $a = @()

    if($MailNickName -eq $null)
    {
        return $null
    }

    foreach( $o in Get-AzureADUser -SearchString $MailNickName | Get-AzureADUserDirectReport )
    {
        $ct++

        Write-Progress -Activity "Looking up AAD user $($o.Displayname)" -Status "Searching $('.' * $a.count)"
        $m = Get-AzureADUserManager -ObjectId $o.ObjectId
        $a += $o | select-object -property @{name = 'Manager'; expression = {$m.DisplayName}}, Displayname, MailNickName, JobTitle, Department, PhysicalDeliveryOfficeName
        orgtrav($o.MailNickName)
    }

    return $a
}

#Connect-AzureAD
$mnn = $SearchString
$l = orgtrav($mnn)
($l.Count-1)..0 | %{ $i = $_; $l[$i] }
