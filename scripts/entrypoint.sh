#!/bin/bash

# This is the borg-ssh-server container entrypoint script; our objective is to avoid including
# secrets in the image. Not only do we require the BorgBackup repository root directory to be
# a bind mount, but we also require the ssh host keys and authorized_keys files to be bind mounts.
#
# 1. Verify that required bind mounts exist with proper permissions:
#    Path                               Expected Permissions
#    ---------------------------------  --------------------
#    /repos                                    700
#    /etc/ssh/ssh_host_ed25519_key             600
#    /etc/ssh/ssh_host_ed25519_key.pub         644
#    /home/borg/.ssh/authorized_keys           600
#
# 2. Adjust borg user UID and GID to match /home/borg/.ssh/authorized_keys so long as they are within
#    Debian Policy Manual recommended ranges for UID and GID. We do this because sshd will refuse
#    authorized_keys if it is writeable by anybody other than the account being authenticated.
#
# Why don't we validate host keys ownership?
# Because sshd runs as root and can read any file regardless of ownership. What matters for the
# host keys is that their **permissions** are correct (private key `600`, public key `644`),
# which we do validate. The owner UID/GID is irrelevant to sshd's ability to use them.
#
# References:
# https://docs.docker.com/engine/storage/bind-mounts/
# https://www.debian.org/doc/debian-policy/ch-opersys.html#users-and-groups
# https://manpages.debian.org/bookworm/openssh-server/sshd.8.en.html

set -euo pipefail

# Required bind mounts
AUTHORIZED_KEYS=/home/borg/.ssh/authorized_keys
HOST_PRIVATE_KEY=/etc/ssh/ssh_host_ed25519_key
HOST_PUBLIC_KEY=/etc/ssh/ssh_host_ed25519_key.pub

# Debian Policy Manual recommended ranges for UID and GID
# Note that we let GID span down to 100 for compatibility with Synology diskstation
MIN_UID=1000
MAX_UID=59999
MIN_GID=100
MAX_GID=59999

# Write all messages to stderr for capture by docker logs
log_info() {
    echo "INFO: $*" >&2
}

log_error() {
    echo "ERROR: $*" >&2
}


