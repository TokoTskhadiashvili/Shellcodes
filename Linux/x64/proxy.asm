; NOT FINISHED!

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

    buffer_size dd 4096

section .data
    target_sockaddr istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2         ; AF_INET
        at sockaddr_in.sin_port, dw 0x0000      ; 0 (DEFAULT)
        at sockaddr_in.sin_addr, dd 0x00000000  ; 0.0.0.0 (DEFAULT)
        at sockaddr_in.sin_zero, dd 0, 0        ; 0
    iend
    target_sockaddr_size equ $ - target_sockaddr

    client_sockaddr istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2         ; AF_INET
        at sockaddr_in.sin_port, dw 0x0000      ; 0 (DEFAULT)
        at sockaddr_in.sin_addr, dd 0x00000000  ; 0.0.0.0 (DEFAULT)
        at sockaddr_in.sin_zero, dd 0, 0        ; 0
    iend
    client_sockaddr_size equ $ - client_sockaddr

    target_info db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ; PORT:IPv4

    msg_conn_refused db 0x11, 0x11, 0x11, 0x00
    msg_conn_success db 0xFF, 0xFF, 0xFF, 0x00
    msg_inte_errored db 0xAA, 0xAA, 0xAA, 0x00

section .text
    global _start

clean_buffer:
    xor rax, rax                        ; counter
    mov rdi, [buffer_size]              ; buffer_size

.loop:
    mov byte [r12 + rax], 0x00
    inc rax

    cmp rax, rdi
    je .done
    jmp .loop
.done:
    ret

_start:
    mov rax, 0x29                       ; socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    mov rdi, 0x02                       ; AF_INET
    mov rsi, 0x01                       ; SOCK_STREAM
    mov rdx, 0x06                       ; IPPROTO_TCP
    syscall

    mov rbx, rax                        ; server_sock

    mov rax, 0x31                       ; bind(server_sock, (sockaddr*)&server_sockaddr, sizeof(server_sockaddr))
    mov rdi, rbx                        ; server_sock
    lea rsi, [server_sockaddr]          ; (sockaddr*)&server_sockaddr
    mov rdx, [server_sockaddr_size]     ; sizeof(server_sockaddr)
    syscall

    cmp rax, -0x01
    je _bind_listen_error_end

    mov rax, 0x32                       ; listen(server_sock, 1)
    mov rdi, rbx                        ; server_sock
    mov rsi, 0x01                       ; 1
    syscall

    cmp rax, -0x01
    je _bind_listen_error_end

accept:
    mov rax, 0x2B                       ; accept(server_sock, (sockaddr*)&client_sockaddr, sizeof(client_sockaddr))
    mov rdi, rbx                        ; server_sock
    lea rsi, [client_sockaddr]          ; (sockaddr*)&client_sockaddr
    lea rdx, [client_sockaddr_size]     ; sizeof(client_sockaddr)
    syscall

    cmp rax, -0x01
    je accept

    mov rcx, rax                        ; client_sock

    mov rax, 0x02D                      ; recv(client_sock, &target_info, 6, 0)
    mov rdi, rcx                        ; client_sock
    lea rsi, [target_info]              ; target_info
    mov rdx, 0x06                       ; 6
    xor r10, r10                        ; 0
    syscall

    ; Convert port from host byte order to network byte order
    mov ax, word [target_info]
    xchg al, ah
    mov word [target_sockaddr + sockaddr_in.sin_port], ax

    ; Convert IPv4 address from host byte order to network byte order
    mov eax, dword [target_info + 2]
    bswap eax
    mov dword [target_info + 2], eax
    mov dword [target_sockaddr + sockaddr_in.sin_addr], eax

    mov rax, 0x29                       ; socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    mov rdi, 0x02                       ; AF_INET
    mov rsi, 0x01                       ; SOCK_STREAM
    mov rdx, 0x06                       ; IPPROTO_TCP
    syscall

    mov r14, rax                        ; target_sock

    mov rax, 0x2A                       ; connect(target_sock, (sockaddr*)&target_sockaddr, sizeof(target_sockaddr))
    mov rdi, r14                        ; target_sock
    lea rsi, [target_sockaddr]          ; (sockaddr*)&target_sockaddr
    mov rdx, [target_sockaddr_size]     ; sizeof(target_sockaddr)
    syscall

    cmp rax, -0x01
    je _conn_refused_error

    mov rax, 0x09                       ; mmap(NULL, buffer_size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)
    xor rdi, rdi                        ; NULL
    mov rsi, [buffer_size]              ; buffer_size
    mov rdx, 0x03                       ; PROT_READ | PROT_WRITE
    mov r10, 0x22                       ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -0x01                       ; -1
    xor r9, r9                          ; 0
    syscall

    cmp rax, -0x01
    je _buffer_allocation_error

    mov r12, rax                        ; buffer_ptr

    call clean_buffer

    mov rax, 0x2C                       ; send(client_sock, &msg_conn_success, 4, 0)
    mov rdi, r14                        ; client_sock
    lea rsi, [msg_conn_success]         ; &msg_conn_success
    mov rdx, 0x04                       ; 4
    xor r10, r10                        ; 0
    syscall

