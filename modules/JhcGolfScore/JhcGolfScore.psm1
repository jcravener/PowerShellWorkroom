
$Script:scoreCardDir = (Split-Path -Path $PSCommandPath -Parent) + '\scorecards'
$Script:jsonDepth = 4

enum golferType {
    man = 1
    woman = 2
}

class golfer {
    [string]$FirstName
    [string]$LastName
    [golferType]$GolferType
    [decimal]$Index

    golfer (
        [string]$fn,
        [string]$ln,
        [golferType]$gt,
        [decimal]$i
    ) {
        $this.FirstName = $fn
        $this.LastName = $ln
        $this.GolferType = $gt
        $this.index = $i
    }
}

function Get-CourseList {
    $gc = Get-ChildItem -Path $Script:scoreCardDir
    $gc | Select-Object -Property @{Name = 'Name'; Expression = { $_.BaseName } }
}

function Get-ScoreCard {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        [ValidateSet('AldarraGC')]
        $CourseName
    )

    $jf = Get-ChildItem -Path $Script:scoreCardDir  | Where-Object -Property BaseName -EQ $CourseName
    if (-not $?) {
        $errMsg = "Could not find score card file for $CourseName"
        throw $errMsg
        return
    }
    $jo = Get-Content -Path $jf.FullName | ConvertFrom-Json
    if (-not $?) {
        $errMsg = "Had problems reading score card file for $CourseName"
        throw $errMsg
        return
    }

    return $jo
}

function New-Golfer {
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ParameterSetName = "valuePropery")]
        [string]
        $FirstName,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ParameterSetName = "valuePropery")]
        [string]
        $LastName,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ParameterSetName = "valuePropery")]
        [golferType]
        [ValidateSet('man', 'woman')]
        $GolferType,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ParameterSetName = "valuePropery")]
        [decimal]
        $Index,
        [Parameter(Mandatory = $true, ValueFromPipeline, ParameterSetName = "valueObject")]
        [System.Object[]]
        $ScoreCardRecord
    )

    begin {
        $rt = @()
    }
    process {
        if ($ScoreCardRecord) {
            foreach ($r in $ScoreCardRecord) {
                $rt += New-Object -TypeName golfer -ArgumentList $r.FirstName, $r.LastName, $r.GolferType, $r.Index
            }
        }
        else {
            $rt = New-Object -TypeName golfer -ArgumentList $FirstName, $LastName, $GolferType, $Index                
        }
    }
    end {
        return $rt
    }
}

function Get-GolferCourseHc {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [golfer]
        $Golfer,
        [Parameter(Mandatory = $true)]
        [string]
        [ValidateSet('AldarraGC')]
        $CourseName,
        [Parameter(Mandatory = $true)]
        [string]
        [ValidateSet('Aldarra', 'Championship', 'Member', 'Club', 'Forward', 'ComboChampMember', 'ComboMemberClub')]
        $TeeLocation
    )

    begin {
        [int]$ch = 0
        $sc = Get-ScoreCard -CourseName $CourseName
        $par = ($sc.holes | Measure-Object -Property par -Sum).Sum
        $rt = New-Object -TypeName psobject
    }
    process {
        if ($golfer.GolferType -eq 'man') {
            $t = $sc.ratingAndSlope | Where-Object -Property type -EQ 'Men' | Where-Object -Property teeLocation -EQ $TeeLocation
        }
        else {
            $t = $sc.ratingAndSlope | Where-Object -Property type -EQ 'Women' | Where-Object -Property teeLocation -EQ $TeeLocation
        }
    }
    end {
        $ch = (($golfer.Index * $t.slope) / 113) + ($t.rating - $par)
        Add-Member -InputObject $rt -MemberType NoteProperty -Name FirstName -Value $golfer.FirstName
        Add-Member -InputObject $rt -MemberType NoteProperty -Name LastName -Value $golfer.LastName
        Add-Member -InputObject $rt -MemberType NoteProperty -Name Index -Value $golfer.Index
        Add-Member -InputObject $rt -MemberType NoteProperty -Name CourseDisplayName -Value $sc.CourseDisplayName
        Add-Member -InputObject $rt -MemberType NoteProperty -Name CourseName -Value $sc.CourseName
        Add-Member -InputObject $rt -MemberType NoteProperty -Name TeeBox -Value $TeeLocation
        Add-Member -InputObject $rt -MemberType NoteProperty -Name Rating -Value $t.rating
        Add-Member -InputObject $rt -MemberType NoteProperty -Name Slope -Value $t.slope
        Add-Member -InputObject $rt -MemberType NoteProperty -Name CourseHandicap -Value $ch
        return $rt
    }
}

