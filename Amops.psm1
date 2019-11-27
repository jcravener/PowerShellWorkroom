#Requires -Modules Azure
#  Tools for use by AmOps engineers.
#
#  John Cravener
#  johcrav@microsoft.com
# 
#  September 23, 2015
#  Version: 1.0
#
#  September 23, 2015
#  Version: 1.1
#
#  September 25, 2015
#  Version: 1.2
#
#  October 19, 2015
#  Version: 1.3
#
#  October 30, 2015
#  Version: 1.4
#
#  November 3, 2015
#  Version: 1.4
#
#  November 9, 2015
#  Version: 1.4
#
#  November 12, 2015
#  Version: 1.5
#
#  November 12, 2015
#  Version: 1.5.1
#
#  November 12, 2015
#  Version: 1.6
#
#  November 13, 2015
#  Version: 1.6.1
#
#  November 16, 2015
#  Version: 1.6.2
#
#  November 18, 2015
#  Version: 1.7
#
#  March 7, 2016
#  Version: 1.8
#
#  March 7, 2016
#  Version: 1.9
#
#  March 7, 2016
#  Version: 1.10
#
#  April 27, 2016
#  Version: 1.11
#
#  May 06. 2016
#  Version: 1.13
#
#  May 06. 2016
#  Version: 1.13.1
#
#  May 08, 2016
#  Version: 1.14
#
#  May 18, 2016
#  Version: 1.15
#
#  May 25, 2016
#  Version: 1.16
#
#  June 1, 2016
#  Version: 1.17
#

function Get-AmopsProtectedAzStorageContext
{
    param
    (
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [System.String]
        $StorageAccountName,

        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=1)]
        [System.String]
        $Content,

        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=2)]
        [System.String]
        $To
    )

    begin{}

    process
    {
        foreach($o in $PSBoundParameters)
        {
            $k = $null
            
            try
            {
                $k = Get-CmsMessage -Content $o['Content'] | Unprotect-CmsMessage
            }
            catch
            {
                Write-Error -Message "Had problems unprotecting Content: $($o['Content']) for storage account name: $($O['StorageAccountName'])."
                Write-Error $Error[1]
                
                continue
            }

            try
            {
                New-AzureStorageContext -StorageAccountName $o['StorageAccountName'] -StorageAccountKey $k
            }
            catch
            {
                Write-Error -Message "Had problems getting context for $($O['StorageAccountName'])."
            }
        }
    }

    end{}
}

