param([string]$Config='configs/releases/dataset21_nlc6_v1.json', [string]$Attempt='01', [string]$JuliaExecutable='')
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Set-Location -LiteralPath $projectRoot
$campaignConfig=Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
if (-not $campaignConfig.execution_authorized -or -not $campaignConfig.formal_launch_authorized) { throw 'Authorization missing' }
if ($campaignConfig.release_id -notmatch '^[a-zA-Z0-9_-]+$' -or $Attempt -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Unsafe identity' }
$runRoot=Join-Path $projectRoot ('runs/'+$campaignConfig.release_id)
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
if (Test-Path -LiteralPath (Join-Path $runRoot 'execution.lock')) { throw 'Campaign execution lock exists' }
$receiptPath=Join-Path $runRoot ('worker_'+$Attempt+'.json')
if (Test-Path -LiteralPath $receiptPath) { throw 'Attempt identity already used' }
if ($JuliaExecutable) {
    $juliaPath=(Resolve-Path -LiteralPath $JuliaExecutable).Path
} else {
    $launcher=(Get-Command julia -CommandType Application).Source
    $juliaPath=(& $launcher --startup-file=no -e 'print(joinpath(Sys.BINDIR,"julia.exe"))').Trim()
}
$env:OPENBLAS_NUM_THREADS='1'; $env:OMP_NUM_THREADS='1'; $env:MKL_NUM_THREADS='1'
$stdout=Join-Path $runRoot ('worker_'+$Attempt+'.log');$stderr=Join-Path $runRoot ('worker_'+$Attempt+'.err.log')
$arguments=@('--startup-file=no','--threads=4','--project=configs/environments/dataset21_naca',
    'experiments/data_generation/run_dataset21_nlc6_campaign.jl','--execute','--config',$Config)
$worker=Start-Process -FilePath $juliaPath -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden `
    -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$record=[ordered]@{status='running';pid=$worker.Id;process_started_utc=$worker.StartTime.ToUniversalTime().ToString('o');
    config=$Config;attempt=$Attempt;stdout=$stdout;stderr=$stderr}
$record | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8
$worker.WaitForExit();$worker.Refresh()
$record['exit_code']=$worker.ExitCode;$record['finished_utc']=[DateTimeOffset]::UtcNow.ToString('o')
$record.status=if ($worker.ExitCode -eq 0) {'completed'} else {'failed'}
$record | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8
exit $worker.ExitCode
