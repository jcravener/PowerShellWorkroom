#Requires -Version 3
#
# Collection a variety of useful tools.
# Date: April 24, 2018
# Version: v 0.1
#

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