# Identify bind mounts from /proc/self/mountinfo (see proc(5) for format).
# A bind mount has a non-"/" root (field 4), distinguishing it from the container's
# own root overlay. We exclude virtual filesystems and Docker's automatic mounts
# (/, /etc/resolv.conf, /etc/hostname, /etc/hosts, /etc/localtime) to isolate
# user-specified mounts.
bind_mounts=$(awk '
    $0 !~ /- (proc|sysfs|tmpfs|devpts|devtmpfs|cgroup|mqueue) / && $4 != "/" &&
    $5 != "/" && $5 != "/etc/resolv.conf" && $5 != "/etc/hostname" && $5 != "/etc/hosts" &&
    $5 != "/etc/localtime" {
        print $5
    }
' /proc/self/mountinfo 2>/dev/null || true)

log_info "Bind mounts:"
while IFS= read -r line; do
    # skip empty lines
    [[ -n "$line" ]] && log_info "  $line"
done <<< "$bind_mounts"

errors=()
for path in /repos /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.pub /home/borg/.ssh/authorized_keys
do
    if echo "$bind_mounts" | grep -qx "$path"
    then
        log_info "$path is a bind mount"
    else
        error="$path is not a bind mount; please bind mount from host"
        log_error "$error"
        errors+=("$error")
    fi
done

if [[ ${#errors[@]} -ne 0 ]]
then
    exit 1
fi


# Validate /repos directory
if [[ ! -d /repos ]]; then
    log_error "/repos is not a directory or doesn't exist"
    exit 1
fi

if [[ "$(stat -c '%a' /repos)" != "700" ]]; then
    log_error "/repos permissions are not 700"
    exit 1
fi


# Validate file existence
for file in "$AUTHORIZED_KEYS" "$HOST_PRIVATE_KEY" "$HOST_PUBLIC_KEY"
do
    if [[ -f "$file" ]]
    then
        log_info "$file found"
    else
        error="$file is not a regular file"
        log_error "$error"
        errors+=("$error")
    fi
done

if [[ ${#errors[@]} -ne 0 ]]
then
    exit 1
fi


# Validate file permissions
if [[ "$(stat -c '%a' "$AUTHORIZED_KEYS")" != "600" ]]
then
    error="$AUTHORIZED_KEYS permissions != 600"
    log_error "$error"
    errors+=("$error")
fi

if [[ "$(stat -c '%a' "$HOST_PRIVATE_KEY")" != "600" ]]
then
    error="$HOST_PRIVATE_KEY permissions != 600"
    log_error "$error"
    errors+=("$error")
fi

if [[ "$(stat -c '%a' "$HOST_PUBLIC_KEY")" != "644" ]]
then
    error="$HOST_PUBLIC_KEY permissions != 644"
    log_error "$error"
    errors+=("$error")
fi

if [[ ${#errors[@]} -ne 0 ]]
then
    exit 1
fi


# Inspect UID and GID of the authorized_keys file
authkeys_uid="$(stat -c '%u' "$AUTHORIZED_KEYS")"
authkeys_gid="$(stat -c '%g' "$AUTHORIZED_KEYS")"

log_info "$AUTHORIZED_KEYS has UID=$authkeys_uid GID=$authkeys_gid"

# Validate UID is within acceptable range
if [[ $authkeys_uid -lt $MIN_UID ]]; then
    log_error "$AUTHORIZED_KEYS UID $authkeys_uid is less than minimum allowed value of $MIN_UID"
    log_error "UIDs below $MIN_UID are reserved for system accounts per Debian Policy"
    exit 1
fi

if [[ $authkeys_uid -gt $MAX_UID ]]; then
    log_error "$AUTHORIZED_KEYS UID $authkeys_uid is greater than maximum allowed value of $MAX_UID"
    log_error "UIDs above $MAX_UID are in reserved ranges per Debian Policy"
    exit 1
fi

# Validate GID is within acceptable range
if [[ $authkeys_gid -lt $MIN_GID ]]; then
    log_error "$AUTHORIZED_KEYS GID $authkeys_gid is less than minimum allowed value of $MIN_GID"
    log_error "GIDs below $MIN_GID are reserved for system groups per Debian Policy"
    exit 1
fi

if [[ $authkeys_gid -gt $MAX_GID ]]; then
    log_error "$AUTHORIZED_KEYS GID $authkeys_gid is greater than maximum allowed value of $MAX_GID"
    log_error "GIDs above $MAX_GID are in reserved ranges per Debian Policy"
    exit 1
fi

# Coerce UID and GID of the borg user account if necessary
borg_uid="$(id -u borg)"
borg_gid="$(id -g borg)"

log_info "container borg user UID=$borg_uid, borg group GID=$borg_gid"

if [[ "$authkeys_gid" -eq "$borg_gid" ]]
then
    log_info "user borg GID=$borg_gid matches $AUTHORIZED_KEYS GID, no GID change necessary"
else
    # Does a group with id $authkeys_gid already exist?
    if getent group "$authkeys_gid" >/dev/null
    then
        # Change borg user's primary group to match
        usermod -g "$authkeys_gid" borg
        log_info "borg user primary group id changed to $authkeys_gid"
    else
        # Change borg group id to match
        groupmod -g "$authkeys_gid" borg
        log_info "borg group reassigned GID=$authkeys_gid"
    fi
fi

# Ensure authkeys_uid is free, then move borg to it
if [[ "$authkeys_uid" -eq "$borg_uid" ]]
then
    log_info "user borg UID=$borg_uid matches $AUTHORIZED_KEYS UID, no UID change necessary"
else
    # Does a user with id $authkeys_uid already exist?
    if getent passwd "$authkeys_uid" >/dev/null
    then
        log_error "UID $authkeys_uid already exists in container; can't remap user borg"
        exit 1
    fi
    # Change borg user id to match
    usermod -u "$authkeys_uid" borg
    log_info "borg user reassigned UID=$authkeys_uid"
fi


# Update ownership in /home/borg after id changes
# Skip authorized_keys since it is a bind mount from the host
find /home/borg -path "$AUTHORIZED_KEYS" -prune -o -exec chown borg:borg {} +

# Log the effective time to ensure /etc/localtime bind mount is functioning
echo "date: $(date)"

# Run sshd as PID 1 with logging to stderr
exec /usr/sbin/sshd -D -e
