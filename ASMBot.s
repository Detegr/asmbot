.data

.text
.global _start

_start:
	call setup_socket
	movl $1, %eax
	movl $0, %ebx
	int $0x80

setup_socket:
	pushl %ebp
	movl %esp, %ebp
	subl $12, %esp  # socket(int,int,int)

	movl $2, -4(%ebp) # af_inet
	movl $0, -8(%ebp) # sock_dgram
	movl $0, -12(%ebp) # protocol 0

	movl $102, %eax # sys_socketcall
	movl $1,   %ebx # sys_socket
	movl -12(%ebp), %ecx
	int $0x80

	addl $12, %esp
	movl %ebp, %esp
	popl %ebp

	ret
