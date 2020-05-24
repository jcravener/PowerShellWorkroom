#
# Module file for module 'JhcKv'
#
# Generated by: john cravever
#
$Global:JhcKvManifest = "$env:APPDATA\jkman.json"
$Global:jsonDepth = 100
$Global:encoding = 'ascii'
$Script:subIndex = 2 
$Script:rgIndex = 4
$Script:rsIndex = -1
function getManifest {
    $obj
    if(Test-Path -Path $Global:JhcKvManifest) {
        
        $obj = Get-Content -Path $Global:JhcKvManifest | ConvertFrom-Json
    }
    else {
        Write-Warning -Message "No Key Vault manifest found..."
    }        
    
    return $obj
}

function Get-DefinedVault {
    
    $obj = getManifest
    $a
    if(-not $?) {
        $Error[0]
    }
    $a = $obj.ResourceId -split '/'
    $rt = "$($a[$Script:subIndex]),$($a[$Script:rgIndex]),$($a[$Script:rsIndex])" | ConvertFrom-Csv -Header 'Subscription', 'ResourceGroupName', 'KeyVaultName'

    return $rt
}

function Write-Manifest {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource]
        $keyVaultResourceObj
    )

    begin{}
    process{
        $keyVaultResourceObj | ConvertTo-Json -Depth $Global:jsonDepth | Out-File -FilePath $Global:JhcKvManifest -Encoding $Global:encoding -Verbose
    }
    end{}
}

function processSecTag {
    param (
        [Parameter(Mandatory)]
        [System.Object]
        $secObj
    )

    $o

    if($secObj.Tags.info) {
        $o = $secObj.Tags.info | ConvertFrom-Json -Depth $Global:jsonDepth
    }
    else {
        "," | ConvertFrom-Csv -Header 'ComputerName', 'Notes'
    }
    return $o
}

function Get-SecretList {
    [OutputType('JhcKv.SecretList')]
    [CmdletBinding()]
    param ()  #--This is needed or else OutputType wont map back to the types.ps1xml
    
    $obj = getManifest
    $seclst 
    $seclst = Get-AzResource -ResourceId $obj.ResourceId | Get-AzKeyVaultSecret
    $tg

    foreach($s in $seclst) {
        $tg = processSecTag -secObj $s
        Add-Member -InputObject $s -MemberType NoteProperty -Name 'ComputerName' -Value $tg.ComputerName
        Add-Member -InputObject $s -MemberType NoteProperty -Name 'Notes' -Value $tg.Notes
        $s
    }
}

function Get-SecretValue {
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName=$true)]
        [System.String]
        $Name   
    )
    begin {
        $sec
        $obj = getManifest
    }
    process {
        $sec = Get-AzKeyVaultSecret -ResourceId $obj.ResourceId -Name $Name
    }
    end {
        $sec | Select-Object -Property Name, Created, Updated, SecretValue
    }
}

function Get-Dummy {
    [OutputType('JhcKv.Dummy')]
    [CmdletBinding()]
    [CmdletBinding()]
    param (
        [Parameter()]
        [System.String]
        $john
    )
    $msg = 'this is a message'

    New-Object -TypeName psobject -Property @{'name' = 'Dummy'; 'msg' = $msg}
}