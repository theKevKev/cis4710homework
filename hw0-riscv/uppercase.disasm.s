
uppercase.bin:     file format elf32-littleriscv


Disassembly of section .text:

00010074 <_start>:
   10074:	ffff2517          	auipc	a0,0xffff2
   10078:	f8c50513          	addi	a0,a0,-116 # 2000 <__DATA_BEGIN__>

0001007c <loop>:
   1007c:	00050583          	lb	a1,0(a0)
   10080:	00058a63          	beqz	a1,10094 <end_program>
   10084:	02058593          	addi	a1,a1,32
   10088:	00b50023          	sb	a1,0(a0)
   1008c:	00150513          	addi	a0,a0,1
   10090:	fedff06f          	j	1007c <loop>

00010094 <end_program>:
   10094:	0000006f          	j	10094 <end_program>
