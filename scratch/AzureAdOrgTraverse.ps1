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
        Write-Progress -Activity "Searching AAD" -Status "User: $($o.Displayname)"
        $m = Get-AzureADUserManager -ObjectId $o.ObjectId
        $a += $o | select-object -property @{name = 'Manager'; expression = {$m.DisplayName}}, Displayname, MailNickName, JobTitle
        orgtrav($o.MailNickName)
    }

    return $a
}

#Connect-AzureAD
$mnn = $SearchString
orgtrav($mnn)
