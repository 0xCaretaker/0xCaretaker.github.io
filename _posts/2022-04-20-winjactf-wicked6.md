---
layout: post
author: Siddhant Chouhan
title: Winja CTF Wicked 6 Reverse Engineering Challenges Writeup
date: 2022-04-21 12:20:00 +0530
categories: [ctf]
tags: [ctf]
image: /assets/img/Posts/winja-wicked6.png
---

## Overview:

As a community volunteer [@Winja](https://twitter.com/Winja_CTF) I created reverse engineering ctf challenges for [Wicked 6 Winja CTF for Women](https://www.wicked6.com/). Without wasting further time let's jump in!

### d3bug-th1s

Challenge Name: d3bug-th1s <br>
Category: Reverse Engineering <br>
Challenge Description: The space station provides a nice environment for enthusiasts to discover their potential. You are given a linux executable which says "segmentation fault" on running can you find out what the binary is doing and get the flag. <br>

#### Solution

Analyze the binary using gdb
```bash
gdb-peda ./space 
Reading symbols from ./space...
(No debugging symbols found in ./space)
gdb-peda$ info functions
All defined functions:

Non-debugging symbols:
0x0000000000001000  _init
0x0000000000001090  __cxa_finalize@plt
0x00000000000010a0  getenv@plt
0x00000000000010b0  strncmp@plt
0x00000000000010c0  puts@plt
0x00000000000010d0  __stack_chk_fail@plt
0x00000000000010e0  printf@plt
0x00000000000010f0  strcat@plt
0x0000000000001100  _start
0x0000000000001130  deregister_tm_clones
0x0000000000001160  register_tm_clones
0x00000000000011a0  __do_global_dtors_aux
0x00000000000011e0  frame_dummy
0x00000000000011e9  banner
0x0000000000001205  main
0x0000000000001340  __libc_csu_init
0x00000000000013b0  __libc_csu_fini
0x00000000000013b8  _fini
gdb-peda$ 
```

Let's have a look at the disassembly of the main function

```bash
gdb-peda$ disassemble main                                                                                                                                      
Dump of assembler code for function main:                                                                                                                       
   0x0000000000001205 <+0>:     endbr64 
   0x0000000000001209 <+4>:     push   rbp
   0x000000000000120a <+5>:     mov    rbp,rsp
   0x000000000000120d <+8>:     sub    rsp,0x40
   0x0000000000001211 <+12>:    mov    rax,QWORD PTR fs:0x28
   0x000000000000121a <+21>:    mov    QWORD PTR [rbp-0x8],rax
   0x000000000000121e <+25>:    xor    eax,eax
   0x0000000000001220 <+27>:    mov    eax,0x0
   0x0000000000001225 <+32>:    call   0x11e9 <banner>
   0x000000000000122a <+37>:    lea    rdi,[rip+0x1212]        # 0x2443
   0x0000000000001231 <+44>:    call   0x10a0 <getenv@plt>
   0x0000000000001236 <+49>:    mov    QWORD PTR [rbp-0x30],rax
   0x000000000000123a <+53>:    mov    WORD PTR [rbp-0x22],0x6d
   0x0000000000001240 <+59>:    mov    WORD PTR [rbp-0x20],0x78
   0x0000000000001246 <+65>:    mov    WORD PTR [rbp-0x1e],0x61
   0x000000000000124c <+71>:    mov    WORD PTR [rbp-0x1c],0x71
   0x0000000000001252 <+77>:    mov    WORD PTR [rbp-0x1a],0x72
   0x0000000000001258 <+83>:    mov    WORD PTR [rbp-0x18],0x6a
   0x000000000000125e <+89>:    mov    WORD PTR [rbp-0x16],0x73
   0x0000000000001264 <+95>:    mov    WORD PTR [rbp-0x14],0x74
   0x000000000000126a <+101>:   mov    WORD PTR [rbp-0x12],0x75
   0x0000000000001270 <+107>:   mov    WORD PTR [rbp-0x10],0x76
   0x0000000000001276 <+113>:   mov    WORD PTR [rbp-0xe],0x77
   0x000000000000127c <+119>:   mov    WORD PTR [rbp-0xc],0x78
   0x0000000000001282 <+125>:   mov    WORD PTR [rbp-0xa],0x79
   0x0000000000001288 <+131>:   mov    BYTE PTR [rbp-0x23],0x0
   0x000000000000128c <+135>:   lea    rdx,[rbp-0x22]
   0x0000000000001290 <+139>:   lea    rax,[rbp-0x23]
   0x0000000000001294 <+143>:   mov    rsi,rdx
   0x0000000000001297 <+146>:   mov    rdi,rax
   0x000000000000129a <+149>:   call   0x10f0 <strcat@plt>
```
We see there is a call to getenv function, that's interesting the binary is looking for an environment variable. Let's set a break point at the main function and then run step by step in gdb.

```bash
gdb-peda$ b * main                                                                                                                                              
Breakpoint 1 at 0x1205                                                                                                                                          

gdb-peda$ r
```

Now single step forward till we reach the call to getenv

```bash
gdb-peda$ ni

[----------------------------------registers-----------------------------------]

RSI: 0x555555556442 --> 0x74656e616c7000 ('')
RDI: 0x555555556443 --> 0xa0074656e616c70 ('planet')
RBP: 0x7fffffffdec0 --> 0x0 
RSP: 0x7fffffffde80 --> 0x7fffffffdea6 --> 0x5555555551000000 ('')
RIP: 0x555555555231 (<main+44>: call   0x5555555550a0 <getenv@plt>)
R8 : 0x400 
R9 : 0x43a 
R10: 0x7ffff7faabe0 --> 0x5555555596a0 --> 0x0 
R11: 0x246 
R12: 0x555555555100 (<_start>:  endbr64)
R13: 0x7fffffffdfb0 --> 0x1 
R14: 0x0 
R15: 0x0
EFLAGS: 0x202 (carry parity adjust zero sign trap INTERRUPT direction overflow)
[-------------------------------------code-------------------------------------]
   0x555555555220 <main+27>:    mov    eax,0x0
   0x555555555225 <main+32>:    call   0x5555555551e9 <banner>
   0x55555555522a <main+37>:    lea    rdi,[rip+0x1212]        # 0x555555556443
=> 0x555555555231 <main+44>:    call   0x5555555550a0 <getenv@plt>
   0x555555555236 <main+49>:    mov    QWORD PTR [rbp-0x30],rax
   0x55555555523a <main+53>:    mov    WORD PTR [rbp-0x22],0x6d
   0x555555555240 <main+59>:    mov    WORD PTR [rbp-0x20],0x78
   0x555555555246 <main+65>:    mov    WORD PTR [rbp-0x1e],0x61
Guessed arguments:
arg[0]: 0x555555556443 --> 0xa0074656e616c70 ('planet')
[------------------------------------stack-------------------------------------]
0000| 0x7fffffffde80 --> 0x7fffffffdea6 --> 0x5555555551000000 ('')
0008| 0x7fffffffde88 --> 0x55555555538d (<__libc_csu_init+77>:  add    rbx,0x1)
0016| 0x7fffffffde90 --> 0x7ffff7faf2e8 --> 0x0 
0024| 0x7fffffffde98 --> 0x555555555340 (<__libc_csu_init>:     endbr64)
0032| 0x7fffffffdea0 --> 0x0 
0040| 0x7fffffffdea8 --> 0x555555555100 (<_start>:      endbr64)
0048| 0x7fffffffdeb0 --> 0x7fffffffdfb0 --> 0x1 
0056| 0x7fffffffdeb8 --> 0xd934b04a72b2e000 
[------------------------------------------------------------------------------]
Legend: code, data, rodata, value
0x0000555555555231 in main ()
gdb-peda$ 
``` 
It looks like the binary is looking for an environment variable called planet.

Let's continue executing one machine instruction at a time.

```bash
[----------------------------------registers-----------------------------------]                                                                                
RAX: 0x0                                                                                                                                                        
RBX: 0x555555555340 (<__libc_csu_init>: endbr64)                                                                                                                
RCX: 0x7fffffffde9d --> 0x710061007372616d ('mars')                                                                                                             
RDX: 0x73 ('s')
RSI: 0x7fffffffdeaa --> 0x76007500740073 ('s')
RDI: 0x7fffffffdea0 --> 0x72007100610073 ('s')
RBP: 0x7fffffffdec0 --> 0x0 
RSP: 0x7fffffffde80 --> 0x7fffffffdea6 --> 0x740073006a0072 ('r')
RIP: 0x5555555552e0 (<main+219>:        mov    edx,0x6)
R8 : 0x400 
R9 : 0x7fffffffde9d --> 0x710061007372616d ('mars')
R10: 0x7ffff7faabe0 --> 0x5555555596a0 --> 0x0 
R11: 0x246 
R12: 0x555555555100 (<_start>:  endbr64)
R13: 0x7fffffffdfb0 --> 0x1 
R14: 0x0 
R15: 0x0
EFLAGS: 0x246 (carry PARITY adjust ZERO sign trap INTERRUPT direction overflow)
[-------------------------------------code-------------------------------------] 
   0x5555555552d3 <main+206>:   call   0x5555555550f0 <strcat@plt>
   0x5555555552d8 <main+211>:   lea    rcx,[rbp-0x23]
   0x5555555552dc <main+215>:   mov    rax,QWORD PTR [rbp-0x30]
=> 0x5555555552e0 <main+219>:   mov    edx,0x6
   0x5555555552e5 <main+224>:   mov    rsi,rcx
   0x5555555552e8 <main+227>:   mov    rdi,rax
   0x5555555552eb <main+230>:   call   0x5555555550b0 <strncmp@plt>
   0x5555555552f0 <main+235>:   mov    DWORD PTR [rbp-0x34],eax
[------------------------------------stack-------------------------------------] 
```
 A bunch of calls to strcat and a string "mars" has been formed, let's give it a shot!

```bash
sid@sid-Inspiron-5547:~/Documents/WinjaCTF_Wicked6/d3bug-th1s!$ export planet=mars
sid@sid-Inspiron-5547:~/Documents/WinjaCTF_Wicked6/d3bug-th1s!$ ./space 
 /\/\/\                            /  \
| \  / |                         /      \
|  \/  |                       /          \
|  /\  |----------------------|     /\     |
| /  \ |                      |    /  \    |
|/    \|                      |   /    \   |
|\    /|                      |  | (  ) |  |
| \  / |                      |  | (  ) |  |
|  \/  |                 /\   |  |      |  |   /\
|  /\  |                /  \  |  |      |  |  /  \
| /  \ |               |----| |  |      |  | |----|
|/    \|---------------|    | | /|   .  |\ | |    |
|\    /|               |    | /  |   .  |  \ |    |
| \  / |               |    /    |   .  |    \    |
|  \/  |               |  /      |   .  |      \  |
|  /\  |---------------|/        |   .  |        \|
| /  \ |              /   CTF   |   .  |  CTF    \
|/    \|              (          |      |           )
|/\/\/\|               |    | |--|      |--| |    |
------------------------/  \-----/  \/  \-----/  \--------
                        \\//     \\//\\//     \\//
                         \/       \/  \/       \/
 
flag{off_to_mars_2022}
```
We got the flag!!


### Unreachable

Challenge: Unreachable <br>
Category: Reverse Engineering <br>
Description: Our engineers said that it was impossible to reach the flag printing function for this program, can you do the impossible? reach the unreachable? <br>

#### Solution

On analyzing the binary we find that our input's length is being compared to 5 and 7 and we can not have an input which can be of length 5 and 7 at the same time so, we can either patch the binary using IDA or simply set the instruction pointer to the give flag function using gdb.

```bash
gdb-peda ./a.out 
Reading symbols from ./a.out...
(No debugging symbols found in ./a.out)
gdb-peda$ info functions 
All defined functions:

Non-debugging symbols:
0x0000000000001000  _init
0x0000000000001090  __cxa_finalize@plt
0x00000000000010a0  putchar@plt
0x00000000000010b0  puts@plt
0x00000000000010c0  strlen@plt
0x00000000000010d0  __stack_chk_fail@plt
0x00000000000010e0  printf@plt
0x00000000000010f0  exit@plt
0x0000000000001100  _start
0x0000000000001130  deregister_tm_clones
0x0000000000001160  register_tm_clones
0x00000000000011a0  __do_global_dtors_aux
0x00000000000011e0  frame_dummy
0x00000000000011e9  giveflag
0x0000000000001299  main
0x0000000000001340  __libc_csu_init
0x00000000000013b0  __libc_csu_fini
0x00000000000013b8  _fini
gdb-peda$ b * main
Breakpoint 1 at 0x1299
gdb-peda$ r
```

```bash
gdb-peda$ info functions

File xpg_basename.c:                                                                                                                                            
25:     char *__xpg_basename(char *);                                                                                                                           
                                                                                                                                                                
Non-debugging symbols:                                                                                                                                          
0x0000555555555000  _init                                                                                                                                       
0x0000555555555090  __cxa_finalize@plt                                                                                                                          
0x00005555555550a0  putchar@plt                                                                                                                                 
0x00005555555550b0  puts@plt                                                                                                                                    
0x00005555555550c0  strlen@plt                                                                                                                                  
0x00005555555550d0  __stack_chk_fail@plt                                                                                                                        
0x00005555555550e0  printf@plt                                                                                                                                  
0x00005555555550f0  exit@plt                                                                                                                                    
0x0000555555555100  _start                                                                                                                                      
0x0000555555555130  deregister_tm_clones                                                                                                                        
0x0000555555555160  register_tm_clones                                                                                                                          
0x00005555555551a0  __do_global_dtors_aux                                                                                                                       
0x00005555555551e0  frame_dummy                                                                                                                                 
0x00005555555551e9  giveflag                                                                                                                                    
```
Now we will set the instruction pointer $rip to point to the giveflag function.
```bash
gdb-peda$ set $rip=0x00005555555551e9
gdb-peda$ c
Continuing.
flag{0h_s0_y0u_kN0w_P4tch1ng}[Inferior 1 (process 10177) exited normally]
Warning: not running
gdb-peda$ 
```



### easy-rev

Challenge Name : Easy-Rev <br>
Category : Reverse Engineering <br>
Description: you are given a 64 bit linux executable named easy-rev.out execute it on your linux systems using ./easy-rev.out. It asks for 3 passwords if you give the correct passwords the flag will be printed. <br>
Flag format: flag{some_thing_here} <br>

#### Solution

On analyzing the bianry with radare2 we can clearly see that the binary will ask for 3 passwords and if we give the correct passwords we will get the flag.

Let's use the "aa" command to analyze the binary and use "afl" to list all the functions in the disassembly.

```zsh
➜  easy-rev r2 easy-rev.out 
[0x00001070]> aa
[x] Analyze all flags starting with sym. and entry0 (aa)
[0x00001070]> afl
0x00001070    1 42           entry0
0x00001030    1 6            sym.imp.strncmp
0x00001040    1 6            sym.imp.printf
0x00001050    1 6            sym.imp.__isoc99_scanf
0x00001155    8 298          main
0x00001150    5 133  -> 56   entry.init0
0x00001110    5 57   -> 50   entry.fini0
0x000010a0    4 41   -> 34   fcn.000010a0
[0x00001070]> 
```

```zsh

            ; DATA XREF from entry0 @ 0x108d
/ 298: int main (int argc, char **argv, char **envp);
|           ; var int64_t var_1ch @ rbp-0x1c
|           ; var int64_t var_18h @ rbp-0x18
|           ; var int64_t var_12h @ rbp-0x12
|           ; var int64_t var_ah @ rbp-0xa
|           ; var int64_t var_6h @ rbp-0x6
|           ; var int64_t var_4h @ rbp-0x4
|           0x00001155      55             push rbp
|           0x00001156      4889e5         mov rbp, rsp
|           0x00001159      4883ec20       sub rsp, 0x20
|           0x0000115d      c745f6000000.  mov dword [var_ah], 0
|           0x00001164      66c745fa0000   mov word [var_6h], 0
|           0x0000116a      48b872616461.  movabs rax, 0x32657261646172 ; 'radare2'
|           0x00001174      488945ee       mov qword [var_12h], rax
|           0x00001178      488d3d890e00.  lea rdi, qword str.Enter_the_first_password ; 0x2008 ; "Enter the first password => "
|           0x0000117f      b800000000     mov eax, 0
|           0x00001184      e8b7feffff     call sym.imp.printf         ; int printf(const char *format)
|           0x00001189      488d45f6       lea rax, qword [var_ah]
|           0x0000118d      4889c6         mov rsi, rax
|           0x00001190      488d3d8e0e00.  lea rdi, qword [0x00002025] ; "%s"
|           0x00001197      b800000000     mov eax, 0
|           0x0000119c      e8affeffff     call sym.imp.__isoc99_scanf ; int scanf(const char *format)
|           0x000011a1      488d55ee       lea rdx, qword [var_12h]
|           0x000011a5      488d45f6       lea rax, qword [var_ah]
|           0x000011a9      4889d6         mov rsi, rdx
|           0x000011ac      4889c7         mov rdi, rax
|           0x000011af      e87cfeffff     call sym.imp.strncmp        ; int strncmp(const char *s1, const char *s2, size_t n)
|           0x000011b4      8945fc         mov dword [var_4h], eax
|           0x000011b7      837dfc00       cmp dword [var_4h], 0
|       ,=< 0x000011bb      0f85aa000000   jne 0x126b
|       |   0x000011c1      488d3d600e00.  lea rdi, qword str.Enter_the_second_password ; 0x2028 ; "Enter the second password => "
|       |   0x000011c8      b800000000     mov eax, 0
|       |   0x000011cd      e86efeffff     call sym.imp.printf         ; int printf(const char *format)
|       |   0x000011d2      488d45e8       lea rax, qword [var_18h]
|       |   0x000011d6      4889c6         mov rsi, rax
|       |   0x000011d9      488d3d660e00.  lea rdi, qword [0x00002046] ; "%d"
|       |   0x000011e0      b800000000     mov eax, 0
|       |   0x000011e5      e866feffff     call sym.imp.__isoc99_scanf ; int scanf(const char *format)
|       |   0x000011ea      8b45e8         mov eax, dword [var_18h]
|       |   0x000011ed      83f80f         cmp eax, 0xf
|      ,==< 0x000011f0      7566           jne 0x1258
|      ||   0x000011f2      488d3d500e00.  lea rdi, qword str.Enter_the_third_password ; 0x2049 ; "Enter the third password => "
|      ||   0x000011f9      b800000000     mov eax, 0
|      ||   0x000011fe      e83dfeffff     call sym.imp.printf         ; int printf(const char *format)
|      ||   0x00001203      488d45e4       lea rax, qword [var_1ch]
|      ||   0x00001207      4889c6         mov rsi, rax
|      ||   0x00001211      b800000000     mov eax, 0
|      ||   0x00001216      e835feffff     call sym.imp.__isoc99_scanf ; int scanf(const char *format)
|      ||   0x0000121b      8b45e4         mov eax, dword [var_1ch]
|      ||   0x0000121e      3d39050000     cmp eax, 0x539              ; 1337
|     ,===< 0x00001223      7520           jne 0x1245
|     |||   0x00001225      8b4de4         mov ecx, dword [var_1ch]
|     |||   0x00001228      8b55e8         mov edx, dword [var_18h]
|     |||   0x0000122b      488d45f6       lea rax, qword [var_ah]
|     |||   0x0000122f      4889c6         mov rsi, rax
|     |||   0x00001232      488d3d2d0e00.  lea rdi, qword str.flag__s__d__d ; 0x2066 ; "flag{\%s_%d_%d}"
|     |||   0x00001239      b800000000     mov eax, 0
|     |||   0x0000123e      e8fdfdffff     call sym.imp.printf         ; int printf(const char *format)
|    ,====< 0x00001243      eb37           jmp 0x127c
|    |`---> 0x00001245      488d3d2c0e00.  lea rdi, qword str.Incorrect_password___Exiting... ; 0x2078 ; "Incorrect password!! Exiting..."
|    | ||   0x0000124c      b800000000     mov eax, 0
|    | ||   0x00001251      e8eafdffff     call sym.imp.printf         ; int printf(const char *format)
|    |,===< 0x00001256      eb24           jmp 0x127c
|    ||`--> 0x00001258      488d3d190e00.  lea rdi, qword str.Incorrect_password___Exiting... ; 0x2078 ; "Incorrect password!! Exiting..."
|    || |   0x0000125f      b800000000     mov eax, 0
|    || |   0x00001264      e8d7fdffff     call sym.imp.printf         ; int printf(const char *format)
|    ||,==< 0x00001269      eb11           jmp 0x127c
|    |||`-> 0x0000126b      488d3d060e00.  lea rdi, qword str.Incorrect_password___Exiting... ; 0x2078 ; "Incorrect password!! Exiting..."
|    |||    0x00001272      b800000000     mov eax, 0
|    |||    0x00001277      e8c4fdffff     call sym.imp.printf         ; int printf(const char *format)
|    |||    ; CODE XREFS from main @ 0x1243, 0x1256, 0x1269
|    ```--> 0x0000127c      90             nop
|           0x0000127d      c9             leave
\           0x0000127e      c3             ret
[0x00001070]>time.sleep(2)
```


Now let's take a look at the interesting pieces...


```zsh
 0x0000116a      48b872616461.  movabs rax, 0x32657261646172 ; 'radare2'
|           0x00001174      488945ee       mov qword [var_12h], rax
|           0x00001178      488d3d890e00.  lea rdi, qword str.Enter_the_first_password ; 0x2008 ; "Enter the first password => "
|           0x0000117f      b800000000     mov eax, 0
|           0x00001184      e8b7feffff     call sym.imp.printf         ; int printf(const char *format)
|           0x00001189      488d45f6       lea rax, qword [var_ah]
|           0x0000118d      4889c6         mov rsi, rax
|           0x00001190      488d3d8e0e00.  lea rdi, qword [0x00002025] ; "%s"
|           0x00001197      b800000000     mov eax, 0
|           0x0000119c      e8affeffff     call sym.imp.__isoc99_scanf ; int scanf(const char *format)
|           0x000011a1      488d55ee       lea rdx, qword [var_12h]
|           0x000011a5      488d45f6       lea rax, qword [var_ah]
|           0x000011a9      4889d6         mov rsi, rdx
|           0x000011ac      4889c7         mov rdi, rax
|           0x000011af      e87cfeffff     call sym.imp.strncmp        ; int strncmp(const char *s1, const char *s2, size_t n)
```

So our input which will be taken via scanf is being compared against a string "radare2" as the first password, alright we got the first piece to the puzzle.

```zsh
|       ,=< 0x000011bb      0f85aa000000   jne 0x126b
|       |   0x000011c1      488d3d600e00.  lea rdi, qword str.Enter_the_second_password ; 0x2028 ; "Enter the second password => "
|       |   0x000011c8      b800000000     mov eax, 0
|       |   0x000011cd      e86efeffff     call sym.imp.printf         ; int printf(const char *format)
|       |   0x000011d2      488d45e8       lea rax, qword [var_18h]
|       |   0x000011d6      4889c6         mov rsi, rax
|       |   0x000011d9      488d3d660e00.  lea rdi, qword [0x00002046] ; "%d"
|       |   0x000011e0      b800000000     mov eax, 0
|       |   0x000011e5      e866feffff     call sym.imp.__isoc99_scanf ; int scanf(const char *format)
|       |   0x000011ea      8b45e8         mov eax, dword [var_18h]
|       |   0x000011ed      83f80f         cmp eax, 0xf
|      ,==< 0x000011f0      7566           jne 0x1258
```

For the second password we can see our input is being compared using a cmd instruction (cmd eax,0xf), now 0xf is 15 is hex...

Similarly for the third part, we can see our input is being compared against 0x539 which is 1337.

```zsh
 ||   0x00001216      e835feffff     call sym.imp.__isoc99_scanf ; int scanf(const char *format)
|      ||   0x0000121b      8b45e4         mov eax, dword [var_1ch]
|      ||   0x0000121e      3d39050000     cmp eax, 0x539              ; 1337
|     ,===< 0x00001223      7520           jne 0x1245
|     |||   0x00001225      8b4de4         mov ecx, dword [var_1ch]
|     |||   0x00001228      8b55e8         mov edx, dword [var_18h]
|     |||   0x0000122b      488d45f6       lea rax, qword [var_ah]
|     |||   0x0000122f      4889c6         mov rsi, rax
|     |||   0x00001232      488d3d2d0e00.  lea rdi, qword str.flag__s__d__d ; 0x2066 ; "flag{\%s_%d_%d}"
```

Let's put all the pieces together

```
➜  easy-rev ./easy-rev.out 
Enter the first password => radare2
Enter the second password => 15
Enter the third password => 1337
flag{radare_15_1337}%                                                                                                 ➜  easy-rev 
```

### packed-locker

Challenge Name: packed-locker <br>
Category: Reverse Engineering <br>
Description: You are given a 64 bit linux executable with some defense mechanisms which will make reverse engineering difficult,find the password!. <br>
flag format is flag{s0me_text} <br>

#### Solution

While making the challenge I did the following things to prevent the solver from simply using ghidra to read the code.

- The binary is compiled using gcc test.c -static -fvisibility=hidden -fvisibility-inlines-hidden -s -o a.out
- The binary is stripped and the functions have been inlined so as to prevent reverse engineering to some extent.
- The binary is then packed using upx 9 a.out


Let's run the file command to get some information about the elf file. 

```zsh
➜  packed-locker git:(main) file packed-locker.out 
packed-locker.out: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, no section header
➜  packed-locker git:(main) 
```

So the given binary is a 64 bit elf executable, it is statically linked and has no section header. 

> The section header table has all of the information necessary to locate and isolate each of the file's sections. A section header entry in a section header table contains information characterizing the contents of the corresponding section, if the file has such a section.

[source for the above defintion](https://docs.oracle.com/cd/E19455-01/806-3773/elf-2/index.html)


Well, if I were to simply open the binary in ghidra it should first of all take a lot of time to analyze since it is statically linked so all the libc functions are inside the binary that would make it a pain to analyze it in ghidra.

Running strings on the binary reveals UPX both at the starting and at the end of dump.

```zsh
➜  packed-locker git:(main) strings packed-locker.out |head
VUPX!
        `o_`o
 O`)
d9o6
WB!#/
c/p_?h.v
_`/@0
?Xg_P
F^P[
$IX/
➜  packed-locker git:(main) strings packed-locker.out |tail
gcNdcept=
l"tEtbss
sub     #IO_v
sbssq
comRn=
vQ0r
ON.v
]l'/
UPX!
UPX!
➜  packed-locker git:(main)
```


[UPX](https://upx.github.io/) is an opensource packer for executables, we can unpack our executable using upx -d

```zsh
➜  packed-locker git:(main) ✗ upx -d packed-locker.out 
                       Ultimate Packer for eXecutables
                          Copyright (C) 1996 - 2020
UPX 3.96        Markus Oberhumer, Laszlo Molnar & John Reiser   Jan 23rd 2020

        File size         Ratio      Format      Name
   --------------------   ------   -----------   -----------
    834064 <-    322080   38.62%   linux/amd64   packed-locker.out

Unpacked 1 file.
➜  packed-locker git:(main) ✗ 
```

Now let's again run the file command on the executable.

```zsh
➜  packed-locker git:(main) ✗ file packed-locker.out 
packed-locker.out: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, BuildID[sha1]=1081ae4afbad864cafbd64396f36e5c0a39aa171, for GNU/Linux 3.2.0, stripped
➜  packed-locker git:(main) ✗
```

Alright now let's analyze it using radare2, using aa to analyze the program and afl to list all the functions.

```zsh
➜  packed-locker git:(main) ✗ r2 packed-locker.out
[0x00401b90]> aa
[x] Analyze all flags starting with sym. and entry0 (aa)
[0x00401b90]> afl
0x00401b90    1 43           entry0
0x00402190  102 1745 -> 1742 fcn.00402190
0x00401cad    4 193          main
[0x00401b90]> 
```

Great we we can see the main function, let's take a look at the disassembly of this function.

```zsh
[0x00401b90]> pdf @main
            ; DATA XREF from entry0 @ 0x401bad
/ 193: int main (int argc, char **argv, char **envp);
|           ; var int64_t var_40h @ rbp-0x40
|           ; var int64_t var_38h @ rbp-0x38
|           ; var int64_t var_30h @ rbp-0x30
|           ; var int64_t var_28h @ rbp-0x28
|           ; var int64_t var_26h @ rbp-0x26
|           ; var int64_t var_20h @ rbp-0x20
|           ; var int64_t var_18h @ rbp-0x18
|           ; var int64_t var_10h @ rbp-0x10
|           ; var int64_t var_8h @ rbp-0x8
|           ; var int64_t var_4h @ rbp-0x4
|           0x00401cad      55             push rbp
|           0x00401cae      4889e5         mov rbp, rsp
|           0x00401cb1      4883ec40       sub rsp, 0x40
|           0x00401cb5      48c745e00000.  mov qword [var_20h], 0
|           0x00401cbd      48c745e80000.  mov qword [var_18h], 0
|           0x00401cc5      48c745f00000.  mov qword [var_10h], 0
|           0x00401ccd      c645f800       mov byte [var_8h], 0
|           0x00401cd1      48b873557033.  movabs rax, 0x74735f7233705573 ; 'sUp3r_st'
|           0x00401cdb      48ba526f6e67.  movabs rdx, 0x7361705f676e6f52 ; 'Rong_pas'
|           0x00401ce5      488945c0       mov qword [var_40h], rax
|           0x00401ce9      488955c8       mov qword [var_38h], rdx
|           0x00401ced      48b873776f72.  movabs rax, 0x33323164726f7773 ; 'sword123'
|           0x00401cf7      488945d0       mov qword [var_30h], rax
|           0x00401cfb      66c745d82123   mov word [var_28h], 0x2321  ; '!#'
|           0x00401d01      c645da00       mov byte [var_26h], 0
|           0x00401d05      488d3dfcc209.  lea rdi, qword str.Enter_the_password ; 0x49e008 ; "Enter the password"
|           0x00401d0c      e88f5b0100     call 0x4178a0
|           0x00401d11      488d45e0       lea rax, qword [var_20h]
|           0x00401d15      4889c6         mov rsi, rax
|           0x00401d18      488d3dfcc209.  lea rdi, qword [0x0049e01b] ; "%s"
|           0x00401d1f      b800000000     mov eax, 0
|           0x00401d24      e857710000     call 0x408e80
|           0x00401d29      488d55c0       lea rdx, qword [var_40h]
|           0x00401d2d      488d45e0       lea rax, qword [var_20h]
|           0x00401d31      4889d6         mov rsi, rdx
|           0x00401d34      4889c7         mov rdi, rax
|           0x00401d37      e834f3ffff     call 0x401070
|           0x00401d3c      8945fc         mov dword [var_4h], eax
|           0x00401d3f      837dfc00       cmp dword [var_4h], 0
|       ,=< 0x00401d43      751a           jne 0x401d5f
|       |   0x00401d45      488d45e0       lea rax, qword [var_20h]
|       |   0x00401d49      4889c6         mov rsi, rax
|       |   0x00401d4c      488d3dcdc209.  lea rdi, qword str.Congrats__the_flag_is_flag__s ; 0x49e020 ; "Congrats, the flag is flag{\%s}"
|       |   0x00401d53      b800000000     mov eax, 0
|       |   0x00401d58      e8936f0000     call 0x408cf0
|      ,==< 0x00401d5d      eb0c           jmp 0x401d6b
|      |`-> 0x00401d5f      488d3dd9c209.  lea rdi, qword str.The_password_is_incorrect ; 0x49e03f ; "The password is incorrect"
|      |    0x00401d66      e8355b0100     call 0x4178a0
|      |    ; CODE XREF from main @ 0x401d5d
|      `--> 0x00401d6b      90             nop
|           0x00401d6c      c9             leave
\           0x00401d6d      c3             ret
[0x00401b90]>
```

And we can see the password right there in the disassembly "sUp3r_stRong_password123!#"


```zsh
➜  packed-locker git:(main) ✗ ./packed-locker.out 
Enter the password
sUp3r_stRong_password123!#
Congrats, the flag is flag{sUp3r_stRong_password123!#}%
➜  packed-locker git:(main) ✗ 
```

Thank you for reading, if you have any doubts you can contact me on twitter @siddhantc_