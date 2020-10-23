

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [String]
    $filePath
)

$root = Import-JhcJson -Path $filePath
$doc = New-Object -TypeName doc
$a = @()
$aa = @()

foreach ($r in $root.environments) {
    
    if ($r.status -ne 'notStarted') {
        
        foreach ($pre in $r.preDeployApprovals) {
            $o = New-Object -TypeName approval
        
            $o.stageName = $r.name
            $o.stageId = $r.Id
            $o.stageCreatedOn = $r.createdOn
            $o.stagemodifiedOn = $r.modifiedOn
            $o.stageStatus = $r.status

            $o.approvalCreatedOn = $pre.createdOn
            $o.approvalModifiedOn = $pre.modifiedOn
            $o.isAutomated = $pre.isAutomated

            if ($pre.approvedBy) {
                $o.approvedBy = $pre.approvedBy.displayName
            }
            $a += , $o
        }

        foreach ($post in $r.postDeployApprovals) {
            $o = New-Object -TypeName approval
        
            $o.stageName = $r.name
            $o.stageId = $r.Id
            $o.stageCreatedOn = $r.createdOn
            $o.stagemodifiedOn = $r.modifiedOn
            $o.stageStatus = $r.status

            $o.approvalCreatedOn = $post.createdOn
            $o.approvalModifiedOn = $post.modifiedOn
            $o.isAutomated = $post.isAutomated

            if ($post.approvedBy) {
                $o.approvedBy = $post.approvedBy.displayName
            }
            $aa += , $o
        }
    }
}

$doc.preDeployApproval = $a | Sort-Object -Property approvalModifiedOn
$doc.postDeployApproval = $aa | Sort-Object -Property approvalModifiedOn
$doc 

class doc {
    [approval[]]$preDeployApproval
    [approval[]]$postDeployApproval
}

class stage {
    [string]$stageName
    [int]$stageId
    [datetime]$stageCreatedOn
    [datetime]$stagemodifiedOn
    [string]$stageStatus
}

class approval : stage {
    [datetime]$approvalCreatedOn
    [datetime]$approvalModifiedOn
    [string]$isAutomated
    [string]$approvedBy
}
