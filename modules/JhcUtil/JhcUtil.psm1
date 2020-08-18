#Requires -Version 3
#
# Collection a variety of useful tools.

#---invokext a scriptblock that has been stored in a clixml file 
#
function Invoke-JhcUtilScriptBlock {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String]
        $ScriptBlockXml,
        [Parameter(Mandatory = $false)]
        [System.String[]]
        $ArgumentList
    )
    
    $sbstr = Import-Clixml -Path $ScriptBlockXml
    $sb = [scriptblock]::Create($sbstr)

    if ($ArgumentList) {
        Invoke-Command -ScriptBlock $sb -ArgumentList $ArgumentList
    }
    else {
        Invoke-Command -ScriptBlock $sb
    }

}

#---updattes the console window
#
function Update-JhcUtilWindowTitle {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.String]
        $Title
    )

    $Host.UI.RawUI.WindowTitle = $Title
}

#---searches down through a users org given a passed in AAD user serach string
#
function Search-JhcUtilAadUserOrg {
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, Position = 0)]
        [System.String]
        $MailNickName
    )
    
    begin {
        $mn = 'AzureAD'
        $m = Get-Module -Name $mn -ListAvailable
        $ext = $false
        $l = @()
        $mnn = ''

        # Check for AAD module. If not there, report and exit.
        #
        if ($null -ne $m) {
            Write-Information -MessageData "Found $($m.Name) module.  Version: $($m.Version)"
        }
        else {
            Write-Error -Message "Cmdlet requires $mn module.  Exiting..."
            $ext = $true
        }

        # Check whether you need to auth to AAD. If so, report adn exit
        #
        if (-not $ext) {
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
        if (-not $ext) {
            $mnn = Get-AzureADUser -SearchString $MailNickName
        }

        #  Report if it was not uniqe and exit 
        #
        if ($mnn.Length -gt 1) {
            Write-Error -Message "MailNickName: `"$MailNickName`" produced more than one result ($($mnn.Length)). It must be a unique user. Exiting..."
            $ext = $true
        }
    }

    process {
        #  Traverse though AAD
        #
        if (-not $ext) {
            $l = orgtrav($MailNickName)
        }
    }
    
    end {
        $mgr = ''
        $k = $null

        if ($ext) {
            return $null
        }
        
        $mgr = Get-AzureADUserManager -ObjectId $mnn.ObjectId
        $k = $mnn | select-object -property @{name = 'Manager'; expression = { $mgr.DisplayName } }, @{name = 'ManagerMailNickName'; expression = { $mgr.MailNickName } }, Displayname, MailNickName, JobTitle, Department, PhysicalDeliveryOfficeName

        if ($l.Count -gt 0) {
            $l += $k
            
            ($l.Count - 1)..0 |
            ForEach-Object { $i = $_; $l[$i] }
        }
        else {
            $k
        }
    }
}

#---internal function for Search-JhcUtilAadUserOrg
#
function orgtrav {
    param (
        [String]
        $MailNickName
    )

    $a = @()

    if ($MailNickName -eq $null) {
        return $null
    }

    foreach ( $o in Get-AzureADUser -SearchString $MailNickName | Get-AzureADUserDirectReport ) {
        $ct++

        Write-Progress -Activity "Looking up AAD user $($o.Displayname)" -Status "Searching $('.' * $a.count)"
        $m = Get-AzureADUserManager -ObjectId $o.ObjectId
        $a += $o | select-object -property @{name = 'Manager'; expression = { $m.DisplayName } }, @{name = 'ManagerMailNickName'; expression = { $m.MailNickName } }, Displayname, MailNickName, JobTitle, Department, PhysicalDeliveryOfficeName
        orgtrav($o.MailNickName)
    }

    return $a
}


#---converts base 64 bstring into a plain string
#
function Convertfrom-JhcUtilBase64String {
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true, Position = 0)]
        [System.String]
        $String,

        [Parameter(Position = 1)]
        [ValidateSet("ASCII", "Unicode", "UTF32", "UTF7", "UTF8", "BigEndianUnicode")]
        [System.String]
        $Encoding = 'ASCII'
    )

    begin { }

    process {
        foreach ($psb in $PSBoundParameters) {
            [System.Text.Encoding]::$Encoding.GetString([System.Convert]::FromBase64String($psb['String']))
        }
    }

    end { }
}

#---converts string to Base64 String
#
function ConvertTo-JhcUtilBase64String {
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true, Position = 0)]
        [System.String]
        $String,

        [Parameter(Position = 1)]
        [ValidateSet("ASCII", "Unicode", "UTF32", "UTF7", "UTF8", "BigEndianUnicode")]
        [System.String]
        $Encoding = 'ASCII'
    )

    begin { }

    process {
        foreach ($psb in $PSBoundParameters) {
            $b = [System.Text.Encoding]::$Encoding.GetBytes($psb['String'])
            
            [System.Convert]::ToBase64String($b)
        }
    }

    end { }
}

#---Converts Secure String into plain string
#
function Unprotect-JhcUtilSecureString {
    param
    (
        [parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.Security.SecureString]
        $SecureString
    )

    begin { }

    process {
        foreach ($ss in $SecureString) {
            if ($null -eq $ss) {
                throw "Passed-in secure string was null."
            }

            try {
                $us = [runtime.interopservices.Marshal]::SecureStringToGlobalAllocUnicode($ss)

                return [runtime.interopservices.Marshal]::PtrToStringAuto($us)
            }
            finally {
                [runtime.interopservices.Marshal]::ZeroFreeGlobalAllocUnicode($us)
            }
        }
    }

    end { }
}

#---Simple long term history retriever 
#
function Get-JhcUtilLongTermHistory {
    [CmdletBinding()]
    [OutputType('JhcUtil.LongTermHistory')]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [int]
        $Id,
        [Parameter(Mandatory = $false, Position = 1)]
        [int]
        $Last
    )
    
    $histfile = $env:APPDATA + '\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt'

    if (Test-Path -Path $histfile) {
        $histcontent = [System.IO.File]::ReadAllLines($histfile)
        $First = 0

        if ($Id) {
            $First = $Id - 1
            $Last = $Id
        }
        elseif ($Last) {
            $First = $histcontent.Length - $Last
            $Last = $histcontent.Length
        }
        else {
            $Last = $histcontent.Length
        }

        for ($j = $First; $j -lt $Last; $j++) {
            New-Object -TypeName pscustomobject -Property @{'Id' = $j + 1; 'CommandLine' = $histcontent[$j] }
        }
    }
    else {
        write-Error -Message "History file not found. $histfile"  
    }
}

#---converts all the tabs in an Excel file to CSVs - requires that Excel is installed
#
function Convert-JhcUtilXlsxToCsv {
    param
    (
        [Parameter(Mandatory, ParameterSetName = "Path", Position = 0)]
        [System.String[]]
        $Path,

        [Parameter(Mandatory, ParameterSetName = "LiteralPath", ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath")]
        [System.String[]]
        $LiteralPath,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $false)]
        [switch]
        $Force = $false
    )

    begin {
        $ex = New-Object -ComObject Excel.Application

        $ex.Visible = $false

        $ex.DisplayAlerts = $false

        $wb = $null
        $i = $null
    }

    process {
        $PathsToProcess = @()

        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $PathsToProcess += Resolve-Path -Path $Path |
            
            ForEach-Object ProviderPath
        }
        else {
            $PathsToProcess += Resolve-Path -LiteralPath $LiteralPath |

            ForEach-Object ProviderPath
        }

        foreach ( $filepath in $PathsToProcess ) {
            $fp = Get-Item -Path $filepath

            try {
                $wb = $ex.Workbooks.Open($fp.FullName)
            }
            catch {
                Write-Error $_

                continue
            }

            $i = 0
            
            try {
                
                foreach ( $ws in $wb.Worksheets ) {
                    $cf = "$($fp.DirectoryName)\$($fp.BaseName)_$($i).csv"                    

                    if ( (-not (Test-Path -Path $cf -PathType Leaf)) -or $Force ) {
                        Write-Verbose -Message "Saving $cf"

                        $ws.SaveAs($cf, 6)
                    }
                    else {
                        Write-Error -Message "$cf file already exists."
                    }
                    
                    $i++
                }
            }
            catch {
                Write-Error $_
            }
        }

    }

    end {
        $ex.Quit()
    }
}

#--- returns encoding of the passed in file
#
function Show-JhcUtilFileEncoding {
    param(
        [Parameter(Mandatory, ParameterSetName = "Path", Position = 0)]
        [System.String[]]
        $Path,

        [Parameter(Mandatory, ParameterSetName = "LiteralPath", ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath")]
        [System.String[]]
        $LiteralPath,

        [Parameter(Mandatory = $false)]
        [switch]
        $ExtendedOutput = $false
    )

    begin {
        $rc = 4
        $tc = 4
        $enc = 'Byte'

        $header = 'Encoding', 'Path'
        $Extheader = 'Encoding', 'Path', 'Byte0', 'Byte1', 'Byte2', 'Byte3'

        $l = $null
    }

    process {
        $pathsToProcess = @()
        
        if ($PSCmdlet.ParameterSetName -eq "LiteralPath") {
            $pathsToProcess += Resolve-Path -LiteralPath $LiteralPath | Foreach-Object ProviderPath
        }
        
        if ($PSCmdlet.ParameterSetName -eq "Path") {
            $pathsToProcess += Resolve-Path $Path | Foreach-Object ProviderPath
        }

        foreach ($filePath in $pathsToProcess) {
            if (Test-Path -LiteralPath $filePath -PathType Container) {
                continue
            }
        
            [byte[]]$byte = get-content -Encoding $enc -ReadCount $rc -TotalCount $tc -Path $filePath
            
            $l = $null

            if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf ) {
                $l = "UTF8"
            }
            elseif ( $byte[0] -eq 0xff -and $byte[1] -eq 0xfe -and $byte[2] -eq 0 -and $byte[3] -eq 0 ) {
                $l = "UTF32"
            }
            elseif ( $byte[0] -eq 0xff -and $byte[1] -eq 0xfe ) {
                $l = "Unicode"
            }
            elseif ( $byte[0] -eq 0xfe -and $byte[1] -eq 0xff ) {
                $l = "BigEndianUnicode"
            }
            else {
                $l = "ASCII"
            }
            
            $l += ",$($filePath)"

            if ($ExtendedOutput) {
                $l += ",$($byte[0]),$($byte[1]),$($byte[2]),$($byte[3])"
                
                $l | ConvertFrom-Csv -Header $Extheader
            }
            else {
                $l | ConvertFrom-Csv -Header $header
            }
        }
    }

    end { }
}

#--retrievs a stock price via alphaavantage web service
#
function Get-JhcUtilStockSp {
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [System.Security.SecureString]
        $apiKey,
        [parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [System.String]
        $symbol
    )

    begin {
        $aak = Unprotect-JhcUtilSecureString -SecureString $apiKey

        #-- Ref: https://www.alphavantage.co/documentation/
        #
        $uri = "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&datatype=csv&apikey=$($aak)&symbol"
    }

    process {
        $o = Invoke-RestMethod -Uri "$($uri)=$($symbol)" | ConvertFrom-Csv

        if ($o) {
            $o.open = [Double]$o.open
            $o.high = [Double]$o.high
            $o.low = [Double]$o.low
            $o.price = [Double]$o.price
            $o.volume = [System.Int32]$o.volume
            $o.latestDay = [datetime]$o.latestDay
            $o.previousClose = [Double]$o.previousClose
            $o.change = [Double]$o.change
            $o.changePercent = [Double]($o.changePercent -replace '\%', '')
        }

        $o

    }

    end { }
}

#---reads in text file and outputs it as object if content is valid JSON
#
function Import-JhcUtilJson {
    
    [CmdletBinding(DefaultParameterSetName = "Path")]
    param(
        [Parameter(Mandatory, ParameterSetName = "Path", Position = 0)]
        [System.String[]]
        $Path,
    
        [Parameter(Mandatory, ParameterSetName = "LiteralPath", ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath")]
        [System.String[]]
        $LiteralPath,

        [Parameter(ValueFromPipelineByPropertyName = $false)]
        [System.Int32]
        $Depth
    )

    begin { }

    process {
        $pathsToProcess = @()
        if ($PSCmdlet.ParameterSetName -eq "LiteralPath") {
            $pathsToProcess += Resolve-Path -LiteralPath $LiteralPath | Foreach-Object ProviderPath
        }
        if ($PSCmdlet.ParameterSetName -eq "Path") {
            $pathsToProcess += Resolve-Path $Path | Foreach-Object ProviderPath
        }
       
        foreach ($filePath in $pathsToProcess) {
            if (Test-Path -LiteralPath $filePath -PathType Container) {
                continue
            }
       
            try {
                # Read the file specified in $FilePath as a Byte array
                $stream = [System.IO.File]::ReadAllLines($filePath)                
                    
                if ($Depth) {
                    $stream | ConvertFrom-Json -Depth $Depth
                }
                else {
                    $stream | ConvertFrom-Json
                }
                    
            }
            catch [Exception] {
                $errorMessage = [Microsoft.PowerShell.Commands.UtilityResources]::FileReadError -f $FilePath, $_
                Write-Error -Message $errorMessage -Category ReadError -ErrorId "FileReadError" -TargetObject $FilePath
                return
            }
        }        
    }

    end { }
}

#---helper function for ConvertTo-JhcUtilJsonTable
#
function getNodes {
    param (
        [Parameter(Mandatory)]
        [System.Object]
        $job,
        [Parameter(Mandatory)]
        [System.String]
        $path
    )

    $t = $job.GetType()
    $ct = 0
    $h = @{}

    if ($t.Name -eq 'PSCustomObject') {
        foreach ($m in Get-Member -InputObject $job -MemberType NoteProperty) {
            getNodes -job $job.($m.Name) -path ($path + '.' + $m.Name)
        }
        
    }
    elseif ($t.Name -eq 'Object[]') {
        foreach ($o in $job) {
            getNodes -job $o -path ($path + "[$ct]")
            $ct++
        }
    }
    else {
        $h[$path] = $job
        $h
    }
}


#---flattens a JSON document object into a key value table where keys are proper JSON paths corresponding to their value
#
function ConvertTo-JhcUtilJsonTable {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Object[]]
        $jsonObj
    )

    begin {
        $rootNode = 'root'    
    }
    
    process {
        foreach ($o in $jsonObj) {
            $table = getNodes -job $o -path $rootNode

            $h = @{}
            $pat = '^' + $rootNode
            
            foreach ($i in $table) {
                foreach ($k in $i.keys) {
                    $h[$k -replace $pat, ''] = $i[$k]
                }
            }
            $h
        }
    }

    end{}
}

#---parses stdout strings into a list of objects
#
function Convert-JhcUtilStrToObj {
    param (
        [Parameter(ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [System.String[]]
        $StringInput,
        [Parameter(Mandatory = $false)]
        [System.String]
        $Pattern = '.',
        [Parameter(Mandatory = $false)]
        [System.String]
        $DelimitterPat = '\s+',
        [Parameter(Mandatory = $false)]
        [System.String]
        $Delimitter = ' ',
        [Parameter(Mandatory = $false)]
        [System.String[]]
        $Header
    )

    begin { 
        $m = @()
        $mxlen = 0
    }
    process {
        foreach ($l in $StringInput) {
            if ($l -match $Pattern) {
                $a = @()
                $a = ($l.Trim() -replace $DelimitterPat, $Delimitter) -split $Delimitter

                if ($a.Length -gt $mxlen) {
                    $mxlen = $a.Length
                }
                $m += $a -join $Delimitter
            }
        }
    }
    end {        
        if (-not $Header) {
            for ($i = 0; $i -lt $mxlen; $i++) {
                $Header += "f$($i)"
            }
        }
        return ($m | ConvertFrom-Csv -Delimiter $Delimitter -Header $Header)
    }
}

#--tests a passed in JSON file against a passes in json schema file
#
function Test-JhcUtilJsonFile {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $JsonFile,
        [Parameter(Mandatory = $false)]
        [String]
        $SchemaFile
    )

    $j = get-content -Path $JsonFile -Raw
    if (-not $?) {
        $errMsg = "Had problems reading $JsonFile"
        throw $errMsg
        return
    }

    $s = get-content -Path $SchemaFile -Raw
    if (-not $?) {
        $errMsg = "Had problems reading $SchemaFile"
        throw $errMsg
        return
    }

    Test-Json -Json $j -Schema $s
}

#---adding aliases
New-Alias -Name Convert-JhcStrToObj -Value Convert-JhcUtilStrToObj
New-Alias -Name Convert-JhcXlsxToCsv -Value Convert-JhcUtilXlsxToCsv
New-Alias -Name Convertfrom-JhcBase64String -Value Convertfrom-JhcUtilBase64String
New-Alias -Name ConvertTo-JhcBase64String -Value ConvertTo-JhcUtilBase64String
New-Alias -Name Get-JhcLongTermHistory -Value Get-JhcUtilLongTermHistory
New-Alias -Name Get-JhcStockSp -Value Get-JhcUtilStockSp
New-Alias -Name Import-JhcJson -Value Import-JhcUtilJson
New-Alias -Name Invoke-JhcScriptBlock -Value Invoke-JhcUtilScriptBlock
New-Alias -Name Search-JhcAadUserOrg -Value Search-JhcUtilAadUserOrg
New-Alias -Name Show-JhcFileEncoding -Value Show-JhcUtilFileEncoding
New-Alias -Name Unprotect-JhcSecureString -Value Unprotect-JhcUtilSecureString
New-Alias -Name Update-JhcWindowTitle -Value Update-JhcUtilWindowTitle
New-Alias -Name Test-JhcJsonFile -Value Test-JhcUtilJsonFile
New-Alias -Name ConvertTo-JhcUtilJsonTable -Value ConvertTo-JhcJsonTable


