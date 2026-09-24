	.file	"main.c"
	.intel_syntax noprefix
	.text
	.section	.text.unlikely,"ax",@progbits
.LCOLDB0:
	.section	.text.hot,"ax",@progbits
.LHOTB0:
	.p2align 4
	.globl	process
	.type	process, @function
process:
.LFB40:
	.cfi_startproc
	endbr64
	mov	r8, rdi
	movsx	rdi, esi
	test	edi, edi
	jle	.L8
	xor	ecx, ecx
	xor	edx, edx
	jmp	.L7
	.p2align 4,,10
	.p2align 3
.L14:
	mov	esi, eax
	neg	esi
	movsx	rsi, esi
	add	rdx, rsi
	test	al, 1
	jne	.L4
	movsx	rsi, eax
	xor	rdx, rsi
.L4:
	cmp	eax, -1000
	jne	.L6
	add	rcx, 1
	cmp	rdi, rcx
	je	.L1
.L7:
	mov	eax, DWORD PTR [r8+rcx*4]
	test	eax, eax
	js	.L14
	lea	esi, 0[0+rax*8]
	sub	esi, eax
	movsx	rax, esi
	add	rax, rdx
	lea	rdx, 0[0+rax*8]
	sar	rax, 60
	or	rdx, rax
.L6:
	add	rdx, rcx
	add	rcx, 1
	cmp	rdi, rcx
	jne	.L7
.L1:
	mov	rax, rdx
	ret
	.cfi_endproc
	.section	.text.unlikely
	.cfi_startproc
	.type	process.cold, @function
process.cold:
.LFSB40:
.L8:
	xor	edx, edx
	jmp	.L1
	.cfi_endproc
.LFE40:
	.section	.text.hot
	.size	process, .-process
	.section	.text.unlikely
	.size	process.cold, .-process.cold
.LCOLDE0:
	.section	.text.hot
.LHOTE0:
	.section	.rodata.str1.1,"aMS",@progbits,1
.LC1:
	.string	"result = %ld, cycles = %llu\n"
	.section	.text.startup,"ax",@progbits
	.p2align 4
	.globl	main
	.type	main, @function
main:
.LFB43:
	.cfi_startproc
	endbr64
	push	r13
	.cfi_def_cfa_offset 16
	.cfi_offset 13, -16
	push	r12
	.cfi_def_cfa_offset 24
	.cfi_offset 12, -24
	push	rbp
	.cfi_def_cfa_offset 32
	.cfi_offset 6, -32
	lea	rbp, data[rip]
	push	rbx
	.cfi_def_cfa_offset 40
	.cfi_offset 3, -40
	mov	rsi, rbp
	lea	r8, 16384[rbp]
	push	rcx
	.cfi_def_cfa_offset 48
	mov	ecx, DWORD PTR seed[rip]
	jmp	.L18
	.p2align 4,,10
	.p2align 3
.L16:
	cmp	eax, 1
	je	.L24
	mov	eax, -1000
.L17:
	mov	DWORD PTR [rsi], eax
	add	rsi, 4
	cmp	r8, rsi
	je	.L25
.L18:
	imul	ecx, ecx, 1103515245
	add	ecx, 12345
	mov	edx, ecx
	shr	edx, 16
	and	edx, 32767
	mov	eax, edx
	imul	rax, rax, 1374389535
	shr	rax, 37
	imul	edi, eax, 100
	mov	eax, edx
	sub	eax, edi
	jne	.L16
	imul	ecx, ecx, 1103515245
	add	ecx, 12345
	mov	eax, ecx
	shr	eax, 16
	and	eax, 32767
	jmp	.L17
.L24:
	imul	ecx, ecx, 1103515245
	add	ecx, 12345
	mov	eax, ecx
	shr	eax, 16
	and	eax, 32767
	not	eax
	jmp	.L17
.L25:
	mov	DWORD PTR seed[rip], ecx
#APP
# 47 "main.c" 1
	CPUID
	RDTSC
	mov %edx, edi
	mov %eax, esi
	
# 0 "" 2
#NO_APP
	sal	rdi, 32
	mov	esi, esi
	mov	ebx, 2000
	xor	r12d, r12d
	or	rdi, rsi
	mov	r13, rdi
	.p2align 4,,10
	.p2align 3
.L19:
	mov	esi, 4096
	mov	rdi, rbp
	call	process
	add	r12, rax
	sub	ebx, 1
	jne	.L19
#APP
# 58 "main.c" 1
	RDTSCP
	mov %edx, esi
	mov %eax, edi
	CPUID
	
# 0 "" 2
#NO_APP
	mov	rcx, rsi
	mov	edi, edi
	mov	rdx, r12
	xor	eax, eax
	sal	rcx, 32
	lea	rsi, .LC1[rip]
	or	rcx, rdi
	mov	edi, 2
	sub	rcx, r13
	call	__printf_chk@PLT
	pop	rdx
	.cfi_def_cfa_offset 40
	xor	eax, eax
	pop	rbx
	.cfi_def_cfa_offset 32
	pop	rbp
	.cfi_def_cfa_offset 24
	pop	r12
	.cfi_def_cfa_offset 16
	pop	r13
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE43:
	.size	main, .-main
	.data
	.align 4
	.type	seed, @object
	.size	seed, 4
seed:
	.long	12345
	.local	data
	.comm	data,16384,32
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
	.section	.note.gnu.property,"a"
	.align 8
	.long	1f - 0f
	.long	4f - 1f
	.long	5
0:
	.string	"GNU"
1:
	.align 8
	.long	0xc0000002
	.long	3f - 2f
2:
	.long	0x3
3:
	.align 8
4:
