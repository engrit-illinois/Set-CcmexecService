function global:Disable-CcmexecService {
	param(
		[Parameter(Mandatory=$true)]
		[string[]]$Queries,
		
		[string]$SearchBase,
		[int]$ThrottleLimit,
		[switch]$ReportOnly, # specify to skip changes and only report the current state of the service
		[switch]$PassThru
	)
	
	$params = @{ Queries = $Queries }
	if($SearchBase) { $params.SearchBase = $SearchBase }
	if($ThrottleLimit) { $params.ThrottleLimit = $ThrottleLimit }
	$params.ReportOnly = $false
	if($ReportOnly) { $params.ReportOnly = $true }
	$params.PassThru = $false
	if($PassThru) { $params.PassThru = $true }
	
	$params.StatusAction = "Stop"
	$params.StartType = "Disabled"
	
	Set-CcmexecService @params
}

function global:Enable-CcmexecService {
	param(
		[Parameter(Mandatory=$true)]
		[string[]]$Queries,
		
		[string]$SearchBase,
		[int]$ThrottleLimit,
		[switch]$ReportOnly, # specify to skip changes and only report the current state of the service
		[switch]$PassThru
	)
	
	$params = @{ Queries = $Queries }
	if($SearchBase) { $params.SearchBase = $SearchBase }
	if($ThrottleLimit) { $params.ThrottleLimit = $ThrottleLimit }
	$params.ReportOnly = $false
	if($ReportOnly) { $params.ReportOnly = $true }
	$params.PassThru = $false
	if($PassThru) { $params.PassThru = $true }
	
	$params.StatusAction = "Start"
	$params.StartType = "Automatic"
	
	Set-CcmexecService @params
}

function global:Set-CcmexecService {
	param(
		[Parameter(Mandatory=$true)]
		[string[]]$Queries,
		
		[Parameter(Mandatory=$true)]
		[string]$StatusAction, # Supports "Start" or "Stop"
		
		[Parameter(Mandatory=$true)]
		[string]$StartType,
		
		[string]$SearchBase,
		[int]$ThrottleLimit = 50,
		[switch]$ReportOnly, # specify to skip changes and only report the current state of the service
		[switch]$PassThru
	)
	
	function log($msg) {
		$ts = Get-Date -Format "HH:mm:ss"
		Write-Host "[$ts] $msg"
	}
	$logFunction = ${function:log}.ToString()
	
	$params = @{
		Queries = $Queries
	}
	if($SearchBase) { $params.SearchBase = $SearchBase }
	$comps = Get-AdComputerName @params | Sort
	
	$compsString = $comps -join ", "
	log "Computers: $compsString"
	
	if($ReportOnly) { $answer = "n" }
	else {
		$answer = Read-Host -Prompt "Are you sure you want to `"$StatusAction`" the Ccmexec (a.k.a. SMS Agent Host) service and set its StartType to `"$StartType`" on all of the above computers? [y/n]"
	}
	
	$results = $comps | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
		${function:log} = $using:logFunction
		$name = $_
		log "Processing `"$name`"..."
		$answer = $using:answer
		$statusAction = $using:StatusAction
		$startType = $using:StartType
		
		$scriptBlock = {
			param($answer,$statusAction,$startType)
			$serviceName = "Ccmexec"
			
			$taskState1 = Get-ScheduledTask -TaskName "Configuration Manager Health Evaluation"
			# https://learn.microsoft.com/en-us/windows/win32/taskschd/runningtask-state
			# https://stackoverflow.com/questions/43545645/powershell-scheduled-task-reporting-change-status-from-number-to-word
			$taskState1 | Add-Member -NotePropertyName "Status" -NotePropertyValue $taskState1.State.ToString()
			
			$serviceState1 = Get-Service -Name $serviceName
			if($answer -eq "y") {
				# The client automatically re-enables and restarts the Ccmexec service as part of its health checks, so disable the scheduled task for this first
				# https://canadianitguy.wordpress.com/2014/05/04/ccmeval-a-client-health-admins-best-friend/
				# If this isn't reliable, may need to also stop the Ccmeval process, in case it's already running or something.				
				if($statusAction -eq "Start") {	$taskState1 | Enable-ScheduledTask | Out-Null }
				if($statusAction -eq "Stop") { $taskState1 | Disable-ScheduledTask | Out-Null }
				$taskState2 = Get-ScheduledTask -TaskName "Configuration Manager Health Evaluation"
				$taskState2 | Add-Member -NotePropertyName "Status" -NotePropertyValue $taskState2.State.ToString()
				
				Set-Service -Name $serviceName -StartupType $startType | Out-Null
				if($statusAction -eq "Start") {	$serviceState1 | Start-Service | Out-Null }
				if($statusAction -eq "Stop") { $serviceState1 | Stop-Service | Out-Null }
				$serviceState2 = Get-Service -Name $serviceName
			}
			else {
				$taskState2 = [PSCustomObject]@{
					Status = "No change attempted"
				}
				$serviceState2 = [PSCustomObject]@{
					Status = "No change attempted"
					StartType = "No change attempted"
				}
			}
			
			[PSCustomObject]@{
				Computer = $env:ComputerName
				TaskState1 = $taskState1
				TaskState2 = $taskState2
				ServiceState1 = $serviceState1
				ServiceState2 = $serviceState2
			}
		}
		
		Invoke-Command -ComputerName $name -Argumentlist $answer,$statusAction,$startType -ScriptBlock $scriptBlock
		log "Done processing `"$name`"..."
	}

	$results = $results | Sort Computer
	$results | Select Computer,{$_.TaskState1.Status},{$_.ServiceState1.Status},{$_.ServiceState1.StartType},{$_.TaskState2.Status},{$_.ServiceState2.Status},{$_.ServiceState2.StartType} | Format-Table
	if($PassThru) { $results }
}