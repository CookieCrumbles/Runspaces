cleaner

#Trigger multiple functions at the same time via a runspacepool.

$runspacepool = [runspacefactory]::CreateRunspacePool(1, 2) 
$runspacepool.Open() 

$myfunction1 = { 
    Function myfunction1 ()
    {
        "$(get-date) write to file from myfunction1" | Out-File C:\temp\myfunction.txt -append
    }
    myfunction1
}

$myfunction2 = { 
    Function myfunction2 ()
    {
        "$(get-date) write to file from myfunction2" | Out-File C:\temp\myfunction.txt -append
    }
    myfunction2
}
 
$myfunction3 = { 
    Function myfunction3 ()
    {
        "$(get-date) write to file from myfunction3" | Out-File C:\temp\myfunction.txt -append
    }
    myfunction3
}

$myFunctionsArray = @($myfunction1, $myfunction2, $myfunction3)

foreach ($function in $myFunctionsArray)
{
    $instance = [PowerShell]::Create().AddScript($function)
    $instance.RunspacePool = $runspacePool
    $instance.BeginInvoke()    
}

(Get-Runspace -Name * | Where-Object { $_.RunspaceAvailability -like "*Available*" }).Dispose()