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

#--- main -----------------------------------------------------------------------------

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

    $o = New-Object -TypeName psobject
    foreach ($kk in $hh.Keys) {

        $prop = $kk -split '\.'

        if ($prop[1] -match '\[') {
            $n = ($prop[1] -split '\[')[0]
            if ($n -notin $o.PSobject.Properties.Name) {
                Add-Member -InputObject $o -MemberType NoteProperty -Name $n -Value @()
            }
        }
        else {
            $n = $prop[1]
            if ($n -notin $o.PSobject.Properties.Name) {
                Add-Member -InputObject $o -MemberType NoteProperty -Name $n -Value $null
            }
            if ($prop.count -eq 2) {
                $o.$n = $hh[$kk]
            }
        }

    }
    $o | ConvertTo-Json -Depth 20

    '-' * 100
}