function New-AmopsAzKeyVaultCertSecureString
{
    param
    (
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [alias('Fullname')]
        [System.String]
        $Path,

        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=1)]
        [System.Security.SecureString]
        $Password
    )

    begin{}

    process
    {
        foreach($psbp in $PSBoundParameters)
        {
            $cert = $null

            $c = $null
            $ec = $null
            $pw = $null

            $s = $null
            $sb = $null
            $es = $null
            $ss = $null
            
            #--Check that the path is valid
            #
            if(-not (Test-Path -Path $psbp['Path'] -PathType Leaf))
            {
                Write-Error -Message "Incorrect Path. `"$($psbp['Path'])`" is not found or is not a file."

                continue
            }

            #---Check that the password is valid
            #
            try
            {
                $cert = Get-PfxData -FilePath $psbp['Path'] -Password $psbp['Password']
            }
            catch
            {
               Write-Error -Message "Could not validate cert file: $($psbp['Path']) with passed-in password."

               continue
            }
            
            try
            {
                $c = Get-Content -Encoding Byte -Path $psbp['Path']

                $ec = [System.Convert]::ToBase64String($c)
            }
            catch
            {
                Write-Error -Message "Had problems reading and encoding cert file: $($psbp['Path'])"

                continue
            }

            $pw = ConvertFrom-JhcPdsSecureString -SecureString $psbp['Password']

            $s =  New-Object -TypeName psobject -Property @{'Data' = $ec; 'Password' = $pw } |
                
                Select-Object -Property Data, Password |
                
                    ConvertTo-Json |

                        ForEach-Object{ $_ -replace '\s+', '' }
            
            $sb = [System.Text.Encoding]::UTF8.GetBytes($s)
                        
            $es = [System.Convert]::ToBase64String($sb)
                        
            $ss = ConvertTo-SecureString -String $es -AsPlainText -Force

            $tags = @{
            
                        'Thumbprint' = $cert.EndEntityCertificates.Thumbprint; 
                        'Subject' = $cert.EndEntityCertificates.Subject
                    }
            
            New-Object -TypeName psobject -Property @{'Thumbprint' = $cert.EndEntityCertificates.Thumbprint; 'Subject' = $cert.EndEntityCertificates.Subject; 'SecureString' = $ss; 'Expires' = $cert.EndEntityCertificates.NotAfter; 'Tags' = $tags } |

                Select-Object -Property Thumbprint, Subject, SecureString, Expires, Tags
        }
    
    }

    end{}
}

function Import-AmopsAzEmailBill
{
    param
    (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $false, Position = 0)]
        [String]
        $Path
    )

    begin
    {
        $File = Get-Content -Path $Path

        if(-not $?)
        {
            throw "Had problems reading in $Path."
        }
    
        $SubPat = 'Subscription Name:\s+(.+)\s\(.+$'

        $TotalPat = 'Total for Subscription\s+\$'

        $HeaderPat = 'Service\s+Service Type\s+Region\s+Resource'

        $Header = 'Subscription Name', 'Service', 'Service Type', 'Region', 'Resource', 'Quantity', 'Effective Rate', 'Extended Price'

        $del = "`t"
    }

    process{}

    end
    {
        $o = $null
        $SubName = $null
        
        foreach($l in $File)
        {            
            if($l -match $SubPat)
            {
                $SubName = $Matches[1]
                continue
            }

            if($l -match $TotalPat)
            {
                $SubName = $null
            }
        
            if($SubName -eq $null)
            {
                continue
            }

            if($l -match $HeaderPat)
            {
                continue
            }
            
            ($SubName, $l) -join $del |
            
                ConvertFrom-Csv -Delimiter $del -Header $Header |

                    Select-Object -Property 'Subscription Name', 'Service', 'Service Type', 'Region', 'Resource', @{ name = 'Quantity'; expression = {[decimal]($_.'Quantity' -replace ',', '')}}, @{ name = 'Effective Rate'; expression = {[decimal]($_.'Effective Rate' -replace ',', '')}}, @{ name = 'Extended Price'; expression = {[decimal]($_.'Extended Price' -replace ',', '')}}
        }
    }
    
}

function Get-AmopsAzManagementCert
{
    param
    (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [String]
        $SubscriptionId,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [String]
        $SubscriptionName,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $false, Position = 2)]
        [System.Security.Cryptography.X509Certificates.X509Certificate]
        $Cert = $null,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, Position = 3)]
        [String]
        $ApiVersion = '2012-03-01'
    )

    begin
    {
        $pat = '<SubscriptionId>'

        $Uri = 'https://management.core.windows.net/<SubscriptionId>/certificates'

        $v = @{'x-ms-version' = $ApiVersion}

        $u = $null           
    }

    process
    {
        foreach($p in $PSBoundParameters)
        {
            $u = $null
            $r = $null
            $o = $null

            $sid = $null
            $sn = $null
            
            $sid = $p['SubscriptionId']

            if($p['SubscriptionName'])
            {
                $sn = $p['SubscriptionName']
            }
                
            $u = $Uri -replace $pat, $sid

            try
            {
                $r = Invoke-RestMethod -Uri $u -Headers $v -Certificate $Cert
            }
            catch
            {
                $Error[0]
                continue
            }

            $o = $r.SubscriptionCertificates.SubscriptionCertificate |

                ForEach-Object{ ConvertFrom-AmOpsCertString -Data $_.SubscriptionCertificateData } |

                    Add-Member -PassThru -MemberType NoteProperty -Name SubscriptionId -Value $sid

            if($sn)
            {
                $o | Add-Member -PassThru -MemberType NoteProperty -Name SubscriptionName -Value $sn
            }
            else
            {
                $o
            }            
        }
    }

    end{}
}

