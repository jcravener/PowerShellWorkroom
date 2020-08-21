#Requires -Version 7
#Requires -Module JhcUtil

#---
# Description: POC for JSON overlay feature
#
#---


#--- setup ----------------------------------------------------------------------------

$viewRoot = $Script:mustacheRoot = Split-Path -Path $PSCommandPath -Parent
$viewRoot += '\..\..\..\..\scratch\saasView'

$h = @{}

foreach ($i in (Get-ChildItem -Path $viewRoot | Where-Object -Property Extension -Match 'json')) {
    $h[$i.Name] = Import-JhcJson -Path $i.FullName
}

#--- functions ------------------------------------------------------------------------

function buildExtendsStack {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Object]
        $job,
        [Parameter(Mandatory)]
        [System.Collections.Hashtable]
        $jsonTable,
        [Parameter(Mandatory)]
        [System.Collections.Stack]
        $stack
    )

    $stack.Push($job)

    if (-not $job.extends) {
        return $stack
    }
    else {
        buildExtendsStack -job $jsonTable[$job.extends] -jsonTable $jsonTable -stack $stack
    }
}

function buildObject {
    param (
        [Parameter(Mandatory)]
        [System.Object]
        $obj,
        [Parameter(Mandatory)]
        [System.Object]
        $k,
        [Parameter(Mandatory)]
        [System.Object]
        $v
    )

    $a = $k -split '\.'

    for($i = 0; $i -lt $a.count; $i++) {
        if($i -eq 0) {
            continue
        }
        if($a[$i] -match '\[') {
            $propName = ($a[$i] -split '\[')[0]
        }
        else {
            $propName = $a[$i]
        }
    }
}
#--- main -----------------------------------------------------------------------------

$m = @{}
foreach ($k in $h.Keys) {
    $stk = [System.Collections.Stack]::new()
    buildExtendsStack -job $h[$k] -jsonTable $h -stack $stk | Out-Null

    $hh = @{}
    $n = $stk.Count
    foreach ($i in (1..$n)) {        
        foreach ($ii in ($stk.Pop() | ConvertTo-JhcUtilJsonTable)) {
            if ($ii.Value -ne 'Inherit') {
                $hh[$ii.Key] = $ii.Value
            }
        }
    }
    # $hh.Keys | Sort-Object | ForEach-Object{ "$($_),$($hh[$_])"} | ConvertFrom-Csv -Header 'Key', 'Value'

    $curr = @{}
    $prev = @{}
    $prevKey = $null
    foreach ($kk in $hh.Keys) {
        $a = $kk -split '\.'
        foreach ($p in $a[1..($a.Count-1)]) {
            $curr = @{$p = $null}
            if($m.Count -eq 0){
                $m = $curr
            }
            
            if($prevKey -and $prev) {
                $prev[$prevKey] = $curr

            }
            $prev = $curr
            $prevKey = $p             
        }
    }
    $m

    '-' * 100
}


