function Invoke-JhcAdoRestPipelinePreviewRun {
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [System.Security.SecureString]
        $Pat = $JhcAdoRestPat,
        [Parameter(Position = 1, Mandatory)]
        [System.String]
        $PipelineId,
        [Parameter(Position = 2, Mandatory = $false)]
        [System.String]
        $Organization = $JhcAdoRestOrganization,
        [Parameter(Position = 3, Mandatory = $false)]
        [System.String]
        $Project = $JhcAdoRestProject,
        [Parameter(Position = 4, Mandatory = $false)]
        [System.String]
        $ApiVersion = '6.1-preview.1'
    )

    begin {
        
        if (-not $Pat) {
            throw "PAT was not found"
        }
        if (-not $JhcAdoRestOrganization) {
            throw "JhcAdoRestOrganization was not found"
        }
        if (-not $JhcAdoRestProject) {
            throw "JhcAdoRestProject was not found"
        }
        
        $uri = 'https://dev.azure.com/' + $Organization + '/' + $Project + '/_apis/pipelines/' + $PipelineId + '/preview?&api-version=' + $ApiVersion
        
        $header = PrepAdoRestApiAuthHeader -SecurePat $pat

        $body = "{
        `n  `"PreviewRun`": true
        `n}"

        $ct = 'application/json'
    }
    process {
        Invoke-RestMethod -Uri $uri -Headers $header -Method POST -Body $body -ContentType $ct
    }
    end {}

}

function Invoke-JhcAdoRestBuildDefinition {
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [System.Security.SecureString]
        $Pat = $JhcAdoRestPat,
        [Parameter(Position = 1, Mandatory = $false)]
        [System.String]
        $PipelineId,
        [Parameter(Position = 2, Mandatory = $false)]
        [System.String]
        $Organization = $JhcAdoRestOrganization,
        [Parameter(Position = 3, Mandatory = $false)]
        [System.String]
        $Project = $JhcAdoRestProject,
        [Parameter(Position = 4, Mandatory = $false)]
        [System.String]
        $ApiVersion = '6.1-preview.7'
    )

    begin {
        
        if (-not $Pat) {
            throw "PAT was not found"
        }
        if (-not $JhcAdoRestOrganization) {
            throw "JhcAdoRestOrganization was not found"
        }
        if (-not $JhcAdoRestProject) {
            throw "JhcAdoRestProject was not found"
        }

        $uri = 'https://dev.azure.com/' + $Organization + '/' + $Project + '/_apis/build/definitions/' + $PipelineId + '?api-version=' + $ApiVersion
                
        $header = PrepAdoRestApiAuthHeader -SecurePat $pat

        $ct = 'application/json'
    }
    process {
        Invoke-RestMethod -Uri $uri -Headers $header -Method Get -verbose -ContentType $ct
    }
    end {}

}

function Invoke-JhcAdoRestBuildList {
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [System.Security.SecureString]
        $Pat = $JhcAdoRestPat,
        [Parameter(Position = 1, Mandatory = $false)]
        [System.String]
        $PipelineId,
        [Parameter(Position = 2, Mandatory = $false)]
        [System.String]
        $Organization = $JhcAdoRestOrganization,
        [Parameter(Position = 3, Mandatory = $false)]
        [System.String]
        $Project = $JhcAdoRestProject,
        [Parameter(Position = 4, Mandatory = $false)]
        [System.String]
        $ApiVersion = '6.1-preview.7'
    )

    begin {
        
        if (-not $Pat) {
            throw "PAT was not found"
        }
        if (-not $JhcAdoRestOrganization) {
            throw "JhcAdoRestOrganization was not found"
        }
        if (-not $JhcAdoRestProject) {
            throw "JhcAdoRestProject was not found"
        }
        
        $uri = 'https://dev.azure.com/' + $Organization + '/' + $Project + '/_apis/build/builds?definitions=' + $PipelineId + '&api-version=' + $ApiVersion
        
        $header = PrepAdoRestApiAuthHeader -SecurePat $pat

        $ct = 'application/json'
    }
    process {
        Invoke-RestMethod -Uri $uri -Headers $header -Method Get -verbose -ContentType $ct
    }
    end {}

}
function Invoke-JhcAdoRestPipeline {
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [System.Security.SecureString]
        $Pat = $JhcAdoRestPat,
        [Parameter(Position = 1, Mandatory = $false)]
        [System.String]
        $PipelineId,
        [Parameter(Position = 2, Mandatory = $false)]
        [System.String]
        $Organization = $JhcAdoRestOrganization,
        [Parameter(Position = 3, Mandatory = $false)]
        [System.String]
        $Project = $JhcAdoRestProject,
        [Parameter(Position = 4, Mandatory = $false)]
        [System.String]
        $ApiVersion = '6.0-preview.1'
    )

    begin {
        
        if (-not $Pat) {
            throw "PAT was not found"
        }
        if (-not $JhcAdoRestOrganization) {
            throw "JhcAdoRestOrganization was not found"
        }
        if (-not $JhcAdoRestProject) {
            throw "JhcAdoRestProject was not found"
        }
        
        $uri = 'https://dev.azure.com/' + $Organization + '/' + $Project + '/_apis/pipelines/' + $PipelineId + '?api-version=' + $ApiVersion
        
        $header = PrepAdoRestApiAuthHeader -SecurePat $pat

        $ct = 'application/json'
    }
    process {
        Invoke-RestMethod -Uri $uri -Headers $header -Method Get -verbose -ContentType $ct
    }
    end {}

}

function Invoke-JhcAdoRestPipelineRuns {
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [System.Security.SecureString]
        $Pat = $JhcAdoRestPat,
        [Parameter(Position = 1, Mandatory = $true)]
        [System.String]
        $PipelineId,
        [Parameter(Position = 1, Mandatory = $false)]
        [System.String]
        $RunId,
        [Parameter(Position = 2, Mandatory = $false)]
        [System.String]
        $Organization = $JhcAdoRestOrganization,
        [Parameter(Position = 3, Mandatory = $false)]
        [System.String]
        $Project = $JhcAdoRestProject,
        [Parameter(Position = 4, Mandatory = $false)]
        [System.String]
        $ApiVersion = '6.0-preview.1'
    )

    begin {
        
        if (-not $Pat) {
            throw "PAT was not found"
        }
        if (-not $JhcAdoRestOrganization) {
            throw "JhcAdoRestOrganization was not found"
        }
        if (-not $JhcAdoRestProject) {
            throw "JhcAdoRestProject was not found"
        }
        
        $uri = 'https://dev.azure.com/' + $Organization + '/' + $Project + '/_apis/pipelines/' + $PipelineId
        
        if ($RunId) {
            $uri += '/runs/' + $RunId + '?api-version='
        }
        else {
            $uri += '/runs?api-version='
        }

        $uri += $ApiVersion
        
        $header = PrepAdoRestApiAuthHeader -SecurePat $pat

        $ct = 'application/json'
    }
    process {
        Invoke-RestMethod -Uri $uri -Headers $header -Method Get -verbose -ContentType $ct
    }
    end {}

}


function Invoke-JhcAdoRestBuild {
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [System.Security.SecureString]
        $Pat = $JhcAdoRestPat,
        [Parameter(Position = 1, Mandatory = $false)]
        [System.String]
        $BuildId,
        [Parameter(Position = 2, Mandatory = $false)]
        [System.String]
        $Organization = $JhcAdoRestOrganization,
        [Parameter(Position = 3, Mandatory = $false)]
        [System.String]
        $Project = $JhcAdoRestProject,
        [Parameter(Position = 4, Mandatory = $false)]
        [System.String]
        $ApiVersion = '6.1-preview.7'
    )

    begin {
        
        if (-not $Pat) {
            throw "PAT was not found"
        }
        if (-not $JhcAdoRestOrganization) {
            throw "JhcAdoRestOrganization was not found"
        }
        if (-not $JhcAdoRestProject) {
            throw "JhcAdoRestProject was not found"
        }

        
        $uri = 'https://dev.azure.com/' + $Organization + '/' + $Project + '/_apis/build/builds/' + $BuildId + '?api-version=' + $ApiVersion
        
        $header = PrepAdoRestApiAuthHeader -SecurePat $pat

        $ct = 'application/json'
    }
    process {
        Invoke-RestMethod -Uri $uri -Headers $header -Method Get -verbose -ContentType $ct
    }
    end {}

}

function Invoke-JhcAdoRestGitPullRequest {
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [System.Security.SecureString]
        $Pat = $JhcAdoRestPat,
        [Parameter(Position = 1, Mandatory)]
        [System.String]
        $RepositoryId,
        [Parameter(Position = 2, Mandatory)]
        [System.String]
        $PullRequestId,
        [Parameter(Position = 3, Mandatory = $false)]
        [System.String]
        $Organization = $JhcAdoRestOrganization,
        [Parameter(Position = 4, Mandatory = $false)]
        [System.String]
        $Project = $JhcAdoRestProject,
        [Parameter(Position = 5, Mandatory = $false)]
        [System.String]
        $ApiVersion = '6.1-preview.1'
    )

    begin {
        
        if (-not $Pat) {
            throw "PAT was not found"
        }
        if (-not $JhcAdoRestOrganization) {
            throw "JhcAdoRestOrganization was not found"
        }
        if (-not $JhcAdoRestProject) {
            throw "JhcAdoRestProject was not found"
        }
        
        $uri = 'https://dev.azure.com/' + $Organization + '/' + $Project + '/_apis/git//repositories/' + $RepositoryId + '/pullrequests/' + $PullRequestId + '?api-version=' + $ApiVersion
        
        $header = PrepAdoRestApiAuthHeader -SecurePat $pat

        $ct = 'application/json'
    }
    process {
        Invoke-RestMethod -Uri $uri -Headers $header -Method Get -verbose -ContentType $ct
    }
    end {}

}

function Invoke-JhcAdoRestReleaseDefinition {
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [System.Security.SecureString]
        $Pat = $JhcAdoRestPat,
        [Parameter(Position = 1, Mandatory = $false)]
        [System.String]
        $DefinitionId,
        [Parameter(Position = 2, Mandatory = $false)]
        [System.String]
        $Organization = $JhcAdoRestOrganization,
        [Parameter(Position = 3, Mandatory = $false)]
        [System.String]
        $Project = $JhcAdoRestProject,
        [Parameter(Position = 4, Mandatory = $false)]
        [System.String]
        $ApiVersion = '6.0'
    )

    begin {
        
        if (-not $Pat) {
            throw "PAT was not found"
        }
        if (-not $JhcAdoRestOrganization) {
            throw "JhcAdoRestOrganization was not found"
        }
        if (-not $JhcAdoRestProject) {
            throw "JhcAdoRestProject was not found"
        }
                
        $uri = 'https://vsrm.dev.azure.com/' + $Organization + '/' + $Project + '/_apis/release/definitions/' + $DefinitionId + '?api-version=' + $ApiVersion
        
        $header = PrepAdoRestApiAuthHeader -SecurePat $pat

        $ct = 'application/json'
    }
    process {
        Invoke-RestMethod -Uri $uri -Headers $header -Method Get -verbose -ContentType $ct
    }
    end {}

}

function Invoke-JhcAdoRestRelease {
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [System.Security.SecureString]
        $Pat = $JhcAdoRestPat,
        [Parameter(Position = 1, Mandatory = $false)]
        [System.String]
        $ReleaseId,
        [Parameter(Position = 2, Mandatory = $false)]
        [System.String]
        $Organization = $JhcAdoRestOrganization,
        [Parameter(Position = 3, Mandatory = $false)]
        [System.String]
        $Project = $JhcAdoRestProject,
        [Parameter(Position = 4, Mandatory = $false)]
        [System.String]
        $ApiVersion = '6.1-preview.8'
    )

    begin {
        
        if (-not $Pat) {
            throw "PAT was not found"
        }
        if (-not $JhcAdoRestOrganization) {
            throw "JhcAdoRestOrganization was not found"
        }
        if (-not $JhcAdoRestProject) {
            throw "JhcAdoRestProject was not found"
        }
                
        # GET https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/releases/{releaseId}?api-version=6.1-preview.8

        $uri = 'https://vsrm.dev.azure.com/' + $Organization + '/' + $Project + '/_apis/release/releases/' + $ReleaseId + '?api-version=' + $ApiVersion
        
        $header = PrepAdoRestApiAuthHeader -SecurePat $pat

        $ct = 'application/json'
    }
    process {
        Invoke-RestMethod -Uri $uri -Headers $header -Method Get -verbose -ContentType $ct
    }
    end {}
}

function Select-JhcAdoRestBuildDefinition {
    
    param (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline=$true)]
        [System.Object[]]
        $Value
    )
  
    begin{
        $p = 'id', 'createdDate', 'revision', @{n='authoredByuniqueName';e={$_.authoredBy.uniqueName}}, 'path', 'name', @{n='processType';e={ $_.process.type }}, @{n='yamlFilename';e={ $_.process.yamlFilename }}, @{n='repoName';e={$_.repository.name}}, @{n='repoBranch'; e={$_.repository.defaultBranch}}
    }

    process{
        foreach($obj in $Value){
            $obj | Select-Object -Property $p
        }
    }

    end{}
}
function Select-JhcAdoRestReleaseDefinition {
    
    param (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline=$true)]
        [System.Object[]]
        $Value
    )
  
    begin{
        $p = 'id', 'createdOn', 'revision', @{n='createdByuniqueName';e={$_.createdBy.uniqueName}}, 'path', 'name', @{n='lastReleaseId';e={ $_.lastRelease.id }}, @{n='lastReleaseName';e={ $_.lastRelease.name }}, @{n='artifactsType';e={ $_.artifacts.type }}, @{n='artifactsAlias';e={ $_.artifacts.alias }}
    }

    process{
        foreach($obj in $Value){
            $obj | Select-Object -Property $p
        }
    }

    end{}
}

function PrepAdoRestApiAuthHeader {

    param (
        [Parameter(Position = 0, Mandatory)]
        [System.Security.SecureString]
        $SecurePat
    )

    if ($null -eq $SecurePat) {
        throw "Passed-in SecurePat string was null."
    }

    $pat = ''

    try {
        $us = [runtime.interopservices.Marshal]::SecureStringToGlobalAllocUnicode($SecurePat)
        $pat = [runtime.interopservices.Marshal]::PtrToStringAuto($us)
    }
    finally {
        [runtime.interopservices.Marshal]::ZeroFreeGlobalAllocUnicode($us)
    }

    $credPair = ":$($pat)"
    $encodedCred = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
    $header = @{'Authorization' = "Basic $encodedCred" }

    return $header
}