function Write-AmopsAzKeyVaultCertData
{
    param
    (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [String]
        $FilePath,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [String]
        $Data
    )

    begin{}

    process
    {
        foreach($p in $PSBoundParameters)
        {
            if( ( $FilePath -match '\.\\' ) -or ( $FilePath -notmatch '\\') )
            {
                $FilePath = "$($PWD.Path)\$FilePath"
            }            
            
            Write-Verbose -Message "Writing $FilePath"
            
            [System.IO.File]::WriteAllBytes($FilePath,[System.Convert]::FromBase64String($Data))
        }
    }

    end{}
    
}

function Expand-AmopsAzKeyVaultCertData
{
    param
    (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [String]
        $Name,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [String]
        $SecretValueText
    )

    begin{}

    process
    {
        foreach($p in $PSBoundParameters)
        {
            $o = $null
            $pw = $null
            
            $o = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($p['SecretValueText'])) |

                ConvertFrom-Json |
                    
                    Select-Object -Property @{Name = 'Name'; expression = {$p['Name']}}, *
            
            try
            {
                $pw = ConvertTo-SecureString -String $o.password -AsPlainText -Force
            }
            catch
            {
                $Error[0]
                continue
            }
            
            $o | Select-Object -Property Name, Data, @{Name = 'Format'; expression = {$_.dataType}}, @{name = 'Password'; expression = {$pw}}
        }
    }

    end{}
}

function ConvertFrom-AmOpsCertString
{
    param(
            [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 0)]
            [System.String]
            $Data
    )

    begin{}

    process
    {
        foreach($p in $PSBoundParameters)
        {
            try
            {
                $d = [System.Convert]::FromBase64String($p['Data'])
            }
            catch
            {
                Write-Error -Message "Had problems converting from Base 64 String."

                continue
            }

            try
            {
              [System.Security.Cryptography.X509Certificates.X509Certificate2]$d   
            }
            catch
            {
                Write-Error -Message "Had problems casting data to X509 certificate."
            }
        }
    }

    end{}
}

