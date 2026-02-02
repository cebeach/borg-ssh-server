# borg-ssh-server
This repository hosts docker artifacts to containerize a minimal BorgBackup SSH service with least-privilege access and persistent storage.

Image on docker hub:
[chadly314/borg-ssh-server](https://hub.docker.com/repository/docker/chadly314/borg-ssh-server/)

The original use model for this container is encapsulation of 'borg serve' on a Synology Diskstation NAS.

This container is intended to expose a single-purpose service (borg serve) over SSH without granting an interactive shell or DSM administrator access. OpenSSH provides authentication + encryption + transport; authorization is enforced via authorized\_keys restrictions and a forced command.

The container runs sshd as PID 1, accepts only public-key auth, and maps a persistent repository directory into the container. Each client key is scoped to Borg only.

By running sshd inside the container:
* a dedicated unprivileged user (borg) is enforced
* no DSM shell access is granted
* no Docker control or host namespace access is possible
* the authentication boundary aligns exactly with the service boundary
* SSH is used purely as a transport and authentication mechanism, not as a general login facility.

The intended use model is to leverage SSH’s forced-command mechanism in the borg user's authorized_keys (/home/borg/.ssh/authorized_keys) to restrict the borg user to running 'borg serve' only. Interactive shells, port forwarding, and agent forwarding are disabled via authorized\_keys options so that:
* the SSH session cannot be repurposed
* authentication success does not imply general execution capability
* the Borg repository interface is the only exposed API

SSH host identity is managed explicitly:
* Only ED25519 host keys are used
* Host keys are generated prior to container runtime if missing
* Keys are not baked into the image to avoid shared identities across deployments

All sensitive state is externalized via bind mounts:
* Borg repositories
* SSH host keys
* `authorized_keys`

The container image itself is treated as **stateless**. Recreating the container does not rotate identities or destroy data.

## Resources:
- [BorgBackup docs](https://borgbackup.readthedocs.io/en/stable/)
- [docker](https://borgbackup.readthedocs.io/en/stable/)





