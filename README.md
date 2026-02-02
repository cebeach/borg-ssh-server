# borg-ssh-server
Minimal BorgBackup SSH service with least-privilege access and persistent storage
borg-ssh-server

Minimal Debian-based BorgBackup SSH service with least-privilege access and persistent storage

https://docs.docker.com/reference/compose-file/

Remove image:
docker compose down
docker rmi borg-ssh-server:bookwom

Rebuild:
sudo docker build -t borg-ssh-server:bookworm .

Start on development machine:
sudo docker compose -f compose/compose.common.yml -f compose/compose.dev.yml

Start on diskstation:
sudo docker compose -f compose/compose.common.yml -f compose/compose.ds.yml


sudo docker compose down

Check logs:
sudo docker logs borgbackup-server

Naming considerations:
- An image name should answer: What service does this image implement?
  Recommended structure: <namespace>/<service>-<protocol>-<scope>
- A container_name answers: What is this container doing here?