function Get-AmOpsCosmosIisLogName
{
    param(
            [Parameter(Mandatory=$true, ValueFromPipeline=$false, Position = 0)]
            [System.String]
            $SerialNumMapPath = $null,

            [Parameter(Mandatory, ParameterSetName="Path", Position = 0)]
            [System.String[]]
            $Path,

            [Parameter(Mandatory, ParameterSetName="LiteralPath", ValueFromPipelineByPropertyName = $true)]
            [Alias("PSPath")]
            [System.String[]]
            $LiteralPath
         )
    
    begin
    {
        try
        {
            $map = Import-Clixml -Path $SerialNumMapPath
        }
        catch
        {
            Write-Error -Message "Had problems reading in SerialNumMapPath file: $SerialNumMapPath"

            throw
        }

        $SnmProperties = 'ServiceName', 'DeploymentId', 'Role', '__serialnum'
        $MemberType = ''

        #---check whether the map object has all the expected properties
        #

        $a = ($map | Get-Member -MemberType 'NoteProperty').name + $SnmProperties 
        
        if( $a | Group-Object | Where-Object{$_.count -ne 2} )
        {
            Write-Error -Message "SerialNumMapPath file: $SerialNumMapPath does not contain all the right properties: $SnmProperties."

            throw
        }

        $npat = '^u_ex\d{8}\.log$'

        $n = $null

        [String]$cent = [int]((Get-Date).Year/100)

        $ypat   = '^u_ex(\d{2})'
        $ypat0  = '^u_ex\d{2}'
        $yreppre = 'u_ex'

        $instpat = '_IN_(\d+)\\'
        $instnumb = $null

        $mapo = $null

        $snumb = $null

        $OutputHeader = 'Path', 'ServiceName', 'DeploymentId', '__serialnum', 'Instance', 'Name', 'NewName'
    }

    process
    {
        $pathsToProcess = @()
        
        if($PSCmdlet.ParameterSetName  -eq "LiteralPath")
        {
            $pathsToProcess += Resolve-Path -LiteralPath $LiteralPath | Foreach-Object ProviderPath
        }
        
        if($PSCmdlet.ParameterSetName -eq "Path")
        {
            $pathsToProcess += Resolve-Path $Path | Foreach-Object ProviderPath
        }

        foreach($filePath in $pathsToProcess)
        {
            if(Test-Path -LiteralPath $filePath -PathType Container)
            {
                continue
            }

            $n = Split-Path -Path $filePath -Leaf

            if( $n -notmatch $pat )
            {
                Write-Warning -Message "Skipping $filePath because it does not match the IIS log file name pattern: $npat"

                continue
            }

            $n -match $ypat | Out-Null

            $nn = $n -replace $ypat0, "$($yreppre)$($cent)$($Matches[1])"

            
            #--now go after the instance number
            #
            
            if($filePath -match $instpat)
            {
                [int]$instnumb = $Matches[1]
            }
            else
            {
                Write-Warning -Message "Skipping $filepath does not match instance number patteren: $instpat"

                continue
            }

            $mapo = $null
            $mapo = $map | Where-Object{ $filePath -match $_.DeploymentId }

            if(-not $mapo)
            {
                Write-Warning -Message "Skipping $filepath None of the DeploymentIds in SerialNumMapPath were found in file path."

                continue
            }

            $snumb = $instnumb + [int]($mapo.__serialnum)

            if(-not $?)
            {
                Write-Error -Message "Skipping $filepath"
                
                continue
            }
            
            $nn = "$($snumb)_$($nn)"
            
            "$filePath,$($mapo.ServiceName),$($mapo.DeploymentId),$($mapo.__serialnum),$($instnumb),$($n),$($nn)" |

                ConvertFrom-Csv -Header $OutputHeader |

                    Select-Object -Property 'Path','ServiceName','DeploymentId', @{ name = '__serialnum'; expression = {[int]($_.__serialnum)}}, @{name = 'Instance'; expression = {[int]($_.Instance)}}, 'Name', 'NewName'
        }
    }

    end{}
}

