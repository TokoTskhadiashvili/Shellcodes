# NOT FINISHED!!!

struc sockaddr_in
    .sin_family resw 1
    .sin_port resw 1
    .sin_addr resd 1
    .sin_zero resb 8
endstruc

section .rodata
    server_sockaddr istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2             ; AF_INET
        at sockaddr_in.sin_family, dw 0x901F        ; 8080 (CHANGE_ME)
        at sockaddr_in.sin_family, dd 0x0100007F    ; localhost (CHANGE_ME)
        at sockaddr_in.sin_zero, dd 0, 0            ; 0
    iend
    sockaddr_in_size equ $ - sockaddr_in

    response_size dq 4096

    error_target_timeout db "[ERROR]: Target timeout\n", 0

section .data
    client_sockaddr istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2             ; AF_INET
        at sockaddr_in.sin_family, dw 0x0000        ; 0000 (DEFAULT)
        at sockaddr_in.sin_family, dd 0x00000000    ; 0.0.0.0 (DEFAULT)
        at sockaddr_in.sin_zero, dd 0, 0            ; 0
    iend

    target_sockaddr istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2             ; AF_INET
        at sockaddr_in.sin_family, dw 0x0000        ; 0000 (DEFAULT)
        at sockaddr_in.sin_family, dd 0x00000000    ; 0.0.0.0 (DEFAULT)
        at sockaddr_in.sin_zero, dd 0, 0            ; 0
    iend

    payload_size dq 0

section .text
    global _start

_start:
    mov rax, 0x29                       ; socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    mov rdi, 2                          ; AF_INET
    mov rsi, 1                          ; SOCK_STREAM
    mov rdx, 6                          ; IPPROTO_TCP
    syscall

    mov rbx, rax

    mov rax, 0x31                       ; bind(sock, (sockaddr*)&server_addr, sizeof(server_addr))
    mov rdi, rbx                        ; sock
    lea rsi, [server_sockaddr]          ; (sockaddr*)&server_addr
    mov rdx, sockaddr_in_size           ; sizeof(server_addr)
    syscall

    cmp rax, -1
    je _end

    mov rax, 0x32                       ; listen(sock, 0)
    mov rdi, rbx                        ; sock
    mov rsi, 0x00                       ; 0
    syscall

    cmp rax, -1
    je _end

_accept:
    mov rax, 0x2B                       ; accept(sock, (sockaddr*)&client_addr, sizeof(client_addr))
    mov rdi, rbx                        ; sock
    lea rsi, [client_sockaddr]          ; (sockaddr*)&client_addr
    mov rdx, sockaddr_in_size           ; sizeof(client_addr)
    syscall

    cmp rax, -1
    je_end

    mov rax, 0x2D                       ; recv(sock, &target_sockaddr.sin_addr, 4, 0)
    mov rdi, rbx                        ; sock
    lea rsi, [target_sockaddr.sin_addr] ; &target_sockaddr.sin_addr
    mov rdx, 0x04                       ; 4
    mov r10, 0x00                       ; 0
    syscall

    cmp rax, -1
    je _end

    mov rax, 0x2D                       ; recv(sock, &target_sockaddr.sin_port, 2, 0)
    mov rdi, rbx                        ; sock
    lea rsi, [target_sockaddr.sin_port] ; &target_sockaddr.sin_port
    mov rdx, 0x02                       ; 2
    mov r10, 0x00                       ; 0
    syscall

    cmp rax, -1
    je _end

    mov rax, 0x2D                       ; recv(sock, &payload_size, 8, 0)
    mov rdi, rbx                        ; sock
    lea rsi, [payload_size]             ; &payload_size
    mov rdx, 0x08                       ; 8
    mov r10, 0x00                       ; 0
    syscall

    mov rax, 0x09                       ; mmap(NULL, payload_size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)
    mov rdi, 0x00                       ; NULL
    mov rsi, payload_size               ; payload_size
    mov rdx, 0x03                       ; PROT_READ | PROT_WRITE
    mov r10, 0x22                       ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -0x01                       ; -1
    mov r9, 0x00                        ; 0
    syscall

    xor r9, r9
    mov r9, rax

    mov rax, 0x2D                       ; recv(sock, *payload_buffer, payload_size, 0)
    mov rdi, rbx                        ; sock
    mov rsi, r9                         ; *payload_buffer
    mov rdx, payload_size               ; payload_size
    mov r10, 0x00                       ; 0
    syscall

    mov rax, 0x29                       ; socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    mov rdi, 2                          ; AF_INET
    mov rsi, 1                          ; SOCK_STREAM
    mov rdx, 6                          ; IPPROTO_TCP
    syscall

    mov rcx, rax

    mov rax, 0x2A                       ; connect(target_sock, (sockaddr*)&target_sockaddr, sizeof(target_sockaddr))
    mov rdi, rcx                        ; target_sock
    lea rsi, [target_sockaddr]          ; (sockaddr*)&target_sockaddr
    mov rdx, sockaddr_in_size           ; sizeof(target_sockaddr)
    syscall

    mov rax, 0x2C                       ; send(target_sock, *payload_buffer, payload_size, 0)
    mov rdi, rcx                        ; target_sock
    mov rsi, r9                         ; *payload_buffer
    mov rdx, payload_size               ; payload_size
    mov r10, 0x00                       ; 0
    syscall

    mov rax, 0x2D                       ; recv(target_sock, *response_buffer, response_size, 0)
    mov rdi, rcx                        ; target_sock
    mov rsi, r8                         ; *response_buffer
    mov rdx, response_size              ; response_size
    mov r10, 0x00                       ; 0
    syscall

    mov rax, 0x03                       ; close(target_sock)
    mov rdi, rcx                        ; sock
    syscall

    mov rax, 0x2C                       ; send(sock, *response_buffer, response_size, 0)
    mov rdi, rbx                        ; sock
    mov rsi, r8                         ; *response_buffer
    mov rdx, response_size              ; response_size
    mov r10, 0                          ; 0
    syscall

    jmp _accept

_end:
    mov rax, 0x03                       ; close(sock)
    mov rdi, rbx                        ; sock
    syscall

    mov rax, 0x3C                       ; exit(0)
    mov rdi, 0x00                       ; 0
    syscall
