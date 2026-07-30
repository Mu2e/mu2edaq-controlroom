"""Windows compatibility tests.

Added in the windows-compat sweep. mu2edaq-controlroom is the NOVA-legacy DAQ
control room: its shell scripts wrap Unix-only Kerberos (kinit/klist), ssh VNC
tunnels, and CVMFS mirroring, and its `krb5` dependency has no Windows wheel
(needs krb5-config). Those pieces are Unix-only by nature and tracked under
Mu2e/mu2edaq-main#11 -- they are deliberately NOT ported to PowerShell.

What does work on Windows is the DAQ env-tools helper, which needs no Kerberos;
this module locks that in, plus the bootstrap PowerShell port and the
"Unix-only scripts are not ported" invariant.
"""
import pathlib
import shutil
import subprocess

import pytest

REPO = pathlib.Path(__file__).resolve().parent
PWSH = shutil.which("pwsh") or shutil.which("powershell")

# Unix-only control-room scripts that must NOT gain a (non-functional) .ps1.
UNIX_ONLY_SCRIPTS = [
    "Mu2eCR/RemoteControlRooms/GetTicket.sh",
    "Mu2eCR/RemoteControlRooms/OpenTunnels.sh",
    "bin/GetTicket.sh",
    "bin/start_vnc_tunnels_mu2e.sh",
]


def test_daq_env_tools_importable_without_kerberos():
    # daq_env_tools has no krb5 dependency, so it must import on Windows.
    import importlib
    mod = importlib.import_module("daq_env_tools")
    # Its public helpers must be importable on Windows (no Kerberos needed).
    assert hasattr(mod, "get_environment_variables")
    assert hasattr(mod, "store_environment_variables_json")


def test_krb5_is_the_windows_blocked_requirement():
    reqs = (REPO / "requirements.txt").read_text(encoding="utf-8")
    # krb5 (no Windows wheel) is present; pyyaml (installable) is too.
    assert "krb5" in reqs
    assert "pyyaml" in reqs.lower()


def test_bootstrap_has_a_powershell_port():
    assert (REPO / "bootstrap.sh").is_file()
    assert (REPO / "bootstrap.ps1").is_file()


def test_unix_only_scripts_are_not_ported():
    for rel in UNIX_ONLY_SCRIPTS:
        assert (REPO / rel).is_file(), f"missing Unix script: {rel}"
        assert not (REPO / rel).with_suffix(".ps1").exists(), (
            f"{rel} is Unix-only (Kerberos/VNC/ssh) and should not have a .ps1")


@pytest.mark.skipif(not PWSH, reason="PowerShell not available")
def test_bootstrap_powershell_parses():
    path = (REPO / "bootstrap.ps1").as_posix()
    code = (
        "$e=$null;"
        f"[System.Management.Automation.Language.Parser]::ParseFile('{path}',[ref]$null,[ref]$e)|Out-Null;"
        "if($e){$e|ForEach-Object{Write-Error $_};exit 1}else{exit 0}"
    )
    result = subprocess.run(
        [PWSH, "-NoProfile", "-NonInteractive", "-Command", code],
        capture_output=True, text=True, timeout=60,
    )
    assert result.returncode == 0, result.stderr
