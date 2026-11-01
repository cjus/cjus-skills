# Configuration

Put `config.json` in `$XDG_CONFIG_HOME/remote-build/`, otherwise
`~/.config/remote-build/`. Use `--config <file>` before the subcommand to override it.
State defaults to `$XDG_STATE_HOME/remote-build/`, otherwise
`~/.local/state/remote-build/`; `--state <directory>` overrides it. Both must remain outside
the installed plugin and source project. Keep them private, not in version control.
Use one state directory and one stable owner per operator; do not create extra state roots
to evade the session guard. JSON contains these exact fields, with no extra fields:

| Field | Value |
|---|---|
| `version` / `provider` | `1` / `"aws"` |
| `profile` / `region` | Existing local AWS profile and target region |
| `owner` | Stable nonsecret namespace, letters/digits/dot/underscore/hyphen |
| `launch_template` | Existing launch template ID supplied by the operator |
| `launch_version` | Pinned positive numeric version **as a string**, never `$Latest` |
| `instance_type` | Explicit selected type |
| `allowed_instance_types` | Operator-approved list containing the selected type |
| `ttl_minutes` | Integer 1–480; cost approval covers this lifetime |
| `janitor_confirmed` | `true` only after an operator verifies independent expiry cleanup |
| `ssh_user` | Existing unprivileged Linux build user |
| `known_hosts` | Absolute path to a regular file containing authenticated host keys/CA entries |
| `identity_file` | Absolute path to an existing private SSH identity; never its contents |
| `address_field` | `"PrivateIpAddress"` or `"PublicIpAddress"` |
| `max_snapshot_bytes` | Integer 1–33554432, including tar overhead |
| `max_jobs` | Integer 1–20 per worker session |
| `cache_retention` | `"session"`; retained volumes are unsupported |

No real infrastructure identifiers are supplied in this repository. Have the operator fill
these values locally, and restrict the config to mode 0600. The CLI validates configuration;
it does not create or repair infrastructure. `setup` checks tool execution, AWS authentication,
the pinned template, and deletion policy inherited from the AMI plus template overrides.
It prints only a safe subset, not account identity or private key paths.

Keep config unchanged during an active session: its hash is bound into state. Restore the
original config/profile to recover or tear down a worker. Host keys can be added to the
existing known-hosts file without changing its configured path.

## Complete example

This is a complete **template**, not ready-to-launch infrastructure. Replace the two angle-
bracket values with the operator's approved launch template and instance type. Adjust profile,
region and SSH user to that existing infrastructure. Both instance-type fields must agree.
No account ID, credential, network ID or private key material belongs in this file.

```json
{
  "version": 1,
  "provider": "aws",
  "profile": "remote-build",
  "region": "us-east-1",
  "owner": "pr-worker",
  "launch_template": "<operator-supplied-launch-template-id>",
  "launch_version": "1",
  "instance_type": "<approved-instance-type>",
  "allowed_instance_types": ["<approved-instance-type>"],
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

The profile must already authenticate locally; `builder` must already exist on the image;
private IP routing must already work; the SSH files must already exist. Tilde expansion is
supported for those two file paths. The numeric template version must be the operator's actual
approved version. `janitor_confirmed: true` is an operator declaration, not an installer switch:
set it only after independently verifying the expiry service described in [AWS](aws.md).
Leaving a placeholder or false declaration in place is supposed to fail setup.

Save the substituted JSON outside the project at the default configuration path, then:

```sh
chmod 600 "${XDG_CONFIG_HOME:-$HOME/.config}/remote-build/config.json"
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/remote_build.py" setup
```

For a custom configuration or state directory, global options precede the command:

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/remote_build.py" --config "$CONFIG_FILE" --state "$STATE_DIR" setup
```

Use the same paths throughout the session. `$CONFIG_FILE` and `$STATE_DIR` are operator-chosen
private absolute paths outside both the plugin and project, not values to commit to a repo.

## Selecting or changing the EC2 type

`instance_type` is the **explicit** choice for the next worker. The CLI passes it to
RunInstances, overriding any type default in the pinned launch template.
`allowed_instance_types` is the operator's local allowlist; the selected value must be in it.
There is no autosizing, benchmark-based selection, silent upgrade, fallback type, or live
price ceiling. A type on the allowlist can still be expensive.

The operator chooses a type based on the workload's measured CPU/RAM needs and an approved
budget. Confirm the type is available in the configured region and compatible with the
launch template's AMI architecture (for example, x86_64 versus arm64), image/toolchain, network
and storage requirements. The CLI does not validate CPU/RAM sizing or architecture compatibility
in advance; a successful config check does not prove that AWS can launch the combination.
Use the operator's normal AWS catalog/instance-type and AMI inspection tools for those checks,
and review current prices separately before authorizing launch.

To change the type, collect required results and explicitly terminate the current session,
then verify termination with `down`. Edit the private config's `instance_type` and, if newly
approved, its allowlist. Use a new approved numeric launch-template version when the new type
needs a different AMI architecture or other infrastructure. Run setup again and obtain launch
authorization for the new type and lifetime before the next up. There is no in-place resize
command. Changing config while a session is active is rejected because its hash is bound to
that session; restore the original config to recover or tear it down.
