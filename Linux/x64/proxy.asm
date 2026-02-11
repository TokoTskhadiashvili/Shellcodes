struc sockaddr_in
    .sin_family resw 1
    .sin_port resw 1
    .sin_addr resd 1
    .sin_zero resb 8
endstruc

section .rodata
    server_sockaddr istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2         ; AF_INET
        at sockaddr_in.sin_port, dw 0x901F      ; 8080 (CHANGE_ME)
        at sockaddr_in.sin_addr, dd 0x00000000  ; 0.0.0.0
        at sockaddr_in.sin_zero, dd 0, 0        ; 0
    iend
    server_sockaddr_size equ $ - server_sockaddr
    target_sockaddr_size dq 16
    client_sockaddr_size dq 16

    buffer_size dq 4096

section .data
    target_sockaddr istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2         ; AF_INET
        at sockaddr_in.sin_port, dw 0x0000      ; 0 (DEFAULT)
        at sockaddr_in.sin_addr, dd 0x00000000  ; 0.0.0.0 (DEFAULT)
        at sockaddr_in.sin_zero, dd 0, 0        ; 0
    iend

    client_sockaddr istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2         ; AF_INET
        at sockaddr_in.sin_port, dw 0x0000      ; 0 (DEFAULT)
        at sockaddr_in.sin_addr, dd 0x00000000  ; 0.0.0.0 (DEFAULT)
        at sockaddr_in.sin_zero, dd 0, 0        ; 0
    iend

    msg_conn_refused db 0x01
    msg_conn_success db 0x02
    msg_inte_errored db 0x03

    server_sock dq 0x0000000000000000
    client_sock dq 0x0000000000000000
    target_sock dq 0x0000000000000000

    buffer_ptr dq 0x0000000000000000
    recv_data_size dq 0x0000000000000000

fn_clean_buffer:
    mov rdi, qword [buffer_ptr]
    mov rcx, [buffer_size]
    xor al, al
    rep stosb
    ret

fn_close_target_sock:
    mov rax, 0x03                       ; close(target_sock)
    mov rdi, qword [target_sock]        ; target_sock
    syscall
    ret

fn_close_client_sock:
    mov rax, 0x03                       ; close(client_sock)
    mov rdi, qword [client_sock]        ; client_sock
    syscall
    ret

fn_conn_refused:
    mov rax, 0x03                       ; close(target_sock)
    mov rdi, qword [target_sock]        ; target_sock
    syscall
    ret

section .text
    global _start

_start:
    mov rax, 0x09                       ; mmap(NULL, buffer_size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)
    xor rdi, rdi                        ; NULL
    mov rsi, [buffer_size]              ; buffer_size
    mov rdx, 0x03                       ; PROT_READ | PROT_WRITE
    mov r10, 0x22                       ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -0x01                       ; -1
    xor r9, r9                          ; 0
    syscall

    mov qword [buffer_ptr], rax
    call fn_clean_buffer

    mov rax, 0x29                       ; socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    mov rdi, 0x02                       ; AF_INET
    mov rsi, 0x01                       ; SOCK_STREAM
    mov rdx, 0x06                       ; IPPROTO_TCP
    syscall

    mov qword [server_sock], rax        ; server_sock

    mov rax, 0x31                       ; bind(server_sock, (sockaddr*)&server_sockaddr, sizeof(server_sockaddr))
    mov rdi, qword [server_sock]        ; server_sock
    lea rsi, [server_sockaddr]          ; (sockaddr*)&server_sockaddr
    mov rdx, server_sockaddr_size       ; sizeof(server_sockaddr)
    syscall

    mov rax, 0x32                       ; listen(server_sock, 1)
    mov rdi, qword [server_sock]        ; server_sock
    mov rsi, 0x01                       ; 1
    syscall

.accept:
    mov rax, 0x2B                       ; accept(server_sock, (sockaddr*)&client_sockaddr, sizeof(client_sockaddr))
    mov rdi, qword [server_sock]        ; server_sock
    lea rsi, [client_sockaddr]          ; (sockaddr*)&client_sockaddr
    lea rdx, [client_sockaddr_size]     ; sizeof(client_sockaddr)
    syscall

    cmp rax, -0x01
    js .accept

    mov qword [client_sock], rax        ; client_sock

