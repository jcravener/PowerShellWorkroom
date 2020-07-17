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
    [CmdletBinding()]
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
    $drawSet[$i].FirstName += '_bd'
    $drawSet[$i].LastName += '_bd'
    $drawSet[$i].Team = $team
    return $drawSet[$i]
}

#--- Main -----------------------------------------------------------------------------

$scoreRecord = Get-ScoreRecord -CsvFilePath $Script:csvPath

$golferRecord = $scoreRecord | New-Golfer | Get-GolferCourseHc | Get-GolferPops

$scoreTable = @()
foreach($g in $golferRecord) {
    $ggs = Get-GolferGrossScore -ScoreRecord $scoreRecord -FirstName $g.FirstName -LastName $g.LastName

    Get-GolferScore -GolferPops $g -GolferGrossScore $ggs | Out-Null

    foreach($h in $g.Holes) {
        $scoreTable += $h | Select-Object -Property @{name = 'FirstName'; Expression = {$g.FirstName}}, @{name = 'LastName'; Expression = {$g.LastName}}, @{name = 'Team'; Expression = {$g.Team}}, * 
    }
}

foreach( $grp in ($golferRecord | Group-Object -Property Team)) {
    if($grp.Count -lt 4){
        getBlindDraw -gRecord $golferRecord -team $grp.Name
    }
}