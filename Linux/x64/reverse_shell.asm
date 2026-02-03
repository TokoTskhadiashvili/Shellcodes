struc sockaddr_in
    .sin_family resw 1
    .sin_port resw 1
    .sin_addr resd 1
    .sin_zero resb 8
endstruc

section .data
    pop_sa istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2         ; AF_INET
        at sockaddr_in.sin_port, dw 0x1F90      ; 8080 (CHANGE_ME)
        at sockaddr_in.sin_addr, dd 0           ; localhost (CHANGE_ME)
        at sockaddr_in.sin_zero, dd 0, 0        ; 0
    iend
    sockaddr_in_size equ $ - pop_sa

section .text
    global _start

_start:
    xor rax, rax
    xor rdi, rdi
    xor rsi, rsi
    xor rdx, rdx

    mov rax, 0x29                   ; socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    mov rdi, 2                      ; AF_INET
    mov rsi, 1                      ; SOCK_STREAM
    mov rdx, 6                      ; IPPROTO_TCP
    syscall

    mov rbx, rax
    xor rax, rax

    mov rax, 0x2A                   ; connect(sock, (sockaddr*)&sockaddr_in, sizeof(sockaddr_in))
    mov rdi, rbx                    ; sock
    lea rsi, [sockaddr_in]            ; (sockaddr*)&sockaddr_in
    mov rdx, sockaddr_in_size       ; sizeof(sockaddr_in)
    syscall

    cmp rax, 0
    jne _end

_end:
    mov rax, 0x3C                   ; exit(0)
    mov rdi, 0x00                   ; 0