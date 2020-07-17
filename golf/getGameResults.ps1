#
# This is the One Gross One Net score script
#

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

    return $a | Sort-Object -Property value
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

$hl = 15
$tm = 'B'
getBestScore -sTable $scoreTable -team $tm -hole $hl
'--------------'
$scoreTable | Where-Object -Property Team -EQ $tm | Where-Object -Property holeNumber -EQ $hl 
