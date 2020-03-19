#Requires -Module AzureAD

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [String]
    $SearchString
)


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
        Write-Progress -Activity "Searching AAD" -Status "User: $($o.Displayname)$jo    "
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
