	.file	"main.c"
	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	process
	.type	process, @function
process:
.LFB40:
	.cfi_startproc
	endbr64
	mov	r8, rdi
	test	esi, esi
	jle	.L8
	movsx	rsi, esi
	xor	edi, edi
	xor	eax, eax
	jmp	.L7
	.p2align 4,,10
	.p2align 3
.L3:
	lea	ecx, 0[0+rdx*8]
	sub	ecx, edx
	movsx	rcx, ecx
	lea	rdx, [rcx+rax]
	lea	rax, 0[0+rdx*8]
	sar	rdx, 60
	or	rax, rdx
.L6:
	add	rax, rdi
	add	rdi, 1
	cmp	rsi, rdi
	je	.L15
.L7:
	mov	edx, DWORD PTR [r8+rdi*4]
	test	edx, edx
	jns	.L3
	mov	ecx, edx
	neg	ecx
	movsx	rcx, ecx
	add	rax, rcx
	movsx	rcx, edx
	xor	rcx, rax
	test	dl, 1
	cmove	rax, rcx
	cmp	edx, -1000
	jne	.L6
	add	rdi, 1
	cmp	rsi, rdi
	jne	.L7
.L15:
	ret
	.p2align 4,,10
	.p2align 3
.L8:
	xor	eax, eax
	ret
	.cfi_endproc
.LFE40:
	.size	process, .-process
	.section	.rodata.str1.1,"aMS",@progbits,1
.LC0:
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
	lea	rdi, 16384[rbp]
	sub	rsp, 8
	.cfi_def_cfa_offset 48
	mov	eax, DWORD PTR seed[rip]
	jmp	.L19
	.p2align 4,,10
	.p2align 3
.L26:
	imul	eax, eax, 1103515245
	add	eax, 12345
	mov	ecx, eax
	shr	ecx, 16
	and	ecx, 32767
.L18:
	mov	DWORD PTR [rsi], ecx
	add	rsi, 4
	cmp	rdi, rsi
	je	.L25
.L19:
	imul	eax, eax, 1103515245
	add	eax, 12345
	mov	ecx, eax
	shr	ecx, 16
	and	ecx, 32767
	mov	edx, ecx
	imul	rdx, rdx, 1374389535
	shr	rdx, 37
	imul	r8d, edx, 100
	mov	edx, ecx
	sub	edx, r8d
	je	.L26
	mov	ecx, -1000
	cmp	edx, 1
	jne	.L18
	imul	eax, eax, 1103515245
	add	rsi, 4
	add	eax, 12345
	mov	ecx, eax
	shr	ecx, 16
	and	ecx, 32767
	not	ecx
	mov	DWORD PTR -4[rsi], ecx
	cmp	rdi, rsi
	jne	.L19
.L25:
	mov	DWORD PTR seed[rip], eax
#APP
# 47 "main.c" 1
	CPUID
	RDTSC
	mov %edx, r13d
	mov %eax, esi
	
# 0 "" 2
#NO_APP
	sal	r13, 32
	mov	esi, esi
	mov	ebx, 2000
	xor	r12d, r12d
	or	r13, rsi
	.p2align 4,,10
	.p2align 3
.L20:
	mov	esi, 4096
	mov	rdi, rbp
	call	process
	add	r12, rax
	sub	ebx, 1
	jne	.L20
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
	lea	rsi, .LC0[rip]
	or	rcx, rdi
	mov	edi, 2
	sub	rcx, r13
	call	__printf_chk@PLT
	add	rsp, 8
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
