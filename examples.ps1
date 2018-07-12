Function clr {
    [void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    [System.Windows.Forms.SendKeys]::SendWait("^{k}") 
    Clear-host
}
clr

#region BasicExample1
<#
    With BeginInvoke() the task is run within the runspace in the background and it gives you back control of your current runspace, being the console.
    The sleep of 10 seconds happens in the background.
 #>
$Runspace = [runspacefactory]::CreateRunspace() # Spin up a Thread\Runspace to run in the background
$PowerShell = [powershell]::Create() # Create a powershell-instance, some refer to it as "Create a pipeline"
$PowerShell.runspace = $Runspace # Tell the Powershell-instance in which Thread\Runspace it needs to run at.
$Runspace.Open() # Before we can do work, we need to open the Thread\Runspace

$PowerShell.AddScript( { # Do work
        sleep 10
        "test" | out-file c:\temp\s\ls.txt -Force
    })

$asyncObject = $PowerShell.BeginInvoke() # Runs the script in the background-runspace and release the consoel
$asyncObject # This object can be used to monitor the background process.
While ($asyncObject.IsCompleted -contains $false) {} # Doing the monitoring, checking if it's completed or not.
$PowerShell.Streams  # Access the different output streams (Verbose,Debug,Host,...)
$PowerShell.Dispose() # Clean up after yourself.
#endregion

#region BasicExample2
<#
    The Difference is with .Invoke() it will keep the console 'reserved or active'.
    This way you can't use if for anything else while the runspace is active. In this example
    you'll be waiting 10 seconds on the sleep.
 #>
$Runspace = [runspacefactory]::CreateRunspace()
$PowerShell = [powershell]::Create()
$PowerShell.runspace = $Runspace
$Runspace.Open()

$PowerShell.AddScript( {
        Start-Sleep 10
        "test" | out-file c:\temp\s\ls.txt -Force
    })

$PowerShell.Invoke() # 'Hijacks' the console, so you can't use it for anything else during its work.
$PowerShell.Streams

$PowerShell.Dispose()
<#
    Say you would run this code 15 times by pressing F5 in the ISE.
    If you would then run get-runspace, you would see that you'd have 15 threads running.
    This can cause problems with e.g. CPU throttling. To prevent that, we'll have to use a runspacepool\threadpool, as shown in the next example.
 #>
#endregion

#region EndInvoke() example
$runspace = [runspacefactory]::CreateRunspace()
$runspace.ApartmentState = "STA"
$runspace.ThreadOptions = "ReuseThread"
$runspace.Open()
$PowerShell = [PowerShell]::Create().AddScript( {
        Get-WmiObject -Class win32_process
    })
$PowerShell.Runspace = $runspace
$AsyncHandle = $PowerShell.BeginInvoke()
do {
    Start-sleep -m 100 
} 
while (!$AsyncHandle.IsCompleted)
$PowerShell.EndInvoke($AsyncHandle) | select Name, Path # This forces the output to the console, the disatvange is that this hijacks the console.
#endregion

#region Synchroniozed Hashtable example
$sharedData = [HashTable]::Synchronized(@{}) #Create new sync hashtable
$sharedData.Foo = "starting value" #Create keys and values
$sharedData.test = "test value 2"

$newRunspace = [RunSpaceFactory]::CreateRunspace()
$newRunspace.Open()
$newRunspace.SessionStateProxy.setVariable("sharedData", $sharedData) # Make variable accessible in other runspace

$global:newPowerShell = [PowerShell]::Create() # Create powershell instance
$newPowerShell.Runspace = $newRunspace # Assign a runspace to the new instance
$handle = $newPowerShell.AddScript( {
        $sharedData.Foo = Get-Random ('tiger', 'dophin', 'trigger', 'finger')
        $sharedData.test = Get-Random ('cat', 'dog', 'fish', 'bow')
        sleep 2
    }).BeginInvoke() #Change the value in the new runspace

while ($handle.IsCompleted -ne $true) {
    write-host "." -NoNewline
    sleep -Milliseconds 100
} # Wait until new runspace is finished.


$newRunspace.Close()
$newPowerShell.Dispose()

$sharedData
# You can access a particular value : $sharedData.test
Get-Runspace
#endregion

#region PoolExample
(Get-Runspace -Name * | where {$_.RunspaceAvailability -like "*Available*"}).Dispose() # clean up old threads
$runspacepool = [runspacefactory]::CreateRunspacePool(1, 3) # Create a Tread|runspace-pool with minimum 1 thread\runspace and max 3
$runspacepool.Open() # Open the pool before doing anything else
$arr = @()

$scriptblock = {
    start-sleep -Seconds 10
    $D = gci C:\Temp\Windows10_Design_WPF-master
    $t = gci C:\Temp\s

    $arr = [pscustomobject]@{
        T = $t
        D = $D
    }
    $arr.T| Out-File C:\temp\s\gci.txt -Force
    $arr.D | Out-File C:\temp\s\gci.txt -append
    "testtexttofile" | Out-File C:\temp\s\testtexttofile.txt -Force
}
# Execute the $scriptblock 50 times spread over 3 threads.
1..10 | % {
    $ps = [powershell]::create()   # create a new Powershell Instance to do the work
    $ps.Runspacepool = $runspacepool # Assign it to the pool
    [void]$ps.AddScript($scriptblock)  # give it some work to do
    $ps.BeginInvoke()  # Invoke returns results automatically.
}
<# If we run get-runspace, we'll see that it has spinned up 3 threads\runspaces. #>
Get-Runspace  | ft
#endregion

#region TrickToPrintOutputToConsoleFromRunspace
    (Get-Runspace -Name * | where {$_.RunspaceAvailability -like "*Available*"}).Dispose() # clean up old threads
    $runspacepool = [runspacefactory]::CreateRunspacePool(1, 3) # Create a Tread|runspace-pool with minimum 1 thread\runspace and max 3
    $runspacepool.Open() # Open the pool before doing anything else
    $arr = @()

    $scriptblock = {
        start-sleep -Seconds 10 
        $D = gci C:\Temp\Windows10_Design_WPF-master
        $t = gci C:\Temp\s

        $arr = @($t, $D)
        $arr
    }
    #Execute the $scriptblock 50 times spread over 3 threads.
    1..50 | % {
        $ps = [powershell]::create()   # create a new Powershell Instance to do the work
        $ps.Runspacepool = $runspacepool # Assign it to the pool
        [void]$ps.AddScript($scriptblock)  # give it some work to do
        # https://learn-powershell.net/2016/02/14/another-way-to-get-output-from-a-powershell-runspace/
        $output = New-Object 'System.Management.Automation.PSDataCollection[psobject]' # Trick to retrieve output for $arr
        $Handle = $ps.BeginInvoke($output, $output)
    }
    ''
    $output
    ''
    <# If we run get-runspace, we'll see that it has spinned up 3 threads\runspaces. #>
    Get-Runspace | ft
#endregion
