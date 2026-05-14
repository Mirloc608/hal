#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
NODES=(
  "hal@ai-srv"
  "hal@ai-srv-node1"
  "hal@ai-srv-node2"
)

echo "=== HAL CLUSTER SSH TRUST BOOTSTRAP ==="

# --- Function: ensure SSH key exists locally ---
ensure_local_key() {
  if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "[LOCAL] No SSH key found — generating one..."
    ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -N "" -f "$HOME/.ssh/id_ed25519"
  else
    echo "[LOCAL] SSH key already exists."
  fi
}

# --- Function: enable password auth on remote temporarily ---
enable_password_auth() {
  local host="$1"
  echo "[${host}] Enabling temporary password authentication..."

  ssh -t "$host" '
    echo -n "Enter sudo password: "
    read -s pw
    echo
    echo "$pw" | sudo -S sed -i \
      -e "s/^#PasswordAuthentication.*/PasswordAuthentication yes/" \
      -e "s/^PasswordAuthentication no/PasswordAuthentication yes/" \
      -e "s/^KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/" \
      /etc/ssh/sshd_config
    echo "$pw" | sudo -S systemctl restart ssh
  '
}

# --- Function: install our public key on remote ---
install_key() {
  local host="$1"
  echo "[${host}] Installing SSH key..."

  ssh-copy-id "$host" || {
    echo "[${host}] ssh-copy-id failed — trying manual install..."
    cat "$HOME/.ssh/id_ed25519.pub" | ssh "$host" \
      "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
  }
}

# --- Function: disable password auth again ---
disable_password_auth() {
  local host="$1"
  echo "[${host}] Re-locking SSH (password auth off)..."

  ssh -t "$host" '
    echo -n "Enter sudo password: "
    read -s pw
    echo
    echo "$pw" | sudo -S sed -i \
      -e "s/^PasswordAuthentication yes/PasswordAuthentication no/" \
      -e "s/^KbdInteractiveAuthentication yes/KbdInteractiveAuthentication no/" \
      /etc/ssh/sshd_config
    echo "$pw" | sudo -S systemctl restart ssh
  '
}

# --- Function: test SSH connectivity ---
test_ssh() {
  local from="$1"
  local to="$2"

  echo -n "[TEST] $from → $to: "
  ssh -o BatchMode=yes -o ConnectTimeout=3 "$from" "ssh -o BatchMode=yes -o ConnectTimeout=3 $to hostname" 2>/dev/null \
    && echo "OK" \
    || echo "FAIL"
}

# === MAIN ===

ensure_local_key

echo
echo "=== STEP 1: Enable temporary password auth on all nodes ==="
for node in "${NODES[@]}"; do
  enable_password_auth "$node"
done

echo
echo "=== STEP 2: Install SSH keys on all nodes ==="
for node in "${NODES[@]}"; do
  install_key "$node"
done

echo
echo "=== STEP 3: Re-lock SSH on all nodes ==="
for node in "${NODES[@]}"; do
  disable_password_auth "$node"
done

echo
echo "=== STEP 4: Build full trust mesh ==="
for src in "${NODES[@]}"; do
  for dst in "${NODES[@]}"; do
    test_ssh "$src" "$dst"
  done
done

echo
echo "=== SSH TRUST BOOTSTRAP COMPLETE ==="
