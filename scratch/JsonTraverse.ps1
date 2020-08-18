#Requires -version 7.0

param (
    [Parameter(Mandatory)]
    [System.String]
    $Path
)

$obj = Get-Content -Path $Path | ConvertFrom-Json
if (-not $?) {
    $errMsg = "Had problems reading in $Path"
    throw $errMsg
}

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

function getNodeValue {
    param (
        [Parameter(Mandatory)]
        [System.Object]
        $job,
        [Parameter(Mandatory)]
        [System.String]
        $name
    )
    $a = $name -split '\.'
    $p = $null
    $cmd = $null
    $rob = $null

    if ($a[0] -match '\[') {
        $a[0] = $a[0] -replace '^.*\[', '['
        
        $p =  $a -join '.'
        $cmd = "`$job" + $p
    }
    else {
        $e = $a.Length - 1
        $p = $a[1..$e] -join '.'
        $cmd = "`$job" + '.' + $p
    }
    $rob = Invoke-Expression -Command $cmd

    return $rob
}

$table = getNodes -job $obj -path "rt"

$ht = @{}

foreach ($i in $table) {
    foreach ($k in $i.keys) {
        $ht[$k] = $i[$k]
    }
}

foreach($k in $ht.Keys){
    getNodeValue -job $obj -name $k
}

# $ht

# getNode -job $obj -name $($ht.Keys | Select-Object -First 1)


# foreach($k in $ht.Keys) {
#     Write-Verbose -Message $k -Verbose
#     getNode -job $obj -name $k; ''
# }

