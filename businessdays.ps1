

function get-Businessdays {
    param (
        [int]$days = 0
    )
    
    $cur_date = Get-Date

    $i = 0
    $totaldays = 0
    $pat = 'Sat|Sun'
    

    while ($totaldays -lt $days) {

        $nextdate = $cur_date.AddDays($i)
        $i++
        
        if($nextdate.DayOfWeek -match $pat){
            Continue
        }

        New-Object -TypeName psobject -Property @{'Day' = ($totaldays + 1); 'Date' = $nextdate }
        $totaldays++
    }
}

get-Businessdays -days 11