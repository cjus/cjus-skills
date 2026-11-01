# Configuration

Configuration has two parts:

- **Private operator config** (one per operator): AWS account access, SSH identity, limits and
  the named **launch profiles** each repository may choose from. Never committed.
- **Repository selection** (one per repository): `.remote-build.json` at the Git root, naming
  a launch profile and an instance type. Committed with the project.

## Private operator config

Put `config.json` in `$XDG_CONFIG_HOME/remote-build/`, otherwise
`~/.config/remote-build/`. Use `--config <file>` before the subcommand to override it.
State defaults to `$XDG_STATE_HOME/remote-build/`, otherwise
`~/.local/state/remote-build/`; `--state <directory>` overrides it. Each project gets its own
subdirectory, `projects/<key>/`, under that state root. Both must remain outside the installed
plugin and every source project. Keep them private, not in version control.
Use one state root and one stable owner per operator; do not create extra state roots
to evade the session or worker guards. JSON contains these exact fields, with no extra fields:

| Field | Value |
|---|---|
| `version` / `provider` | `2` / `"aws"` |
| `profile` / `region` | Existing local AWS profile and target region |
| `owner` | Stable nonsecret namespace, letters/digits/dot/underscore/hyphen |
| `launch_profiles` | Named profiles; see below. At least one |
| `max_workers` | Integer 1–10: concurrent workers across all repositories for this owner |
| `ttl_minutes` | Integer 1–480; cost approval covers this lifetime |
| `janitor_confirmed` | `true` only after an operator verifies independent expiry cleanup |
| `ssh_user` | Existing unprivileged Linux build user, present on every profile's image |
| `known_hosts` | Absolute path to a regular file containing authenticated host keys/CA entries |
| `identity_file` | Absolute path to an existing private SSH identity; never its contents |
| `address_field` | `"PrivateIpAddress"` or `"PublicIpAddress"` |
| `max_snapshot_bytes` | Integer 1–33554432, including tar overhead |
| `max_jobs` | Integer 1–20 per worker session |
| `cache_retention` | `"session"`; retained volumes are unsupported |

Each launch profile is keyed by a name (letters/digits/dot/underscore/hyphen) and has exactly:

| Field | Value |
|---|---|
| `launch_template` | Existing launch template ID supplied by the operator |
| `launch_version` | Pinned positive numeric version **as a string**, never `$Latest` |
| `instance_types` | Operator-approved instance types for this template's AMI |

Use one profile per AMI architecture or image (for example, `x86` and `arm`), so a repository
can only pair a type with an image it can boot.

No real infrastructure identifiers are supplied in this repository. Have the operator fill
these values locally, and restrict the config to mode 0600. The CLI validates configuration;
it does not create or repair infrastructure. `setup` checks tool execution, AWS authentication,
and the pinned template plus deletion policy inherited from the AMI and template overrides:
for the current repository's profile when run inside a checkout with `.remote-build.json`,
otherwise for every profile. It prints only a safe subset, not account identity or private key
paths.

A session binds the shared settings plus its own repository's selected profile and type. Add
or edit other profiles, or change `max_workers`, at any time. Keep this repository's profile
and selection unchanged during its session; restore them to recover or tear it down. Host keys
can be added to the existing known-hosts file without changing its configured path.

Version 1 configs (a single `launch_template`, `launch_version`, `instance_type` and
`allowed_instance_types`) are refused. To migrate, move those values into one launch profile,
add `max_workers`, set `version` to 2, and add `.remote-build.json` to each repository. Tear
down any v1 session first; v1 state is not read by v2.

### Complete example

This is a complete **template**, not ready-to-launch infrastructure. Replace the angle-bracket
values with the operator's approved launch templates and instance types. Adjust profile,
region and SSH user to that existing infrastructure. No account ID, credential, network ID or
private key material belongs in this file.

