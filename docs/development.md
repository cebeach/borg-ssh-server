# Development Notes

The initial development environment is a [debian bookworm](https://www.debian.org/releases/bookworm) workstation on amd64 architecture using UFW for firewall rules.

When using UFW, the following are recommended rules to add to the UFW 'before hook' in `/etc/ufw/before.rules`:
```
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
```