function Expand-AmOpsWadIisLogBlobPrefixSet
{
    param(
            [Parameter(Mandatory=$true, ParameterSetName="Object", ValueFromPipeline=$true, Position = 0)]
            [System.Object[]]
            $AmOpsAzWadInfoObj,

            [Parameter(Mandatory=$true, ParameterSetName="Scalar", Position = 1)]
            [System.String]
            $ServiceName,

            [Parameter(Mandatory=$true, ParameterSetName="Scalar", Position = 2)]
            [System.String]
            $Role,

            [Parameter(Mandatory=$true, ParameterSetName="Scalar", Position = 3)]
            [System.String]
            $DeploymentId,

            [Parameter(Mandatory=$true, Position = 4)]
            [System.Int32[]]
            $InstanceSet,

            [Parameter(Mandatory=$true, Position = 5)]
            [System.DateTime]
            $LogStartDate,

            [Parameter(Mandatory=$false, Position = 6)]
            [switch]
            $IncludeStorageContext = $false
        )

    begin
    {
        $iheader = 'ServiceName','Role','DeploymentId'
        $DateFormat = 'yyMMdd'
        $del = ','

        $logpre = 'u_ex' + $LogStartDate.ToString($DateFormat)

        $oheader = 'ServiceName','Role','DeploymentId','Inst','Prefix'

        if($IncludeStorageContext -and ($PSCmdlet.ParameterSetName -eq 'Scalar'))
        {
            Write-Error -Message "The -IncludeStorageContext switch can only be used with -AmOpsAzWadInfoObj paramater and not with -ServiceNamem, -Role, -DeploymentId paramaters."

            throw
        }

        $oo = $null
        $c = $null
    }

    process
    {
        if($PSCmdlet.ParameterSetName -eq 'Scalar')
        {
            $AmOpsAzWadInfoObj = "$ServiceName,$Role,$DeploymentId" | ConvertFrom-Csv -Header $iheader
        }

        foreach($o in $AmOpsAzWadInfoObj)
        {
            if($IncludeStorageContext)
            {
                $c = New-AzureStorageContext -StorageAccountName $o.AccountName -StorageAccountKey $o.AccountKey
            }
            
            foreach( $i in $InstanceSet )
            {
                $oo = "$($o.ServiceName)$del$($o.Role)$del$($o.DeploymentId)$del$($i)$del$($o.DeploymentId)/$($o.Role)/$($o.Role)_IN_$($i)/Web/W3SVC1273337584/$($logpre)" |

                    ConvertFrom-Csv -Header $oheader |

                        Select-Object -Property 'ServiceName','Role', 'DeploymentId', @{name = 'Instance'; expression = {[System.Int32]($_.Inst)}},'Prefix'
                
                if($IncludeStorageContext)
                {
                    $oo | Select-Object -Property *, @{name = 'BlobEndPoint'; expression = {$c.BlobEndPoint}}, @{name = 'TableEndPoint'; expression = {$c.TableEndPoint}}, @{name = 'QueueEndPoint'; expression = {$c.QueueEndPoint}}, @{name = 'Context'; expression = {$c.Context}}, @{name = 'Name'; expression = {$c.Name}}, @{name = 'StorageAccount'; expression = {$c.StorageAccount}}
                }
                else
                {
                    $oo
                }
            }
        }
    }

    end{}
}

function Get-AmOpsAzWadInfo
{
    param(
            [Parameter(Mandatory, ValueFromPipeline=$true, Position = 0)]
            [System.Object[]]
            $DeploymentInfoContextObj
        )
    
    begin
    {
        $x = $null

        $wadpat = 'Diagnostics.*ConnectionString'
        $del = ';'
        $inerdel = '='
        $objdel = ','

        $sn = $null
        $rn = $null
        $did = $null
        
        $a = $null
        $ak = $null
        $akpat = '^AccountKey=(.+$)'
        
        $line = $null
        $header = $null
    }

    process
    {
        foreach($o in $DeploymentInfoContextObj)
        {
            $did = $o.DeploymentId
            $sn = $o.ServiceName
            
            [xml]$x = $o.Configuration

            $x.ServiceConfiguration.Role |

                ForEach-Object{ $line = $null; $rn = $_.name; $_.ConfigurationSettings.Setting |

                    Where-Object{ $_.name -match $wadpat } |

                        ForEach-Object{
                        
                            $a = "ServiceName=$($sn)$($del)Role=$($rn)$($del)DeploymentId=$($did)$($del)$($_.value)" -split $del
                            
                             ( $a | Select-Object -Last 1 ) -match $akpat | Out-Null

                            $ak = $Matches[1]

                            $a = $a[0..($a.Length-2)]
                            
                            $header = $a | ForEach-Object{ $_ -split $inerdel | Select-Object -First 1 }
                            $header += 'AccountKey'
                            
                            $line = ( $a | ForEach-Object{ $_ -split $inerdel | Select-Object -Last 1 } ) -join $objdel
                            $line += ",$($ak)"

                            $line | ConvertFrom-Csv -Header $header
                        }
                }
        }
    }

    end{}
}

