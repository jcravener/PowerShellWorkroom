#
# This is the One Gross One Net score script
#
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [System.Int32]
    $hl
)


#--- Setup ----------------------------------------------------------------------------

$Script:scriptRoot = Split-Path -Path $PSCommandPath -Parent
$Script:modulePath = $Script:scriptRoot + "\module\JhcGolfScore"
$Script:csvPath = $Script:scriptRoot + "\scores\score.csv"
$Script:jsonDepth = 20

Import-Module -FullyQualifiedName $Script:modulePath -Force

#--- Functions ------------------------------------------------------------------------
function getBlindDraw {
    param (
        [Parameter(Mandatory=$true)]
        [System.Object]
        $gRecord,
        [Parameter(Mandatory=$true)]
        [System.String]
        $team
    )

    $drawSet = $gRecord | Where-Object -Property Team -NE $team | ConvertTo-Json -Depth $Script:jsonDepth | ConvertFrom-Json
    $i = Get-Random -Minimum 0 -Maximum ($drawSet.length)
    # $drawSet[$i].FirstName += '_bd'
    # $drawSet[$i].LastName += '_bd'
    $drawSet[$i].Team = $team
    return $drawSet[$i]
}

function getBestScore {
    param (
        [Parameter(Mandatory=$true)]
        [System.Object]
        $sTable,
        [Parameter(Mandatory=$true)]
        [System.String]
        $team,
        [Parameter(Mandatory=$true)]
        [System.Int32]
        $hole
    )
    
    $testTable = $sTable | Where-Object -Property Team -EQ $team | Where-Object -Property holeNumber -EQ $hole
    $a = @()

    foreach ($i in $testTable) {
        $a += New-Object -TypeName psobject -Property @{'value' = $i.grossScore; 'obj' = $i}
        $a += New-Object -TypeName psobject -Property @{'value' = $i.netScore; 'obj' = $i}
    }

    $a = $a | Sort-Object -Property value

    #---grab first val
    $firstVal = $a[0]
    $nextVal
    $firstScoreType
    $nextScoreType

    if($firstVal.obj.grossScore -eq $firstVal.obj.netScore) {
        $firstScoreType = 'both'

    }elseif($firstVal.value -eq $firstVal.obj.grossScore) {
        $firstScoreType = 'grossScore'
    }
    else {
        $firstScoreType = 'netScore'
    }

    for($i = 1; $i -lt $a.length; $i++) {
        
        if(($a[$i].obj.FirstName -eq $firstVal.obj.FirstName) -and ($a[$i].obj.LastName -eq $firstVal.obj.LastName)) {
            continue
        }

        if($a[$i].obj.grossScore -eq $a[$i].obj.netScore) {
            $nextScoreType = 'both'
        }
        elseif($a[$i].value -eq $a[$i].obj.grossScore) {
            $nextScoreType = 'grossScore'
        }
        else {
            $nextScoreType = 'netScore'
        }

        if(($nextScoreType -eq 'both') -or ($firstScoreType -ne $nextScoreType)) {
            $nextVal = $a[$i]
            break
        }
    } 

    return $firstVal.obj, $nextVal.obj
}

#--- Main -----------------------------------------------------------------------------

$scoreRecord = Get-ScoreRecord -CsvFilePath $Script:csvPath

$golferRecord = $scoreRecord | New-Golfer | Get-GolferCourseHc | Get-GolferPops

foreach( $grp in ($golferRecord | Group-Object -Property Team)) {
    if($grp.Count -lt 4){
        $golferRecord += getBlindDraw -gRecord $golferRecord -team $grp.Name
    }
}

$scoreTable = @()
foreach($g in $golferRecord) {
    $ggs = Get-GolferGrossScore -ScoreRecord $scoreRecord -FirstName $g.FirstName -LastName $g.LastName

    Get-GolferScore -GolferPops $g -GolferGrossScore $ggs | Out-Null

    foreach($h in $g.Holes) {
        $scoreTable += $h | Select-Object -Property @{name = 'FirstName'; Expression = {$g.FirstName}}, @{name = 'LastName'; Expression = {$g.LastName}}, @{name = 'Team'; Expression = {$g.Team}}, * 
    }
}

#$hl = 1
$tm = 'B'
getBestScore -sTable $scoreTable -team $tm -hole $hl
'--------------'
$scoreTable | Where-Object -Property Team -EQ $tm | Where-Object -Property holeNumber -EQ $hl 
