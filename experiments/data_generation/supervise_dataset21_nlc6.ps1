param([string]$Config, [string]$Attempt, [string]$JuliaExecutable)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Set-Location -LiteralPath $projectRoot
$cfg=Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
$runRoot=Join-Path $projectRoot ('runs/'+$cfg.release_id)
Start-Transcript -LiteralPath (Join-Path $runRoot ('supervisor_'+$Attempt+'.log')) | Out-Null
try {
    & (Join-Path $PSScriptRoot 'start_dataset21_nlc6_campaign.ps1') -Config $Config -Attempt $Attempt -JuliaExecutable $JuliaExecutable
} catch {
    [ordered]@{status='supervisor_failed';utc=[DateTimeOffset]::UtcNow.ToString('o');error=$_.ToString()} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runRoot ('supervisor_'+$Attempt+'_failure.json')) -Encoding utf8
    throw
} finally {
    Stop-Transcript | Out-Null
}