```json
{
  "version": 2,
  "provider": "aws",
  "profile": "remote-build",
  "region": "us-east-1",
  "owner": "pr-worker",
  "launch_profiles": {
    "x86": {
      "launch_template": "<operator-supplied-x86-launch-template-id>",
      "launch_version": "1",
      "instance_types": ["<approved-x86-type>", "<larger-approved-x86-type>"]
    },
    "arm": {
      "launch_template": "<operator-supplied-arm64-launch-template-id>",
      "launch_version": "1",
      "instance_types": ["<approved-arm64-type>"]
    }
  },
  "max_workers": 2,
  "ttl_minutes": 120,
  "janitor_confirmed": true,
  "ssh_user": "builder",
  "known_hosts": "~/.ssh/remote-build-known-hosts",
  "identity_file": "~/.ssh/remote-build-identity",
  "address_field": "PrivateIpAddress",
  "max_snapshot_bytes": 33554432,
  "max_jobs": 20,
  "cache_retention": "session"
}
```

The profile must already authenticate locally; `builder` must already exist on every image;
private IP routing must already work; the SSH files must already exist. Tilde expansion is
supported for those two file paths. Each numeric template version must be the operator's
actual approved version. `janitor_confirmed: true` is an operator declaration, not an installer
switch: set it only after independently verifying the expiry service described in [AWS](aws.md).
Leaving a placeholder or false declaration in place is supposed to fail setup.

Save the substituted JSON outside every project at the default configuration path, then:

```sh
chmod 600 "${XDG_CONFIG_HOME:-$HOME/.config}/remote-build/config.json"
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/remote_build.py" setup
```

For a custom configuration, state root or checkout, global options precede the command:

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/remote_build.py" --config "$CONFIG_FILE" --state "$STATE_DIR" --project "$CHECKOUT" setup
```

Use the same paths throughout the session. `$CONFIG_FILE` and `$STATE_DIR` are operator-chosen
private absolute paths outside both the plugin and every project, not values to commit to a repo.

## Repository selection

Commit `.remote-build.json` at the repository's Git root, with exactly these fields:

```json
{ "version": 1, "launch_profile": "x86", "instance_type": "<approved-x86-type>" }
```

| Field | Value |
|---|---|
| `version` | `1` |
| `launch_profile` | A profile name defined in the private config |
| `instance_type` | A type on that profile's `instance_types` list |

Every command except `setup` needs this file in the selected checkout (`--project`, default the
current directory). A profile the private config does not define, or a type that profile does
not list, is refused before any AWS call. The file contains only names, never identifiers or
credentials, and is uploaded with the source like any other file.

The file selects; it never authorizes. Before a launch, the agent states the repository's
profile, instance type and lifetime and gets explicit cost approval for them. Because the file
is project text, an operator should keep expensive types off profiles that untrusted
repositories might name.

## Selecting or changing the EC2 type

The repository's `instance_type` is the **explicit** choice for that repository's next worker.
The CLI passes it to RunInstances with its profile's pinned template, overriding any type
default in the template. The profile's `instance_types` list is the operator's allowlist.
There is no autosizing, benchmark-based selection, silent upgrade, fallback type, or live
price ceiling. A type on an allowlist can still be expensive.

Choose a type based on the workload's measured CPU/RAM needs and an approved budget. Confirm
the type is available in the configured region and compatible with its profile's AMI
architecture (for example, x86_64 versus arm64), image/toolchain, network and storage
requirements. The CLI does not validate CPU/RAM sizing or architecture compatibility in
advance; a successful config check does not prove that AWS can launch the combination. Use the
operator's normal AWS catalog/instance-type and AMI inspection tools for those checks, and
review current prices separately before authorizing launch.

To change a repository's type, collect required results and explicitly terminate its session,
then verify termination with `down`. Edit and commit `.remote-build.json`; if the type is new,
the operator first adds it to the profile's list (or adds a profile with a new pinned template
when the type needs a different AMI architecture). Run setup again and obtain launch
authorization for the new type and lifetime before the next up. There is no in-place resize
command. Changing the selection while that repository's session is active is rejected; restore
it to recover or tear the session down.
