#
# This is the One Gross One Net score script
#

$Script:scriptRoot = Split-Path -Path $PSCommandPath -Parent
$Script:modulePath = $Script:scriptRoot + "\module\JhcGolfScore"
$Script:csvPath = $Script:scriptRoot + "\scores\score.csv"

Import-Module -FullyQualifiedName $Script:modulePath

$scoreRecord = Get-ScoreRecord -CsvFilePath $Script:csvPath

$scoreRecord | New-Golfer | Get-GolferCourseHc | Get-GolferPops