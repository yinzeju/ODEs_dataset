param([string[]]$Models = @())
# Delegate to the retained entry point without changing frozen release identities.
& (Join-Path $PSScriptRoot 'run_testsub2_nv.ps1') -Models $Models
