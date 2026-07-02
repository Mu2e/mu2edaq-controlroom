# DAQ-ControlRoom

Scripts and supporting configuration for the Mu2e DAQ control room.

## Contents

### Kerberos ticket management

| Script | Description |
|--------|-------------|
| `mu2e-krb-cron.py` | Headless ticket lifecycle manager designed to run from `cron`. Renews or replaces tickets for a configured list of service principals. |
| `ticket-manage.py` | Qt6 GUI for interactive ticket management: switch active principal, get new tickets from keytabs, renew individual or all tickets. |
| `kerb.py` | Diagnostic script that prints the active principal and all credential caches via the `krb5` Python library. |
| `bin/GetTicket.sh` | Shell script to obtain a Kerberos TGT from a keytab, with automatic macOS/Linux `kinit` flag selection. |

### VNC / control room tunnels

| Script | Description |
|--------|-------------|
| `bin/start_vnc_tunnels_mu2e.sh` | Opens or closes SSH port-forward tunnels for VNC sessions running inside the DAQ network. Requires a valid Kerberos ticket. |

### GitHub organisation utilities

| Script | Description |
|--------|-------------|
| `bin/clone_mu2e_repos.sh` | Clones every repository in the `mu2e` GitHub organisation into a local `mu2e/<repo>` directory tree. |
| `bin/list_issues_mu2e.sh` | Lists open GitHub issues across all `mu2e` organisation repositories. |
| `bin/list_pr_mu2e.sh` | Lists open pull requests across all `mu2e` organisation repositories. |

### DAQ environment tools

| Script | Description |
|--------|-------------|
| `daq-env-tools.py` | Captures the current shell environment to a JSON file or restores a previously saved environment. Useful for preserving UPS/Muse software setups. |
| `bin/make-data-dirs.sh` | Creates the standard Mu2e DAQ data directory hierarchy (`/data`, `/data-2`, `/test-data`, `/scratch`) partitioned by run type and detector subsystem. |

### Configuration files

| File | Description |
|------|-------------|
| `kerb_princ.json` | Kerberos principal and keytab metadata used by `ticket-manage.py`. |
| `requirements.txt` | Python package dependencies (`krb5`, `pyyaml`). |

## Quick start

### Python dependencies

```bash
pip install -r requirements.txt
pip install PyQt6   # only needed for ticket-manage.py
```

### Kerberos ticket renewal (cron)

Add to the crontab (`crontab -e`):

```
*/30 * * * * /usr/bin/python3 /path/to/mu2edaq-controlroom/mu2e-krb-cron.py
```

Edit the embedded `DEFAULT_CONFIG` block in `mu2e-krb-cron.py` to set your
principal names, keytab paths, and OS-username-to-principal mappings, or
supply an external YAML file with `--config`.

### Interactive ticket management

```bash
python3 ticket-manage.py
```

Requires `kerb_princ.json` in the working directory or alongside the script.

### VNC tunnels

```bash
# Open default tunnels (ports 5951–5955 via mu2edaq-gateway.fnal.gov)
bash bin/start_vnc_tunnels_mu2e.sh

# Open tunnels on a custom port range
bash bin/start_vnc_tunnels_mu2e.sh -h mu2edaq01.fnal.gov -p 5960 -n 3

# Close tunnels
bash bin/start_vnc_tunnels_mu2e.sh -k
```

## Man pages

Full reference documentation is in the `man/` directory.
To read a page locally:

```bash
man man/mu2e-krb-cron.1
man man/ticket-manage.1
man man/start-vnc-tunnels-mu2e.1
# etc.
```

| Page | Covers |
|------|--------|
| `man/mu2e-krb-cron.1` | `mu2e-krb-cron.py` |
| `man/ticket-manage.1` | `ticket-manage.py` |
| `man/kerb.1` | `kerb.py` |
| `man/GetTicket.1` | `bin/GetTicket.sh` |
| `man/start-vnc-tunnels-mu2e.1` | `bin/start_vnc_tunnels_mu2e.sh` |
| `man/clone-mu2e-repos.1` | `bin/clone_mu2e_repos.sh` |
| `man/list-issues-mu2e.1` | `bin/list_issues_mu2e.sh` |
| `man/list-pr-mu2e.1` | `bin/list_pr_mu2e.sh` |
| `man/make-data-dirs.1` | `bin/make-data-dirs.sh` |
| `man/daq-env-tools.1` | `daq-env-tools.py` |
