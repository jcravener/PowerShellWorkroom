#Requires -Version 3
#
# Collection a variety of useful tools.
# Date: April 24, 2018
# Version: v 0.1
# Date: March 10, 2020
# Version: v 0.2
# Date: March 18, 2020
# Version: v 0.3
#

#---searches down through a users org given a passed in AAD user serach string
#
function Search-JhcUtilAadUserOrg
{
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName,Position = 0)]
        [System.String]
        $MailNickName
    )
    
    begin{
        $mn = 'AzureAD'
        $m = Get-Module -Name $mn -ListAvailable
        $ext = $false
        $l = @()
        $mnn = ''

        # Check for AAD module. If not there, report and exit.
        #
        if($null -ne $m){
            Write-Information -MessageData "Found $($m.Name) module.  Version: $($m.Version)"
        }
        else{
            Write-Error -Message "Cmdlet requires $mn module.  Exiting..."
            $ext = $true
        }

        # Check whether you need to auth to AAD. If so, report adn exit
        #
        if(-not $ext)
        {
            try {
                Get-AzureADUser -Top 1 -ErrorAction SilentlyContinue | Out-Null 
            }
            catch {
                Write-Error -Message 'You must call the Connect-AzureAD cmdlet before running this cmdlet.'
                $ext = $true
            }
        }

        #  Grab mail nickname to test whether it is unique
        #
        if(-not $ext)
        {
            $mnn =  Get-AzureADUser -SearchString $MailNickName
        }

        #  Report if it was not uniqe and exit 
        #
        if($mnn.Length -gt 1)
        {
            Write-Error -Message "MailNickName: `"$MailNickName`" produced more than one result ($($mnn.Length)). It must be a unique user. Exiting..."
            $ext = $true
        }
    }

    process{
        #  Traverse though AAD
        #
        if(-not $ext)
        {
            $l = orgtrav($MailNickName)
        }
    }
    
    end
    {
        $mgr = ''

        if($ext)
        {
            return $null
        }
        
        if($l.Count -gt 0)
        {
            ($l.Count-1)..0 |
                ForEach-Object{ $i = $_; $l[$i] }
        }
        else
        {
            $mgr = Get-AzureADUserManager -ObjectId $mnn.ObjectId
            $mnn | select-object -property @{name = 'Manager'; expression = {$mgr.DisplayName}}, @{name = 'ManagerMailNickName'; expression = {$mgr.MailNickName}}, Displayname, MailNickName, JobTitle, Department, PhysicalDeliveryOfficeName
        }
    }
}

#---internal function for Search-JhcUtilAadUserOrg
#
function orgtrav
{
    param (
        [String]
        $MailNickName
    )

    $a = @()

    if($MailNickName -eq $null)
    {
        return $null
    }

    foreach( $o in Get-AzureADUser -SearchString $MailNickName | Get-AzureADUserDirectReport )
    {
        $ct++

        Write-Progress -Activity "Looking up AAD user $($o.Displayname)" -Status "Searching $('.' * $a.count)"
        $m = Get-AzureADUserManager -ObjectId $o.ObjectId
        $a += $o | select-object -property @{name = 'Manager'; expression = {$m.DisplayName}}, @{name = 'ManagerMailNickName'; expression = {$m.MailNickName}}, Displayname, MailNickName, JobTitle, Department, PhysicalDeliveryOfficeName
        orgtrav($o.MailNickName)
    }

    return $a
}


#---converts base 64 bstring into a plain string
#
function Convertfrom-JhcUtilBase64String
{
    param(
            [Parameter(Mandatory, ValueFromPipeline=$true, Position = 0)]
            [System.String]
            $String,

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

#---converts string to Base64 String
#
function ConvertTo-JhcUtilBase64String
{
    param(
            [Parameter(Mandatory, ValueFromPipeline=$true, Position = 0)]
            [System.String]
            $String,

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

#---Converts Secure String into plain string
#
function Unprotect-JhcUtilSecureString
{
    param
    (
        [parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        [System.Security.SecureString]
        $SecureString
    )

    begin{}

    process
    {
        foreach($ss in $SecureString)
        {
            if($null -eq $ss)
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

#---Simple long term history retriever 
#
function Get-JhcUtilLongTermHistory
{
    begin
    {
        $histfile = $env:APPDATA + '\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt'
	}
    process
    {
        if(Test-Path -Path $histfile)
        {
            $i = 0
            Get-Content -Path $histfile |
            
                ForEach-Object { $l = $_; $i++; New-Object -TypeName pscustomobject -Property @{'Id' = $i; 'CommandLine' = $l} }
        }
        else
        {
            write-Error -Message "History file not found. $histfile"  
		}
	}
    end{}
}

#---This cmdlet requires Excel is installed
#
function Convert-JhcUtilXlsxToCsv
{
    param
    (
        [Parameter(Mandatory, ParameterSetName="Path", Position = 0)]
        [System.String[]]
        $Path,

        [Parameter(Mandatory, ParameterSetName="LiteralPath", ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath")]
        [System.String[]]
        $LiteralPath,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $false)]
        [switch]
        $Force = $false
    )

    begin
    {
        $ex = New-Object -ComObject Excel.Application

        $ex.Visible = $false

        $ex.DisplayAlerts = $false

        $wb = $null
        $i = $null
    }

    process
    {
        $PathsToProcess = @()

        if($PSCmdlet.ParameterSetName -eq 'Path')
        {
            $PathsToProcess += Resolve-Path -Path $Path |
            
                ForEach-Object ProviderPath
        }
        else
        {
            $PathsToProcess += Resolve-Path -LiteralPath $LiteralPath |

                ForEach-Object ProviderPath
        }

        foreach( $filepath in $PathsToProcess )
        {
            $fp = Get-Item -Path $filepath

            try
            {
                $wb = $ex.Workbooks.Open($fp.FullName)
            }
            catch
            {
                Write-Error $_

                continue
            }

            $i = 0
            
            try
            {
                
                foreach( $ws in $wb.Worksheets )
                {
                    $cf = "$($fp.DirectoryName)\$($fp.BaseName)_$($i).csv"                    

                    if( (-not (Test-Path -Path $cf -PathType Leaf)) -or $Force )
                    {
                        Write-Verbose -Message "Saving $cf"

                        $ws.SaveAs($cf,6)
                    }
                    else
                    {
                        Write-Error -Message "$cf file already exists."
                    }
                    
                    $i++
                }
            }
            catch
            {
                Write-Error $_
            }
        }

    }

    end
    {
        $ex.Quit()
    }
}

