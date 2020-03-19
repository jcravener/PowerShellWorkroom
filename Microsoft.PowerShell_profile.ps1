#$MirrorPricipleCheckQuery = 'SELECT name, state_desc FROM sys.databases'
$MaximumHistoryCount = 1024
#$MemberType = 'NoteProperty'
#$LtmWitAg = 'wit:wit'
#$LtmMcsAg = 'mcs:mcs'
$Co1TsServer11 = 'co1wusts11'
$Co1TsServer01 = 'co1wusts01'
$BayTsServer01 = 'baymsftwuts01'
#Add-PSSnapin LtmCmdLetsSnapInR2
$LtmAdminGroup = 'WUPDS:WUPDS','TWCD:TWCD'
$WebServicConnectionsCounter = '\Web Service(_Total)\Current Connections'

$ProtectedDataStore = 'D:\john\work\info\DataStore.xml'

$env:PSModulePath += ';D:\john\psmodule\'

function Cfj {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [String]
        $Json
    )
    begin {
        $jsonstr = ''
    }

    process {
        foreach($s in $Json) {
            $jsonstr += $s
        }
    }

    end {
        $jsonstr | ConvertFrom-Json | ForEach-Object{$_}
    }
}

function ConvertFrom-DnsZoneRecord
{
    [CmdletBinding(DefaultParameterSetName = "Path")]
    param
    (
        [Parameter(Mandatory, ParameterSetName="Path", Position = 1)]
        [System.String[]]
        $Path,

        [Parameter(Mandatory, ParameterSetName="LiteralPath", ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath")]
        [System.String[]]
        $LiteralPath
    )

    begin
    {
        $ComPat = '^\;|^\@'
        $SplPat = '\s+'
        $SplDel = ','
        $header = 'Name','Class','Type','Rdata'        
    }

    process
    {
       $Paths = @()

       if($PSCmdlet.ParameterSetName  -eq "LiteralPath")
       {
           $Paths += Resolve-Path -LiteralPath $LiteralPath | Foreach-Object { $_.ProviderPath }
       }
       else
       {
           $Paths += Resolve-Path $Path | Foreach-Object { $_.ProviderPath }
       }

       foreach($fullname in $Paths)
       {
            Get-Content -Path $fullname | Where-Object{ $_ -notmatch $ComPat } | ForEach-Object{ $_ -replace $SplPat, $SplDel } | ConvertFrom-Csv -Header $header
       }
    }

    end{}
}

function Get-OpsLightAssetList
{
    param
    (
        [String]$AssetNameOrID = '182135d4-1f12-41fa-b063-ce35321ed95a',
        [String]$OpslLightCLPath = 'C:\localbin\OpsLightCL.exe'
    )

    begin
    {
        try
        {
            $null = Get-Item -Path $OpslLightCLPath
        }
        catch [System.Exception]
        {
            Write-Error $Error[0]

            throw
        }

        $p = @{'ComputerName' = $null; 'OpsLightPath' = $null; 'AssetId' = $null}

        $l = ''

        $splitdel = ']'
    }

    process
    {
        try
        {
            Write-Progress -Activity "OpsLightCL.exe is working." -Status "Hold on a moment..."

            Invoke-Expression -Command ("$OpslLightCLPath /search $AssetNameOrID /type msopsMachine /showpath /id /quiet") |
                ForEach-Object { $p['ComputerName'] = Split-Path -Path $_ -Leaf; $l = Split-Path -Path $_ -Parent; $p['OpsLightPath'] = $l.split($splitdel)[1] -replace '^\s+', ''; $p['AssetId'] = $l.split($splitdel)[0] -replace '^\[', ''; New-Object -TypeName psobject -Property $p; }
        }
        catch [System.Exception]
        {
            Write-Error $Error[0]

            throw
        }
    }

    end{}
}

function Get-JohncravStorageAccount
{
    param(
            [String]$SubscriptionName = 'JCravenerVsUltimateMsdn',
            [String]$StorageAccountName = 'johncravsa00'
         )

    Select-AzureSubscription -SubscriptionName $SubscriptionName
    return( Get-AzureStorageAccount -StorageAccountName $StorageAccountName)
}

function Write-NewLines
{
    param(
            [int]$scalar = 10,
            [String]$string = "`n"
         )

    return( $string * $scalar )
    
}

#--returns an object that is useful for CSCFG upload from the passd in CSCFG files that are created by Save-DevOpsCscfgFromObj
#
function Convert-DevOpsCscfgFileForUpdate
{
    param(
            [parameter(mandatory=$true, ValueFromPipeline=$true)][System.Object[]]$FileObj = $null,
            $Slot = 'Staging',
            $Delimiter = '.'
         )
    
    begin{}

    process
    {
        foreach($obj in $FileObj)
        {
            return( New-Object -TypeName psobject -Property @{'ServiceName'= $obj.name.split($Delimiter)[0]; 'Configuration' = $obj.fullname; 'Slot'= $Slot} )
        }
    }

    end{}

}

#---launches an RDP file from a passed in SRI object
#
function Get-DevOpsAzRemoteDesktopFile
{
    param(
            [parameter(mandatory=$true, ValueFromPipeline=$true)][System.Object[]]$SriObj = $null
         )

    begin{}

    process
    {
        foreach($obj in $SriObj)
        {
            try
            {
                Get-AzureRemoteDesktopFile -Name $obj.InstanceName -Launch -ServiceName $obj.ServiceName
            }
            catch
            {
                Write-Error -ErrorRecord $Error[0]
            }
        }
    }

    end{}
}


# Lists out Environment Path making it easy to see redundant paths.
# -Optimize switch removes all redundant values
#
function Show-EnvironmentPath
{
    param([switch]$Optimize = $false)

    if($Optimize)
    {
        $line = ''; $env:path.split(';') | Group-Object | %{ $_.group | Select-Object -First 1 } | %{ $line += $_ + ';' }; $line = $line -replace ';$', '';
        $env:path = $line;
    }
    else
    {
        $env:path.split(';') | Group-Object -NoElement
    }
}

function Invoke-DevOpsAzDeployment
{
    param(
            [parameter(mandatory=$true, ValueFromPipeline=$true)][System.Object]$obj = $null
         )

    begin{}
    process
    {
        foreach( $o in $obj)
        {
            try
            {
                $sid = $o.SubscriptionId
                $currentsub = Get-AzureSubscription -Current
                $sub = Get-AzureSubscription | ? SubscriptionId -EQ $sid

                if($currentsub -ne $sub)
                {
                    $sub | Select-AzureSubscription
                }
            }
            catch
            {
                Write-Error -ErrorRecord $Error[0] -Message "Had problems selecting subscription $sid."
            }

            $ServiceName = $o.ServiceName
            $Package = $o.Package
            $Configuration = $o.Configuration
            $Slot = $o.Slot
            
            #$Label = $null

            if($o.Label)
            {
                $Label = $o.Label
            }
            else
            {
                $Label = (Get-Date).ToString("yyyy-MM-dd--HH-mm-ss")
            }
            
            try
            {
                New-AzureDeployment -ServiceName $ServiceName -Package $Package -Configuration $Configuration -Slot $Slot -Label $Label -Verbose
            }
            catch
            {
                Write-Error -ErrorRecord $Error[0] -Message "Had problems deploying to $ServiceName"
            }
        }
    }
    end{}
}

function Invoke-DevOpsAzProvisionResource
{
    param(
            [parameter(mandatory=$true, ValueFromPipeline=$true)][System.Object]$obj = $null
         )

    begin{}
    process
    {
        foreach( $o in $obj)
        {
            try
            {
                $sid = $o.SubscriptionId
                $currentsub = Get-AzureSubscription -Current
                $sub = Get-AzureSubscription | ? SubscriptionId -EQ $sid

                if($currentsub -ne $sub)
                {
                    $sub | Select-AzureSubscription
                }
            }
            catch
            {
                Write-Error -ErrorRecord $Error[0] -Message "Had problems selecting subscription $sid."
            }

            if($o.Resource -eq 'AzureService')
            {
                $ServiceName = $o.name
                $Location = $o.location

                try
                {
                    New-AzureService -ServiceName $ServiceName -Location $Location -Verbose
                }
                catch
                {
                    Write-Error -ErrorRecord $Error[0] -Message "Had problems creating service $ServiceName"
                }
            }
            elseif($o.Resource -eq 'AzureStorageAccount')
            {
                $StorageAccountName = $o.name
                $Location = $o.location

                try
                {
                    New-AzureStorageAccount -StorageAccountName $StorageAccountName -Location $Location -Verbose
                }
                catch
                {
                    Write-Error -ErrorRecord $Error[0] -Message "Had problems creating storage account $StorageAccountName" -ErrorId
                }
            }
            elseif($o.Resource -eq 'CertToDeploy')
            {
                $ServiceName = $o.Name
                $CertToDeploy = $o.Location
                
                #--nesd to implement encryption/decryption
                $Password = $o.P                

                try
                {
                    Add-AzureCertificate -ServiceName $ServiceName -CertToDeploy $CertToDeploy -Password $Password -Verbose
                }
                catch
                {
                    Write-Error -ErrorRecord $Error[0] -Message "Had problems adding certificate $CertToDeploy"
                }
            }
        }
    }
    end{}
}

function Get-DevOpsWebSitePublishingInfo
{
    param(
            [parameter(mandatory=$true, ValueFromPipeline=$true)][System.Object]$obj = $null
         )

         begin{}

         process
         {
            foreach( $o in $obj)
            {
                $h = @{}; $o.SiteProperties.Properties | %{ $h[$_.Name] = $_.value }
                
                New-Object -TypeName psobject -Property $h |
                    Add-Member -PassThru -MemberType NoteProperty -Name 'SiteName' -Value $o.name |
                        Select-Object -Property SiteName, RepositoryUri, PublishingUsername, PublishingPassword
            }
         }

         end{}
}

function ConvertTo-Hash
{
    param(
            [parameter(mandatory=$true, ValueFromPipeline=$true)][String]$String = '',
            [String]$AlgorithmName = 'SHA256'
         )
    
    begin{}

    process
    {
    
        $sb = New-Object -TypeName System.Text.StringBuilder

        try
        {
            [System.Security.Cryptography.HashAlgorithm]::Create($AlgorithmName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String)) |
                ForEach-Object{ $null = $sb.Append($_.ToString('x2')) }
        }
        catch
        {
            Write-Error -ErrorRecord $Error[0]
        }
        
        New-Object -TypeName psobject -Property @{ 'String' = $String; 'Hash' = $sb.ToString(); 'AlgorithmName' = $AlgorithmName } | Select-Object -Property String, Hash, AlgorithmName
    }

    end{}
}
#---secret web proxy setup
#
function New-SecretServerWebServiceProxy
{
    param(
            [String]$Uri = 'https://secretserver/winauthwebservices/sswinauthwebservice.asmx',
            [String]$SearchTerm = ''
         )
    
    try
    {
        $p = New-WebServiceProxy -Uri $Uri -UseDefaultCredential
    }
    catch
    {
        return $Error[0]
    }
    
    return $p
}

#--secret server search
#
function Search-SecretServer
{
    param(
            [String]$SearchTerm = '',
            [String]$Uri = 'https://secretserver/winauthwebservices/sswinauthwebservice.asmx'
         )
    
    try
    {
        $p = New-WebServiceProxy -Uri $Uri -UseDefaultCredential
    }
    catch
    {
        return $Error[0]
    }
    
    if($Search -ne '')
    {
        return ( $p.SearchSecrets($SearchTerm) | ForEach-Object { if($_.Errors){ $_.Errors }else{ $_.SecretSummaries } } )
    }
    else
    {
        return $null
    }
}

#--secret server get secret
#
function Get-SecretServerSecret
{
    param( [parameter(Mandatory=$true, ValueFromPipeline=$true)][System.Object]$SecretObj = $null,
           [string]$Uri = 'https://secretserver/winauthwebservices/sswinauthwebservice.asmx'
         )

    begin
    {
        try
        {
            $p = New-WebServiceProxy -Uri $Uri -UseDefaultCredential
        }
        catch
        {
            return $Error[0]
        }
    }
    process
    {
        try
        {
            foreach( $o in $SecretObj )
            {
                $SecretName = $o.SecretName
                $SecretId = $o.SecretId
                $SecretTypeName = $o.SecretTypeName

                $p.GetSecret($SecretId) | ForEach-Object{ if($_.Errors){$_.Errors }else{ $_.Secret  | ForEach-Object { $_.Items } } } |
                    Add-Member -PassThru -MemberType NoteProperty -Name SecretName -Value $SecretName | 
                        Add-Member -PassThru -MemberType NoteProperty -Name SecretId -Value $SecretId | 
                            Add-Member -PassThru -MemberType NoteProperty -Name SecretTypeName -Value $SecretTypeName
            }
        }
        catch
        {
            $Error[0]
        }

    }
    end
    {
        #--nothing to do
    }

}

function Get-LatestAzurePsModule
{
    param(
            [String]$Uri = 'http://go.microsoft.com/?linkid=9811175&clcid=0x409',
            [Switch]$Download = $false
         )
    
    try
    {
        $wr = Invoke-WebRequest -Uri $Uri
    }
    catch
    {
        return $Error[0]
    }

    $FnObj = $wr.Headers| %{ $_.'Content-Disposition' } | %{ $_ -match '(filename)=(.+$)'; New-Object -TypeName psobject  -Property @{$Matches[1] = $Matches[2]} }

    if($Download)
    {
        $bt = Start-BitsTransfer -Asynchronous -DisplayName $FnObj.filename -Destination ( '.\' + $FnObj.filename ) -Source $Uri

        while($bt.JobState -ne 'Transferred')
        {
            $bt | Select-Object -Property DisplayName, JobState, BytesTotal, BytesTransferred, @{name='PercentComplete'; expression={($_.BytesTransferred / $_.BytesTotal)*100}}
            Start-Sleep -Seconds 2
        }

        $bt | Select-Object -Property DisplayName, JobState, BytesTotal, BytesTransferred, @{name='PercentComplete'; expression={($_.BytesTransferred / $_.BytesTotal)*100}}
        $bt | Complete-BitsTransfer
    }
    else
    {
        return $FnObj
    }
}

function Save-WebRequestImage
{
    param(
            [parameter(mandatory=$true, ValueFromPipeline=$true)][Microsoft.PowerShell.Commands.WebResponseObject]$WebResponseObj = $null,
            [parameter(mandatory=$true)][String]$BasePath = ''
         )
         
    if($BasePath -notmatch '^\\|^[a-zA-Z]{1}:')
    {
        $Path = $PWD.Path + '\' + $BasePath
    }
    else
    {
        $Path = $BasePath
    }
 
    $ct = 'image'

    if($WebResponseObj.Headers.'Content-Type' -match $ct)
    {
        $ext =  '.' + $WebResponseObj.Headers.'Content-Type'.split('/')[1]
    }
    else
    {
        return (Write-Error -Message "Contenet type is not $ct." )
    }

    $Path = $Path + $ext

    #return $WebResponseObj

    
    try
    {
        $siofs = New-Object -TypeName System.IO.FileStream -ArgumentList $Path, Create, Write
        
        #$siofs
        #$siofs.Close()

        #return

        $siofs.Write($WebResponseObj.Content, 0, $WebResponseObj.Content.Length)
        $siofs.Close()

        Get-Item -Path $Path
    }
    catch
    {
        $Error[0]
    }    
}

#---copies all JohncravPsProfile blobs from one storage accoutn to the next
#
function Copy-JohncravPsProfile
{
   param(
            #[parameter(mandatory=$true)][Microsoft.WindowsAzure.Commands.Storage.Model.ResourceModel.AzureStorageContext]$Context = $null, ValueFromPipeline=$true)][System.Object
            [parameter(mandatory=$true, ValueFromPipelineByPropertyName=$true)][System.Object]$SrcContext = $null,
            [parameter(mandatory=$true, ValueFromPipelineByPropertyName=$true)][System.Object]$DestContext = $null,
            [String]$SrcContainer = 'ps-profile',
            [String]$DestContainer = 'ps-profile'
        )

    try
    {
        $null = Get-AzureStorageContainer -Name $DestContainer -Context $DestContext -ErrorAction SilentlyContinue
    }
    catch
    {
        return $Error[0]
    }
    
    if(-not $?)  #--create the container if it's not there
    {
        try
        {
            $null = New-AzureStorageContainer -Name $DestContainer -Context $DestContext
        }
        catch
        {
            $Error[0]
        }
    }
    
    try
    {
        return ( Get-AzureStorageBlob -Container $SrcContainer -Context $SrcContext | Start-CopyAzureStorageBlob -DestContainer $DestContainer -DestContext $DestContext )
    }
    catch
    {
        return $Error[0]
    } 
}


# -- need better error handling
#
function Get-JohncravPsProfile
{
    param(
            #[parameter(mandatory=$true)][Microsoft.WindowsAzure.Commands.Storage.Model.ResourceModel.AzureStorageContext]$Context = $null, ValueFromPipeline=$true)][System.Object
            [parameter(mandatory=$true, ValueFromPipeline=$true)][System.Object]$Context = $null, 
            [switch]$ShortOutput = $false,
            [String]$ContainerName = 'ps-profile',
            [Switch]$Download = $false,
            [String]$Destination = '.',
            [String]$Blob = ''
         )
    
    $WindowsFileTimeString = '1/1/1601 00:00:00' #---ref http://msdn.microsoft.com/en-us/library/system.datetime.tofiletime(v=vs.110).aspx
    $MiliToNanoScalar = 0.0001
    
    $pat = '.+\-(.+)?\.ps1'

    try
    {
        $BlobList = Get-AzureStorageContainer -Name $ContainerName -Context $Context |
            Get-AzureStorageBlob | 
                ForEach-Object { 
                    if($_.name -match $pat){ $wft = [int64]$Matches[1]}else{ $wft = ( $_.LastModified ).ToFileTime() }; 
                    $fts = ( Get-Date -Date $WindowsFileTimeString ).AddMilliseconds( $wft * $MiliToNanoScalar ).ToLocalTime(); 
                    $_ | Add-Member -PassThru -MemberType NoteProperty -Name TimeUploaded -Value $fts } |
                        Sort-Object -Property TimeUploaded
    }
    catch
    {
        $Error[0]
    }

    if($Download)
    {
        if($Blob -eq '')
        {
            $Blob = ($BlobList | Select-Object -Last 1).Name
        }

        try
        {
            Get-AzureStorageBlobContent -Blob $Blob -Container $ContainerName -Destination $Destination -Context $Context -Verbose
        }
        catch
        {
            $Error[0]
        }
    }
    elseif($ShortOutput)
    {
        $BlobList | Select-Object -Property Name, Length, LastModified, TimeUploaded
    }
    else
    {
        $BlobList
    }
}

# -- need better error handling
#
function Publish-JohncravPsProfile
{
    param(
            #[parameter(mandatory=$true)][Microsoft.WindowsAzure.Commands.Storage.Model.ResourceModel.AzureStorageContext]$Context = $null,
            [parameter(mandatory=$true, ValueFromPipeline=$true)][System.Object]$Context = $null, 
            [String]$ContainerName = 'ps-profile',
            [String]$ProfilePath = $PROFILE
         )

    $h = @{'Message' = ''}

    $td = Get-Date
    
    try
    {
        #$h['Message'] = "Checking for container `"$ContainerName`" in storage account `"" + $Context.StorageAccountName + '".'; New-Object -TypeName psobject -Property $h
        
        $null = Get-AzureStorageContainer -Name $ContainerName -Context $Context -ErrorAction SilentlyContinue

        if(-not $?)
        {
            #$h['Message'] = "Creating container `"$ContainerName`" in storage account `"" + $Context.StorageAccountName + '".'; New-Object -TypeName psobject -Property $h
            $null = New-AzureStorageContainer -Name $Context -Context $Context
        }
    }
    catch
    {
        return $Error[0]
    }

    $ProfileDir = Split-Path -Path $ProfilePath -Parent
    $ProfileFile = Split-Path -Path $ProfilePath -Leaf
    
    $NewProfileFile = (([System.GUID]::newGUID()).Guid -replace '.{12}$', (Get-Date).ToFileTime() ) + '.ps1'  #---replacing last portion of guid with datetime in 'filetime' format.
    $NewProfilePath = $ProfileDir + '\' +  $NewProfileFile

    try
    {
        Copy-Item -Path $ProfilePath -Destination $NewProfilePath
    }
    catch
    {
        return $Error[0]
    }

    try
    {
        Set-AzureStorageBlobContent -File $NewProfilePath -Container $ContainerName -Blob $NewProfileFile -Context $Context
    }
    catch
    {
        return $Error[0]
    }

    try
    {
        Remove-Item -Path $NewProfilePath
    }
    catch
    {
        return $Error[0]
    }
}


function New-DevOpsPassword
{
    $g = [System.GUID]::newGUID()

    $front = $g.Guid.tostring().Substring(0,7)
    $back = $g.Guid.tostring().ToUpper().Substring(7,7)
    
    $pw = ''

    $s = '!@#$%^&*()_+'
    $a = 'abcdefghijklmnopqrstuvwzyz'

    if($front -notmatch '[a-zA-Z]')
    {
        $front += $a.Substring((Get-Random -Maximum 25), 1)
    }

    if($back -notmatch '[a-zA-Z]')
    {
        $back += $a.Substring((Get-Random -Maximum 25), 1)
    }

    if((Get-Random -Maximum 2)%2)
    {
        $pw = $front + $s.Substring((Get-Random -Maximum 11), 1) + $back
    }
    else
    {
        $pw = $back + $front + $s.Substring((Get-Random -Maximum 11), 1)
    }

   return(New-Object -TypeName psobject -Property @{'Guid' = $g.Guid; 'Password' = $pw;})
}

function New-DevOpsAzStorageContext
{
    param(
        [parameter(mandatory=$true,ValueFromPipelineByPropertyName=$true)][String]$StorageAccountName,
        [parameter(mandatory=$true,ValueFromPipelineByPropertyName=$true)][String]$Primary
        )

    begin
    {
        #---test for the existance of the Azure Module that supports New-AzureStorageContext cmdlt
    }
    process
    {
        return( New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $Primary )
    }
    
}

function Invoke-DevOpsAzRestApiCall
{
    param(
        [parameter(mandatory=$true)][String]$UriTemplate,
        [parameter(mandatory=$true)][String]$ApiVersion,
        [parameter(mandatory=$true, ValueFromPipelineByPropertyName=$true)][String]$SubscriptionId,
        [parameter(mandatory=$true, ValueFromPipelineByPropertyName=$true)][System.Security.Cryptography.X509Certificates.X509Certificate]$Certificate,
        [hashtable]$Headers = @{'x-ms-version' =''},
        [String]$UriToken = '<subscription-id>',
        [String]$SubscriptionName = 'SubscriptionName'
        )
       
    $Uri = $UriTemplate -replace $UriToken, $SubscriptionId
    $Headers['x-ms-version'] = $ApiVersion

    return( Invoke-RestMethod -Uri $Uri -Certificate $Certificate -Headers $Headers | Add-Member -PassThru -MemberType NoteProperty -Name 'SubscriptionId' -Value $SubscriptionId | Add-Member -PassThru -MemberType NoteProperty -Name $SubscriptionName -Value $SubscriptionName )
}

#---Gets RemoteAccess thumbprint, username and encrypted password, per role, from passed in CSCFG object
function Get-DevOpsCscfgRemoteAccessData
{
    param(
            [parameter(mandatory=$true, ValueFromPipeline=$true)][System.Object[]]$CscfgObj = $null
         )

    begin
    {
        $cpat = 'RemoteAccess'
        $upat = 'RemoteAccess.*Username'
        $ppat = 'RemoteAccess.*ptedPassword'

        $h = @{'ServiceName' = $null; 'RoleName' = $null; 'AccountUsername' = $null; 'EncryptedPassword' = $null; 'thumbprint' = $null; }
    }

    process
    {
        foreach( $Obj in $CscfgObj )
        {
            $certlist = Get-DevOpsAzCscfgInfo -CscfgObj $Obj -Certificates
            $uplist = Get-DevOpsAzCscfgInfo -CscfgObj $Obj -ConfigurationSettings
            $rlist = Get-DevOpsAzCscfgInfo -CscfgObj $Obj -Roles

            #$certlist

            foreach( $r in $rlist )
            {
                $o = New-Object -TypeName psobject -Property $h

                $o.ServiceName = $obj.ServiceName

                $certlist | Where-Object { $_.name -match $cpat -and $_.RoleName -eq $r.RoleName } | ForEach-Object { $o.RoleName = $_.RoleName; $o.thumbprint = $_.thumbprint }
                $uplist | Where-Object { $_.name -match $upat -and $_.RoleName -eq $r.RoleName } | ForEach-Object { $o.AccountUsername = $_.value }
                $uplist | Where-Object { $_.name -match $ppat -and $_.RoleName -eq $r.RoleName } | ForEach-Object { $o.EncryptedPassword = $_.value }
            
                $o | Select-Object -Property ServiceName, RoleName, thumbprint, AccountUsername, EncryptedPassword
            }    
            
        }
    }
    
    end{}
}

#---Saves the XML file content from a Get-DevOpsAzCscfg object
#
function Save-DevOpsCscfgFromObj
{
    param(
            [parameter(Mandatory=$true, ValueFromPipeline=$true)][System.Object[]]$CscfgObj = $null
         )

    begin{}

    process
    {
        foreach($Obj in $CscfgObj)
        {        
            $g = NewGuid
            $x = $null
            $f = $PWD.Path
    
            if($Obj -ne $null)
            {
                [xml]$x = $Obj.Configuration

                $ServiceName = $Obj.ServiceName
            }
    
	        $f = $f + '\' + $ServiceName + '.cscfg.' + $g.Guid

            try
            {
                $x.save($f)

                New-Object -TypeName psobject -Property @{'Message'='File saved.'; 'FileName'= ( Split-Path -Path $f -Leaf ); 'ServiceName' = $ServiceName } | Select-Object -Property ServiceName, Message, FileName
            }
            catch
            {
                Write-Error -ErrorRecord $Error[0]
            }
        }
    }

    end{}
}


#--pareses an MDS MonitoringXStoreAccounts setting value
function Get-DevOpsCscfgMonXStoreAcctVal
{
    param(
            [parameter(Mandatory=$true, ValueFromPipeline=$true)][System.Object[]]$CscfgObj = $null
         )

    begin
    {
        $pat = 'MonitoringXStoreAccounts'
    }

    process
    {
        foreach($val in ( Get-DevOpsAzCscfgInfo -CscfgObj $CscfgObj -ConfigurationSettings | Where-Object{ $_.name -match $pat } | ForEach-Object {$_.value} ) )
        {
            $s = $val.split('#')
            
            $h = @{'name' = $s[0]; 'usePathStyleUris' = $s[1]; 'accountName' = $s[2]; 'accountSharedKey' = $s[3]; 'tableUri' = $s[4]; 'queueUri' = $s[5]; 'blobUri' = $s[6]; 'CertStore'  = $s[7]}
            
            New-Object -TypeName psobject -Property $h | Select-Object -Property name, usePathStyleUris, accountName, accountSharedKey, tableUri, queueUri, blobUri, CertStore
        }
    }

    end{}
}

function ConvertTo-DevOpsMonXStoreAcctVal
{
    param(
            [parameter(Mandatory=$true, ValueFromPipeline=$true)][System.Object[]]$Obj = $null
         )

    begin
    {
        if($Obj -eq $null)
        {
            return 'usage: ConvertTo-DevOpsMonXStoreAcctVal [-Obj [Object]]'
        }
    }

    process
    {
        foreach($o in $Obj)
        {
            $l = $o.name + '#' + $o.usePathStyleUris + '#' + $o.accountName + '#' + $o.accountSharedKey + '#' + $o.tableUri + '#' + $o.queueUri + '#' + $o.blobUri + '#' + $o.CertStore

            $l
        }
    }

    end{}
}


#---returns a PSCredential from a passed in plain text user name and password
function Set-DevOpsPlTxCred
{
	param([String]$UserName = '', [String]$Password = '')

	$pw = ConvertTo-SecureString -String $Password -AsPlainText -Force

	return ( New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $pw )
}

#---returns one of the four primary nodes associated with the CSCFG file
function Get-DevOpsAzCscfgInfo
{
    param(
            [parameter(Mandatory=$true, ValueFromPipeline=$true)][System.Object[]]$CscfgObj = $null,
            [switch]$Roles = $false,
            [switch]$ConfigurationSettings = $false,
            [switch]$Instances = $false,
            [switch]$Certificates = $false,
            [string]$ServiceName = $null
        )

    begin{}
    
    process
    {
        $x = $null
        $or = @()
    
        foreach($Obj in $CscfgObj)
        {
            try
            {
                [xml]$x = $Obj.Configuration
            }
            catch
            {
                Write-Error -ErrorRecord $Error[0] -Message "Had problems reading in CSCFG object."
            }

            $ServiceName = $Obj.ServiceName

            if($Roles)
            {
                return ( $x.ServiceConfiguration.Role | Add-Member -PassThru -MemberType NoteProperty -Name ServiceName -Value $ServiceName | Select-Object -Property ServiceName, @{Name="RoleName"; Expression = {$_.name}} )
            }
            elseif($ConfigurationSettings)
            {
                return ( $x.ServiceConfiguration.Role | ForEach-Object { $rn = $_.name; $_.ConfigurationSettings.Setting  | Add-Member -PassThru -MemberType NoteProperty -Name ServiceName -Value $ServiceName  | Add-Member -PassThru -MemberType NoteProperty -Name RoleName -Value $rn } )        
            }
            elseif($Instances)
            {
                return( $x.ServiceConfiguration.Role | ForEach-Object { $rn = $_.name; $_.Instances  | Add-Member -PassThru -MemberType NoteProperty -Name ServiceName -Value $ServiceName | Add-Member -PassThru -MemberType NoteProperty -Name RoleName -Value $rn } )
            }
            elseif($Certificates)
            {
                return ( $x.ServiceConfiguration.Role | ForEach-Object { $rn = $_.name; $_.Certificates.Certificate  | Add-Member -PassThru -MemberType NoteProperty -Name ServiceName -Value $ServiceName | Add-Member -PassThru -MemberType NoteProperty -Name RoleName -Value $rn } )
            }
            else
            {
                return $x
            }
        }
    }

    end{}
}

#---Downloads the CSCFG file from all deployments of the passed in azure subscription and returns CscfgObj objects for every hosted service it finds
#   
function Get-DevOpsAzCscfg
{
      param(
            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName=$true)][String[]]$SubscriptionName = '',
            [String]$Slot = 'Production'
           )
      
      begin{}

      process
      {
        foreach($subname in $SubscriptionName)
        {
            Select-AzureSubscription -SubscriptionName $SubName -ErrorAction SilentlyContinue

            $a = $null
      
            if(-not $?)
            {
                $error[0]
            }

            if($slot -notmatch '^Production$|^Staging$')
            {
                Write-Error -Message "Slot name `"$Slot`" is invalid."
            
            }

            Get-AzureService | Get-AzureDeployment -Slot $Slot | Select-Object -Property ServiceName, Configuration
        }
    }
    end{}
}

#---Returns CscfgObj objects for the passed in CSCFG files
#   
function Get-DevOpsAzCscfgFile
{
      param(
                [parameter(Mandatory = $true, ValueFromPipelineByPropertyName=$true)][String[]]$FullName = ''
           )
      
      begin{}

      process
      {
        foreach($path in $FullName)
        {
            $o = New-Object -TypeName psobject -Property @{'ServiceName' = ''; 'Configuration' = '' }

            try
            {
                $o.ServiceName = Split-Path -Path $path -Leaf
                $o.Configuration = Get-Content -Path $path
            }
            catch
            {
                Write-Error -ErrorRecord $Error[0]
            }
            
            return $o
        }
    }
    end{}
}

#--lists out the Azure subscription names that are loaded with the Azure Module
#
function Get-DevOpsAzSubs
{
	param($Pattern = '')

    Return (Get-AzureSubscription | ? SubscriptionName -Match $Pattern | Sort-Object -Property SubscriptionName | Select-Object -Property SubscriptionName, SubscriptionId, @{'name'='Thumbprint'; Expression = {$_.Certificate.Thumbprint}} )
}

#---Gets Service/Role/Instance Status of all hosted services 
#   of the passed in Azure Sub.  The Sub must be configured in
#   th Azure Snapin -- needs better error checking
function Get-DevOpsAzSRI
{
      param(
		[parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)][String]$SubscriptionName = '', 
		[String]$Slot = 'Production', 
		[String]$ServiceName = '', 
		[Switch]$ExtendedOutput = $false
	   )

    begin{}
      
	process
    {

        Select-AzureSubscription -SubscriptionName $SubscriptionName -ErrorAction SilentlyContinue
      
        if(-not $?)
        {
            $error[0]
            return $null
        }

        if($slot -notmatch '^Production$|^Staging$')
        {
            Write-Error -Message "Slot name `"$Slot`" is invalid."
            return $null
        }

        if($ServiceName)
        {
            $rt = Get-AzureService -ServiceName $ServiceName | Get-AzureDeployment -Slot $Slot | 
            ForEach-Object { 
                $sn = $_.ServiceName; $dt = Get-Date; $lb = $_.label; $did = $_.DeploymentId; $slt = $_.Slot; $sdk = $_.SdkVersion; $_.RoleInstanceList | 
                    Add-Member -PassThru -MemberType 'NoteProperty' -Name ServiceName -Value $sn | 
                        Add-Member -PassThru -MemberType 'NoteProperty' -Name DateTime -Value $dt  | 
                            Add-Member -PassThru -MemberType 'NoteProperty' -Name Subscription -Value $SubName  | 
                                Add-Member -PassThru -MemberType 'NoteProperty' -Name Label -Value $lb  | 
                            	    Add-Member -PassThru -MemberType 'NoteProperty' -Name Slot -Value $slt  |
	                                    Add-Member -PassThru -MemberType 'NoteProperty' -Name SdkVersion -Value $sdk  |
        	                    	        Add-Member -PassThru -MemberType 'NoteProperty' -Name DeploymentId -Value $did
                            }
        }
        else
        {
            $rt = Get-AzureService | Get-AzureDeployment -Slot $Slot | 
            ForEach-Object { 
                $sn = $_.ServiceName; $dt = Get-Date; $lb = $_.label; $did = $_.DeploymentId; $slt = $_.Slot; $sdk = $_.SdkVersion; $_.RoleInstanceList | 
                    Add-Member -PassThru -MemberType 'NoteProperty' -Name ServiceName -Value $sn | 
                        Add-Member -PassThru -MemberType 'NoteProperty' -Name DateTime -Value $dt  | 
                            Add-Member -PassThru -MemberType 'NoteProperty' -Name Subscription -Value $SubName  | 
                                Add-Member -PassThru -MemberType 'NoteProperty' -Name Label -Value $lb  |
                            	    Add-Member -PassThru -MemberType 'NoteProperty' -Name Slot -Value $slt  |
	                                    Add-Member -PassThru -MemberType 'NoteProperty' -Name SdkVersion -Value $sdk  |
        	                    	        Add-Member -PassThru -MemberType 'NoteProperty' -Name DeploymentId -Value $did
                            }
        }

        if($ExtendedOutput)    
        {
	        return $rt | Select-Object -Property DateTime, Label, Slot, ServiceName, RoleName, InstanceName, InstanceStatus, PowerState, Subscription, DeploymentId, SdkVersion, InstanceSize
        }
        else
        {
	        return $rt | Select-Object -Property DateTime, Label, Slot, ServiceName, RoleName, InstanceName, InstanceStatus, PowerState
        }

	} #---end process block

    end{}
}

#---converts the string representation of a cert into a cert object
function ConvertFrom-DevOpsCertString
{
    param([String]$CertString = '')

    $enc = [system.Text.Encoding]::UTF8
    $b = $enc.GetBytes($CertString)
    $c = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList (,$b)

    return $c
}

function Get-DevOpsLmmCert
{
	param([String]$Thumbprint = '')

	$p = 'Cert:\LocalMachine\My\' + $Thumbprint

	return (Get-Item -Path $p)
}

function DbQueryListDb
{
	return 'select name from sys.databases'
}

function DbQueryListTable
{
	return 'select * from information_schema.tables'
}

#---Returns a web service proxy to a zip code WS -- need to add error-handling
function GetZipCodeInfo
{

                $wsp = New-WebServiceProxy -Uri 'http://www.webservicex.net/uszip.asmx'

                return $wsp
}


#---Gets a Stock Quote -- need to add error-handling
#   If you use it too many times within a short period
#   of time it will ask for a license or tell you to come
#   back later.
function GetIpLocation
{
                param([String]$ip = '')

                if($ip -eq '')
                {
                                return('usage: GetIpLocation <[String] -ip>')
                }

                $wsp = New-WebServiceProxy -Uri 'http://ws.cdyne.com/ip2geo/ip2geo.asmx'

                $x = $wsp.ResolveIP($ip, '')

                return $x
}

#--- new implementation using different API
#
function Get-StockQuote
{
    param( [parameter(Mandatory=$true, ValueFromPipeline=$true)][String]$Symbol = $null
           
         )
    $uri = 'http://dev.markitondemand.com/Api/v2/Quote?symbol=' + $symbol

    try
    {
        return ( Invoke-RestMethod -Uri $uri | %{ if($_.Error){ $_.error }else{ $_.StockQuote } } )
    }
    catch
    {
        return $Error[0]
    }
    
}


#---Gets a Stock Quote -- need to add error-handling
function GetStockQuote
{
                param([String]$ticker = '')


                if($ticker -eq '')
                {
                                return('usage: GetStockQuote <[String] -ticker>')
                }

                $wsp = New-WebServiceProxy -Uri 'http://www.webservicex.net/stockquote.asmx'

                [xml]$x = $wsp.GetQuote($ticker)

                return ($x.StockQuotes.Stock)
}


#---list out Sched Tasks
function ListSchedTask
{
                return ( schtasks /query /fo csv /v | ConvertFrom-Csv )
}


#---list IE Favorites

function ListFavorites
{
                ( Get-Variable -Name home ).value  + '\Favorites' |
                                
                                Get-ChildItem -Recurse |
                                ?{ -not $_.psiscontainer } |
                                %{ $n = $_.name -replace '.url$', ''; $fn = $_.fullname; $bu = ( Get-Content $fn | ?{ $_ -match '^BASEURL|^URL' } );
                                   New-Object -TypeName psobject -Property @{ 'Name' = $n; 'URL' = $bu } }
}


#---creates a GUID
function NewGuid
{
                return [System.GUID]::newGUID()
}


#---Parses a URL into three pieces
#
function ParseURL
{
    param([string]$url = '')
    
    $usage = 'ParseURL [-url <String>]'
    
    if( $url -eq '' )
    {
        return $usage
    }
    
    $pat = '(^http.*//)(.+?)(/.*$)'
    
    $o = New-Object -TypeName PSObject -Property @{'Protocol' = $null; 'FQDN' = $null; 'UriStem' = $null}
    
    if( $url -match $pat )
    {
        $o.Protocol = $Matches[1]
        $o.FQDN = $Matches[2]
        $o.UriStem = $Matches[3]
    }
    
    return $o
}

#--Parses a SQL connection
#  from the passed in file
#
function ParseDBConnStr
{
    param([String]$File = '', [switch]$ShowPassword = $false)
    
    $usage = 'usage: ParseConnStr [-file <String>]'
        
    if( $file -eq '' )
    {
        return $usage
    }
    
    $o = $null
    $h = @{
            'ConnectionString' = $null;
            'Line' = $null;
            'File' = $null;
            'DataSource' = $null;
            'InitialCatalog' = $null;
            'UserID' = $null;
            'Password' = $null;
            'MultipleActiveResultSets' = $null;
            'Encrypt' = $null
            }
            
    $pwscrub = '********'
    $pwscrubCS = 'Password=********;'
    
    $pat0 = 'ConnectionString.*catalog'
    $pat1 = '(Data Source=.+?)"'
    $patDS = 'Data Source=(.+?);'
    $patIC = 'Initial Catalog=(.+?);'
    $patUID = 'User ID=(.+?);'
    $patPWscrub = '(Password=.+?;)'
    $patPW = 'Password=(.+?);'
    $patMARS = 'MultipleActiveResultSets=(.+?);'
    $patE = 'Encrypt=(\w+)'
    
    try
    {
        foreach( $l in ( Get-Content -Path $File | Where-Object { $_ -match $pat0 } ) )
        {
            $o = New-Object -TypeName PSObject -Property $h
            
            $o.File = ( Get-Item -Path $File ).FullName
            
            $l = $l -replace '^\s+', ''
            $l = $l -replace '\s+$', ''
            
            $o.Line = $l
            
            $null = $l -match $pat1
            $o.ConnectionString = $Matches[1]
            
            if( $o.ConnectionString -match '(^.+?)\|' )
            {
                $o.ConnectionString = $Matches[1]
            }
            
            if( -not $ShowPassword )
            {
                $o.Line = $o.Line -replace $patPWscrub, $pwscrubCS
                $o.ConnectionString = $o.ConnectionString -replace $patPWscrub, $pwscrubCS
            }
            
            $null = $o.ConnectionString -match $patDS
            $o.DataSource = $Matches[1]
            
            $null = $o.ConnectionString -match $patIC
            $o.InitialCatalog = $Matches[1]

            $null = $o.ConnectionString -match $patUID
            $o.UserID = $Matches[1]
            
            $null = $o.ConnectionString -match $patPW
            if( -not $ShowPassword )
            {
               $o.Password = $pwscrub
            }
            else
            {
                $o.Password = $Matches[1]
            }
            
            $null = $o.ConnectionString -match $patMARS
            $o.MultipleActiveResultSets = $Matches[1]

            $null = $o.ConnectionString -match $patE
            $o.Encrypt = $Matches[1]

            $o | Select-Object -Property DataSource, InitialCatalog, UserID, Password, MultipleActiveResultSets, Encrypt, ConnectionString, Line, File
        }
    }
    catch
    {
        return $Error[0]
    }
    
}

# reads in an XML file and returns and XML object
#
function Get-XMLobj
{
    param(
            [parameter(mandatory=$true, ValueFromPipelineByPropertyName=$true)][String[]]$FullName = ''
         )


    begin{}

    process
    {
        foreach( $p in $FullName)
        {
            [xml]$x = Get-Content -Path $FullName
            return $x
        }
        
        return $x 
    }

    end{}
}

#---parses an HWLB device name
#
function HwlbDevParse
{
    param( [String]$DeviceName = '')
    
    $usage = 'HwlbDevParse [-DeviceName <String>]'
    $pat = '(^.+)(.$)'
    
    
    if($n -eq $DeviceName)
    {
        return $usage
    }
    
    if( $DeviceName -match $pat )
    {
        return ( New-Object -TypeName psobject -Property @{ 'DeviceName' = $Matches[0]; 'Major' = $Matches[1]; 'Suffix' = $Matches[2] } )
    }

}

#---takes the passed in raw cert byte array and writes it to disk
#
function WriteRawCertData
{
                param([Byte[]]$RawCert, [String]$FilePath)

                $usage = 'usage: WriteRawCertData [-RawCert <RawCert[]>] [FilePath <String>]'

                if(-not $RawCert)
                {
                                return $usage
                }
                
                if(-not $FilePath)
                {
                                return $usage
                }

                [system.IO.file]::WriteAllBytes($FilePath, $RawCert)
}


#---Lists out the cert and relevant data, of the passed in HTTPS URL
#
function Get-SiteCert
{
                param([String]$url)

                $usage = 'usage: CheckSiteCert [-url <String>]'

                if( -not $url )
                {
                                return $usage
                }

                if($url -notmatch 'https.*')
                {
                                return "Error: URL `"$url`" is not using HTTPS."
                }

                try
                {
                                $WebReq = [System.Net.HttpWebRequest]::Create($url)
                                $Resp = $WebReq.GetResponse()
                                $Resp.Close()
                }
                catch
                {
                return "Error: problems connecting to site $url"
                }

                if($WebReq.ServicePoint.Certificate) #---some sites just redir to their HTTP site if HTTPS not supported, www.yahoo.com
                {
                                [DateTime]$ExpDate = ( $WebReq.ServicePoint.Certificate ).GetExpirationDateString()

                                $CertLifeTime = New-TimeSpan -Start ( Get-Date ) -End $ExpDate | Select-Object -Property Days, Hours, Minutes
                }

                $o = New-Object -TypeName PSObject -Property @{'URL' = $null; 'ResponseUri' = $null; 'CertSubject' = $null; 'CertExpirationDate' = $null; 'CertLifetime' = $null; 'RawCertData' = $null}

                $o.URL = $url
                $o.ResponseUri = $Resp.ResponseUri.AbsoluteUri
                $o.CertSubject = $WebReq.ServicePoint.Certificate.Subject
                $o.CertExpirationDate = $ExpDate
                $o.CertLifetime = $CertLifeTime
                $O.RawCertData = $WebReq.ServicePoint.Certificate.GetRawCertData()

                return $o
} 


#---creates a blank Storage Analytics Management object
#
function BlankStorAnaManObj
{
                return ( New-Object -TypeName psobject -Property @{     'SubscriptionId' = ''; 
                                                                                                                                'StorageAccountName' = '';
                                                                                                                                'ServiceName' = '';
                                                                                                                                'StorageAccountKey' = '';
                                                                                                                                'CertificateThumbprint' = '';
                                                                                                                                'LocalPathRoot' = '';
                                                                                                                                'FileName' = '' } )
}

#--looks up the SCOM servers used to manage the pasdssed in node
#
function IdScomServer
{
                param([String]$server = $null )

                $rk = 'HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Agent Management Groups'
                $pat = 'parent.*0'

                if($server)
                {              
                                Invoke-Command -ComputerName $server -ScriptBlock { param($rk); Get-ChildItem -Path $rk -Recurse | where-object { $_.name -match $pat } | Get-ItemProperty | where-object { $_.networkname } | Select-Object -Property NetworkName } -argumentlist $rk
                }
                else
                {
                                Get-ChildItem -PAth $rk -Recurse | where-object { $_.name -match $pat } | Get-ItemProperty | where-object { $_.networkname } | Select-Object -Property NetworkName
                }
}


#---This function checks which HWLB a given servers can use.
#   It works by searching the passed in and LTM VLAN object collection
#   for the CIDR associated with the passed in IPaddress opject.
#

function FindHWLB
{
    param([system.object[]]$IpObj = $null, [system.object[]]$VlanObj = @())
    
    $usage = 'FindHWLB [-IpObj <System.Object[]>] [-VlanObj <system.object[]>]'
    
    if($IpObj.length -eq $null)
    {
        "usage: $usage"
        return $null
    }

    if($VlanObj.length -eq $null)
    {
        "usage: $usage"
        return $null
    }
    
    $h = @{'Server' = $null; 'IPAddress' = $null; 'Cidr' = $null; 'MACAddress' = $null; 'VlanName' = $null; 'VlanNetworks' = $null; 'Device' = $null }
        
    foreach ( $i in $IPObj )
    {
        foreach ( $c in $i.cidr )
        {
            foreach ( $v in $VlanObj )
            {
                if( $v.Networks -contains $c )
                {
                    $o = New-Object -TypeName PSObject -Property $h
                
                    $o.Server = $i.DNSHostName
                    $o.IPAddress = $i.IPAddress
                    $o.MACAddress = $i.MACAddress
                    $o.Cidr = $i.Cidr
                    $o.Device = $v.Device
                    $o.VlanName = $v.Name
                    $o.VlanNetworks = $v.Networks
                
                    $o | Select-Object -Property Server, IPAddress, Cidr, MACAddress, Device, VlanName, VlanNetworks
                }
            }
        }
    }
}


#---parses an ITM Policy file into a PS object with the following fields 
#   id,loadShare,ttl,name,monUrl,mon,shedFraction,ipAddr,label
#
function ITMserverView
{
    param([string]$infile = '' )
    
    if($infile -eq '')
    {
        "usage: ITMserverView [-infile <String>]"
        return $null
    }
    
    [xml]$x = Get-Content -Path $infile 
    
    $h = @{}
    
    $x.POLICY | ForEach-Object { $_.MANAGEDSERVER } | Get-Member -MemberType Property | ForEach-Object { $h.add( $_.name, $null) }
    
    $managedserver = $x.POLICY | ForEach-Object { $_.MANAGEDSERVER } | ForEach-Object { $o = $_; $p = New-Object -TypeName PSOBject -Property $h; $h.keys | ForEach-Object { $p.$_ = $o.$_ }; $p }
    
    $h = @{'label' = $null; 'id' = $null }
    
    $node = $x.POLICY | ForEach-Object { $_.NODE } | ForEach-Object { $l = $_.label; $_.RESOURCE | ForEach-Object { $i = $_.id; New-Object -TypeName PSObject -Property @{'label' = $l; 'id' = $i } } }
    $node += $x.POLICY | ForEach-Object { $_.BRANCH } |ForEach-Object { $_.NODE } | ForEach-Object { $l = $_.label; $_.RESOURCE | where-object {$_} | ForEach-Object { $i = $_.id; New-Object -TypeName PSObject -Property @{'label' = $l; 'id' = $i } } }

    #$node

    $report0 = $managedserver | ForEach-Object { $mso = $_; $node | Where-Object { $_.label -and ( $_.id -eq $mso.id) } | ForEach-Object { $no = $_; $mso | Add-Member -PassThru -MemberType 'NoteProperty' -Name 'label' -Value $no.label -ErrorAction SilentlyContinue } }
    
    
    
    $report1 = $managedserver | Where-Object { ( $report | ForEach-Object { $_.id } ) -notcontains $_.id } | Add-Member -PassThru -MemberType 'NoteProperty' -Name 'label' -Value $null -ErrorAction SilentlyContinue
    
    return ( $report0 + $report1 )
    
}

#---Gets the next cert up the chain of the passed in cert
#
function Get-IssuerCert
{
    param([System.Security.Cryptography.X509Certificates.X509Certificate]$cert = $null, [String]$StorePath = 'cert:\LocalMachine\CA')
    
    $e = ''
    
    $AKI = $cert.Extensions | Where-Object { $_.oid.FriendlyName -eq 'Authority Key Identifier' } | %{ $_.format(1) }
    
    #---Now we need to parse the strring as it comes out like this: "KeyID=08 42 e3 ..."
    #   Note:  if the next cert in the chan is a root cert the format is different
    #          it comes out in a multi lined string like this:
    #
    #          Certificate Issuer:
    #         Directory Address:
    #              CN=GTE CyberTrust Global Root
    #              OU="GTE CyberTrust Solutions, Inc."
    #              O=GTE Corporation
    #              C=US
    #         Certificate SerialNumber=01 a5
    #
    #          this function does not handle this case.
    
    $AKI = $AKI -replace 'KeyID=', ''  #---get rid of 'KeyID='
    $AKI = $AKI -replace '\s', ''  #---get rid of all spaces
    $AKI = $AKI -replace '\n', ''  #---get rid of newline
    
    $a = Get-ChildItem -Path $StorePath | Where-Object { ForEach-Object { $_.Extensions } | Where-Object { $_.oid.FriendlyName -eq 'Subject Key Identifier' } | Where-Object { $_.SubjectKeyIdentifier -eq $AKI } }
    
    return $a
}


#---creates a "blank" Cert Config record
#
function CertConfRec
{
                param( [String]$Env = $null, [String]$Build = $null, [String]$SUName = $null, [String]$Role = $null, [String]$SubRole = $null, [String]$CNIDType = $null, [String]$CNID = $null, [String]$SANID = $null, [String]$DNSubString = $null, [Boolean]$HasPrivateKey = $false, [String]$CertStoreName = $null, [String]$PriKeyAccessAccount = $null, [Boolean]$IISbind = $false, [String]$RawSUName = $null )

                $p = 'Env','Build','SUName','Role','SubRole','CNIDType','CNID','SANID','DNSubString','HasPrivateKey','CertStoreName','PriKeyAccessAccount','IISbind','RawSUName'

                $o = new-object system.object

                $p | ForEach-Object { Add-Member -InputObject $o -MemberType 'NoteProperty' -Name $_ -Value ( Get-Variable -Name $_ ).Value }

                $o
}

#---creates a "blank" SWD-Infra record object
#
function swdrecord
{
                param( [String]$EnvName = $null, [String]$SubscriptionId = $null, [String]$StorAccount = $null, [String]$Origin = $null, [String]$MmcDnsName = $null, [String]$CDN = $null )

                $p = 'EnvName','SubscriptionId','StorAccount','Origin','MmcDnsName','CDN'

                $o = new-object system.object

                $p | ForEach-Object { Add-Member -InputObject $o -MemberType 'NoteProperty' -Name $_ -Value ( Get-Variable -Name $_ ).Value }

                $o
}


#---very simple A record lookup using system.net.dns
#
function Arecord
{
                param([String]$name = '')

                return ( [system.net.dns]::GetHostEntry($name) | Select-Object -Property HostName, Aliases -ExpandProperty AddressList | Select-Object -Property HostName, Aliases, Address, AddressFamily, IPAddressToString )
}



#---Does the equivalent of a DNS reverse-lookup
#   Depends on an PS XML file containing NIC config
#   records with the ipaddress function (defined in
#   this file).
#
function PTRrecord
{
                param([String]$ip = '')

                $rp = 'C:\Users\johncrav\resources\gold\AllScoBoxIPInfo.xml';
                
                $r = Get-Item -Path $rp -ErrorAction SilentlyContinue
                
                if(-not $r)
                {
                                Write-Error -Message "$rp file does not exist"
                                return $null
                }
                
                $ipdb = Import-Clixml -Path $r.FullName

                return ( $ipdb | Where-Object { $_.IPAddress -contains $ip } ).DNSHostName
}


#---Get-Content on latest Microsoft.com.dns zone file
function mscomdns
{
                param([String]$Filter = 'microsoft.com.dns' )

                #$rt = '\\phx\services\dns\daily_zones_backup'
                $rt = '\\phx\services\azuredns\daily_zones_backup'
                $latestfolder = Get-ChildItem -Path $rt | Sort-Object -Property LastWriteTime | Select-Object -Last 1

                return ( Get-ChildItem -Path $latestfolder.fullname -Filter $Filter )
}


#---Outputs the SAN names of the passed in cert object
#
function Get-SANview
{
                param( [System.Security.Cryptography.X509Certificates.X509Certificate]$cert = $null )

                $SanFriendlyNameString = 'Subject Alternative Name'

                $del = ','

                if($cert -eq $null)
                {
                    "usage: ViewSAN <[-cert]<X509Certificate>>"
                    return
                }

                $SanExt = $cert.Extensions | Where-Object { $_.oid.FriendlyName -eq $SANFriendlyNameString }
                $SanStr = $SanExt.Format(1)

                #--gets created as a single string with names seperated by newlines.  turn it into a string array:

                $SanA = ( $SanStr -replace '\n', $del ).split($del)

                #---there is alwasy a blank element in the list so the Where-Object get's rid of it

                $SanA | Where-Object{$_ -match '.'}
}



#---parses the Key feild of a WinLiveOps.Gns.LocalTrafficManagement.LtmCmdLets.LtmProxyR2.LtmKey 
#   (from Get-LtmKnownVirtuals commandlet) into a nice object with VSName and VAP fields.
#
function VSKeyParse
{
    param([String]$k = '', [String]$location = '')

    $keydel = ','
    $vapdel = ':'
    
    $i = $k.split($keydel)
    
    $o = New-Object system.object
    
    Add-Member -InputObject $o -MemberType NoteProperty -Name 'VSName' -Value $i[1]
    Add-Member -InputObject $o -MemberType NoteProperty -Name 'VAP' -Value $i[0]

    
    
    $j = $o.VAP.split($vapdel)

    Add-Member -InputObject $o -MemberType NoteProperty -Name 'VIP' -Value $j[0]
    Add-Member -InputObject $o -MemberType NoteProperty -Name 'Port' -Value ([int]($j[1]))

    if($lacation -ne '')
    {
                Add-Member -InputObject $o -MemberType NoteProperty -Name 'deVICE' -Value $location
    }
    
    $o
}

#---parses an X509 cert's subject field and returns it as an object
#
#
function Get-CertSub
{
                param([String]$subject = '')

                $o = New-Object system.object

                if( $subject -notmatch ',|=' )
                {
                                Write-Error -Message 'Subject string $subject not in expected format'
                                return $null
                }

                $j = $j = $subject.Split(',') | ForEach-Object{ $_ -replace '^\s+', '' }

                $j | ForEach-Object{ $k = $_.split('='); Add-Member -InputObject $o -MemberType 'NoteProperty' -Name $k[0] -Value $k[1] }

                $o
}


#---returns an object of network names based on the 
#   network ini file in \\ipsconfigs\ADDROUTES
#
function Netnames
{
                $p = '\\ipsconfigs\ADDROUTES'
                $f = '*net*.ini'
                $bn = $null
                $o = $null

                $null = Get-Item -Path \\ipsconfigs\ADDROUTES -ErrorAction silentlycontinue

                if( -not $? )
                {
                                Write-Error -Message "Error: $p directory not found. Could not build NetName objects."
                                return 1
                }


                foreach ( $fo in ( Get-ChildItem -Path $p -Filter $f ) )
                {
                                $bn = $fo.BaseName
                                $o = $null

                                foreach ( $l in ( Get-Content -Path $fo.FullName ) )
                                {
                                                $o = New-Object system.object
                                                Add-Member -InputObject $o -MemberType NoteProperty -Name Cidr -Value $l
                                                Add-Member -InputObject $o -MemberType NoteProperty -Name NetName -Value $bn
                                                $o
                                }
                }
}

#---lists the contents of the "route script" share
#
#
function RouteScriptDir
{
                $p = '\\ipsconfigs\ADDROUTES'

                Get-ChildItem -Path $p
}



#---returns the .Net Version of the passed in computer
#   Assumtions:
#              - OS is located on c: drive
#              - Framework versions listed as folfer names in
#                                             - \\hostname\c$\Windows\Microsoft.NET\Framework
#                                             - \\hostname\c$\Windows\Microsoft.NET\Framework64
#
function get-dotnetversion
{
                param([String]$servername = "localhost")

                $rootfldr = 'c$\Windows\Microsoft.NET'
                $32bitName = 'Framework'
                $64bitName = 'Framework64'
                $vpat = '^v'

                $d = $null

                $o = New-Object system.object
                
                Add-Member -InputObject $o -MemberType NoteProperty -Name Server -Value $servername
                Add-Member -InputObject $o -MemberType NoteProperty -Name $32bitName -Value $null
                Add-Member -InputObject $o -MemberType NoteProperty -Name $64bitName -Value $null

                if( Get-Item -Path \\$servername\$rootfldr -ErrorAction SilentlyContinue )
                {
                                $d = Get-ChildItem -Path \\$servername\$rootfldr\$32bitName -ErrorAction SilentlyContinue

                                if( $d )
                                {
                                                $o.$32bitName = $d | Where-Object { $_.name -match $vpat } | ForEach-Object { $_.name }
                                }
                                
                                $d = $null

                                $d = Get-ChildItem -Path \\$servername\$rootfldr\$64bitName -ErrorAction SilentlyContinue

                                if( $d )
                                {
                                                $o.$64bitName = $d | Where-Object { $_.name -match $vpat } | ForEach-Object { $_.name }
                                }
                }
                
                $o
}


#---returns the QFE of the passed in computer
function get-qfe
{
                param([String]$servername = "localhost")

                $wmiclass = 'Win32_QuickFixEngineering'
                $i = $null

                foreach ( $i in ( Get-WmiObject -Class $wmiclass -ComputerName $servername ) )
                {
                                $i
                }
}


#---returns the Serial Number of the passed in computer, per info in the BIOS
function Get-SerialNumber
{
                param([String]$servername = "localhost")

                $wmiclass = 'Win32_BIOS'
                $i = $null

                foreach ( $i in ( Get-WmiObject -Class $wmiclass -ComputerName $servername ) )
                {
                                Add-Member -InputObject $i -MemberType noteproperty -Name ServerName -Value $servername

                                $i | Select-Object -Property ServerName, SerialNumber, Manufacturer, ReleaseDate, SMBIOSBIOSVersion
                }
}



#---gets basic HW details of the passed in box
function hardware
{
                param([String]$servername = "localhost")

                $wmiclass = 'Win32_ComputerSystem'
                $i = $null

                foreach ( $i in ( Get-WmiObject -Class $wmiclass -ComputerName $servername ) )
                {
                                $i | Select-Object -Property DNSHostName, Manufacturer, Model, OEMStringArray, SystemType
                }
}



#---gets RAM details of the passed in box
function ram
{
                param([String]$servername = "localhost")

                $wmiclass = 'Win32_PhysicalMemory'
                $i = $null
                $cpg = 0

                foreach ( $i in ( Get-WmiObject -Class $wmiclass -ComputerName $servername ) )
                {
                                Add-Member -InputObject $i -MemberType noteproperty -Name Server -Value $servername
                                Add-Member -InputObject $i -MemberType noteproperty -Name CapacityGig -Value ( $i.Capacity / 1gb )

                                $i | Select-Object -Property Server, DeviceLocator, DataWidth, CapacityGig, Capacity, Speed
                }              
}



#---gets CPU details of the passed in box
function cpu
{
                param([String]$servername = "localhost")

                $wmiclass = 'Win32_Processor'
                $i = $null

                foreach ( $i in ( Get-WmiObject -Class $wmiclass -ComputerName $servername ) )
                {
                                $i | Select-Object -Property SystemName, DeviceID, Manufacturer, Name, AddressWidth, MaxClockSpeed, L2CacheSize
                }              
}


#---gets details about a the disks of the passed in box
function disk
{
                param([String]$servername = "localhost")

                $wmiclass = 'Win32_LogicalDisk'

                $o = @()
                
                $fg = 0
                $sg = 0                  
                $pf = 0  

                foreach ( $i in ( Get-WmiObject -Class $wmiclass -ComputerName $servername ) )
                {
                                $fg = 0
                                $sg = 0                  
                                $pf = 0  

                                $fg = $i.FreeSpace / 1gb;
                                $sg = $i.Size / 1gb


                                if( $i.Size -eq $null -or $i.Size -eq 0 )
                                {
                                                $pf = $null
                                }
                                else
                                {
                                                $pf = ( $i.FreeSpace / $i.Size ) * 100
                                }


                                Add-Member -InputObject $i -MemberType noteproperty -Name FreeSpaceGB -Value $fg
                                Add-Member -InputObject $i -MemberType noteproperty -Name SizeGB -Value $sg
                                Add-Member -InputObject $i -MemberType noteproperty -Name PercentFree -Value $pf

                                $o += $i
                }

                $o | Select-Object -Property SystemName, DeviceID, VolumeName, SizeGB, FreeSpaceGB, PercentFree, Size, FreeSpace, DriveType, Description
}


#---creates a box list from the passed in prefix and number list
function boxes
{
                param([String]$p = 'DCMSFTTPAP', [Int32[]]$n = 0 )

                $n | ForEach-Object { $i = $_.ToString(); if( $i.length -eq 1 ) { $i = '0' + $i }; ( $p + $i ) }
}


#---gets details about a the OS of the passed in box
function os
{
                param([String]$servername = "localhost")

                $wmiclass = 'Win32_OperatingSystem'

                Get-WmiObject -Class $wmiclass  -ComputerName $servername | Select-Object -Property CSName, Caption, CSDVersion, Version, BuildNumber
}


function ConvertTo-Iisw3cTimeStamp
{
    param(
            [parameter(mandatory=$true, ValueFromPipeline=$true)][DateTime[]]$Date = $null
         )
    
    begin{}

    process
    {
        foreach($d in $Date)
        {
            $d.ToString('yyMMddHH')
        }
    }

    end{}
}

function ConvertFrom-Iisw3cTimeStamp
{
    param(
            [parameter(mandatory=$true, ValueFromPipeline=$true)][String[]]$DateString = $null
         )
    
    begin
    {
        [String]$yearscalar = Get-Date | Select-Object -Property year | ForEach-Object{[int]($_.year/100)}
    }

    process
    {
        foreach($d in $DateString)
        {
            Get-Date -Year ($yearscalar + $d.Substring(0,2)) -Month $d.Substring(2,2) -Day $d.Substring(4,2) -Hour $d.Substring(6,2)  -Minute 0 -Second 0
        }
    }

    end{}
}



#---creates a date-timestamp
function dstamp
{
        param([DateTime]$td, [Switch]$dir, [String]$rootpath = '')

        if( $td -eq $null )
        {
            $td = Get-Date
        }
		else
		{
			$td = Get-Date -Date $td
		}

                if( $rootpath -eq '' )
                {
                                $rootpath = '.'
                }

                $o = $td | Select-Object -Property DateTime, Kind

                if( $td.kind -eq 'Utc' )
                {
                                $o = $o | Add-Member -PassThru -MemberType NoteProperty -Name LocalTime -Value $td.ToLocalTime()
                }
                else
                {
                                $o = $o | Add-Member -PassThru -MemberType NoteProperty -Name UtcTime -Value $td.ToUniversalTime()
                }

                $o = $o | Add-Member -PassThru -MemberType NoteProperty -Name x-ms-date -Value ($td.ToUniversalTime()).ToString('R')
                $o = $o | Add-Member -PassThru -MemberType NoteProperty -Name Stamp -Value $td.ToString("yyyy-MM-dd")
                #$o = $o | Add-Member -PassThru -MemberType NoteProperty -Name IdcTime -Value ( $td.ToUniversalTime() ).addhours(5.5)
                $o = $o | Add-Member -PassThru -MemberType NoteProperty -Name Label -Value $td.ToString("yyyy-MM-dd--HH-mm-ss")
                $o = $o | Add-Member -PassThru -MemberType NoteProperty -Name IIS -Value $td.ToString("yyMMddHH")

                if( $dir )
                {

                                New-Item -Path ( $rootpath  + '\' + $ds ) -ItemType dir
                }
                else
                {
                                return $o 
                }
}

#---retruns the IP address of the passed in box
#   calls: get_net function (see below)
function ipaddress
{
                param([String]$servername = "localhost")

                $wmiclass = 'Win32_NetworkAdapterConfiguration'

                foreach ( $i in Get-WmiObject -Class $wmiclass -ComputerName $servername )
                {

                                if($i.IPAddress -match ".")
                                {
                                                $j = Select-Object -InputObject $i -Property DNSHostName, Index, IPAddress, IPSubnet, DefaultIPGateway, DNSServerSearchOrder, DomainDNSRegistrationEnabled, FullDNSRegistrationEnabled, WINSPrimaryServer, WINSSecondaryServer, TcpipNetbiosOptions, MACAddress, IPEnabled
                                                
                                                Add-Member -InputObject $j -MemberType NoteProperty -Name Cidr -Value ( get_net $j.IPAddress $j.IPSubnet )

                                                $j
                                }
                }
}


#----returns the IP v4 Route Table of the passed in box
#
function IPv4Route
{
                param([String]$servername = "localhost")

                $wmiclass = 'Win32_IP4RouteTable'

                foreach ( $i in Get-WmiObject -Class $wmiclass -ComputerName $servername )
                {
                                $j = Select-Object -InputObject $i Destination, Mask, NextHop, InterfaceIndex, Metric1
                                
                                Add-Member -InputObject $j -MemberType NoteProperty -Name Server -Value $servername
                                Add-Member -InputObject $j -MemberType NoteProperty -Name DestinationNet -Value ( get_net $i.Destination $i.Mask )

                                Select-Object -InputObject $j Server, DestinationNet, Destination, Mask, NextHop, InterfaceIndex, Metric1
                }
}


#----returns the IP v4 Persistent Route Table of the passed in box
#
function IPv4PersistentRoute
{
                param([String]$servername = "localhost")

                $wmiclass = 'Win32_IP4PersistedRouteTable'

                foreach ( $i in Get-WmiObject -Class $wmiclass -ComputerName $servername )
                {
                                $j = Select-Object -InputObject $i Destination, Mask, NextHop, Metric1

                                Add-Member -InputObject $j -MemberType NoteProperty -Name Server -Value $servername
                                Add-Member -InputObject $j -MemberType NoteProperty -Name DestinationNet -Value ( get_net $i.Destination $i.Mask )

                                Select-Object -InputObject $j Server, DestinationNet, Destination, Mask, NextHop, Metric1
                }
}



#---returns the CIDR-style suffix from the passed in IP-style subnet mask
#   called by: function get_net
function get_cidr_mask
{
                param([String]$ipmask = $null)

                $i = ''
                $j = '';

                $zero = '0'
                $mask = 0

                [String]$bip = $null
                [char[]]$bits = $null

                #---return 0 if we don;t get the right params
                #
                if($ipmask -eq $null)
                {
                                return 0
                }

                #---convert ip into a string of bits
                #
                $i = $ipmask.split(".")

                foreach ( $j in $i )
                {
                                [String]$bip += [System.Convert]::ToString($j,2).PadLeft(8,"0")
                }

                #---convert the binary string into an array of chars
                #
                $bits = $bip

                #---count the ones, stop when we hit o
                #
                foreach ( $i in $bits )
                {
                                if( $i -eq $zero )
                                {
                                                break
                                }

                                $mask++
                }

                return $mask
}


#---returns the CIDR prefixed network from the passed in
#   IP and Mask addresses
function get_net
{
                param([String[]]$ip = $null, [String[]]$mask = $null)

                $cidr = $null

                [String[]] $ipA = $null
                [String[]] $maskA = $null

                $delim = '.'
                $i = 0;
                $j = 0;

                $x = 0
                [String[]]$result = $null

                [String]$prefix = $null

                #---return 0 if we don't get the right params
                #
                if( ( $ip -eq $null ) -or ( $ip.length -lt 1 ) )
                {
                                return 0
                }
                #---return 0 if we don't get the right params
                #
                if( ( $mask.length -eq $null ) -or ( $mask.length -lt 1 ) )
                {
                                return 0
                }

                #---return 0 if we don't get the right params
                #
                if( $ip.length -ne $mask.length )
                {
                                return 0
                }

                for( $x = 0; $x -lt $ip.length; $x++ )
                {
                $prefix = '' #---got to clear this thing out if we have more than 1 IP

                                #---first get the CIDR suffix
                                #
                                $cidr = get_cidr_mask $mask[$x]

                                #---now calculate network prefix
                                #
                                $ipA = $ip[$x].split($delim)
                                $maskA = $mask[$x].split($delim)

                                for ( $i = 0; $i -lt $ipA.length; $i++ )
                                {
                                                $prefix += $ipA[$i] -band $maskA[$i]

                                                if ( $i -lt ( $ipA.length - 1 ) )
                                                {
                                                                $prefix += $delim
                                                }
                                                else
                                                {
                                                                $prefix += "/"
                                                }
                                }

                                $result += $prefix + $cidr
                }

                return $result
}


#---toggles the HW load-balancing heartbeat file of the passed in box
function toghb
{
                param( [string]$box = '',
                       [switch]$modify = $false,
                       [string]$hbpath = 'd$\mscomtest',
                       [string]$hbfile = 'test.htm',
                       [string]$obfus = '_'
                     )

                if( $box -eq '' )
                {
                                ""
                                "usage: toghbf [-box] <string> [-modify] [-hbpath [string]] [-hbfile [string]] [-obfus [string]]"
                                ""
                
                                return
                }

                $hbfilewc = $hbfile + '*'

                $i = ''
                $j = ''

                $i = Get-ChildItem "\\$box\$hbpath" -Filter $hbfilewc
                

                if( $i.name -match "$obfus$" )
                {
                                $j = $hbfile
                }
                else
                {
                                $j = $hbfile + $obfus
                }

                if(-not $modify)
                {
                                $i.fullname
                }
                else
                {
                                Rename-Item $i.fullname $j -Verbose
                }
}


#---remote uptime function
function ruptime
{
                param([String]$servername = "localhost")

                $wmiobj = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $servername

                $boxtime = [System.Management.ManagementDateTimeConverter]::ToDateTime($wmiobj.LastBootUpTime);

                $nowstamp = Get-Date;

                $uptime = $nowstamp - $boxtime;

                $outobj = New-Object System.Object

                Add-Member -InputObject $outobj -MemberType noteproperty -Name 'Name' -Value $servername
                Add-Member -InputObject $outobj -MemberType noteproperty -Name 'Days' -Value $uptime.Days
                Add-Member -InputObject $outobj -MemberType noteproperty -Name 'Hours' -Value $uptime.Hours
                Add-Member -InputObject $outobj -MemberType noteproperty -Name 'Minutes' -Value $uptime.Minutes
                Add-Member -InputObject $outobj -MemberType noteproperty -Name 'Seconds' -Value $uptime.Seconds

                $outobj                
}


#---hits a given URL via HTTP Get
function smoke
{
                param([String]$url = '', [String]$hostname = '', [String]$uri = '/mscomtest/test.htm'  )

                if( $url -eq '' -and $hostname -eq '')
                {
                                ""
                                "usage: smoke [-url] <string> | [-hostname] <string> [-uri [string]]"
                                ""
                
                                return 
                }

                $ErrorActionPreference = 'SilentlyContinue'

                if( $url -eq '' )     
                {
                                $port = 'http://'
                                $url = $port + $hostname + $uri
                }

                $webclient = new-object system.net.webclient

                $suc = $true
                $er = $false         

                $result = $webclient.DownloadString($url)

                if( -not $? )
                {
                                $result = ''
                                $suc = $false
                                $er = $error[0]
                }

                $outobj = New-Object System.Object

                Add-Member -InputObject $outobj -MemberType noteproperty -Name 'Url' -Value $url
                Add-Member -InputObject $outobj -MemberType noteproperty -Name 'Success' -Value $suc
                Add-Member -InputObject $outobj -MemberType noteproperty -Name 'Error' -Value $er
                Add-Member -InputObject $outobj -MemberType noteproperty -Name 'Result' -Value $result

                $outobj                

}


#---sends an SMTP message
#
function sendamail
{
        param( $smtpserver, $from, $to, $subject = '', $body = '' )

                $usage = 'sendamail <smtp server> <from> <to> [subject] [body]'

        $rt = 0

        if( $smtpserver -notmatch "." )
        {
               $usage
                       return $null
        }

        if( $from -notmatch "." )
        {
               $usage
                       return $null
        }

        if( $to -notmatch "." )
        {
               $usage
                       return $null
        }

        $mailmessage = New-Object system.net.mail.mailmessage($from, $to, $subject, $body)
        $mailclient = New-Object system.net.mail.smtpclient($smtpserver)

        $mailclient.send($mailmessage)
}

function Get-ProfileFunctions
{
	return( Get-Content -Path $PROFILE | ?{ $_ -match '^function' } | %{ $n = $_ -replace '\s*function\s+', ''; $p = 'function:\' + $n; Get-Item -Path $p } | Select-Object -Property Name, ParameterSets )
}

function Get-DecryptedRemoteAccessCredentials
{
    param(
            [parameter(mandatory=$true, ValueFromPipeline=$true)][System.Object[]]$CscfgRemoteAccessDataObj = $null
         )

    begin
    {
        $cert = $null
        $cse = $null
    }

    process
    {
        foreach($obj in $CscfgRemoteAccessDataObj)
        {
            try
            {
                $cert = Get-DevOpsLmmCert -Thumbprint $obj.thumbprint
            }
            catch
            {
                Write-Error -ErrorRecord $Error[0]
                continue
            }

            try
            {
                $cse = Invoke-CmsStringEncryption -InString $obj.EncryptedPassword -Certificate $cert -Decrypt
            }
            catch
            {
                Write-Error -ErrorRecord $Error[0]
                continue
            }

            $obj | Select-Object -Property ServiceName, RoleName, AccountUsername, @{Name = 'DecryptPassword'; Expression = {$cse.DecryptedString}}
        }
    }

}

#  Encrypts/decrypts a passed in string based on the algorithm used 
#  by most Azure CSCFG implementations (PKCS/CMS).
#
function Invoke-CmsStringEncryption
{
    param(
            [parameter(mandatory=$true)][String]$InString = '',
            [parameter(mandatory=$true)][Security.Cryptography.X509Certificates.X509Certificate2]$Certificate = $null,
            [switch]$Encrypt = $false,
            [switch]$Decrypt = $false 
         )

    Add-Type -AssemblyName System.Security

    function EncryptString
    {
        param([String]$inputString = '', [Security.Cryptography.X509Certificates.X509Certificate2]$cert = $null)

        $stringBytes = [System.Text.Encoding]::UTF8.GetBytes($inputString)
        $contentInfo = New-Object -TypeName System.Security.Cryptography.Pkcs.ContentInfo -ArgumentList (,$stringBytes)
        $envelopedCms = New-Object -TypeName System.Security.Cryptography.Pkcs.EnvelopedCms $contentInfo
        $cmsRecepient = New-Object -TypeName System.Security.Cryptography.Pkcs.CmsRecipient($cert)
        $envelopedCms.Encrypt( $cmsRecepient )
        $encodedString = $envelopedCms.Encode();

        $vvv = [Convert]::ToBase64String($encodedString)

        return $vvv
    }

    function DecryptString
    {
        param([String]$s = '', [Security.Cryptography.X509Certificates.X509Certificate2]$c = $null)

        $sb = [convert]::FromBase64String($s)
        $ec = New-Object -TypeName System.Security.Cryptography.Pkcs.EnvelopedCms
    
        $ec.Decode($sb)

        $x509collection = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2Collection $c
        $ec.Decrypt($x509collection)

        $ae = New-Object -TypeName System.Text.ASCIIEncoding
    
        $vvv = $ae.GetString(($ec.ContentInfo.Content))

        return $vvv
    }

    $h = @{'InString' = $null; 'EncryptedString' = $null; 'DecryptedString' = $null}
    $o = New-Object -TypeName psobject -Property $h

    if($Encrypt)
{
        $o.InString = $InString
        $o.EncryptedString = EncryptString $InString $Certificate
    }
    elseif($Decrypt)
    {
        $o.InString = $InString
        $o.DecryptedString = DecryptString $InString $Certificate
    }
    else
    {
        Write-Error -Message $usage
        exit
    }

    return ($o | Select-Object -Property InString, EncryptedString, DecryptedString)
}

#
# Get-FileHash fuction definition.
# Source from: Module              : Microsoft.PowerShell.Utility
#

function Get-FileHash
{
    [CmdletBinding(DefaultParameterSetName = "Path")]
    param(
        [Parameter(Mandatory, ParameterSetName="Path", Position = 0)]
        [System.String[]]
        $Path,

        [Parameter(Mandatory, ParameterSetName="LiteralPath", ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath")]
        [System.String[]]
        $LiteralPath,
        
        [ValidateSet("SHA1", "SHA256", "SHA384", "SHA512", "MACTripleDES", "MD5", "RIPEMD160")]
        [System.String]
        $Algorithm="SHA256"
    )
    
    begin
    {
        # Construct the strongly-typed crypto object
        $hasher = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
    }
    
    process
    {
        $pathsToProcess = @()
        
        if($PSCmdlet.ParameterSetName  -eq "LiteralPath")
        {
            $pathsToProcess += Resolve-Path -LiteralPath $LiteralPath | Foreach-Object ProviderPath
        }
        else
        {
            $pathsToProcess += Resolve-Path $Path | Foreach-Object ProviderPath
        }
        
        foreach($filePath in $pathsToProcess)
        {
            if(Test-Path -LiteralPath $filePath -PathType Container)
            {
                continue
            }
            
            try
            {
                # Read the file specified in $FilePath as a Byte array
                [system.io.stream]$stream = [system.io.file]::OpenRead($FilePath)
                
                # Compute file-hash using the crypto object
                [Byte[]] $computedHash = $hasher.ComputeHash($stream)
            }
            catch [Exception]
            {
                $errorMessage = [Microsoft.PowerShell.Commands.UtilityResources]::FileReadError -f $FilePath, $_
                Write-Error -Message $errorMessage -Category ReadError -ErrorId "FileReadError" -TargetObject $FilePath
                return
            }
            finally
            {
                if($stream)
                {
                    $stream.Close()
                }
            }
                        
            # Convert to hex-encoded string
            [string] $hash = [BitConverter]::ToString($computedHash) -replace '-',''
                
            $retVal = [PSCustomObject] @{
                Algorithm = $Algorithm.ToUpperInvariant()
                Hash = $hash
                Path = $filePath
            }
            $retVal.psobject.TypeNames.Insert(0, "Microsoft.Powershell.Utility.FileHash")
            
            $retVal
        }
    }

}

#---add the ltm snapin
#Add-PSSnapin LtmCmdLetsSnapInR2


#---Ask for window title
#$Host.UI.RawUI.WindowTitle = Read-Host -Prompt "Enter Window Title"

#----set-location to home -- this is to avoid landing at C:\windows\system32 if the shell was launched as Admin
Set-Location ~

#---regular expression for mathing the OBS prod subs
$ObsProdPat = '^[w][eu].*obs|^ea'

#---path updates
$env:path += ';E:\devops\tools\MdsEncryption\tools;E:\devops\tools\dbscripts;C:\Program Files (x86)\Windows Kits\8.1\bin\x64;C:\Program Files (x86)\Log Parser 2.2;C:\Program Files\IIS\Microsoft Web Deploy V3;C:\Program Files\7-Zip'

#---Add Secret Store Module
#Import-Module -Name E:\devops\tools\rdtools\rd_cmt_stable.130227-2059\SecretStore\SecretStoreSnapin.dll

#---load SS functions
#. E:\devops\tools\dbscripts\DevOpsSsFunctions.ps1

#---MDS environments
$MdsTest = 'https://test1.diagnostics.monitoring.core.windows.net'
$MdsStage = 'https://stage.diagnostics.monitoring.core.windows.net'
$MdsProd = 'https://production.diagnostics.monitoring.core.windows.net'

#---SS environments
#$SsTofino = 'https://baymsftvcdmadi2/certsvc.svc'

#---load latest JhcAz functions
#. E:\GitRepository\PsProfile\JhcAz.ps1

#---

function Set-LocationCurrentWorkRoom
{
    $d = (Get-Date).ToString('yyy-MM-dd')
    $r = 'D:\john\work\'
    
    $p = $r +'\' + $d

    if(-not( Test-Path -Path $p -PathType Container))
    {
        New-Item -Path $p -ItemType dir -Verbose
    }

    Set-Location -Path $p -Verbose
}
