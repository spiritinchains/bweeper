; bweeper.asm
; A boot sector minesweeper game
; See LICENSE for copyright information


bits 16

org 0x7c00

; globals
; 14-byte buffer
BOARD           equ 0x50e       ; byte[140]     board layout [10x14]
; 14 byte buffer
POS_X           equ 0x5a8       ; byte          player position x
POS_Y           equ 0x5a9       ; byte          player position y
RUN_STATE       equ 0x5aa       ; byte          game running or ended
MINES           equ 0x5ab       ; byte          number of mines left
TEMP            equ 0x5ac       ; ?

; keycodes
KEY_UP          equ 0x48
KEY_DOWN        equ 0x50
KEY_LEFT        equ 0x4b
KEY_RIGHT       equ 0x4d
KEY_R           equ 0x13
KEY_X           equ 0x2d
KEY_C           equ 0x2e

; board
; layout: 10x14
; start: (8, 33)
; end: (17, 46)
BOARD_TOP       equ 8
BOARD_BOT       equ 17
BOARD_LEFT      equ 33
BOARD_RIGHT     equ 46
BOARD_OFFSET    equ 0x8000 + ((BOARD_TOP * 80) + BOARD_LEFT) * 2

; states
RUN_IDLE        equ 0x1
RUN_RUNNING     equ 0x2
RUN_WON         equ 0x4
RUN_LOST        equ 0x8

TILE_MARKED     equ 0x10
TILE_VISITED    equ 0x20
TILE_MINE       equ 0x40

MINE_FLAGGED    equ 0x07
MINE_FOUND      equ 0x0f

start:
    ; clear screen by changing vga mode
    mov ax, 3                       ; change vga mode to 3
    int 0x10
    ; set cursor
    mov ah, 2                       ; int 10h function : set cursor position
    mov bx, 0                       ; display page
    mov dx, 0x0821                  ; line 8 [dh=y], col 33 [dl=x]
    int 0x10
    sub dx, 0x0821                  ; convert to relative offset
    mov [POS_X], dx                 ; store to local memory
    mov ah, 1                       ; int 10h function : set cursor type
    mov cx, 7                       ; screen lines 0-7
    int 0x10

    ; init globals
    mov al, RUN_IDLE
    mov [RUN_STATE], al

    .main_loop:
        call draw_board
        ; xor bx, bx
        mov ah, 0                   ; int 16h function : retrieve keyboard input
        int 0x16                    ; output : al = ASCII code, ah = keycode
        call handle_input
    jmp .main_loop


draw_board:
    ; reads board data from memory and writes graphics to video memory
    pusha
    mov cx, 0xb000
    mov es, cx

    mov cx, 10
    mov di, BOARD_OFFSET
    mov si, BOARD
    mov bx, coltab
    ; iterate over all tiles and print char according to their state
    .L1:
        push cx
        mov cl, 14
        .L2:
            mov al, [si]            ; al = tile byte
            mov ah, al              ; ah = tile byte copy
            test al, TILE_VISITED
            jnz .discovered
            .undiscovered:
                mov ah, 0x3f        ; '?'
                test al, TILE_MARKED
                jz .not_flagged
                and ah, 0x7         ; dot symbol
                .not_flagged:
                mov al, 0x70
                jmp .output_cell
            .discovered:
                and ah, 0xf
                test al, TILE_MINE
                jz .no_mine
                .yes_mine:
                    mov al, 0x7c
                    jmp .output_cell
                .no_mine:
                    and al, 0xf
                    xlatb
                    cmp al, 0x80
                    je .output_cell
                    add ah, 0x30
            .output_cell:
            xchg al, ah
            mov es:[di], ax         ; write to vga buffer
            add di, 2
            inc si
        loop .L2
        pop cx
        add di, 132
    loop .L1
    
    popa
    ret

handle_input:
    ; ah = keycode
    pusha
    mov dx, [POS_X]                 ; dl = X, dh = Y

    call convert_flat
    mov al, 1

    cmp ah, KEY_UP
    je .moveU
    cmp ah, KEY_DOWN
    je .moveD
    cmp ah, KEY_LEFT
    je .moveL
    cmp ah, KEY_RIGHT
    je .moveR
    cmp ah, KEY_X
    je .mark
    cmp ah, KEY_C
    je .clear
    jne .end

    .moveU:
        neg al
    .moveD:
        add dh, al
        cmp dh, 10
        jae .end
        jmp .move
    .moveL:
        neg al
    .moveR:
        add dl, al
        cmp dl, 14
        jae .end
    .move:
        mov [POS_X], dx
        mov ah, 2                   ; int 10h function : set cursor position
        add dx, 0x0821
        int 0x10
        jmp .end
    
    .mark:
        mov al, [bx+BOARD]
        xor al, TILE_MARKED         ; toggle the bit that lists tile as marked
        mov [bx+BOARD], al
        jmp .end
    .clear:
        ; should states be managed elsewhere?
        mov al, [RUN_STATE]
        test al, RUN_IDLE
        jz .already_started
        call generate_board
        .already_started:
        shl al, 1
        mov [RUN_STATE], al
        call floodfill
        jmp .end

    .end:
    popa
    ret

