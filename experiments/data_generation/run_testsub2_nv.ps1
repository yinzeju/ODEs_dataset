param([string[]]$Models = @())
$ErrorActionPreference = 'Stop'
$TaskProject = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$TaskJuliaCommand = Get-Command julia -ErrorAction SilentlyContinue
$TaskJulia = if ($TaskJuliaCommand) { $TaskJuliaCommand.Source } else {
    Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE '.julia/juliaup') -Directory |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName 'bin/julia.exe' } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $TaskJulia) { throw 'Julia executable not found.' }
$env:JULIA_DEPOT_PATH = (Join-Path $TaskProject 'data/.julia_depot') + ';' + (Join-Path $env:USERPROFILE '.julia')
$env:OPENBLAS_NUM_THREADS = '1'
$TaskEnvironment = Join-Path $TaskProject 'configs/environments/testsub2_nv'
$TaskGPUEnvironment = Join-Path $TaskProject 'configs/environments/testsub2_nv_gpu'
$TaskConfig = Get-Content -LiteralPath (Join-Path $TaskProject 'configs/releases/testsub2_nv_20261004.json') -Raw | ConvertFrom-Json
$TaskReleaseManifest = Join-Path $TaskProject ('data/releases/' + $TaskConfig.release_id + '/TestSub2/release_manifest.json')
if (Test-Path -LiteralPath $TaskReleaseManifest) {
    & $TaskJulia --startup-file=no "--project=$TaskEnvironment" (Join-Path $PSScriptRoot 'verify_testsub2_nv_dataset.jl')
    if ($LASTEXITCODE -ne 0) { throw 'Frozen release verification failed.' }
    return
}
$TaskSelected = if ($Models.Count -eq 0) { @($TaskConfig.objects) } else { @($Models) }
foreach ($TaskModel in $TaskSelected) {
    if ($TaskModel -notin $TaskConfig.objects) { throw "Unknown model: $TaskModel" }
}
$TaskCPUModels = @($TaskSelected | Where-Object { $_ -in @('duffing', 'beam') })
$TaskGPUModels = @($TaskSelected | Where-Object { $_ -in @('shell_nr', 'shell_ir12', 'plate') })
& $TaskJulia --startup-file=no --threads=3 "--project=$TaskEnvironment" (Join-Path $PSScriptRoot 'prepare_testsub2_nv_models.jl')
if ($LASTEXITCODE -ne 0) { throw 'Mechanical assembly qualification failed.' }
if ($TaskCPUModels.Count -gt 0) {
    & $TaskJulia --startup-file=no --threads=3 "--project=$TaskEnvironment" (Join-Path $PSScriptRoot 'generate_testsub2_nv_dataset.jl') @TaskCPUModels
    if ($LASTEXITCODE -ne 0) { throw 'CPU formal generation failed.' }
}
if ($TaskGPUModels.Count -gt 0) {
    & $TaskJulia --startup-file=no --threads=2 "--project=$TaskGPUEnvironment" (Join-Path $PSScriptRoot 'generate_testsub2_nv_gpu.jl') @TaskGPUModels
    if ($LASTEXITCODE -ne 0) { throw 'GPU formal generation failed.' }
}
if ($Models.Count -eq 0) {
    & $TaskJulia --startup-file=no --threads=3 "--project=$TaskEnvironment" (Join-Path $PSScriptRoot 'verify_testsub2_nv_dataset.jl')
    if ($LASTEXITCODE -ne 0) { throw 'Complete release verification failed.' }
}
