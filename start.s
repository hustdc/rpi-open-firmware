/*=============================================================================
Copyright (C) 2016 Kristina Brooks
All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

FILE DESCRIPTION
Entry.

A small explanation. The ROM loads bootcode.bin at 0x80000000 and jumps to
0x80000200. This region corresponds to L1/L2 cached IO and cache is never
evicted as long as we don't touch memory above that. This gives us 128KB
of memory at startup.

Exception names are from the public release from:
	brcm_usrlib\dag\vmcsx\vcfw\rtos\none\rtos_none.c

=============================================================================*/


.text

empty_space:
	.space 0x200

.include "ghetto.s"

/* main entry point */

.globl _start
.align 2
_start:
	mov r0, cpuid
	mov r5, r0

	# get addr of the exception vector table
	lea r1, __INTERRUPT_VECTORS
	mov r3, r1

	/*
	 * populate the exception vector table using PC relative labels
	 * so the code isnt position dependent
	 */
.macro RegExceptionHandler label, exception_number
	lea r2, Exc_\label
	st r2, (r1)
	add r1, #4
.endm

	RegExceptionHandler zero, #0
	RegExceptionHandler misaligned, #1
	RegExceptionHandler dividebyzero, #2
	RegExceptionHandler undefinedinstruction, #3
	RegExceptionHandler forbiddeninstruction, #4
	RegExceptionHandler illegalmemory, #5
	RegExceptionHandler buserror, #6
	RegExceptionHandler floatingpoint, #7
	RegExceptionHandler isp, #8
	RegExceptionHandler dummy, #9
	RegExceptionHandler icache, #10
	RegExceptionHandler veccore, #11
	RegExceptionHandler badl2alias, #12
	RegExceptionHandler breakpoint, #13
	RegExceptionHandler unknown, #14

	/*
	 * load the interrupt and normal stack pointers. these
	 * are chosen to be near the top of the available cache memory
	 */

	mov r28, #0x1D000 
	mov sp, #0x1C000

	/* set interrupt vector bases */
	mov r0, #IC0_VADDR
	st r3, (r0)
	mov r0, #IC1_VADDR
	st r3, (r0)

	/* jump to C code */
	mov r0, r5
	lea r1, _start

	ei

	bl _main

/************************************************************
 * Debug
 ************************************************************/

blinker:
	mov r1, #GPFSEL1
	ld r0, (r1)
	and r0, #(~(7<<18))
	or r0, #(1<<18)
	st r0, (r1)
	mov r1, #GPSET0
	mov r2, #GPCLR0
	mov r3, #(1<<16)
loop:
	st r3, (r1)
	mov r0, #0
delayloop1:
	add r0, #1
	cmp r0, #0x100000
	bne delayloop1
	st r3, (r2)
	mov r0, #0
delayloop2:
	add r0, #1
	cmp r0, #0x100000
	bne delayloop2
	b loop

/************************************************************
 * Exception Handling
 ************************************************************/

_sleh_generic_gate:
	# get faulting PC
	ld r1, 4(sp)
	# call the C exception handler
	b sleh_fatal


.macro ExceptionHandler label, exception_number
Exc_\label:
	mov r0, \exception_number
	b _sleh_generic_gate
.endm

	ExceptionHandler zero, #0
	ExceptionHandler misaligned, #1
	ExceptionHandler dividebyzero, #2
	ExceptionHandler undefinedinstruction, #3
	ExceptionHandler forbiddeninstruction, #4
	ExceptionHandler illegalmemory, #5
	ExceptionHandler buserror, #6
	ExceptionHandler floatingpoint, #7
	ExceptionHandler isp, #8
	ExceptionHandler dummy, #9
	ExceptionHandler icache, #10
	ExceptionHandler veccore, #11
	ExceptionHandler badl2alias, #12
	ExceptionHandler breakpoint, #13
	ExceptionHandler unknown, #14

/************************************************************
 * ISRs
 ************************************************************/

.align 4
__INTERRUPT_VECTORS:
	# 31 slots, 4 byte each for processor exceptions. patched to have the correct
	# exception handler routines at runtime to allow the code to be loaded anywhere
	.space 124, 0
