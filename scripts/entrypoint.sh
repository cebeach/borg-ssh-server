#!/bin/bash

# This is the container entrypoint script.
#
# Here we set the borg user UID and GID according to the UID and GID of the bind mapped file
# /home/borg/.ssh/authorized_keys; this helps us avoid 'baking in' UID and GID for the borg
# account at image build time.
#
# We do this because, for good reason, sshd will refuse an authorized_keys file if it is
# writeable by anybody other than the account being authenticated, as explained in the
# sshd man page:
#
# ~/.ssh/authorized_keys
#    Lists the public keys (DSA, ECDSA, Ed25519, RSA) that can be used for logging in as this user.
#    The format of this file is described above.  The content of the file is not highly sensitive,
#    but the recommended permissions are read/write for the user, and not accessible by others.
#    If this file, the ~/.ssh directory, or the user's home directory are writable by other users,
#    then the file could be modified or replaced by unauthorized users. In this case, sshd will not
#    allow it to be used unless the StrictModes option has been set to 'no'.

set -euo pipefail

AUTH_KEYS="${AUTH_KEYS:-/home/borg/.ssh/authorized_keys}"
USER=borg
GROUP=borg

if [[ ! -f "$AUTH_KEYS" ]]; then
  echo "ERROR: $AUTH_KEYS not found (bind mount it from host)" >&2
  exit 1
fi

# Insepect UID and GID of the authorized_keys file
target_uid="$(stat -c '%u' "$AUTH_KEYS")"
target_gid="$(stat -c '%g' "$AUTH_KEYS")"

old_uid="$(id -u "$USER")"
old_gid="$(id -g "$USER")"

# ensure group with target_gid exists, and borg uses it
if [[ "$target_gid" != "$old_gid" ]]; then
  if getent group "$target_gid" >/dev/null; then
    # Reuse existing group with that GID
    usermod -g "$target_gid" "$USER"
  else
    # Move borg group to that GID
    groupmod -g "$target_gid" "$GROUP"
  fi
fi

# ensure target_uid is free, then move borg to it
if [[ "$target_uid" != "$old_uid" ]]; then
  if getent passwd "$target_uid" >/dev/null; then
    echo "ERROR: UID $target_uid already exists in container; can't remap $USER" >&2
    exit 1
  fi
  usermod -u "$target_uid" "$USER"
fi

# sshd is picky; enforce perms inside the container
# Note: chmod on bind mount will change host perms. Decide if you want that.
# If you want to avoid changing host perms, just warn instead of chmod.
if [[ "$(stat -c '%a' "$AUTH_KEYS")" -gt 600 ]]; then
  echo "WARN: $AUTH_KEYS permissions are too open for sshd; fix on host (suggest 600)" >&2
fi

# Run sshd in as PID 1 with logging to stderr; run the following to tail sshd log:
# $ docker logs --tail 100 -f borgbackup-server
exec /usr/sbin/sshd -D -e

