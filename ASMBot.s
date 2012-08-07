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
	leal -12(%ebp), %ecx # args ptr
	int $0x80
	
	cmp $0, %eax
	jle fail

	addl $16, %esp

	leave
	ret

/*
   struct sockaddr_in:
   short sin_family (AF_INET)
   unsigned short sin_port
   unsigned long s_addr (inet_pton())
   char[8] sin_zero

   size: 16 bytes
*/
connect:
	pushl %ebp
	movl %esp, %ebp
	subl $32, %esp # 26 used, aligned by 16

	# build sockaddr_in
	movw $2, -20(%ebp) # af_inet
	movw $2842, -18(%ebp) # htons(6667) == 2842
	movl $3568077907, -16(%ebp) # irc.quakenet.org

	movl %eax, -12(%ebp) # fd
	leal -20(%ebp), %edx # move sockaddr_in ptr via edx
	movl %edx, -8(%ebp) # sockaddr_in ptr
	movl $16, -4(%ebp) # addrlen

	movl $102, %eax # sys_socketcall
	movl $3, %ebx # sys_connect
	leal -12(%ebp), %ecx # args ptr
	int $0x80

	cmp $0, %eax
	jne fail

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
