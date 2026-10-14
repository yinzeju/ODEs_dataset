param([string]$Config='configs/releases/dataset21_nlc6_v1_r2.json', [string]$Attempt='01', [string]$JuliaExecutable='')
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Set-Location -LiteralPath $projectRoot
if ($Config -notmatch '^[a-zA-Z0-9_./-]+$' -or $Attempt -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Unsafe launch argument' }
$cfg=Get-Content -LiteralPath $Config -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $cfg.execution_authorized -or -not $cfg.formal_launch_authorized -or $cfg.revision_driver_required -or $cfg.numerical_revision_driver_required) { throw 'Launch interlock' }
$state=Get-Content -LiteralPath 'runs/naca_campaign_control/state.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$active=Get-Content -LiteralPath $state.current_receipt -Raw -Encoding UTF8 | ConvertFrom-Json
$live=Get-CimInstance Win32_Process -Filter ('ProcessId='+$active.pid)
if ($live) { throw 'An active receipt PID exists; verify its identity before launching another worker' }
$runRoot=Join-Path $projectRoot ('runs/'+$cfg.release_id)
$supervisorReceipt=Join-Path $runRoot ('supervisor_'+$Attempt+'.json')
if (Test-Path -LiteralPath $supervisorReceipt) { throw 'Supervisor attempt already used' }
if (Test-Path -LiteralPath (Join-Path $runRoot 'execution.lock')) { throw 'Target execution lock exists' }
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$shellPath=(Get-Command powershell.exe -CommandType Application).Source
if ($JuliaExecutable) {
    $juliaPath=(Resolve-Path -LiteralPath $JuliaExecutable).Path
} else {
    $launcher=(Get-Command julia -CommandType Application).Source
    $juliaPath=(& $launcher --startup-file=no -e 'print(Base.julia_cmd().exec[1])').Trim()
}
$scriptPath=Join-Path $PSScriptRoot 'supervise_dataset21_nlc6.ps1'
$commandLine='"'+$shellPath+'" -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$scriptPath+'" -Config "'+$Config+'" -Attempt "'+$Attempt+'" -JuliaExecutable "'+$juliaPath+'"'
# WMI creates the supervisor outside the calling terminal's process tree.
$startup=New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ShowWindow=[uint16]0}
$created=Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
    CommandLine=$commandLine;CurrentDirectory=$projectRoot;ProcessStartupInformation=$startup
}
if ($created.ReturnValue -ne 0) { throw ('WMI process creation failed: '+$created.ReturnValue) }
$identity=Get-CimInstance Win32_Process -Filter ('ProcessId='+$created.ProcessId)
$record=[ordered]@{status='launched';pid=$created.ProcessId;created_utc=[DateTimeOffset]::UtcNow.ToString('o');
    process_started_utc=$identity.CreationDate.ToUniversalTime().ToString('o');parent_pid=$identity.ParentProcessId;
    launch_method='Win32_Process.Create through Windows WMI service';config=$Config;attempt=$Attempt;
    supervisor_script=$scriptPath;worker_receipt=('runs/'+$cfg.release_id+'/worker_'+$Attempt+'.json')}
$record | ConvertTo-Json | Set-Content -LiteralPath $supervisorReceipt -Encoding utf8
$record | ConvertTo-Json
