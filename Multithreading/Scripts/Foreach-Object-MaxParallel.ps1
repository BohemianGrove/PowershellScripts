<#
    .SYNOPSIS
    Uses all available cores to parrallize a scriptblock passed in (Something in between {})

    .PARAMETER Script
    The codeblock that will run

    .PARAMETER Objects
    The objects to iterate over

    .PARAMETER ProgressBar
    Whether to show the progress bar or not. You can turn this off if you want the return value to pipe into something, 
    as we do append a $null at the end of each script to get the progress bar to show. On by default

    .EXAMPLE
    Foreach-Object-MaxParallel -Objects (Get-ChildItem .) -Script {echo $_.Name}

    .EXAMPLE
    #We do processing on this so it still runs in parallel
    gci c:/ | Foreach-Object-MaxParallel {echo $_.name}

    .EXAMPLE
    #This is for when you need the return value to be valid or don't want the progress bar.
    gci c:/ | Foreach-Object-MaxParallel {echo $_.name} -ProgressBar $True

#>

function Foreach-Object-MaxParallel {
    [CmdletBinding()]
    Param(
    
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [System.Object[]]
        $PipelineObjects,
        # Objects to iterate over
        [Parameter(Mandatory = $false)]
        [System.Object[]]
        $Objects,

        # Scriptblock to execute
        [Parameter(Mandatory = $true, position = 0)]
        [scriptblock]
        $Script,

        # Scriptblock to execute
        [Parameter(Mandatory = $false)]
        [bool]
        $ProgressBar = $true
    )

    begin {
        if ($PSVersionTable.PSVersion.Major -lt 7 -eq $True) {
            throw "Please use PS version 7 or above to access parallel features... Exiting"
        }
        $CPUCount = ((Get-WmiObject -Class Win32_processor).NumberOfLogicalProcessors) 
        [Collections.ArrayList]$inputObjects = @()
        [Collections.ArrayList]$CurCount = @()
        $fileLock = [System.Threading.ReaderWriterLockSlim]::new()
    
        if ($ProgressBar -eq $true) {
            #Returning null to the end of the string just incase it doesn't return a module. We have to use pipe for the progress bar.
            #Also done just incase an array is returned and it fucks up our count.
            $sbNull = {
                return $null 
            }
            $Script = [scriptblock]::create($Script.ToString() + $sbNull.ToString())
        }
    }

    process {
        [void]$inputObjects.Add($_)
    }
    end {
        if ($ProgressBar -eq $false) {
            if ($Objects -eq $null) { #If passed in pipeline
                $maxCount = $InputObjects.Count
                $inputObjects | ForEach-Object -Parallel $Script -ThrottleLimit $CPUCount
            }
            else { #If passed in as argument
                $maxCount = $Objects.Count
                $Objects | ForEach-Object -Parallel $Script -ThrottleLimit $CPUCount
            }
        }
        else {            
            #Determines if objects passed in via pipe or not
            if ($Objects -eq $null) { #If passed in pipeline
                $maxCount = $InputObjects.Count
                Write-Progress -Activity "Activity" -PercentComplete 0 -Status "(Working - 0% (0 / $maxCount Left)"
                $inputObjects | ForEach-Object -Parallel $Script -ThrottleLimit $CPUCount | ForEach-Object {
                    $fileLock.EnterWriteLock()
                    $CurCount += 1 #This is really hacky, but we do this because incrementing doesn't work even with our locks. For some reason adding to a list does.
                    $fileLock.ExitWriteLock()
                    $iPercentComplete = (($CurCount.Count / ($maxCount)) * 100)
                    $count = $CurCount.Count
                    Write-Progress -Activity "Activity" -PercentComplete $iPercentComplete -Status ("Working - " + $iPercentComplete + "% ($count / $maxCount Left)")
                }
            }
            else { #If passed in as argument
                $maxCount = $Objects.Count
                Write-Progress -Activity "Activity" -PercentComplete 0 -Status "(Working - 0% (0 / $maxCount Left)"
                $Objects | ForEach-Object -Parallel $Script -ThrottleLimit $CPUCount | ForEach-Object {
                    $fileLock.EnterWriteLock()
                    $CurCount += 1 #This is really hacky, but we do this because incrementing doesn't work even with our locks. For some reason adding to a list does.
                    $fileLock.ExitWriteLock()
                    $iPercentComplete = ($CurCount.Count / $maxCount) * 100
                    $count = $CurCount.Count
                    Write-Progress -Activity "Activity" -PercentComplete $iPercentComplete -Status ("Working - " + $iPercentComplete + "% ($count / $maxCount Left)")
                }
            }
        }
    }
}

#Export-ModuleMember -Function Foreach-Object-MaxParallel