function Show-AmOpsFileEncoding
{
    param(
            [Parameter(Mandatory, ParameterSetName="Path", Position = 0)]
            [System.String[]]
            $Path,

            [Parameter(Mandatory, ParameterSetName="LiteralPath", ValueFromPipelineByPropertyName = $true)]
            [Alias("PSPath")]
            [System.String[]]
            $LiteralPath,

            [Parameter(Mandatory=$false)]
            [switch]
            $ExtendedOutput = $false
        )

    begin
    {
        $rc = 4
        $tc = 4
        $enc = 'Byte'

        $header = 'Encoding', 'Path'
        $Extheader = 'Encoding', 'Path', 'Byte0', 'Byte1', 'Byte2', 'Byte3'

        $l = $null
    }

    process
    {
        $pathsToProcess = @()
        
        if($PSCmdlet.ParameterSetName  -eq "LiteralPath")
        {
            $pathsToProcess += Resolve-Path -LiteralPath $LiteralPath | Foreach-Object ProviderPath
        }
        
        if($PSCmdlet.ParameterSetName -eq "Path")
        {
            $pathsToProcess += Resolve-Path $Path | Foreach-Object ProviderPath
        }

        foreach($filePath in $pathsToProcess)
        {
            if(Test-Path -LiteralPath $filePath -PathType Container)
            {
                continue
            }
        
            [byte[]]$byte = get-content -Encoding $enc -ReadCount $rc -TotalCount $tc -Path $filePath
            
            $l = $null

            if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf )
            {
                $l = "UTF8"
            }
            elseif( $byte[0] -eq 0xff -and $byte[1] -eq 0xfe -and $byte[2] -eq 0 -and $byte[3] -eq 0 )
            {
                $l = "UTF32"
            }
            elseif( $byte[0] -eq 0xff -and $byte[1] -eq 0xfe )
            {
                $l = "Unicode"
            }
            elseif( $byte[0] -eq 0xfe -and $byte[1] -eq 0xff )
            {
                $l = "BigEndianUnicode"
            }
            else 
            {
                $l = "ASCII"
            }
            
            $l += ",$($filePath)"

            if($ExtendedOutput)
            {
                $l += ",$($byte[0]),$($byte[1]),$($byte[2]),$($byte[3])"
                
                $l | ConvertFrom-Csv -Header $Extheader
            }
            else
            {
                $l | ConvertFrom-Csv -Header $header
            }
        }
    }

    end{}
}

function Convertfrom-AmOpsBase64String
{
    param(
            [Parameter(Mandatory, ValueFromPipeline=$true, Position = 0)]
            [System.String]
            $String = $null,

            [Parameter(Position = 1)]
            [ValidateSet("ASCII", "Unicode", "UTF32", "UTF7", "UTF8", "BigEndianUnicode")]
            [System.String]
            $Encoding = 'ASCII'
    )

    begin{}

    process
    {
        foreach($psb in $PSBoundParameters)
        {
            [System.Text.Encoding]::$Encoding.GetString([System.Convert]::FromBase64String($psb['String']))
        }
    }

    end{}
}

function ConvertTo-AmOpsBase64String
{
    param(
            [Parameter(Mandatory, ValueFromPipeline=$true, Position = 0)]
            [System.String]
            $String = $null,

            [Parameter(Position = 1)]
            [ValidateSet("ASCII", "Unicode", "UTF32", "UTF7", "UTF8", "BigEndianUnicode")]
            [System.String]
            $Encoding = 'ASCII'
    )

    begin{}

    process
    {
        foreach($psb in $PSBoundParameters)
        {
            $b = [System.Text.Encoding]::$Encoding.GetBytes($psb['String'])
            
            [System.Convert]::ToBase64String($b)
        }
    }

    end{}
}

