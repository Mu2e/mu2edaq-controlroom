# DAQ-ControlRoom (mu2edaq-controlroom)

Scripts and supporting configuration for the Mu2e DAQ control room.

> **Deprecated.** Kerberos ticket management is provided by
> [mu2edaq-kerberos](https://github.com/Mu2e/mu2edaq-kerberos)
> (`get-kerberos-ticket`, `ticket-manager`, `mu2edaq-krb`), and VNC access by
> [mu2edaq-controlroom-setup](https://github.com/Mu2e/mu2edaq-controlroom-setup)
> (`crs-tunnel`, `crs-gui`). Do not run `mu2e-krb-cron.py` on a machine
> where you hold a personal Kerberos ticket: it destroys any default ticket
> whose principal is not one of its six service principals. What is still
> missing from the replacements, and the retirement plan, are in
> [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#deprecation).

## Contents

### Kerberos ticket management

| Script | Description |
|--------|-------------|
| `mu2e-krb-cron.py` | Headless ticket lifecycle manager designed to run from `cron`. Renews or replaces tickets for a configured list of service principals. |
| `ticket-manage.py` | Qt6 GUI for interactive ticket management: switch active principal, get new tickets from keytabs, renew individual or all tickets. |
| `kerb.py` | Diagnostic script that prints the active principal and all credential caches via the `krb5` Python library. |
| `bin/GetTicket.sh` | Shell script to obtain a Kerberos TGT from a keytab, with macOS/Linux `kinit` flag selection. As shipped it is configured for a DUNE control-room principal. |

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
| `daq_env_tools.py` | Captures the current shell environment to a JSON file or restores a previously saved environment. Useful for preserving UPS/Muse software setups. |
| `bin/make-data-dirs.py` | Creates the standard Mu2e DAQ data directory hierarchy (`/data`, `/data-2`, `/test-data`, `/scratch`) partitioned by run type and detector subsystem. |

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

Superseded by `crs-tunnel` in mu2edaq-controlroom-setup. The script below is zsh and
checks the ticket with Heimdal's `klist --test`, so it does not run under MIT Kerberos (Linux).

```bash
# Open default tunnels (ports 5951–5956: the range is inclusive) via mu2edaq-gateway.fnal.gov
bash bin/start_vnc_tunnels_mu2e.sh

# Open tunnels on a custom port range
bash bin/start_vnc_tunnels_mu2e.sh -h mu2edaq01.fnal.gov -p 5960 -n 3

# Close tunnels
bash bin/start_vnc_tunnels_mu2e.sh -k
```

## Man pages

Pages live under `man/man1/`, one per command, named as the command is
invoked. To read one locally:

```bash
man ./man/man1/mu2e-krb-cron.py.1
man ./man/man1/ticket-manage.py.1
man ./man/man1/start_vnc_tunnels_mu2e.sh.1
```

| Page | Covers |
|------|--------|
| `man/man1/mu2e-krb-cron.py.1` | `mu2e-krb-cron.py` |
| `man/man1/ticket-manage.py.1` | `ticket-manage.py` |
| `man/man1/kerb.py.1` | `kerb.py` |
| `man/man1/GetTicket.sh.1` | `bin/GetTicket.sh` |
| `man/man1/start_vnc_tunnels_mu2e.sh.1` | `bin/start_vnc_tunnels_mu2e.sh` |
| `man/man1/clone_mu2e_repos.sh.1` | `bin/clone_mu2e_repos.sh` |
| `man/man1/list_issues_mu2e.sh.1` | `bin/list_issues_mu2e.sh` |
| `man/man1/list_pr_mu2e.sh.1` | `bin/list_pr_mu2e.sh` |
| `man/man1/make-data-dirs.py.1` | `bin/make-data-dirs.py` |
| `man/man1/daq_env_tools.py.1` | `daq_env_tools.py` |

Review documentation: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md),
[docs/INTERFACES.md](docs/INTERFACES.md).
