param(
    [ValidateSet('prepare','qualify','generate','verify','precision')][string]$Stage,
    [string]$Config = 'configs/releases/dataset21_naca_v1.json',
    [string]$Attempt = '01'
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Set-Location -LiteralPath $projectRoot
$control = Join-Path $projectRoot 'runs/naca_campaign_control'
New-Item -ItemType Directory -Path $control -Force | Out-Null
$stem = Join-Path $control ($Stage + '_' + $Attempt)
$receiptPath = $stem + '.json'
if (Test-Path -LiteralPath $receiptPath) { throw "Attempt receipt already exists: $receiptPath" }
$env:JULIA_NUM_PRECOMPILE_TASKS = '2'
$env:OPENBLAS_NUM_THREADS = '1'
$env:OMP_NUM_THREADS = '1'
$env:MKL_NUM_THREADS = '1'
$juliaLauncher = (Get-Command julia -CommandType Application).Source
$juliaPath = (& $juliaLauncher --startup-file=no --history-file=no -e 'print(joinpath(Sys.BINDIR,"julia.exe"))').Trim()
$gmshPath = Join-Path $projectRoot 'data/cache/naca_tools/gmsh-4.14.1-Windows64/gmsh.exe'
$entry = if ($Stage -eq 'precision') { 'experiments/data_generation/diagnose_dataset21_naca_precision.jl' } else { 'experiments/data_generation/run_dataset21_naca.jl' }
$arguments = @('--startup-file=no','--threads=1','--project=configs/environments/dataset21_naca',
    $entry,'--execute','--stage',$Stage,'--config',$Config,'--gmsh',$gmshPath)
$process = Start-Process -FilePath $juliaPath -ArgumentList $arguments -WorkingDirectory $projectRoot `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput ($stem + '.log') -RedirectStandardError ($stem + '.err.log')
$receipt = [ordered]@{stage=$Stage; attempt=$Attempt; config=$Config; pid=$process.Id;
    process_started_utc=$process.StartTime.ToUniversalTime().ToString('o'); status='running';
    stdout=($stem + '.log'); stderr=($stem + '.err.log')}
$receipt | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8
$process.WaitForExit()
$receipt.status = if ($process.ExitCode -eq 0) { 'completed' } else { 'failed' }
$receipt.exit_code = $process.ExitCode
$receipt.finished_utc = [DateTimeOffset]::UtcNow.ToString('o')
$receipt | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8
exit $process.ExitCode