function Get-AmOpsFirstIisLogRecord
{
    param(
            [Parameter(Mandatory, ParameterSetName="Path", Position = 0)]
            [System.String[]]
            $Path,

            [Parameter(Mandatory, ParameterSetName="LiteralPath", ValueFromPipelineByPropertyName = $true)]
            [Alias("PSPath")]
            [System.String[]]
            $LiteralPath
        )

    begin
    {
        $pat = '^#Fields:\s+(.+)$'
        $N = 10  #--assume we have the header field and a good record within the first 10 lines

        $Header = $null
    }

    process
    {
        $pathsToProcess = @()
        
        if($PSCmdlet.ParameterSetName  -eq "LiteralPath")
        {
            $pathsToProcess += Resolve-Path -LiteralPath $LiteralPath | Foreach-Object ProviderPath
        }
        
        if($PSCmdlet.ParameterSetName -eq "Path")
        {
            $pathsToProcess += Resolve-Path $Path | Foreach-Object ProviderPath
        }

        foreach($filePath in $pathsToProcess)
        {
            if(Test-Path -LiteralPath $filePath -PathType Container)
            {
                continue
            }
        
            $o = Get-Content -Path $filePath -First $N

            if(-not $o)
            {
                continue
            }

            $o | Where-Object{ $_ -match '^#Fields:\s+(.+)$' } | Out-Null
            
            $Header = $Matches[1] -split '\s+'

            $o | Select-Object -Last 1 | ConvertFrom-Csv -Delimiter ' ' -Header $Header | Select-Object -Property @{Name = 'Path'; expression = {$filePath}}, *
        }
    }

    end{}
}

function Get-AmOpsTimeFromIisLogName
{
    [CmdletBinding(DefaultParameterSetName = "Path", HelpURI = "http://go.microsoft.com/fwlink/?LinkId=517145")]
    param(
            [Parameter(Mandatory, ParameterSetName="Path", Position = 0)]
            [System.String[]]
            $Path,

            [Parameter(Mandatory, ParameterSetName="LiteralPath", ValueFromPipelineByPropertyName = $true)]
            [Alias("PSPath")]
            [System.String[]]
            $LiteralPath
        )

    begin
    {
        #$pat = '.*ex(\d{8})\.log'
        $pat = '.*(\d{8})\.log$'
        
        $ts = $null

        $dpat = '^(\d{2})(\d{2})(\d{2})(\d{2})$'

        $Cent = 2000

        $h = @{'Year' = 1; 'Month' = 2; 'Day' = 3; 'Hour' = 4}

        $it = $null
    }

    process
    {
        $pathsToProcess = @()
        
        if($PSCmdlet.ParameterSetName  -eq "LiteralPath")
        {
            $pathsToProcess += Resolve-Path -LiteralPath $LiteralPath | Foreach-Object ProviderPath
        }
        
        if($PSCmdlet.ParameterSetName -eq "Path")
        {
            $pathsToProcess += Resolve-Path $Path | Foreach-Object ProviderPath
        }

        foreach($filePath in $pathsToProcess)
        {
            if(Test-Path -LiteralPath $filePath -PathType Container)
            {
                continue
            }
        
            $o = Get-Item -Path $filePath

            if($o.name -match $pat)
            {
                $ts = $Matches[1]

                $ts -match $dpat | Out-Null

                $it =  Get-Date -Date "$($Matches[$h['Month']])/$($Matches[$h['Day']])/$($Matches[$h['Year']]) $($Matches[$h['Hour']]):00:00"

                $o | Select-Object -Property LastWriteTime, @{Name = 'IisTime'; expression = { Get-Date -Date "$($Matches[$h['Month']])/$($Matches[$h['Day']])/$($Matches[$h['Year']]) $($Matches[$h['Hour']]):00:00" }}, Name, @{Name = 'Path'; expression = {$_.fullname}}
            }
            else
            {
                Write-Error -Message "File name from $filePath does not match the IIS log-name pattern."
            }
        }
     }

    end{}
}

function New-AmOpsAzSaContext
{
    param(
            [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position = 0)]
            [Alias("AccountName")]
            [System.String]
            $StorageAccountName,

            [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position = 1)]
            [Alias("Primary","AccountKey")]
            [System.String]
            $StorageAccountKey

            )

    begin{}
    
    process
    {
        New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
    }
    
    end{}
}

