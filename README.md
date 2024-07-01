# Summary
Some functions to quickly stop and disable the CcmExec service on remote computers, or re-enable it. Sometimes this is desireable for the purposes of re-importing computer information to MECM.  

# Context
The CcmExec (a.k.a SMS Agent Host) service is a component (arguably the primary component) of the MECM client. Normally, if you delete a computer's MECM object in the MECM console, the client on the associated computer will re-create its object, and this is handled by the CcmExec service.

If you don't want that re-creation to happen you can temporarily shut the computer off or kill its networking (not ideal for remote access purposes), or you can uninstall the MECM client (not the most time-efficient), or you can otherwise hose the computer by reimaging it, wiping its hard drive, etc. (not reversible).

Alternatively, you can just stop (and disable) the CcmExec service, which is fast, keeps the endpoint online, and is fully reversible. However this is not as easy as it seems:

Another component of the MECM client is "CcmEval", an executable occasionally run by the client which checks the health of the client and can perform certain remediations. Some of those remediations include re-starting the CcmExec service if it's stopped, and re-enabling it if it's disabled. However CcmEval is (thankfully) apparently only ever run by the client as the "Action" component of a "manually"-triggered scheduled task. So we can prevent CcmEval from interfering by disabling this scheduled task.

# Usage
1. Download all files to a `Set-CcmexecService` subdirectory of your PowerShell [modules directory](https://github.com/engrit-illinois/how-to-install-a-custom-powershell-module).
2. Run one of the cmdlets using the documentation provided below

# Examples

### Disable the CcmExec service on a client
The following disables the CcmEval scheduled task, sets the StartMode of the CcmExec service to `Disabled`, and then stops the CcmExec service.  
```powershell
Disable-CcmexecService -Queries "COMP-101-01"
```

### Enable the CcmExec service on a client
The following enables the CcmEval scheduled task, sets the StartMode of the CcmExec service to `Automatic`, and then starts the CcmExec service.  
```powershell
Enable-CcmexecService -Queries "COMP-101-01"
```

### Acting on multiple computers
```powershell
Disable-CcmexecService -Queries "COMP-101-*","COMP-201-05"
```

### More customized parameters
`Disable-CcmexecService` and `Enable-CcmexecService` are just shortcuts for `Set-CcmexecService` with some parameters filled in by default.  

For example,
```powershell
Disable-CcmexecService -Queries "COMP-101-01"
```
is equivalent to:
```powershell
Set-CcmexecService -Queries "COMP-101-01" -StatusAction "Stop" -StartMode "Disabled"
```

# Parameters

### Queries \<string[]\>
Mandatory string array.  
WIP  

### StatusAction \<string\>
Mandatory string.  
WIP  
Must be either `Start`, or `Stop`.  

### StartMode \<string\>
Mandatory string.  
WIP  
Supported values are:  
WIP  

### SearchBase \<string\>
Optional string.  
WIP  

### ThrottleLimit \<int\>
Optional integer.  
WIP  

### ReportOnly
Optional switch.  
WIP  

### PassThru
Optional switch.  
WIP  

# Notes
- By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.