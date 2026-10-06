# Staged issues — mu2edaq-controlroom

GitHub writes are not permitted in this review wave (CONTRACT §9.1). Each
section below is one issue body in the §6 format, fingerprint included.
Target repository: `Mu2e/mu2edaq-controlroom` (public, issues enabled).
Label: `mega-review` plus the category.

Dedup read, 2026-10-06:

```
$ gh issue list -R Mu2e/mu2edaq-controlroom --state all --limit 300
#8 OPEN   macOS Python 3.12 venv (1,061 files) and 452 .pyc files are committed to git
#6 CLOSED Unversioned `#!/usr/bin/env python` shebangs fail on AlmaLinux 9
#5 CLOSED daq-env-tools.py is untestable (hyphenated name, module-level argparse/exit) and has two latent bugs
#4 CLOSED bin/make-data-dirs.sh is a Python script with a .sh extension, a Python-2 shebang, and a syntax error
#3 CLOSED 7 scripts are Python 2 (NOvA-era legacy) and fail on any Python 3
```

No fingerprint present. #5 shares tokens with CR-004 (`daq-env-tools`) but
concerned the module structure and two fixed bugs, not credential
exposure or `--restore`; CR-004 is filed fresh with a back-reference.

**Staged comment, not a new issue — `Mu2e/mu2edaq-controlroom#8`:**

> Fixed on `main`: `e5c1481` (stop tracking venv, add `.gitignore`) and
> `0c42280` (stop tracking stray `.pyc`). `git ls-tree -r origin/main | grep -c '^venv/'`
> → 0 at `076de7a`. Suggest closing. (mega-review, 2026-10-06)