function ConvertTo-AmOpsSplunk
{
    param(
    
            [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
            [System.Object[]]
            $Obj = $null,

            [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
            [switch]
            $ScrubTimeStamp = $false
         )
    
    begin
    {
        $del = ' '
        $pat = 'Time'
        $reppat = '\+.+$'
        $reppat0 = 'T'
    }
    
    process
    {
        foreach($o in $Obj)
        {
            $l = $null
            
            $o |
            
                Get-Member -MemberType Properties |
                
                    ForEach-Object{ $_.name } |

                        ForEach-Object{ $n = $_; $v = $o.$n; if(($ScrubTimeStamp) -and $n -match $pat){$v = $v -replace $reppat, ''; $v = $v -replace $reppat0, ' '; }; $l += "$($n)=`"$($v)`"$($del)" }
            
            $l = $l -replace '\s+$', ''
            
            $l
        }
    }
    
    end{}
}

function ConvertFrom-AmOpsSplunk
{
    param(
    
            [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
            [System.Object[]]
            $Obj = $null
         )
    
    begin
    {
        $del = '\s'
        $pat = '=.*"$'
        $del0 = '="'       
    }
    
    process
    {
        foreach($l in $Obj)
        {
            $o = New-Object -TypeName psobject
            
            $a = $null
            
            $a = $l -split $del

            foreach( $aa in $a )
            {
                if($aa -match $pat)
                {
                    $aaa = $aa
                    
                    $m = ($aaa -replace '"$', '') -split $del0
                    
                    $o = $o | Add-Member -PassThru -MemberType NoteProperty -Name $m[0] -Value $m[1]
                    
                    $aaa = $null
                    $m = $null
                }
                else
                {
                    $aaa += " $aa"
                }

                if($aaa -match $pat)
                {
                    $aaa = $aaa -replace "^\s+", ''

                    $m = ($aaa -replace '"$', '') -split $del0
                    
                    $o = $o | Add-Member -PassThru -MemberType NoteProperty -Name $m[0] -Value $m[1]

                    $aaa = $null
                    $m = $null
                }
            }
            
            $o
        }
    }
    
    end{}
}

function ConvertFrom-JhcPdsSecureString
{
    param
    (
        [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [System.Security.SecureString]
        $SecureString
    )

    begin{}

    process
    {
        foreach($ss in $SecureString)
        {
            if($ss -eq $null)
            {
                throw "Passed-in secure string was null."
            }

            try
            {
                $us = [runtime.interopservices.Marshal]::SecureStringToGlobalAllocUnicode($ss)

                return [runtime.interopservices.Marshal]::PtrToStringAuto($us)
            }
            finally
            {
                [runtime.interopservices.Marshal]::ZeroFreeGlobalAllocUnicode($us)
            }
        }
    }

    end{}
}

Export-ModuleMember -Function  Convertfrom-AmOpsBase64String
Export-ModuleMember -Function  ConvertFrom-AmOpsCertString
Export-ModuleMember -Function  ConvertFrom-AmOpsSplunk
Export-ModuleMember -Function  ConvertTo-AmOpsBase64String
Export-ModuleMember -Function  ConvertTo-AmOpsSplunk
Export-ModuleMember -Function  Expand-AmopsAzKeyVaultCertData
Export-ModuleMember -Function  Expand-AmOpsWadIisLogBlobPrefixSet
Export-ModuleMember -Function  Get-AmopsAzManagementCert
Export-ModuleMember -Function  Get-AmOpsAzWadInfo
Export-ModuleMember -Function  Get-AmOpsCosmosIisLogName
Export-ModuleMember -Function  Get-AmOpsFirstIisLogRecord
Export-ModuleMember -Function  Get-AmOpsTimeFromIisLogName
Export-ModuleMember -Function  Import-AmopsAzEmailBill
Export-ModuleMember -Function  New-AmopsAzKeyVaultCertSecureString
Export-ModuleMember -Function  New-AmOpsAzSaContext
Export-ModuleMember -Function  Show-AmOpsFileEncoding
Export-ModuleMember -Function  Write-AmopsAzKeyVaultCertData
Export-ModuleMember -Function  New-AmopsAzKeyVaultCertSecureString
Export-ModuleMember -Function  Get-AmopsProtectedAzStorageContext