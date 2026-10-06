---
title: mu2edaq-controlroom interfaces
group: control-room
tier: A
audience: expert
summary: >
  Command surfaces, configuration formats, external commands, files and
  inbound references of the legacy mu2edaq-controlroom scripts
---

# mu2edaq-controlroom — interfaces

Everything here is superseded or unowned; see
[ARCHITECTURE.md § Deprecation](ARCHITECTURE.md#deprecation). This page
exists so that the references still pointing at the package can be
repointed with full knowledge of what they point at.

| Interface | Kind | Section |
|---|---|---|
| ten scripts | command line | §1 |
| embedded YAML of `mu2e-krb-cron.py`, `kerb_princ.json` | file formats | §2 |
| `kinit`, `kdestroy`, `kswitch`, `klist`, `ssh`, `gh` | external commands run | §3 |
| files read and written | filesystem | §4 |
| documentation that points here | inbound references | §5 |

---

## 1. Command surfaces

| Command | Synopsis | Exit | Page |
|---|---|---|---|
| `mu2e-krb-cron.py` | `[--config FILE] [-v] [-s] [-n]` | 0 whenever a decision is reached, even if `kinit` fails; 1 config / krb5-context error; 2 argparse | `mu2e-krb-cron.py(1)` |
| `ticket-manage.py` | none (Qt options) | 1 without `kerb_princ.json`; else Qt's | `ticket-manage.py(1)` |
| `kerb.py` | none | 0; 1 on import error or empty default cache | `kerb.py(1)` |
| `bin/GetTicket.sh` | none | `kinit`'s | `GetTicket.sh(1)` |
| `bin/start_vnc_tunnels_mu2e.sh` | `[-h host] [-u user] [-p start] [-n count] [-k]` | 1 no ticket and always after `-k`; else last command's | `start_vnc_tunnels_mu2e.sh(1)` |
| `bin/list_issues_mu2e.sh` | `[-s newest\|oldest] [-o terminal\|html\|pdf\|browser] [-f path] [-r repo] [-l label] [-j n]` | 0; 1 prerequisite/argument/PDF failure | `list_issues_mu2e.sh(1)` |
| `bin/list_pr_mu2e.sh` | none | last `gh pr list`'s | `list_pr_mu2e.sh(1)` |
| `bin/clone_mu2e_repos.sh` | none | last `gh repo clone`'s | `clone_mu2e_repos.sh(1)` |
| `bin/make-data-dirs.py` | none | always 0 | `make-data-dirs.py(1)` |
| `daq_env_tools.py` | `[-c] [-r] [-o F] [-i F] [-f]` (`-v -d -s --config -e` ignored) | 0; 1 existing output without `-f` or missing input; 2 argparse | `daq_env_tools.py(1)` |

None reads an environment variable of its own, a `.env`, or a `config/`
directory. `TERM_PROGRAM` (`GetTicket.sh`) and `KRB5CCNAME` (indirectly,
through the Kerberos library) are the only environment inputs.

---

## 2. Configuration formats

### 2.1 `mu2e-krb-cron.py` — embedded YAML or `--config FILE`

`mu2e-krb-cron.py:49-83`; loader `:89-115`.

| Key | Type | Default | Notes |
|---|---|---|---|
| `settings.renew_threshold_hours` | number | 2 | act when the TGT has less than this left |
| `settings.renew_till_threshold_hours` | number | 24 | re-`kinit` instead of renewing when renew-until is closer than this (or unknown) |
| `settings.log_file` | path | none | appended in addition to stdout |
| `principals[]` | list of `{name, keytab}` | required, ≥1 | the allow-list: any other default principal is `kdestroy`ed |
| `user_principals` | map OS user → principal | `{}` | `kswitch -p` target after every run |

Shipped values: six principals `{mu2edaq, mu2eshift, mu2eraw, mu2edcs,
mu2e-teststand, mu2e-controlroom}/mu2edaq/mu2e.fnal.gov@FNAL.GOV`, keytabs
`/Users/anorman/Kerberos_Keytabs/Mu2e/<id>.keytab`; `user_principals` maps
`mu2edaq`, `mu2eshift`, `mu2eraw` to their service principals and
`anorman` to `anorman@FNAL.GOV`, which is not in `principals`.

### 2.2 `kerb_princ.json` — `ticket-manage.py`

Searched in the working directory, then beside the script
(`ticket-manage.py:24-43`).

| Key | Type | Used |
|---|---|---|
| `user` | list of ids | no |
| `principal` | id → principal | yes: maps the selected principal back to an id |
| `keytab` | id → filename | read, then overwritten by `keytab-master` (`:220-221`) |
| `keytab-master` | filename | yes: `mu2e-all.keytab`, every `kinit -kt` |
| `keypath` | directory | yes: `/Users/anorman/Kerberos_Keytabs/Mu2e` |

`ticket-config.json` (same search path) is loaded if present and its
contents are never used (`:93-101`).

The successor formats are `mu2edaq-kerberos`'s
`config/identities-mu2e.yaml` (identity list) and `config/vault.yaml`
(Vault address and paths); the keytabs themselves live in Vault at
`td/scd/experiments/mu2e/kerberos/<identity>`.

---

## 3. External commands run

| Caller | argv | Where |
|---|---|---|
| `mu2e-krb-cron.py` | `kinit -f -A -k -t KEYTAB PRINCIPAL` (macOS) / `kinit -5 -F -A -k -t KEYTAB PRINCIPAL` (other) | `:198-209` |
| | `kinit -R PRINCIPAL` | `:212-216` |
| | `kdestroy` (default cache only) | `:219-222` |
| | `kswitch -p PRINCIPAL` | `:225-233` |
| | `klist` (text parsed for expiry and "renew until") | `:131-175` |
| `ticket-manage.py` | `kswitch -p P`; `klist -A`; `kinit -R P`; `kinit -kt KEYPATH/mu2e-all.keytab P`; `kinit P` (interactive) | `:180-181`, `:190`, `:201`, `:247`, `:230` |
| `bin/GetTicket.sh` | `kinit -f -A -k -t …` if `TERM_PROGRAM=Apple_Terminal`, else `kinit -5 -F -A -k -t …` | `:22-28` |
| `bin/start_vnc_tunnels_mu2e.sh` | `klist --test`; `ssh -f -N -M -S /tmp/ssh-ctrl-HOST-P -L P:localhost:P -l USER HOST`; `ssh -S … -O exit HOST` | `:50`, `:87`, `:70` |
| `bin/list_issues_mu2e.sh` | `gh api user`; `gh repo list mu2e --limit 4000 --json nameWithOwner`; `gh issue list --repo R --state open --limit 500 --json …`; `jq`; `pandoc`/`wkhtmltopdf`/`google-chrome`; `open`/`xdg-open` | throughout |
| `bin/list_pr_mu2e.sh`, `bin/clone_mu2e_repos.sh` | `gh repo list mu2e --limit 4000`; `gh pr list --repo R` / `gh repo clone R R` | `:5-7` |

The `kinit -5 -F` form is MIT syntax; under Heimdal `-F` means
"not forwardable". The cron picks it by `platform.system()`, `GetTicket.sh`
by terminal program, so `GetTicket.sh` run from iTerm2 on macOS uses the
MIT flags against Heimdal.

---

## 4. Files read and written

| Path | Written by | Mode | Notes |
|---|---|---|---|
| `/Users/anorman/Kerberos_Keytabs/Mu2e/*.keytab`, `mu2e-all.keytab` | — (read) | as found; not checked | §2 |
| `$HOME/.krb5/dune-controlroom-fnal.keytab` | — (read by `GetTicket.sh`) | not checked | DUNE identity |
| default credential cache / collection | `kinit`, `kdestroy` | Kerberos library's | the cron and GUI act only on the default selection |
| `settings.log_file` | cron | umask | optional |
| `/tmp/ssh-ctrl-HOST-PORT` | tunnel script | ssh's (socket `0600`) | world-writable directory; the successor uses `~/.crs/` |
| `default_env_out.json` (or `-o`) | `daq_env_tools.py -c` | umask, normally `0644` | full environment, credentials included |
| `/data{,-2}/…`, `/test-data/…`, `/scratch/…` | `make-data-dirs.py` | umask | 140 directories |
| `/tmp/mu2e-issues.{html,pdf}` | `list_issues_mu2e.sh` | umask | default output |
| `./Mu2e/<repo>/` | `clone_mu2e_repos.sh` | — | one clone per org repository |
| `~/.credentials/github.token` | — (read) | — | used as `GH_TOKEN` if valid |

---

## 5. Inbound references

No suite package executes anything in this repository. Documentation in
three repositories names `mu2e-krb-cron.py` as the Kerberos remedy; the
table with line numbers is in
[ARCHITECTURE.md § Who still points here](ARCHITECTURE.md#who-still-points-here).
Structural references: superproject `.gitmodules:13-15`, `README.md:51`,
`testing/common.sh:31`, `:120` (pytest directory "."). `mu2edaq-kerberos`
names this package as its predecessor
(`../mu2edaq-kerberos/doc/ARCHITECTURE.md:24`, `:210-214`).
