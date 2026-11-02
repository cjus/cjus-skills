# remote-build: GPU launch profiles

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/123

## Changes

- **GPU profiles.** `prepare` already reads each type with `describe-instance-types`, and now
  also reads its GPUs.
  - A profile whose types all have NVIDIA GPUs is a GPU profile. `plan` shows each type's GPUs.
  - A profile that mixes GPU and CPU types is refused, because the image is baked on the first
    type and a repository may launch any of them. So is another GPU maker.
- **Driver.**
  - Bootstrap passes `GPU=nvidia` (empty for other profiles) to the provisioning script.
  - The bundled `provision.sh` installs the headless server driver (`ubuntu-drivers install
    --gpgpu`) and the matching `nvidia-utils`, unless the base image's driver already works.
  - It also installs `python3-venv` on every image, because `builder` has no sudo and Ubuntu's
    Python refuses pip outside a virtual environment.
- **Bake check.**
  - For a GPU profile, the bake reboots the build machine and waits for a new boot ID as
    `builder`. It then runs `nvidia-smi --query-gpu=name,memory.total,driver_version` as
    `builder`.
  - A failure fails the bake and cleans up as before.
  - The image is tagged `remote-build:gpu` with what `nvidia-smi` reported. `setup` shows it in
    the profile's check, and the apply summary shows it per profile.
- **Per-profile settings.**
  - `--disk-gb` and `--provision-script` take a plain value (every profile) or `NAME=VALUE` (one
    profile). The new `--base-image NAME=AMI|SSM-PARAMETER` takes only `NAME=VALUE`.
  - `NAME=default` drops a setting. Settings are remembered in bootstrap state as `overrides`,
    and are forgotten when their profile is dropped.
  - Provisioning scripts are stored as absolute paths.
- **Base images.** `plan` checks a base image before anything changes: it must resolve to an
  AMI that exists, match the profile's architecture, boot from EBS, and have a root volume no
  bigger than the profile's disk. The bake then starts from it.
- **Rebuilds.**
  - A profile's image is rebuilt when anything it was built from changes: architecture, disk,
    base image, its own script, or GPU kind.
  - State from earlier versions has none of the new keys, which reads as the defaults, so
    upgrading rebuilds nothing.
  - The exception is a profile of GPU types, which an earlier version baked without a driver.
- **Summaries.** `plan` and `apply` list `disk_gb`, `base_image`, `provision_script` and `gpu`
  per profile.
- **Docs:**
  - the operator guide gains a GPU profiles section (quota, cost of GPU bakes and janitor tests,
    empty sessions, `ttl_minutes`, the CUDA toolkit) and rows in the summary, re-run and
    Make it yours tables
  - troubleshooting gains five rows
  - the setup skill says a repository that needs GPUs needs a GPU profile, never a CPU one just
    to pass `setup`
  - the README mentions GPU profiles
- **Tests:**
  - nine bootstrap tests:
    - plan shows a GPU profile's GPUs, disk and base
    - mixed profiles and other makers are refused
    - a GPU bake reboots, checks `nvidia-smi` and tags the image, and `setup` shows the tag
    - a GPU that `builder` can't use fails the bake, cleans up, and a re-run recovers
    - a reboot that never returns fails the bake
    - per-profile settings are remembered, rebuild only their profile, and `NAME=default` drops
      them
    - bad per-profile flags are refused before any change
    - an upgrade rebuilds only a driverless GPU image
    - the bundled script parses
  - The simulated cloud gains GPU types, SSM parameters, base images, reboots, boot IDs and
    `nvidia-smi`.
  - Mutation checks: each of 16 mutations fails a test. They cover no reboot, no boot-ID
    change, mixed profiles allowed, other makers allowed, no GPU input, a fixed disk, the base
    ignored, no `default` reset, overrides kept for dropped profiles, no GPU tag, no
    base-image size or architecture check, unknown profile names accepted, an unnamed
    `--base-image` accepted, no GPU in `setup`, and GPU missing from `BUILT_FROM`.
- **Live read-only check** against a real account with `plan`:
  - GPU detection from real `describe-instance-types` data
  - the existing CPU image reused, with no changes on a plain re-run
  - a mixed profile refused
  - AWS's GPU base image resolved from its SSM parameter, refused on a 40 GB disk (it needs
    75 GB), and accepted on 150 GB
  - The driver install and `nvidia-smi` check run only on a real GPU bake, which `apply` does.
- Version 0.7.0.