convert_flat:
    ; convert 2D index in dx to 1D index, store to bx
    ; clobbers bx
    push ax
    mov ax, 14
    mul dh                          ; ax = 14 * relative Y
    add al, dl                      ; result <= 140 so ah can be ignored
    mov bx, ax
    pop ax
    ret

convert_box:
    ; convert 1D index in di to 2D, store to dx
    ; clobbers dx
    push ax
    mov ax, di
    sub ax, BOARD                   ; si is memory address, sub base to get offset
    mov dl, 14
    div dl                          ; ah = modulus (col), al = result (line)
    mov dx, ax
    ; xchg dl, dh
    pop ax
    ret

generate_board:
    ; each tile on board is a byte
    ; lower 4 bits denote mine numbers
    ; 0-8 : num. mines in surr. blocks, 15 : mine present
    ; bit 4 : has tile been marked
    ; bit 5 : has tile been discovered
    pusha
    ; clear board
    ; xor ax, ax
    ; mov es, ax
    ; xor di, di
    ; mov cx, 140
    ; rep stosb

    ; mov dx, [POS_X]                 ; dh = y, dl = x
    ; call convert_flat               ; bx = flat index
    mov ah, 0                       ; int 1Ah function : read clock count
    int 0x1A                        ; output : dx = low word, cx = high word

    sub sp, 50
    mov bp, sp

    ; generate 50 random numbers
    mov cx, 50
    ; mov si, 0
    xor si, si
    .L1:
        ; X1 = (23 * X0 + 17) % 140 ; [X = dl]
        mov ax, 23
        mul dl
        add ax, 17
        mov dh, 140
        div dh
        mov dl, ah
        mov [bp+si], dl             ; store to stack space
        inc si
    loop .L1

    ; place mines in board
    mov cx, 50
    ; mov si, 0
    xor si, si
    ; mov dx, bx
    xor bx, bx
    mov di, BOARD

    .minelaying:
        mov bl, [bp+si]             ; bl = mine index
        mov al, 0x4F                ; 0x4f = mine
        mov [di+bx], al             ; store mine to board index
        inc si
    loop .minelaying

    mov al, TILE_MINE

    mov cx, 140
    .place_nums:
        test al, [di]
        jnz .next
        call probe_neighbors
        mov ah, [TEMP]
        mov [di], ah
        .next:
        inc di
    loop .place_nums

    mov sp, bp
    add sp, 50
    popa
    ret

probe_neighbors:
    call convert_box
    pusha

    mov bx, 0x4001
    mov dl, 0
    mov si, nborsFull           ; see nbors explanation
    cmp dh, 0                   ; if on left edge
    je .left
    cmp dh, 13                  ; if on right edge
    jne .placenums
    neg bl                      ; on right edge (see nbors)
    .left:
    add si, 3                   ; on at least one edge, move to nborsLeft
    .placenums:
    xor ah, ah
    mov al, [si]                ; nbors offset
    imul bl                     ; +1 or -1
    add di, ax                  ; tile + nbor offset
    test bh, [di]               ; test if tile has mine
    jz .skip_inc
    cmp di, BOARD
    jl .skip_inc
    inc dl
    .skip_inc:
    sub di, ax
    inc si
    cmp si, (nborsFull+8)
    jl .placenums
    mov [TEMP], dl
    popa
    ret

floodfill:
    ; dx = line (dh) and col (dl) (relative)
    ; bx = unsigned tile index (flat)
    pusha

    ; test if out of bounds, exit if yes
    cmp dh, 10
    jae .end
    cmp dl, 14
    jae .end
    call convert_flat

    mov al, [bx+BOARD]              ; get tile
    test al, (TILE_MARKED | TILE_VISITED)
    jnz .end                        ; skip tile if marked or visited
    xor al, TILE_VISITED            ; uncover tile
    mov [bx+BOARD], al              ; update tile
    cmp al, TILE_VISITED
    jg .end                         ; if tile value > 0, don't recurse

    ; recursive calls
    
    inc dl                          ; x + 1
    inc bx                          ; i + 1
    call floodfill
    sub dl, 2                       ; x - 1
    sub bx, 2                       ; i - 1
    call floodfill
    inc dl                          ; revert x

    inc dh                          ; y + 1
    add bx, 15                      ; revert i, then i + (1*14) [down one row]
    call floodfill
    sub dh, 2                       ; y - 1
    sub bx, 28                      ; revert i, then i - (1*14) [up one row]
    call floodfill

    .end:
    popa
    ret

; data
coltab      db 0x80, 0x79, 0x72, 0x7C, 0x71, 0x74, 0x73, 0x70, 0x78

nborsFull   db 13, -1, -15
nborsLeft   db -13, 1, 15, 14, -14

; -----------------------------------------------------------------------------
; nbors explanation
; in 10x14 grid array, offsets for surrounding blocks:
;
;  -15  -14  -13
;   -1    0   +1
;  +13  +14  +15
;
; nborsFull iterates over the entire range
; nborsLeft skips the leftmost column
; by negating the numbers you get to skip the rightmost column
; -----------------------------------------------------------------------------


; pad bytes
times 510-($-$$) db 0
dw 0xAA55
