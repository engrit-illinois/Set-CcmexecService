function Set-CcmexecService {
	param(
		[Parameter(Mandatory=$true)]
		[string[]]$Queries,
		
		[Parameter(Mandatory=$true)]
		[string]$StatusAction, # Supports "Start" or "Stop"
		
		[Parameter(Mandatory=$true)]
		[string]$StartMode,
		
		[string]$SearchBase,
		[int]$ThrottleLimit = 50,
		[switch]$ReportOnly, # specify to skip changes and only report the current state of the service
		[switch]$PassThru
	)
	
	function log {
		param(
			[string]$Msg,
			[string]$Color,
			[switch]$NoNewline
		)
		$ts = Get-Date -Format "HH:mm:ss"
		$Msg = "[$ts] $msg"
		$params = @{ Object = $Msg }
		if($color) { $params.ForegroundColor = $Color }
		if($NoNewline) { $params.NoNewline = $true }
		Write-Host @params
	}
	$logFunction = ${function:log}.ToString()
	
	# https://learn.microsoft.com/en-us/windows/win32/taskschd/runningtask-state
	# https://stackoverflow.com/questions/43545645/powershell-scheduled-task-reporting-change-status-from-number-to-word
	function Translate-TaskState($state) {
		switch ($state) {
			0 { 'Unknown' }
			1 { 'Disabled' }
			2 { 'Queued' }
			3 { 'Ready' }
			4 { 'Running' }
			Default { $state }
		}
	}
	# https://learn.microsoft.com/en-us/dotnet/api/system.serviceprocess.servicecontrollerstatus?view=net-8.0
	function Translate-ServiceStatus($status) {
		switch ($status) {
			1 { 'Stopped' }
			2 { 'StartPending' }
			3 { 'StopPending' }
			4 { 'Running' }
			5 { 'ContinuePending' }
			6 { 'PausePending' }
			7 { 'Paused' }
			Default { $status }
		}
	}
	# https://learn.microsoft.com/en-us/dotnet/api/system.serviceprocess.servicestartmode?view=net-8.0
	function Translate-ServiceStartMode($startMode) {
		switch ($startMode) {
			0 { 'Boot' }
			1 { 'System' }
			2 { 'Automatic' }
			3 { 'Manual' }
			4 { 'Disabled' }
			Default { $startMode }
		}
	}
	
	function Translate-Results($results) {
		# The values we're interested in are technically stored as integers.
		# Normally we could just call the ".ToString()" method on these to get their English equivalents (if they didn't natively translate themselves), however, we had to convert these to and from Json earlier, in order to keep static copies of the data, so all we have now is the integers, and we'll have to translate them manually. It's always flippin' _something_ isn't it...
		
		$results | ForEach-Object {
			$result = $_
		
			$result | Add-Member -NotePropertyName "TaskStatus1" -NotePropertyValue (Translate-TaskState $result.TaskState1.State)
			$result | Add-Member -NotePropertyName "ServiceStatus1" -NotePropertyValue (Translate-ServiceStatus $result.ServiceState1.Status)
			# The start mode of the service is called by several different names. Get-Service returns it as "StartType". Set-Service calls it "StartupType" with an alias of "StartType", but the alias doesn't seem to be recognized, on our endpoints at least. The underlying return type class definition calles it "StartMode" and that's what I'll use, mostly because it's easier to type and is the most distinct.
			$result | Add-Member -NotePropertyName "ServiceStartMode1" -NotePropertyValue (Translate-ServiceStartMode $result.ServiceState1.StartType)
			
			$result | Add-Member -NotePropertyName "TaskStatus2" -NotePropertyValue (Translate-TaskState $result.TaskState2.State)
			$result | Add-Member -NotePropertyName "ServiceStatus2" -NotePropertyValue (Translate-ServiceStatus $result.ServiceState2.Status)
			$result | Add-Member -NotePropertyName "ServiceStartMode2" -NotePropertyValue (Translate-ServiceStartMode $result.ServiceState2.StartType)
			
			$result
		}
	}
	
	function Do-Stuff {
		$params = @{
			Queries = $Queries
		}
		if($SearchBase) { $params.SearchBase = $SearchBase }
		$comps = Get-AdComputerName @params | Sort
		
		if(-not $comps) { Throw "No matching computers found in AD!" }
		
		$compsString = $comps -join ", "
		log "Computers: $compsString"
		
		if($ReportOnly) { $answer = "n" }
		else {
			log "Are you sure you want to `"$StatusAction`" the Ccmexec (a.k.a. SMS Agent Host) service and set its StartType to `"$StartType`" on all of the computers listed above? [y/n]: " -Color "yellow" -NoNewline
			$answer = Read-Host
			$answer = $answer.ToLower()
			if($answer -eq "y") { log "Answered YES. Continuing..." }
			else { log "Did not answer YES. No changes will be made. Continuing in ReportOnly mode..." }
		}
		
		$results = $comps | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
			${function:log} = $using:logFunction
			$name = $_
			log "Processing `"$name`"..."
			$answer = $using:answer
			$statusAction = $using:StatusAction
			$startMode = $using:StartMode
			
			$scriptBlock = {
				param($answer,$statusAction,$startMode)
				$serviceName = "Ccmexec"
				
				$task = Get-ScheduledTask -TaskName "Configuration Manager Health Evaluation"
				# Powershell doesn't make it easy to get a static copy of the data in a variable -_-
				# https://stackoverflow.com/questions/9581568/how-to-create-new-clone-instance-of-psobject-object
				$taskState1 = $task | ConvertTo-Json | ConvertFrom-Json
				
				$service = Get-Service -Name $serviceName
				$serviceState1 = $service | ConvertTo-Json | ConvertFrom-Json
				
				if($answer -eq "y") {
					# The client automatically re-enables and restarts the Ccmexec service as part of its health checks, so disable the scheduled task for this first
					# https://canadianitguy.wordpress.com/2014/05/04/ccmeval-a-client-health-admins-best-friend/
					# If this isn't reliable, may need to also stop the Ccmeval process, in case it's already running or something.				
					if($statusAction -eq "Start") {	$task | Enable-ScheduledTask -ErrorAction "Stop" | Out-Null }
					if($statusAction -eq "Stop") { $task | Disable-ScheduledTask -ErrorAction "Stop" | Out-Null }
					# This is probably not necessary because of the way PowerShell automatically updates variable properties, but just in case
					$task = Get-ScheduledTask -TaskName "Configuration Manager Health Evaluation"
					$taskState2 = $task | ConvertTo-Json | ConvertFrom-Json
					
					# Now that we've dealth with CcmEval, disable and stop the Ccmexec service
					Set-Service -Name $serviceName -StartupType $startMode
					# This is probably not necessary because of the way PowerShell automatically updates variable properties, but just in case
					$service = Get-Service -Name $serviceName
					if($statusAction -eq "Start") {	$service | Start-Service -ErrorAction "Stop" }
					if($statusAction -eq "Stop") { $service | Stop-Service -ErrorAction "Stop" }
					# This is probably not necessary because of the way PowerShell automatically updates variable properties, but just in case
					$service = Get-Service -Name $serviceName
					$serviceState2 = $service | ConvertTo-Json | ConvertFrom-Json
				}
				else {
					$taskState2 = [PSCustomObject]@{
						State = "No change attempted"
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
					Error = $false
					ErrorRecord = $null
					ErrorMsg = "None"
				}
			}
			
			try {
				Invoke-Command -ComputerName $name -Argumentlist $answer,$statusAction,$startMode -ScriptBlock $scriptBlock -ErrorAction "Stop"
			}
			catch {
				[PSCustomObject]@{
					Computer = $name
					TaskState1 = $null
					TaskState2 = $null
					ServiceState1 = $null
					ServiceState2 = $null
					Error = $true
					ErrorRecord = $_
					ErrorMsg = $_.Exception.Message
				}
			}
			log "Done processing `"$name`"..."
		}
		
		$results = Translate-Results $results
		
		$results = $results | Sort Computer
		$results | Select Computer,Error,TaskStatus1,ServiceStatus1,ServiceStartMode1,TaskStatus2,ServiceStatus2,ServiceStartMode2,ErrorMsg | Format-Table
		
		if($PassThru) { $results }
	}
	
	Do-Stuff
	
	log "EOF"
}