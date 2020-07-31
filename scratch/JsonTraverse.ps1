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

    if($t.Name -eq 'PSCustomObject') {
        foreach($m in Get-Member -InputObject $job -MemberType NoteProperty) {
            #$path = $path + '.' + $m.Name
            getNodes -job $job.($m.Name) -path ($path + '.' + $m.Name)
        }
        
    }elseif ($t.Name -eq 'Object[]') {
        foreach($o in $job) {
            #$path += '[i]'
            getNodes -job $o -path ($path + "[$ct]")
            $ct++
            #$path = ''
        }
    }
    else {
        "$path $job"
        $path = ''
    }
}
getNodes -job $obj -path 'root'
