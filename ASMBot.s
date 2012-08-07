.text
.global _start

_start:
	call setup_socket
	call connect
	movl $1, %eax
	movl $0, %ebx
	int $0x80

setup_socket:
	pushl %ebp
	movl %esp, %ebp
	subl $16, %esp  # socket(int,int,int), align stack by 16

	movl $2, -12(%ebp) # af_inet
	movl $1, -8(%ebp) # sock_dgram
	movl $0, -4(%ebp) # protocol 0

	movl $102, %eax # sys_socketcall
	movl $1,   %ebx # sys_socket
	leal -12(%ebp), %ecx
	int $0x80
	
	cmp $0, %eax
	jle fail

	addl $16, %esp

	leave
	ret

connect:
	pushl %ebp
	movl %esp, %ebp

	leave
	ret

fail:
	pushl %eax
	movl $4, %eax
	movl $1, %ebx
	movl $errmsg, %ecx
	movl $errlen, %edx
	int $0x80

	popl %ebx
	movl $1, %eax
	int $0x80

.data
errmsg:
	.string "Error!\n"
	errlen = . - errmsg
