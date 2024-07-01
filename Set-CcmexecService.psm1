$ErrorActionPreference = 'Stop'

$functions = Get-ChildItem $PSScriptRoot -File -Filter "*.ps1"
foreach($function in $functions) {
	# dot-source file (loads the function definitions into module scope)
	. $function.FullName
	# output the function name for export
	Export-ModuleMember -Function $function.BaseName
}