Cross-package findings referenced here: `mu2edaq-controlroom-setup`
CRS-008 (`f73dfcd7`, its no-ticket hint points at this package's cron).

| ID | Sev | Category | Title | Fingerprint |
|---|---|---|---|---|
| CR-001 | S3 | enhancement | [deprecation] retire mu2edaq-controlroom once mu2edaq-kerberos covers unattended renewal and the seven references are repointed | b1867f6d |
| CR-002 | S3 | bug | [krb] mu2e-krb-cron.py destroys any default ticket outside its list, including the personal principal it maps the operator to, and maintains only the default cache | 3acfaaa5 |
| CR-003 | S3 | bug | [krb] keytab locations are hard-coded to one user's macOS home with a master keytab of all six identities; GetTicket.sh is configured for DUNE | b48c31bd |
| CR-004 | S3 | bug | [env] daq_env_tools.py --capture writes the whole environment, credentials included, to stdout and a world-readable file; --restore cannot work | 0215629f |
| CR-005 | S4 | bug | [vnc] start_vnc_tunnels_mu2e.sh fails under MIT Kerberos, opens n+1 tunnels and keeps control sockets in /tmp | 991d68b7 |
| CR-006 | S4 | bug | [deps] kerb.py imports gssapi, which requirements.txt does not install | 7a849feb |
| CR-007 | S4 | documentation | [man] man pages were flat, misnamed and described behaviour the scripts do not have | dfced355 |
| CR-008 | S4 | enhancement | [repo] Mu2eCR/ is a vendored NOvA CVS checkout, CVS metadata included, used by nothing | 3aca7540 |

---

## CR-001 — [deprecation] retire mu2edaq-controlroom once mu2edaq-kerberos covers unattended renewal and the seven references are repointed

**Severity:** S3 — correctness or maintainability risk, no current outage
**Category:** enhancement
**Location:** `README.md:1`
**Found by:** mega-review (`mu2e-sept-mega-review`), 2026-10-06

## What
Every control-room capability of this package is superseded:
interactive ticket management, ticket minting and cache listing by
`mu2edaq-kerberos` (`ticket-manager`, `get-kerberos-ticket`, `krb-caches`,
`mu2edaq-krb`); VNC tunnels by `mu2edaq-controlroom-setup` (`crs-tunnel`,
`crs-gui`, whose `tunnels.py:5` says it "generalizes" this package's
script). The package is still a submodule, in the superproject README
and test harness, and in every release tag. One capability has no full
replacement: **unattended** ticket keeping from cron.

## Evidence
```
$ grep -rn 'mu2e-krb-cron' ../mu2edaq-controlroom-setup ../mu2edaq-reverse-proxy ../*.md --include=*.py --include=*.md
../mu2edaq-controlroom-setup/src/mu2edaq_controlroom_setup/sshutil.py:22:  python3 mu2edaq-controlroom/mu2e-krb-cron.py
../mu2edaq-controlroom-setup/README.md:46:`mu2edaq-controlroom/mu2e-krb-cron.py`) and a VNC client.
../mu2edaq-reverse-proxy/README.md:279:  `mu2edaq-controlroom/mu2e-krb-cron.py`
../mu2edaq-reverse-proxy/doc/OPERATIONS.md:27:   python3 mu2edaq-controlroom/mu2e-krb-cron.py
../mu2edaq-reverse-proxy/doc/API.md:198:  daemon, refresh with `mu2edaq-controlroom/mu2e-krb-cron.py` or a keytab.
../DAQ-ControlRoom-Instructions.md:63:python3 ../mu2edaq-controlroom/mu2e-krb-cron.py     # renews from keytabs
../DAQ-ControlRoom-Testing.md:208:`mu2edaq-controlroom/mu2e-krb-cron.py`), `klist -s` clean, and
$ grep -n -i 'cron\|unattended\|systemd' ../mu2edaq-kerberos/doc/OPERATIONS.md
(only a renew_interval row; no unattended recipe)
$ sed -n 110,117p ../mu2edaq-kerberos/doc/INTERFACES.md
mu2edaq-krb list [--json] | default | switch TYPE:name | renew TYPE:name|--all
... 2 NotSupportedError (e.g. renew on Apple ...)
```
Capability-by-capability table: `docs/ARCHITECTURE.md` § Deprecation.

## Why it matters
The seven references keep a superseded tool load-bearing, and the tool
they recommend destroys personal tickets (CR-002) and assumes keytabs on
disk (CR-003), the practice `mu2edaq-kerberos` was built to end. Leaving
the package in the release manifest keeps shipping it.

## Suggested fix
Retire in this order:
1. `mu2edaq-kerberos` documents an unattended mode: `mu2edaq-krb renew --all`
   from a cron or systemd timer on Linux, and a stated policy for
   re-acquisition after renew-until (Vault token lifetime or a machine
   credential). File that against `Mu2e/mu2edaq-kerberos`.
2. Repoint the seven references to `kinit` (personal) or
   `get-kerberos-ticket <identity>` (service).
3. Move `bin/list_issues_mu2e.sh`, `bin/list_pr_mu2e.sh`,
   `bin/clone_mu2e_repos.sh` and `bin/make-data-dirs.py` to a developer-tools
   repository, or drop them, by owner decision; `daq_env_tools.py` likewise.
4. Remove the submodule from `.gitmodules`, the superproject `README.md:51`
   and `testing/common.sh:31,120`; archive `Mu2e/mu2edaq-controlroom`.

If retirement is declined, the explicit statement of what the package is
still needed for is: unattended keytab renewal on hosts with no Vault
token, and the GitHub-organisation utilities. Nothing else.

## Related
- `mu2edaq-controlroom-setup` CRS-008 (`f73dfcd7`)

<!-- mega-review-fingerprint: b1867f6d -->

---

## CR-002 — [krb] mu2e-krb-cron.py destroys any default ticket outside its list, including the personal principal it maps the operator to, and maintains only the default cache

**Severity:** S3 — correctness or maintainability risk, no current outage
**Category:** bug
**Location:** `mu2e-krb-cron.py:341-350`
**Found by:** mega-review (`mu2e-sept-mega-review`), 2026-10-06

## What
Two defects in the decision logic.
(1) If the default cache's principal is not one of the six configured
service principals, the script runs `kdestroy` and re-acquires all six.
Every personal principal qualifies — including `anorman@FNAL.GOV`, which
the same embedded configuration's `user_principals` maps the OS user
`anorman` to and then tries to `kswitch` to (that fails, the cache having
just been destroyed).
(2) After the first run only the default cache is examined, so the other
five tickets are never renewed and lapse.

## Evidence
```
$ sed -n 341,350p mu2e-krb-cron.py
    if current_principal not in allowed_principals:
        logging.warning(
            "Current principal '%s' is not in the allowed list — destroying ticket.", ...
        run_kdestroy(args.dry_run)
        for p in principals:
            kinit_new(p["name"], p["keytab"], args.dry_run)
        set_active_principal(user_principals, args.dry_run)
        sys.exit(0)
$ sed -n 78,82p mu2e-krb-cron.py
user_principals:
  mu2edaq: "mu2edaq/mu2edaq/mu2e.fnal.gov@FNAL.GOV"
  mu2eshift: "mu2eshift/mu2edaq/mu2e.fnal.gov@FNAL.GOV"
  mu2eraw: "mu2eraw/mu2edaq/mu2e.fnal.gov@FNAL.GOV"
  anorman: "anorman@FNAL.GOV"
$ grep -n 'cc_default\|current_principal = ' mu2e-krb-cron.py
320:        cache = krb5.cc_default(ctx)
326:    current_principal = get_current_principal(ctx, cache)
$ klist --version; klist | grep -ci 'renew until'      # macOS
klist (Heimdal 1.5.1apple1)
0
```
On Heimdal the missing "renew until" line makes `renew_remaining` 0
(`:366`), so every renewal is a fresh keytab `kinit`.

## Why it matters
Installed as the README's 30-minute cron on an operator workstation, it
silently deletes the operator's own ticket after each `kinit`; ssh to the
DAQ as the personal user — `mu2edaq-controlroom-setup`'s tunnels — then
fails, and the cause is not visible. Torn between S2 and S3: S3 because
DAQ hosts running it as a service user (whose principal is in the list)
are unaffected, recovery is one `kinit`, and the package is being retired
(CR-001).

## Suggested fix
Do not fix in place; retire (CR-001). If it must keep running: never
`kdestroy` — select or create a per-principal cache in the collection
(`kinit -c` / `KRB5CCNAME=DIR:` or `KCM:`) for each configured principal,
iterate over all of them for renewal, and leave foreign caches alone.

## Related
- `mu2edaq-controlroom-setup` CRS-008 (`f73dfcd7`)

<!-- mega-review-fingerprint: 3acfaaa5 -->

---

## CR-003 — [krb] keytab locations are hard-coded to one user's macOS home with a master keytab of all six identities; GetTicket.sh is configured for DUNE

**Severity:** S3 — correctness or maintainability risk, no current outage
**Category:** bug
**Location:** `mu2e-krb-cron.py:63-74`
**Found by:** mega-review (`mu2e-sept-mega-review`), 2026-10-06

## What
Both Kerberos tools assume six service keytabs under
`/Users/anorman/Kerberos_Keytabs/Mu2e/`, and `ticket-manage.py` uses a
single `mu2e-all.keytab` holding all six keys for every `kinit`. Nothing
checks keytab owner or mode before `kinit -kt`. `bin/GetTicket.sh`, the
package's shell ticket getter, is configured for a DUNE identity.

## Evidence
```
$ sed -n 63,64p mu2e-krb-cron.py
  - name: "mu2edaq/mu2edaq/mu2e.fnal.gov@FNAL.GOV"
    keytab: "/Users/anorman/Kerberos_Keytabs/Mu2e/mu2edaq.keytab"
$ sed -n 16,24p kerb_princ.json | grep -E 'master|keypath'
    "keytab-master": "mu2e-all.keytab",
    "keypath": "/Users/anorman/Kerberos_Keytabs/Mu2e"
$ sed -n 220,223p ticket-manage.py
                keytab = theData["keytab"][k]
                keytab = theData["keytab-master"]
$ sed -n 6,8p bin/GetTicket.sh
pname="dune-controlroom-fnal/dune/dune-cr-01@FNAL.GOV"
keytab="dune-controlroom-fnal.keytab"
keytabpath="$HOME/.krb5"
$ git log --all --diff-filter=A --name-only --format= | grep -c '\.keytab$'
0
```

## Why it matters
The scripts work unmodified on exactly one laptop, and the design keeps
every DAQ service key on it, plus a combined keytab whose loss exposes all
six identities. No keytab was ever committed, so this is a design risk,
not a leak (S3, not S1). `mu2edaq-kerberos` exists to remove keytabs from
workstations.

## Suggested fix
Retire (CR-001). Until then: read keytab paths from a config file outside
the repository, refuse a keytab not owned by the caller or with group or
other permissions, drop `keytab-master`, and remove or re-target
`GetTicket.sh`.

<!-- mega-review-fingerprint: b48c31bd -->

---

## CR-004 — [env] daq_env_tools.py --capture writes the whole environment, credentials included, to stdout and a world-readable file; --restore cannot work

**Severity:** S3 — correctness or maintainability risk, no current outage
**Category:** bug
**Location:** `daq_env_tools.py:170-180`
**Found by:** mega-review (`mu2e-sept-mega-review`), 2026-10-06

## What
`--capture` prints every variable as `KEY: value` and writes the
environment as JSON with the process umask (normally `0644`). Tokens and
credential paths in the environment (`GH_TOKEN`, `VAULT_TOKEN`,
`KRB5CCNAME`, ...) go to the terminal, to any log the output is piped to,
and to a world-readable file. `--restore` loads the JSON into the
script's own `os.environ` and exits, which cannot change the caller's
environment. Five options (`-v`, `-d`, `-s`, `--config`, `-e`) are parsed
and ignored.

## Evidence
```
$ sed -n 170,180p daq_env_tools.py
    if args.capture:
        env = get_environment_variables()
        print("Environment Variables:")
        for key, value in env.items():
            print(f"{key}: {value}")
        store_environment_variables_json(args.output)
    if args.restore:
        restore_environment_variables_json(args.input)
$ sed -n 81,82p daq_env_tools.py
    with open(filename, 'w') as f:
        json.dump(env_vars, f, indent=4)
```

## Why it matters
The stated use is snapshotting a UPS/Muse setup on DAQ nodes, i.e. in
shells that also hold service credentials; the snapshot and the console
output both carry them. The restore half of the tool does nothing.

## Suggested fix
Retire with the package, or: open the output with `os.open(..., 0o600)`,
drop the stdout dump (or mask names matching `TOKEN|SECRET|PASS|KEY`),
make `--restore` emit `export` lines for `eval`, and remove the dead
options.

## Related
- Mu2e/mu2edaq-controlroom#5 (closed; module structure, different defect)

<!-- mega-review-fingerprint: 0215629f -->

---

## CR-005 — [vnc] start_vnc_tunnels_mu2e.sh fails under MIT Kerberos, opens n+1 tunnels and keeps control sockets in /tmp

**Severity:** S4 — cosmetic, stale, hygiene
**Category:** bug
**Location:** `bin/start_vnc_tunnels_mu2e.sh:50`
**Found by:** mega-review (`mu2e-sept-mega-review`), 2026-10-06

## What
`klist --test` is Heimdal syntax; MIT `klist` (AlmaLinux) rejects it, so
the script always reports "No Kerberos Ticket found" there. The zsh range
`{$start_port..$end_port}` with `end_port = start + n` is inclusive, so
`-n 5` opens six tunnels. Control sockets go to `/tmp`. The default
gateway `mu2edaq-gateway.fnal.gov` is not the `mu2egateway01.fnal.gov` the
current tools use, and `-k` exits 1 even on success.

## Evidence
```
$ sed -n 50,51p bin/start_vnc_tunnels_mu2e.sh
`klist --test`
ticket=$?
$ sed -n 37p bin/start_vnc_tunnels_mu2e.sh; sed -n 84p bin/start_vnc_tunnels_mu2e.sh
end_port=$((start_port + $numports))
for i in {$start_port..$end_port}
$ sed -n 87p bin/start_vnc_tunnels_mu2e.sh
    ssh -f -N -M -S /tmp/ssh-ctrl-${vnchost}-${i} -L ${i}:localhost:${i} -l $vncuser $vnchost
```

## Why it matters
Superseded by `crs-tunnel`, which fixes each of these (`~/.crs` sockets,
`klist -s`, configured sessions). Only someone still following the old
README is affected; S4.

## Suggested fix
None beyond retirement (CR-001).

<!-- mega-review-fingerprint: 991d68b7 -->

---

## CR-006 — [deps] kerb.py imports gssapi, which requirements.txt does not install

**Severity:** S4 — cosmetic, stale, hygiene
**Category:** bug
**Location:** `kerb.py:5`
**Found by:** mega-review (`mu2e-sept-mega-review`), 2026-10-06

## What
`kerb.py` imports `gssapi` and never uses it; `requirements.txt` lists only
`krb5` and `pyyaml`, so in the venv `bootstrap.sh` builds the script dies
at import.

## Evidence
```
$ sed -n 5p kerb.py
import gssapi
$ grep -c gssapi kerb.py requirements.txt
kerb.py:1
requirements.txt:0
```

## Why it matters
A diagnostic that fails in the supported environment; superseded by
`krb-caches`. S4.

## Suggested fix
Delete the import, or retire (CR-001).

<!-- mega-review-fingerprint: 7a849feb -->

---

## CR-007 — [man] man pages were flat, misnamed and described behaviour the scripts do not have

**Severity:** S4 — cosmetic, stale, hygiene
**Category:** documentation
**Location:** `man/man1/`
**Found by:** mega-review (`mu2e-sept-mega-review`), 2026-10-06

## What
Before this review the ten pages sat in a flat `man/`, used names unlike
the commands (`start-vnc-tunnels-mu2e.1` for `start_vnc_tunnels_mu2e.sh`),
non-ISO dates ("April 2026"), and described behaviour the scripts lack:
`GetTicket.1` gave a Mu2e principal example for a DUNE-configured script,
`make-data-dirs.1` and the README named `make-data-dirs.sh` and
`daq-env-tools.py`, which no longer exist.

## Evidence
```
$ git ls-tree --name-only 076de7a man/
man/GetTicket.1 man/clone-mu2e-repos.1 man/daq-env-tools.1 man/kerb.1 ...
$ git show 076de7a:man/make-data-dirs.1 | sed -n 5p
.B make\-data\-dirs.sh
```

## Why it matters
Fixed in the mega-review commits (`git mv` into `man/man1/`, rewrite,
README man table); recorded so the fingerprint exists if it regresses.

## Suggested fix
None beyond the review commits.

<!-- mega-review-fingerprint: dfced355 -->

---

## CR-008 — [repo] Mu2eCR/ is a vendored NOvA CVS checkout, CVS metadata included, used by nothing

**Severity:** S4 — cosmetic, stale, hygiene
**Category:** enhancement
**Location:** `Mu2eCR/`
**Found by:** mega-review (`mu2e-sept-mega-review`), 2026-10-06

## What
82 tracked files from NOvA's `Online/pkgs/NovaRemoteControlRooms`
(`novacvs@cdcvs.fnal.gov:/cvs/nova`), 36 of them `CVS/` bookkeeping, with
NOvA hosts (`novadaq-far-master-02`, `novadaq-near-mgr-02`, ...) and
desktop launchers for FarDet/NearDet/TestBeam. Nothing in the suite runs
them; `mu2edaq-controlroom-setup/viewer.py:3-5` cites `Tools.py` as the
pattern it followed.

## Evidence
```
$ cat Mu2eCR/ControlRoom/CVS/Root
novacvs@cdcvs.fnal.gov:/cvs/nova
$ git ls-files Mu2eCR | wc -l; git ls-files Mu2eCR | grep -c /CVS/
82
36
```

## Why it matters
Dead code in a Mu2e release; readers mistake NOvA host maps for Mu2e
configuration.

## Suggested fix
Remove with the package (CR-001); if the package stays, drop `Mu2eCR/` or
keep only a pointer to the NOvA source.

<!-- mega-review-fingerprint: 3aca7540 -->
