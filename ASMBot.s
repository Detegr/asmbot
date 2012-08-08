.text
.global _start

_start:
	call setup_socket
	call connect
	call identify
	call recvloop
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
	subl $32, %esp # align stack by 16

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

	movl -12(%ebp), %eax # fd

	addl $32, %esp
	leave
	ret

/*
   Sends a string to a socket.
   %eax - socket fd
   %ebx
   %ecx - string
   %edx - string length
*/
send:
	pushl %ebp
	movl %esp, %ebp
	subl $16, %esp

	movl %eax, -16(%ebp)
	movl %ecx, -12(%ebp)
	movl %edx, -8(%ebp)
	movl $0, -4(%ebp)
	jmp sendagain
sendagain:
	movl $102, %eax # sys_socketcall
	movl $9, %ebx # sys_send
	leal -16(%ebp), %ecx
	int $0x80

	cmp $0, %eax
	jle fail
	cmp %eax, %edx
	jl sendmore

	movl -16(%ebp), %eax # restore fd
	addl $16, %esp

	leave
	ret

sendmore:
	subl %edx, %eax
	movl %edx, -8(%ebp)
	jmp sendagain

identify:
	pushl %ebp
	movl %esp, %ebp

	movl $nick, %ecx
	movl $nicklen, %edx
	call send
	movl $user, %ecx
	movl $userlen, %edx
	call send

	leave
	ret

recvloop:
	pushl %ebp
	movl %esp, %ebp
	subl $4112, %esp
	movl %eax, -16(%ebp) # fd
	leal -4112(%ebp), %edx # buffer ptr via edx
	movl %edx, -12(%ebp)
	movl $4096, -8(%ebp) # len
	movl $0, -4(%ebp) #flags
recvagain:
	movl $102, %eax # sys_socketcall
	movl $10, %ebx # sys_recv
	leal -16(%ebp), %ecx
	int $0x80

	cmp $0, %eax
	jle fail

	#print received string
	movl %eax, %edx
	movl $4, %eax
	movl $1, %ebx
	leal -4112(%ebp), %ecx
	int $0x80

	pushl %eax
	leal -4112(%ebp), %eax
	call handle_str

	popl %eax
	cmp $0, %eax
	jg recvagain
	je done
done:
	addl $4112, %esp
	leave
	ret

# Assumes buffer in %eax
handle_str:
	pushl %ebp
	movl %esp, %ebp
	call check_pingpong

	leave
	ret

# Assumes buffer in %eax
check_pingpong:
	pushl %ebp
	movl %esp, %ebp
	movl $ping, %esi
	movl %eax, %edi
	movl $4, %ecx
	repe cmpsb
	je isping
	jmp out
out:
	addl $4, %esp
	leave
	ret

isping:
	movl %eax, %ecx
	incl %ecx
	movl $0x4F, (%ecx)
	movl $4, %eax
	movl $1, %ebx
	movl $10, %edx
	int $0x80
	jmp out

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
user:
	.asciz "USER ASMBot ASMBot * :ASMBot\r\n"
	userlen= . - user
nick:
	.asciz "NICK ASMBot\r\n"
	nicklen= . - nick
ping:
	.asciz "PING"
errmsg:
	.string "Error!\n"
	errlen = . - errmsg
