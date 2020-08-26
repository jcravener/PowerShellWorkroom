#Requires -Version 7
#
# Collection a cmdlets for working with JSON files and data

#---Reads in text file and outputs it as object if content is valid JSON
#
function Import-JhcJson {
    
    [CmdletBinding(DefaultParameterSetName = "Path")]
    param(
        [Parameter(Mandatory, ParameterSetName = "Path", Position = 0)]
        [System.String[]]
        $Path,
    
        [Parameter(Mandatory, ParameterSetName = "LiteralPath", ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath")]
        [System.String[]]
        $LiteralPath,

        [Parameter(ValueFromPipelineByPropertyName = $false)]
        [System.Int32]
        $Depth
    )

    begin { }

    process {
        $pathsToProcess = @()
        if ($PSCmdlet.ParameterSetName -eq "LiteralPath") {
            $pathsToProcess += Resolve-Path -LiteralPath $LiteralPath | Foreach-Object ProviderPath
        }
        if ($PSCmdlet.ParameterSetName -eq "Path") {
            $pathsToProcess += Resolve-Path $Path | Foreach-Object ProviderPath
        }
       
        foreach ($filePath in $pathsToProcess) {
            if (Test-Path -LiteralPath $filePath -PathType Container) {
                continue
            }
       
            try {
                # Read the file specified in $FilePath as a Byte array
                $stream = [System.IO.File]::ReadAllLines($filePath)                
                    
                if ($Depth) {
                    $stream | ConvertFrom-Json -Depth $Depth
                }
                else {
                    $stream | ConvertFrom-Json
                }
                    
            }
            catch [Exception] {
                $errorMessage = [Microsoft.PowerShell.Commands.UtilityResources]::FileReadError -f $FilePath, $_
                Write-Error -Message $errorMessage -Category ReadError -ErrorId "FileReadError" -TargetObject $FilePath
                return
            }
        }        
    }

    end { }
}

#---helper function for ConvertFrom-JhcUtilJsonTable
#
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

#---helper function for ConvertFrom-JhcUtilJsonTable
#
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

#---helper function for ConvertFrom-JhcUtilJsonTable
#
function intKeyHashToLists {
    param (
        [Parameter(Mandatory)]
        [System.Object]
        $obj
    )
    
    if (isType -obj $obj -typeName 'Hashtable') {
        if ($obj -and (allKeysDigits -h $obj)) {
            $a = @()
            foreach ($k in ( $obj.Keys | Sort-Object -Property @{e={[int]$_}} )) {
                $a += intKeyHashToLists -obj $obj.item($k)
            }

            return ,$a  #--- adding the comma forces this to retun an array even when it's a single element
        }
        else {
            $h = @{}
            foreach ($k in  $obj.Keys) {
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

#---Unflattens a the JSON hash table previously flattend by ConvertFrom-JhcUtilJsonTable cmdlet
#
function ConvertFrom-JhcJsonTable {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Collections.Hashtable]
        $jsonHashTable
    )
    begin {}
    
    process {
        foreach ($h in $jsonHashTable) {
            
            $m = @{}
            foreach ($k in $h.Keys) {
                $current = $m
                $val = $h[$k]
                $k = ($k -replace '\]', '') -replace '\[', '.'
                $bits = $k.split('.')
                $path = $bits[1..($bits.Count - 1)]

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
            
            intKeyHashToLists -obj $m
            #--python code had a buit about handling root units e.g. {'$empty': '{}'} - need to add that
        }
    }
    
    end {}
}

#---helper function for ConvertTo-JhcUtilJsonTable
#
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

#---Flattens a JSON document object into a key value table where keys are proper JSON paths corresponding to their value
#
function ConvertTo-JhcJsonTable {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Object[]]
        $jsonObj,
        [Parameter(Mandatory = $false)]
        [switch]
        $outputObjectTable = $false
    )

    begin {
        $rootNode = 'root'  
    }
    
    process {
        foreach ($o in $jsonObj) {
            $table = getNodes -job $o -path $rootNode

            $h = @{}
            $pat = '^' + $rootNode
            
            foreach ($i in $table) {
                foreach ($k in $i.keys) {
                    $h[$k -replace $pat, ''] = $i[$k]
                }
            }
            
            if ($outputObjectTable) {
                $h.Keys | ForEach-Object { New-Object -TypeName psobject -Property @{ 'Name' = $_; 'Value' = $h[$_] } } | Select-Object -Property Name, Value
            }
            else {
                $h
            }
        }   
    }
    end {}
}

#--Tests a passed in JSON file against a passes in json schema file
#
function Test-JhcJsonFile {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $JsonFile,
        [Parameter(Mandatory = $false)]
        [String]
        $SchemaFile
    )

    $j = get-content -Path $JsonFile -Raw
    if (-not $?) {
        $errMsg = "Had problems reading $JsonFile"
        throw $errMsg
        return
    }

    $s = get-content -Path $SchemaFile -Raw
    if (-not $?) {
        $errMsg = "Had problems reading $SchemaFile"
        throw $errMsg
        return
    }

    Test-Json -Json $j -Schema $s
}
