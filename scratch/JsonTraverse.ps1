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

    if($t.Name -eq 'PSCustomObject') {
        foreach($m in Get-Member -InputObject $job -MemberType NoteProperty) {
            getNodes -job $job.($m.Name) -path ($path + '.' + $m.Name)
        }
        
    }elseif ($t.Name -eq 'Object[]') {
        foreach($o in $job) {
            getNodes -job $o -path ($path + "[$ct]")
            $ct++
        }
    }
    else {
        $h[$path] = $job
        $h
    }
}

function getNode {
    param (
        [Parameter(Mandatory)]
        [System.Object]
        $job,
        [Parameter(Mandatory)]
        [System.String]
        $name
    )

    $a = $name -split '\.'

    # foreach($i in $a[1..$a.Length]) {
    #     if($i -match '\['){
    #         $aa = $i -split '\['
    #         $ii =  $aa[0]

    #         $aa = $aa -split '`]'
    #         $idx = $aa[0]

    #         return $job.$i[$idx] | ConvertTo-Json -Depth 10
    #     }
    # }

    return $a
}

$table = getNodes -job $obj -path 'root'
$ht = @{}

foreach($i in $table) {
    foreach($k in $i.keys) {
        $ht[$k] = $i[$k]
    }
}

$ht

# foreach($k in $ht.Keys) {
#     Write-Verbose -Message $k -Verbose
#     getNode -job $obj -name $k; ''
# }

