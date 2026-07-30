<#
.SYNOPSIS
    Set up the Python virtual environment for mu2edaq-controlroom on Windows
    (PowerShell port of bootstrap.sh).

.DESCRIPTION
    The `krb5` requirement has no Windows wheel (it needs krb5-config to build),
    and the control room's Kerberos/VNC/ssh tooling is Unix-only anyway (see
    WINDOWS-COMPATIBILITY-REPORT.md and Mu2e/mu2edaq-main#11). This bootstrap
    installs the Windows-installable dependencies (pyyaml) so the DAQ env tools
    (daq_env_tools.py) work, and skips krb5 with a clear message rather than
    failing the whole install.

.PARAMETER Dev
    Also install pytest.
#>
[CmdletBinding()]
param(
    [switch]$Dev
)

$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Here
$Venv = Join-Path $Here 'venv'

# Prefer 'python'; fall back to the py launcher ('python3' on Windows is the
# Microsoft Store alias stub, so it is not used here).
$Python = $env:PYTHON
if (-not $Python) {
    if (Get-Command python -ErrorAction SilentlyContinue) { $Python = 'python' }
    elseif (Get-Command py -ErrorAction SilentlyContinue) { $Python = 'py' }
    else { Write-Error 'Python 3.9+ not found on PATH. Install it first.'; exit 1 }
}

& $Python -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'
if ($LASTEXITCODE -ne 0) { Write-Error 'Python 3.9 or newer is required.'; exit 1 }

if (-not (Test-Path $Venv)) { & $Python -m venv $Venv }
$VenvPy = Join-Path $Venv 'Scripts\python.exe'
& $VenvPy -m pip install --upgrade pip | Out-Null

# Install requirements minus krb5 (no Windows wheel; Kerberos is Unix-only).
Write-Host 'Installing Windows-installable dependencies (pyyaml)...'
& $VenvPy -m pip install pyyaml
Write-Warning ("Skipping 'krb5' -- it has no Windows wheel (needs krb5-config). " +
    "The control room's Kerberos ticket / VNC-tunnel tooling is Unix-only " +
    "(GetTicket.sh, OpenTunnels.sh, ...); see #11. daq_env_tools.py works without it.")

if ($Dev) { & $VenvPy -m pip install pytest }

Write-Host ''
Write-Host 'Bootstrap complete (Windows subset).'
Write-Host '  Run the DAQ env tools with:  venv\Scripts\python.exe daq_env_tools.py'
