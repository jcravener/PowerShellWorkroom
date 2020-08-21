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

function isType {
    param (
        [Parameter(Mandatory)]
        [System.Object]
        $obj,
        [Parameter(Mandatory)]
        [ValidateSet('Hashtable', 'Object[]')]
        [System.String]
        $typeName
    )
    
    $t = $obj.GetType()

    if ($t.Name -eq $typeName) {
        return $true
    }
    return $false
}

function allKeysDigits {
    param (
        [Parameter(Mandatory)]
        [System.Collections.Hashtable]
        $h
    )

    foreach ($k in $h.Keys) {
        
        if ($k -match '^0\d') {
            return $false
        }
        
        if ($k -notmatch '^\d+$') {
            return $false  
        }
    }
    return $true
}

function intKeyHashToLists {
    param (
        [Parameter(Mandatory)]
        [System.Object]
        $obj
    )
    
    if (isType -obj $obj -typeName 'Hashtable') {
        if ($obj -and (allKeysDigits -h $obj)) {
            #---do something
            #-- here you return a list based on a recursive call
            $a = @()
            foreach ($k in ($obj.Keys | Sort-Object) ) {
                $a += intKeyHashToLists -obj $obj.item($k)
            }
            return $a
        }
        else {
            #---do something else
            #-- here you return a hash table based on a recursive call
            $h = @{}
            foreach ($k in $obj.Keys) {
                $h[$k] = intKeyHashToLists -obj $obj.item($k)
            }
            return $h
        }
    }
    elseif (isType -obj $obj -typeName 'Object[]') {
        return ( $obj | ForEach-Object { intKeyHashToLists -obj $_ } )
    }
    else {
        return $obj
    }
}

$m = @{}
foreach ($k in $h.Keys) {
    $current = $m
    $val = $h[$k]
    $k = ($k -replace '\]', '') -replace '\[', '.'
    $bits = $k.split('.')
    $path = $bits[1..($bits.Count - 1)]
    # $lastKey = $bits[-1]

    $count = 0
    
    foreach ($bit in $path) {
        $count++
        if ($v = $current.item($bit)) {
            $current[$bit] = $v
        }
        else {
            if ($count -eq $path.Count) {
                $current[$bit] = $val
            }
            else {
                $current[$bit] = @{}
            }
        }
        $current = $current[$bit]
    }
}
# $m
intKeyHashToLists -obj $m

