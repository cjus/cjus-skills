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
