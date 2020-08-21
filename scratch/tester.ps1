#Requires -version 7
#
# POC scritp to unflattent a JSON table.  Take in a hashtable produced by ConvertTo-JhcUtilJsonTable from JhcUtil module
# Most of the functionality is based on this code: https://github.com/simonw/json-flatten/blob/master/json_flatten.py
#

param (
    [Parameter(Mandatory)]
    [System.Collections.Hashtable]
    $h
)

function allKeysDigits {
    param (
        [Parameter(Mandatory)]
        [System.Collections.Hashtable]
        $h
    )

    foreach($k in $h.Keys) {
        
        if($k -match '^0\d') {
            return $false
        }
        
        if($k -notmatch '^\d+$') {
            return $false  
        }
    }
    return $true
}

function intKeyHashToLists {
    param (
        [Parameter(Mandatory)]
        [System.Collections.Hashtable]
        $h
    )
}

$m = @{}
foreach ($k in $h.Keys) {
    $current = $m
    $val = $h[$k]
    $k = ($k -replace '\]', '') -replace '\[', '.'
    $bits = $k.split('.')
    $path = $bits[1..($bits.Count-1)]
    # $lastKey = $bits[-1]

    $count = 0
    
    foreach($bit in $path) {
        $count++
        if($v = $current.item($bit)) {
            $current[$bit] = $v
        }
        else {
            if($count -eq $path.Count) {
                $current[$bit] = $val
            }
            else {
                $current[$bit] = @{}
            }
        }
        $current = $current[$bit]
    }
}
$m

