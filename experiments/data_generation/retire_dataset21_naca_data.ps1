param([switch]$Execute)
$ErrorActionPreference='Stop'
if (-not $Execute) { throw 'Deletion requires the explicit Execute switch and reviewed manifest' }
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$control=Join-Path $root 'runs/naca_retirement_20261012'
$plan=Get-Content -LiteralPath (Join-Path $control 'deletion_plan.json') -Raw | ConvertFrom-Json
$receiptPath=Join-Path $control 'deletion_receipt.json'
if (Test-Path -LiteralPath $receiptPath) { throw 'Receipt exists; inspect it before a separate retry' }
Push-Location -LiteralPath $root
try {
    & git cat-file -e ($plan.archive_commit+':abolish/naca_pre_nlc6_20261012/README.md')
    if ($LASTEXITCODE -ne 0) { throw 'Archive commit is not available' }
    if ((Get-FileHash -LiteralPath (Join-Path $root $plan.archive) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $plan.archive_sha256) { throw 'Source archive hash mismatch' }
    foreach ($property in $plan.protected.PSObject.Properties) {
        if ((Get-FileHash -LiteralPath (Join-Path $root $property.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $property.Value) { throw 'Protected dependency hash mismatch' }
    }
    $targets=@()
    foreach ($row in $plan.files) {
        if ($row.path -notmatch '^(runs/(dataset21_naca_zeta006_[^/]+|naca_precision_[^/]+)/|data/releases/dataset21_naca_zeta006_[^/]+/).+\.h5$') { throw 'Path outside authorized old numerical scope' }
        $absolute=[IO.Path]::GetFullPath((Join-Path $root $row.path))
        if (-not $absolute.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Target escaped project' }
        $item=Get-Item -LiteralPath $absolute
        if ($item.PSIsContainer -or $item.Length -ne $row.bytes) { throw 'Target type or size changed' }
        $check=$item
        while ($null -ne $check) {
            if ($check.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse point in deletion path' }
            $check=if ($check -is [IO.FileInfo]) {$check.Directory} else {$check.Parent}
        }
        $targets+=@{path=$row.path;absolute=$absolute;bytes=$row.bytes}
    }
    if (($targets.absolute | Select-Object -Unique).Count -ne $targets.Count) { throw 'Duplicate deletion targets' }
    $result=[ordered]@{status='deleting';archive_commit=$plan.archive_commit;deleted=@();failed=@();deleted_bytes=0}
    foreach ($target in $targets) {
        try {
            Remove-Item -LiteralPath $target.absolute -Force
            if (Test-Path -LiteralPath $target.absolute) { throw 'Target remains after deletion' }
            $result.deleted+=@{path=$target.path;bytes=$target.bytes};$result.deleted_bytes+=$target.bytes
        } catch { $result.failed+=@{path=$target.path;error=$_.Exception.Message} }
        $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $receiptPath -Encoding utf8
    }
    foreach ($property in $plan.protected.PSObject.Properties) {
        if ((Get-FileHash -LiteralPath (Join-Path $root $property.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $property.Value) { throw 'Protected dependency changed during cleanup' }
    }
    $result.status=if ($result.failed.Count -eq 0) {'completed'} else {'partial_failure'}
    $result['protected_hashes_verified']=$true;$result['finished_utc']=[DateTimeOffset]::UtcNow.ToString('o')
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $receiptPath -Encoding utf8
    [pscustomobject]@{status=$result.status;deleted_bytes=$result.deleted_bytes;protected_hashes_verified=$result.protected_hashes_verified} | ConvertTo-Json
    if ($result.failed.Count -gt 0) { throw 'Some authorized old files could not be removed; see receipt' }
} finally { Pop-Location }