_communication_loop:
    mov rax, 0x02D                      ; recv(client_sock, buffer_ptr, buffer_size, 0)
    mov rdi, rcx                        ; client_sock
    mov rsi, r12                        ; buffer_ptr
    mov rdx, [buffer_size]              ; buffer_size
    xor r10, r10                        ; 0
    syscall

    mov rax, 0x2C                       ; send(target_sock, buffer_ptr, buffer_size, 0)
    mov rdi, r14                        ; target_sock
    mov rsi, r12                        ; buffer_ptr
    mov rdx, [buffer_size]              ; buffer_size
    xor r10, r10
    syscall

    call clean_buffer

    mov rax, 0x02D                      ; recv(target_sock, buffer_ptr, buffer_size, 0)
    mov rdi, r14                        ; target_sock
    mov rsi, r12                        ; buffer_ptr
    mov rdx, [buffer_size]              ; buffer_size
    xor r10, r10                        ; 0
    syscall

    mov rax, 0x2C                       ; send(client_sock, buffer_ptr, buffer_size, 0)
    mov rdi, rcx                        ; client_sock
    mov rsi, r12                        ; buffer_ptr
    mov rdx, [buffer_size]              ; buffer_size
    xor r10, r10                        ; 0
    syscall

    call clean_buffer

jmp _communication_loop

_conn_refused_error:
    mov rax, 0x2C                       ; send(client_sock, &msg_conn_refused, 4, 0)
    mov rdi, r14                        ; client_sock
    lea rsi, [msg_conn_refused]         ; &msg_conn_refused
    mov rdx, 0x04                       ; 4
    xor r10, r10                        ; 0
    syscall

    mov rax, 0x03                       ; close(client_sock)
    mov rdi, rcx                        ; client_sock
    syscall

    mov rax, 0x03                       ; close(target_sock)
    mov rdi, r14                        ; target_sock
    syscall

    xor rcx, rcx
    xor r14, r14

    jmp accept

_buffer_allocation_error:
    mov rax, 0x2C                       ; send(client_sock, &msg_inte_errored, 4, 0)
    mov rdi, r14                        ; client_sock
    lea rsi, [msg_inte_errored]         ; &msg_inte_errored
    mov rdx, 0x04                       ; 4
    xor r10, r10                        ; 0
    syscall

    mov rax, 0x03                       ; close(client_sock)
    mov rdi, rcx                        ; client_sock
    syscall

    mov rax, 0x03                       ; close(target_sock)
    mov rdi, r14                        ; target_sock
    syscall

    xor rcx, rcx
    xor r14, r14

    jmp accept

_bind_listen_error_end:
    mov rax, 0x03                       ; close(server_sock)
    mov rdi, rbx                        ; server_sock
    syscall

    mov rax, 0x3C                       ; exit(0)
    xor rdi, rdi                        ; 0
    syscall