.recv_target_info:
    mov rax, 0x2D                       ; recv(client_sock, buffer_ptr, 6, 0)
    mov rdi, qword [client_sock]        ; client_sock
    mov rsi, buffer_ptr                 ; buffer_ptr
    mov rdx, 0x06                       ; 6
    xor r10, r10                        ; 0
    xor r8, r8
    xor r9, r9
    syscall

    cmp rax, 0x00
    jle .accept

    mov ax, word [buffer_ptr]
    xchg al, ah
    mov word [target_sockaddr + sockaddr_in.sin_port], ax

    mov eax, dword [buffer_ptr + 2]
    mov dword [target_sockaddr + sockaddr_in.sin_addr], eax

    mov rax, 0x29                       ; socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    mov rdi, 0x02                       ; AF_INET
    mov rsi, 0x01                       ; SOCK_STREAM
    mov rdx, 0x06                       ; IPPROTO_TCP
    syscall

    mov qword [target_sock], rax        ; target_sock

    mov rax, 0x2A                       ; connect(target_sock, (sockaddr*)&target_sockaddr, sizeof(target_sockaddr))
    mov rdi, qword [target_sock]        ; target_sock
    lea rsi, [target_sockaddr]          ; (sockaddr*)&target_sockaddr
    mov rdx, [target_sockaddr_size]     ; sizeof(target_sockaddr)
    syscall

    cmp rax, -0x01
    jne .communication_loop
    call fn_conn_refused
    jmp .accept

    mov rax, 0x48                       ; fcntl(client_sock, F_SETFL, O_NONBLOCK)
    mov rdi, qword [client_sock]        ; client_sock
    mov rsi, 0x4                        ; F_SETFL
    mov rdx, 0x04                       ; O_NONBLOCK
    syscall

    mov rax, 0x48                       ; fcntl(target_sock, F_SETFL, O_NONBLOCK)
    mov rdi, qword [target_sock]        ; target_sock
    mov rsi, 0x4                        ; F_SETFL
    mov rdx, 0x04                       ; O_NONBLOCK
    syscall

.communication_loop:
    mov rax, 0x2D                       ; recv(client_sock, buffer_ptr, buffer_size, 0)
    mov rdi, qword [client_sock]        ; client_sock
    mov rsi, buffer_ptr                 ; buffer_ptr
    mov rdx, [buffer_size]              ; buffer_size
    xor r10, r10                        ; 0
    xor r8, r8
    xor r9, r9
    syscall

    cmp rax, 0x00
    je .reset_server

    mov qword [recv_data_size], rax

    mov rax, 0x2C                       ; send(target_sock, buffer_ptr, recv_data_size, 0)
    mov rdi, qword [target_sock]        ; target_sock
    mov rsi, buffer_ptr                 ; buffer_ptr
    mov rdx, qword [recv_data_size]     ; recv_data_size
    xor r10, r10                        ; 0
    syscall

    mov rax, 0x2D                       ; recv(target_sock, buffer_ptr, buffer_size, 0)
    mov rdi, qword [target_sock]        ; target_sock
    mov rsi, buffer_ptr                 ; buffer_ptr
    mov rdx, [buffer_size]              ; buffer_size
    xor r10, r10                        ; 0
    xor r8, r8
    xor r9, r9
    syscall

    cmp rax, 0x00
    je .reset_server

    mov qword [recv_data_size], rax

    mov rax, 0x2C                       ; send(client_sock, buffer_ptr, recv_data_size, 0)
    mov rdi, qword [client_sock]        ; client_sock
    mov rsi, buffer_ptr                 ; buffer_ptr
    mov rdx, [recv_data_size]           ; recv_data_size
    xor r10, r10                        ; 0
    syscall

    jmp .communication_loop

.reset_server:
    call fn_close_client_sock
    call fn_close_target_sock
    jmp .accept
