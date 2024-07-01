function Disable-CcmexecService {
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
	$params.StartMode = "Disabled"
	
	Set-CcmexecService @params
}