function Get-GolferPops {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Object]
        $GolferCourseHc
    )

    begin {
        [ref]$r = 0
    }
    process {
        $sc = Get-ScoreCard -CourseName $GolferCourseHc.CourseName
        $a = $sc.holes | ConvertTo-Json -Depth $Script:jsonDepth | ConvertFrom-Json | Add-Member -PassThru -MemberType NoteProperty -Name popCount -Value 0 | Sort-Object -Property handicap

        $gch = $GolferCourseHc | ConvertTo-Json -Depth $Script:jsonDepth | ConvertFrom-Json

        for ($i = 1; $i -le $gch.CourseHandicap; $i++) {
            
            if ($i -gt 18) {
                $q = ([math]::DivRem($i, 18, $r))
                $n = $i - (18 * $q)
                if ($q -gt 1) {
                    $n++
                }                
            }
            else {
                $n = $i
            }
            $a[$n - 1].popCount++
        }

    }
    end {
        $gch | Add-Member -PassThru -MemberType NoteProperty -Name Holes -Value ($a | Sort-Object -Property holeNumber)
    }
}

function Get-GolferScore {
    param (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $GolferPops,
        [Parameter(Mandatory = $true)]
        [System.Object]
        $GolferGrossScore
    )

    if ("$($GolferPops.FirstName) $($GolferPops.LastName)" -ne "$($GolferGrossScore.FirstName) $($GolferGrossScore.LastName)") {
        $errMsg = "$($GolferPops.LastName), $($GolferPops.FirstName) from pop record doesn't match $($GolferGrossScore.LastName), $($GolferGrossScore.FirstName) from gross score record."
        throw $errMsg
        return
    }
    $rt = @()

    foreach ($hole in $GolferPops.Holes) {
        $gs = [int]$GolferGrossScore.($hole.holeNumber)
        $ns = [int]$gs - [int]$($hole.popCount)
        if ($gs -gt ([int]$hole.par + [int]$hole.popCount + 2)) {
            $es = [int]$hole.par + [int]$hole.popCount + 2
        }
        else {
            $es = $gs
        }

        $rt += $hole | Select-Object -Property *, @{name = 'equitableScore'; expression = { $es } }, @{name = 'grossScore'; expression = { $gs } }, @{name = 'netScore'; expression = { $ns } }

    }

    $GolferPops.Holes = ($rt | ConvertTo-Json -Depth $Script:jsonDepth | ConvertFrom-Json)
    return $GolferPops
}

function Get-ScoreRecord {
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $CsvFilePath
    )

    $csv = Import-Csv -Path $CsvFilePath
    if (-not $?) {
        $errMsg = "Had problems reading $CsvFilePath"
        throw $errMsg
        return
    }
    return $csv
}

function Get-GolferGrossScore {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline)]
        [System.Object[]]
        $ScoreRecord,
        [Parameter(Mandatory = $true)]
        [System.String]
        $FirstName,
        [Parameter(Mandatory = $true)]
        [System.String]
        $LastName
    )

    begin {
        $rt = $null
    }
    process {
        
        foreach ($r in $ScoreRecord) {
            if ($r.FirstName -eq $FirstName -and $r.LastName -eq $LastName) {
                $rt = $r
                break
            } 
        }        
    }
    end {
        if (-not $rt) {
            $errMsg = "No gross scorew found for $FirstName $LastName"
            throw $errMsg
            return    
        }
        return $rt        
    }
}