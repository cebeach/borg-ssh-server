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



## UFW Considerations
If using UFW, the following are recommended rules to add to the UFW before hook
in /etc/ufw/before.rules:
*filter
...
:DOCKER-USER - [0:0]
...
-A DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A DOCKER-USER -i br+ -o br+ -j ACCEPT
-A DOCKER-USER -d 172.16.0.0/12 -j ACCEPT
-A DOCKER-USER -j DROP
...
COMMIT

