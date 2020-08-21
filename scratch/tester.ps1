
param (
    [Parameter(Mandatory)]
    [System.Collections.Hashtable]
    $h
)

# $a = '.person.pets[0].color.black.toy.foo' -split '\.'
# $b = '.john.harold.cravener' -split '\.'
# $z = '.john.is.content' -split '\.'

# $h = @{'.person.pets[0].color.black.toy.foo.foo' = 'val1'; '.john.harold.cravener' = 'val2'; '.john.is.content' = 'val3' }

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
