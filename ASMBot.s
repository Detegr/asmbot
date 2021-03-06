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
	movl %eax, -12(%ebp) # fd
	movl (ip), %eax
	movl %eax, -16(%ebp)

	xorl %eax, %eax
	movw (port), %ax
	ror $8, %ax # rotate right by 8 bits to get the word to network byte order
	movw %ax, -18(%ebp)

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
	jl fail
	cmp %eax, %edx
	jl sendmore

	movl $4, %eax
	movl $1, %ebx
	movl -12(%ebp), %ecx
	movl -8(%ebp), %edx
	int $0x80

	# restore registers
	movl -16(%ebp), %eax
	movl -12(%ebp), %ecx
	movl -8(%ebp), %edx
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
	leal -4112(%ebp), %edi # for comparing
	movl -16(%ebp), %eax # fd
	call handle_str

#clear the buffer
	leal -4112(%ebp), %edi
	movl $4096, %ecx
	movb $0, %al
	rep stosb

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
checkstrings:
	movl %eax, %ebx # fd
	movl %edi, %edx
	xorl %eax, %eax
	movb $'\n', %al
	cld
	repne scasb
	pushl %edi # \n[c] c=0 or c=char

	movl %ebx, %eax
	leal -1(%edi), %ebx # [\n]c
	movb $0, (%ebx) # replace newline with 0x0 [0]c
	incl %ebx # 0[c]
	movl %edx, %edi # [s]tart
	movl %ebx, %edx # 0[c]
	call check_pingpong # fd in %eax
	popl %ecx
	leal (%ecx), %edi
	cmp $0, (%edi)
	jne checkstrings
	leave
	ret

# Assumes buffer in %eax
check_pingpong:
	pushl %ebp
	movl %esp, %ebp
	movl $ping, %esi
	movl $4, %ecx
	repe cmpsb
	je isping # fd in %eax
	jmp out
out:
	leave
	ret

isping:
	call sendpong
	jmp out 

sendpong:
	pushl %ebp
	movl %esp, %ebp
	subl $32, %esp

	pushl %edi
	movl $ping, %esi
	movl $pinglen, %ecx
	leal -32(%ebp), %edi
	rep movsb

	leal -31(%ebp), %edx
	movb $'O', (%edx)
	leal -26(%ebp), %edi
	popl %esi
	addl $2, %esi
	movl $10, %ecx
	rep movsb

	leal -32(%ebp), %ecx
	movl $pinglen, %edx
	call send

	addl $32, %esp
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
ip:
	.byte 83,140,172,212 # irc.quakenet.org
port:
	.int 6667
user:
	.ascii "USER ASMBot 0 * :ASMBot\r\n"
	userlen= . - user
nick:
	.ascii "NICK ASMBot\r\n"
	nicklen= . - nick
ping:
	.ascii "PING :XXXXXXXXXX\r\n"
	pinglen = . - ping
errmsg:
	.asciz "Error!\n"
	errlen = . - errmsg
