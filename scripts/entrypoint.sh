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

# Required bind mounts
AUTHORIZED_KEYS=/home/borg/.ssh/authorized_keys
HOST_PRIVATE_KEY=/etc/ssh/ssh_host_ed25519_key
HOST_PUBLIC_KEY=/etc/ssh/ssh_host_ed25519_key.pub

# Debian Policy Manual recommended ranges for UID and GID
# https://www.debian.org/doc/debian-policy/ch-opersys.html#users-and-groups
# Note that we let GID span down to 100 for compatibility with Synology diskstation
# which uses GID 100 as the default users group.
# 0-99: Reserved for statically allocated system users and groups
# 100-999: Dynamically allocated system users and groups (created by packages)
# 1000-59999: Regular user accounts (dynamically allocated)
# 60000-64999: Reserved for special purposes
# 65000-65533: Reserved
# 65534: User "nobody" and group "nogroup"
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

log_warning() {
    echo "WARNING: $*" >&2
}


# Validate directory existence
errors=()
for dir in /home/borg/.ssh /repos
do
    if [[ ! -d "$dir" ]]
        then
        error="$dir is not a directory or doesn't exist"
        log_error "$error"
        errors+=("$error")
    fi
done

if [[ ${#errors[@]} -ne 0 ]]
then
    exit 1
fi

# Validate directory permissions
for dir in /home/borg/.ssh /repos
do
    if [[ "$(stat -c '%a' "$dir")" != "700" ]]
    then
        error="$dir permissions are not 700"
        log_error "$error"
        errors+=("$error")
    fi
done

if [[ ${#errors[@]} -ne 0 ]]
then
    exit 1
fi


# Validate file existence
for file in "$AUTHORIZED_KEYS" "$HOST_PRIVATE_KEY" "$HOST_PUBLIC_KEY"
do
    if [[ -f "$file" ]]
    then
        log_info "$file found"
    else
        error="$file not found; please bind mount"
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
target_uid="$(stat -c '%u' "$AUTHORIZED_KEYS")"
target_gid="$(stat -c '%g' "$AUTHORIZED_KEYS")"

log_info "$AUTHORIZED_KEYS has UID=$target_uid GID=$target_gid"

if [[ $target_uid -lt $MIN_UID ]]; then
    log_error "$AUTHORIZED_KEYS UID $target_uid is less than minimum allowed value of $MIN_UID"
    log_error "UIDs below $MIN_UID are reserved for system accounts per Debian Policy"
    exit 1
fi

if [[ $target_uid -gt $MAX_UID ]]; then
    log_error "$AUTHORIZED_KEYS UID $target_uid is greater than maximum allowed value of $MAX_UID"
    log_error "UIDs above $MAX_UID are in reserved ranges per Debian Policy"
    exit 1
fi

# Validate GID is within acceptable range
if [[ $target_gid -lt $MIN_GID ]]; then
    log_error "$AUTHORIZED_KEYS GID $target_gid is less than minimum allowed value of $MIN_GID"
    log_error "GIDs below $MIN_GID are reserved for system groups per Debian Policy"
    exit 1
fi

if [[ $target_gid -gt $MAX_GID ]]; then
    log_error "$AUTHORIZED_KEYS GID $target_gid is greater than maximum allowed value of $MAX_GID"
    log_error "GIDs above $MAX_GID are in reserved ranges per Debian Policy"
    exit 1
fi

# Coerce UID and GID of the borg user account if necessary
old_uid="$(id -u borg)"
old_gid="$(id -g borg)"

log_info "container borg user UID=$old_uid, borg group GID=$old_gid"

if [[ "$target_gid" -eq "$old_gid" ]]
then
    log_info "user borg GID=$old_gid matches $AUTHORIZED_KEYS GID, no GID change necessary"
else
    if getent group "$target_gid" >/dev/null
    then
        # add user to existing group
        usermod -g "$target_gid" borg
        log_info "borg user added to group $target_gid"
    else
        # move borg group to target_gid
        groupmod -g "$target_gid" borg
        log_info "borg group reassigned GID=$target_gid"
    fi
fi

# ensure target_uid is free, then move borg to it
if [[ "$target_uid" -eq "$old_uid" ]]
then
    log_info "user borg UID=$old_uid matches $AUTHORIZED_KEYS UID, no UID change necessary"
else
    if getent passwd "$target_uid" >/dev/null
    then
        log_error "UID $target_uid already exists in container; can't remap user borg"
        exit 1
    fi
    usermod -u "$target_uid" borg
    log_info "borg user reassigned UID=$target_uid"
fi




# Run sshd in as PID 1 with logging to stderr; run the following to tail sshd log:
# $ docker logs --tail 100 -f borgbackup-server
exec /usr/sbin/sshd -D -e

