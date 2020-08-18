#Requires -version 7.0

#--- param --------------------------------------------------------------------------------------

param (
    [Parameter(Mandatory)]
    [System.String]
    $Path
)

#--- setup --------------------------------------------------------------------------------------

$obj = Get-Content -Path $Path | ConvertFrom-Json
if (-not $?) {
    $errMsg = "Had problems reading in $Path"
    throw $errMsg
}

#--- functions ----------------------------------------------------------------------------------

function getNodes {
    param (
        [Parameter(Mandatory)]
        [System.Object]
        $job,
        [Parameter(Mandatory)]
        [System.String]
        $path
    )

    $t = $job.GetType()
    $ct = 0
    $h = @{}

    if ($t.Name -eq 'PSCustomObject') {
        foreach ($m in Get-Member -InputObject $job -MemberType NoteProperty) {
            getNodes -job $job.($m.Name) -path ($path + '.' + $m.Name)
        }
        
    }
    elseif ($t.Name -eq 'Object[]') {
        foreach ($o in $job) {
            getNodes -job $o -path ($path + "[$ct]")
            $ct++
        }
    }
    else {
        $h[$path] = $job
        $h
    }
}

function getJsonTable {
    param (
        [Parameter(Mandatory)]
        [System.Object]
        $job,
        [Parameter(Mandatory)]
        [System.String]
        $rootNode
    )
    $table = getNodes -job $obj -path $rootNode

    $h = @{}
    $pat = '^' + $rootNode
    
    foreach ($i in $table) {
        foreach ($k in $i.keys) {
            $h[$k -replace $pat, ''] = $i[$k]
        }
    }
    return $h
}

#--- main ---------------------------------------------------------------------------------------

$ht = getJsonTable -job $obj -rootNode 'rt'

foreach( $k in $ht.Keys) {
    $cmd = '$obj' + $k
    Invoke-Expression -Command $cmd
}
