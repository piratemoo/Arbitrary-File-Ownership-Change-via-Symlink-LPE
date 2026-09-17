## Arbitrary File Ownership Change via Symlink in dell-xps-touchpad-haptics (LPE)

**dell-xps-touchpad-haptics 1.0.0-3, Omarchy 4.0.4**<br>
Severity: High  
CVSS 3.1 Base Score: 7.8 (Local/Low Complexity/No Privileges Required)<br><br>
•	Improper Link Resolution Before File Access (CWE-59) <br>
•	**TOCTOU** (Time-of-check Time-of-use) Race Condition (CWE-367)<br>

## Summary
The ALPM install script for dell-xps-touchpad-haptics performs privileged chown operations on `~/.config/omarchy/dell-haptic.conf` and before changing ownership, checks the path using `-f` and the subsequent chown symbolic links. An unprivileged local user can replace `dell-haptic.conf` with a symbolic link to a root-owned file like `/etc/passwd` and on the next package install/upgrade, the script executes as root, follows the symbolic link and changes file ownership to the selected user. 

**Impact:** An attacker can gain write access to a root-owned file and when /etc/passwd is targeted, can modify system account data (including uid 0 accounts), resulting in a local privilege escalation without needing to invoke a package manager to do so. 

## Details
ALPM install scripts execute with root privileges during package installs/upgrades, identifies a user, derives a config path in the writable home directory and invokes `_ensure_user_config` from `post_install` and `post_upgrade`. In the script, `_ensure_user_config` checks `~/.config/omarchy/dell-haptic.conf` and applies chown to it. Because symbolic links aren't rejected, an attacker can retain control over what is referenced by that path. 

An attacker can create `~/.config/omarchy/dell-haptic.conf` -> `/etc/passwd` without elevated privileges so that when a package install/upgrade executes the script as root, chown follows the symlink on `/etc/passwd` instead of the intended config file, transferring ownership.

The affected code in the ALPM `post_install` and `post_upgrade` hooks:

```bash
_ensure_user_config() {
  local user=$1
  local home=$2
  local config_dir="$home/.config/omarchy"
  local config_path="$config_dir/dell-haptic.conf"

  if [[ ! -f $config_path ]] && ! env HOME="$home" USER="$user" LOGNAME="$user" \
    /usr/bin/dell-xps-touchpad-haptics set "$_default_level"; then
    echo ":: Failed to create ${config_path} for user '$user'." >&2
    return 1
  fi

  if [[ -f $config_path ]]; then
    chown "$user:$user" "$home/.config" 2>/dev/null || true
    chown "$user:$user" "$config_dir" 2>/dev/null || true
    chown "$user:$user" "$config_path" 2>/dev/null || true
  fi
}
```
The helper is reachable from both hooks:

```bash
post_install() {
  _configure_package
}

post_upgrade() {
  _configure_package
}
```

## PoC
1. A user with uid 1000 creates the symbolic link without sudo
2. /etc/passwd is owned by root:root and the affected package is reinstalled, causing the script to execute as root
3. Ownership of /etc/passwd changes from uid 0 to uid 1000 and the attacker modifies the user-owned account resulting in uid 0 (root)



