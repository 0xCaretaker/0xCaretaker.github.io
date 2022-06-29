---
layout: post
author: Siddhant Chouhan
title:  My OSCP Journey
date: 2021-11-08 12:20:00 +0530
categories: []
tags: [offensive-security]
image: /assets/images/cover.png
---


## Introduction:

In this blog post I'll be talking about my [PWK-OSCP](https://www.offensive-security.com/pwk-oscp/) journey. I will be sharing useful resources as well that were helpful for me in this journey.

>  An OSCP has demonstrated the ability to use persistence, creativity, and perceptiveness to identify vulnerabilities and execute organized attacks under tight time constraints. OSCP holders have also shown they can think outside the box while managing both time and resources.

## $whoami - My Background

My name is Siddhant Chouhan, I am from New Delhi,India. I am a cyber security enthusiast and have keen interest in vulnerability assessment and penetration testing. I am a [HackTheBox](https://app.hackthebox.com/profile/280978) player and I love hacking.

## Penetration Testing With Kali Linux

### Course Prequisites

All students are required to have:

    Solid understanding of TCP/IP networking
    Reasonable Windows and Linux administration experience
    Familiarity with basic Bash and/or Python scripting

### Certification Exam

The OSCP certification exam simulates a live network in a separate VPN, which contains a small number of vulnerable machines. You will have 23 hours and 45 minutes to complete the challenge itself and a further 24 hours to submit your documentation.

### My approach

I got 2 months pwk lab subscription, and the lab started on 30 May 2021, I decided to spend the first week reading the pdf, watching the course videos and doing the exercises. Before enrolling into the pwk course I solved over 100 machines from [HackTheBox](https://www.hackthebox.com/) and did most of the offensive penetration testing path on tryhackme. I also did Tib3rius's Linux and Windows Privilege Escalation courses available on udemy. I did most of TCM Security's Practical Ethical Hacking course as well, I believe it helped clear my basics. Clear understanding of Linux and Windows privilege escalation and windows x86 buffer overflow exploit development is very important before enrolling into the course. Playing CTFs, doing HackTheBox and tryhackme is something that is going to help you for sure. 


--------------------- | ---------------------  
Practical Ethical Hacking by TCM Security          | [https://academy.tcm-sec.com/p/practical-ethical-hacking-the-complete-course](https://academy.tcm-sec.com/p/practical-ethical-hacking-the-complete-course)      
Windows Privilege Escalation for OSCP & Beyond!    | [https://www.udemy.com/course/windows-privilege-escalation/](https://www.udemy.com/course/windows-privilege-escalation/)
Linux Privilege Escalation for OSCP & Beyond!             | [https://www.udemy.com/course/linux-privilege-escalation/](https://www.udemy.com/course/linux-privilege-escalation/)
Buffer Overflows Made Easy    | [https://www.youtube.com/watch?v=qSnPayW6F7U&list=PLLKT__MCUeix3O0DPbmuaRuR_4Hxo4m3G](https://www.youtube.com/watch?v=qSnPayW6F7U&list=PLLKT__MCUeix3O0DPbmuaRuR_4Hxo4m3G)
TryHackMe Offensive Penetration Testing Path    | [https://tryhackme.com/path/outline/pentesting](https://tryhackme.com/path/outline/pentesting)


### PWK Labs

This was definitely one of the most exciting time of my life, 75 target machines to pwn, I went through pain, sufferance and a lot!

Offsec provides detailed writeups for two machines Alpha and Beta, they are so beautifully written and the step by step methodology shown is essential, you will eventually come up with your own methodology at some point, but reading the writeups for Alpha and Beta will surely help you understand penetration testing better.



<p class="aligncenter">
<img src="/assets/images/sufferance.png">
<br>
<br>  
<img src="/assets/images/pain.png">
<br>
<br>
I had scheduled my exam for 2nd August 2021, I solved all the 75 machines of the machines by 17th July 2021, and rescheduled my exam to 20th July (Yes I gave the exam on my birthday, After all I needed all the luck I can get, and what better way to spend my 21st birthday than spending the whole day hacking). 
<img src="/assets/images/pwk-lab-done.png">
<br>
<br>
I also offered to help clear doubts of fellow students on the offensive security discord server during my lab time, I believe it gave me more clarity on the boxes I had hacked earlier and was at times praised by the student admins as well for helping out other students.
<img src="/assets/images/help_others.png">
</p>
I also did around 20 boxes from Offensive Security Proving Grounds Practice, it costs $19/month and will teach you how to face rabbit holes, it even has retired OSCP exam machines so you can have a more realistic insight as to what you are going to face during the exam. I did 2 practice exams:
<p class="aligncenter">
<img src="/assets/images/practice_test.png">
</p>

The more boxes you do the better you chance you will have, it is important to do the boxes on your own. It is completely fine to read the writeups if you are stuck but do keep in mind, in the exam you are on your own. So do keep a balance, and yes try harder!



### fumenoid's checklist for a fool-proof exam day

This is the checklist my friend gave me 1 day before the exam:

- Aditional internet recharge in sim, incase wifi fails.
- One replica of my vm incase vm crashes.
- Snapshot of vms before and after exam.
- Additional ubuntu and centos vm
- Using power sockets that has inverter backup
- Backup laptop (lol.. i was planning for worse)
- 6 red bulls, chocolates, cold drink.. basically quick snacks to refresh, no chips don't wanna waste any time to wash hands and stuff
- Medicines (do get medicines), I personally had pain killers , eno and paracetamol.
- Water bottles (atleast 2)
- Documents (aadhar card,passport) 
- Webcam check.
- Ethernet if possible
- Chart papers/ rough paper sheets + pens/markers, i generally do write ports and things on paper and try to think which service can be used to exploit another one, basically incase of exploit chains
- Hashcat and john running on cloud 
- Check all tools (i never did it.. lol)
- Read all faqs
- Very Important > turn off windows update in host operating system, windows update during exam, would waste a lot of time


## Exam Day

The proctoring started at 8:15 am, I was asked to show my room, under my table etc. to ensure there wasn't anybody else with me. I got the exam vpn and the certification exam started at 8:30am 20th July 2021. The exam objective is to hack into 5 machines within 23 hours and 45 minutes and a further 24 hours to make a detailed report. 70 points are needed to pass the exam.

Timeline:

--------------------- | --------------------- 
8:30 AM  - 9:30 AM  | Completed the Buffer overflow machine (25 points)
9:45 AM - 10:45 AM  | Enumerated all the other machines, tried the other 25 point machine but no luck
11:00 AM - 11:30 AM | Successfully hacked the 10 point windows machine (10 points, Total = 25 + 10 = 35 points)
11:45 AM - 3:00 PM  | Stuck, can't find anything for more than 3 hours (panic attacks, but took frequent breaks)
3:00 PM  - 6:00 PM  | Obtained remote code execution on the 25 point Linux machine, privilege escalation wasn't really hard (25 + 10 + 25 = 60 points)
6:00 PM - 6:20 PM | Found foothold for a 20 point machine but I got errors when trying to replicate the exploit.
6:30 PM - 6:50 PM | Enumerated the other 20 point machine and found the right exploit needed, but the exploit failed.
7:00 PM - 7:30 PM | Read the python script and then manually performed the exploit, obtained remote code execution !!, Privilege escalation was not so hard this time as well. (25 + 10 + 25 + 20 = 80 points)
7:30 PM - 8:30 PM | Had my birthday cake and had dinner.
8:30 PM - 2:00 AM | Made the report, made sure to have all the screen shots, and took a snapshot of my virtual machine.

I asked the procotor to end my exam, and I slept peacefully knowing I have enough points to pass (I was able to hack 4/5 machines!!).

Next morning I reviewed the report and submitted it, my report was 82 pages long I had used the whoisflynn word report template and made sure to provide step by step report with all the required screenshots.

## Results

The wait for the result email is pure torture, it took 2 days for the results to come, I got the pass email at 4:25 AM 23rd July.


<p class="aligncenter">
<img src="/assets/images/result.png">
</p>

The cert came all the way from Philippines, it took around 1 month for them to send the cert to my address. This journey is one of the most exciting experiences of my life, going through those machines, the 24 hour hands on exam everything was worth it, the hardwork I had put in,new hacking techniques,tools and so much I have learned. I loved each and every moment of this journey. Maybe I would go for OSWE next haha.

<p class="aligncenter">
<img src="/assets/images/cert.jpg">
</p>

## Resources


-------------------------- | -----------------------  
Practical Ethical Hacking by TCM Security          | [https://academy.tcm-sec.com/p/practical-ethical-hacking-the-complete-course](https://academy.tcm-sec.com/p/practical-ethical-hacking-the-complete-course)      
Windows Privilege Escalation for OSCP & Beyond!    | [https://www.udemy.com/course/windows-privilege-escalation/](https://www.udemy.com/course/windows-privilege-escalation/)
Linux Privilege Escalation for OSCP & Beyond!             | [https://www.udemy.com/course/linux-privilege-escalation/](https://www.udemy.com/course/linux-privilege-escalation/)
Buffer Overflows Made Easy    | [https://www.youtube.com/watch?v=qSnPayW6F7U&list=PLLKT__MCUeix3O0DPbmuaRuR_4Hxo4m3G](https://www.youtube.com/watch?v=qSnPayW6F7U&list=PLLKT__MCUeix3O0DPbmuaRuR_4Hxo4m3G)
TryHackMe Offensive Penetration Testing Path    | [https://tryhackme.com/path/outline/pentesting](https://tryhackme.com/path/outline/pentesting)
Offensive Security Proving Grounds Practice | [https://www.offensive-security.com/labs/individual/](https://www.offensive-security.com/labs/individual/)
whoisflynn/OSCP-Exam-Report-Template | [https://github.com/whoisflynn/OSCP-Exam-Report-Template](https://github.com/whoisflynn/OSCP-Exam-Report-Template)
Tj Null's list of OSCP like boxes | [https://docs.google.com/spreadsheets/u/1/d/1dwSMIAPIam0PuRBkCiDI88pU3yzrqqHkDtBngUHNCw8/htmlview#](https://docs.google.com/spreadsheets/u/1/d/1dwSMIAPIam0PuRBkCiDI88pU3yzrqqHkDtBngUHNCw8/htmlview#)
Busra Demir's OSCP Journey | [https://areyou1or0.it/index.php/2021/02/10/finally-oscp-may-the-force-be-with-you/](https://areyou1or0.it/index.php/2021/02/10/finally-oscp-may-the-force-be-with-you/)
