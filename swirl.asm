    section          .text
    global           apply_swirl

; Function:
    apply_swirl
; Parameters (32-bit cdecl calling convention, pushed right-to-left):
    ;                [ebp+8] - unsigned char *imageData (input image)
    ;                [ebp+12] - unsigned char *outBuffer (output image)
    ;                [ebp+16] - int width
    ;                [ebp+20] - int height
    ;                [ebp+24] - int channels
    ;                [ebp+28] - float strength
    ;                [ebp+32] - int centerX
    ;                [ebp+36] - int centerY

apply_swirl:
    ;                Function prologue
    push             ebp
    mov              ebp, esp
    push             ebx
    push             esi
    push             edi

    ; Local variables (from high to low address):
    ;                [ebp-16] = width
    ;                [ebp-20] = height
    ;                [ebp-24] = channels
    ;                [ebp-28] = current y
    ;                [ebp-32] = current x
    ;                [ebp-36] = temp for: x - centerX
    ;                [ebp-40] = temp for: y - centerY
    ;                [ebp-44] = distance from center (float)
    ;                [ebp-48] = current angle (float)
    ;                [ebp-52] = saved pixel offset
    ;               [ebp-56] = swirl amount factor = 1 - dist / maxDist, maxDist = min(width, height) / 2 
    ;                [ebp-60] = new calculated angle = current angle + strength * swirl amount factor
    ;                [ebp-64] = srcX (source x coordinate)
    ;                [ebp-68] = srcY (source y coordinate)
    sub              esp, 68

    ;                ========================================================================
    ;                REGISTERS USAGE
    ;                ========================================================================
    ;                esi - pointer to imageData (input)
    ;                edi - pointer to outBuffer (output)

    ;                Load and save parameters
    mov              esi, [ebp+8] ; esi = imageData pointer (preserved)
    mov              edi, [ebp+12] ; edi = outBuffer pointer (preserved)

    mov              eax, [ebp+16] ; load width
    mov              [ebp-16], eax ; save width

    mov              eax, [ebp+20] ; load height
    mov              [ebp-20], eax ; save height

    mov              eax, [ebp+24] ; load channels
    mov              [ebp-24], eax ; save channels

    ;                Initialize y loop counter
    mov              dword [ebp-28], 0 ; y = 0

.loop_y:
    ;                check if y < height
    mov              eax, [ebp-28] ; eax = y
    cmp              eax, [ebp-20] ; compare with height
    jge              .end_loop_y ; if y >= height, exit

    ;                Initialize x loop counter
    mov              dword [ebp-32], 0 ; x = 0

.loop_x:
    ;                if x < width
    mov              eax, [ebp-32] ; eax = x
    cmp              eax, [ebp-16] ; compare with width
    jge              .end_loop_x ; if x >= width, exit

    ;
    ; calculate source pixel offset:
    ; offset           = (y * width + x) * channels
    mov              eax, [ebp-28] ; eax = y
    imul             eax, [ebp-16] ; eax = y * width
    add              eax, [ebp-32] ; eax = y * width + x
    imul             eax, [ebp-24] ; eax = (y * width + x) * channels

    ;                now eax contains the offset for the current pixel
    ;                esi + eax = pointer to source pixel
    ;                edi + eax = pointer to destination pixel
    ;                ebx, ecx, edx are free to use

    ; ========================================================================
    ; TRANSFORMATION:
    mov             [ebp-52], eax ; save pixel offset
    
    mov             eax, [ebp-32] ; eax = x
    mov             [ebp-36], eax ; [ebp-36] = x
    mov             eax, [ebp-28] ; eax = y
    mov             [ebp-40], eax ; [ebp-40] = y

    mov             eax, [ebp+32] ; eax = centerX
    sub             [ebp-36], eax ; [ebp-36] = x - centerX
    mov             eax, [ebp+36] ; eax = centerY
    sub             [ebp-40], eax ; [ebp-40] = y - centerY

    ; now dx = [ebp-36] = x - centerX
    ;     dy = [ebp-40] = y - centerY

    ; calculate distance from center as dist = sqrt(dx*dx + dy*dy)
    mov             ebx, [ebp-36] ; ebx = dx
    imul            ebx, ebx      ; ebx = dx*dx
    mov             edx, [ebp-40] ; edx = dy
    imul            edx, edx      ; edx = dy*dy
    add             ebx, edx      ; ebx = dx*dx + dy*dy

    ; now ebx = dx*dx + dy*dy, store it to memory and calculate sqrt
    mov             [ebp-44], ebx ; store dx*dx + dy*dy to memory
    fild dword      [ebp-44]      ; st(0) = float(dx*dx + dy*dy)
    fsqrt                         ; st(0) = sqrt(dx*dx + dy*dy)
    fstp dword      [ebp-44]      ; store distance back in [ebp-44]

    ; now [ebp-44] = distance from center as dist = sqrt(dx*dx + dy*dy)

    ; Calculate current angle = atan2(dy, dx)
    fild            dword [ebp-40] ; st(0) = dy (as float)
    fild            dword [ebp-36] ; st(0) = dx, st(1) = dy
    fpatan                         ; st(0) = atan2(dy, dx)

    fstp            dword [ebp-48] ; store current angle in [ebp-48]
    ; now [ebp-48] = current angle

    ; calculate swirl amount factor = 1 - dist / maxDist
    ; maxDist = min(width, height) / 2

    ; first maxDist:
    mov             eax, [ebp-16] ; eax = width
    mov             edx, [ebp-20] ; edx = height
    cmp             eax, edx
    jle             .width_is_min
    mov             eax, edx ; eax = min(width, height)

.width_is_min:
    shr             eax, 1 ; eax = min(width, height) / 2 by right shifting
    ; now eax = maxDist (integer)
    
    ; check if distance > maxDist, if so skip transformation and just copy pixel
    mov             [ebp-56], eax     ; temp store maxDist
    fld             dword [ebp-44]    ; st(0) = distance
    fild dword      [ebp-56]          ; st(0) = float(maxDist), st(1) = distance
    fcomip st0, st1                   ; compare maxDist vs distance, pop maxDist
    fstp            st0               ; pop distance to clean FPU stack
    jae             .apply_transformation ; if maxDist >= distance, apply transformation

    ; otherwise, distance > maxDist, so just copy source to destination
    mov             eax, [ebp-52]     ; source offset (original pixel)
    lea             ebx, [esi + eax]  ; ebx = &imageData[offset]
    lea             ecx, [edi + eax]  ; ecx = &outBuffer[offset]

    xor             edx, edx          ; edx = channel index
.copy_channels_no_transform:
    cmp             edx, [ebp-24]
    jge             .end_copy_channels
    movzx           eax, byte [ebx + edx]
    mov             [ecx + edx], al
    inc             edx
    jmp             .copy_channels_no_transform

.apply_transformation:
    ; now we can calculate swirl amount factor = 1.0 - dist/maxDist
    fild dword      [ebp-56]          ; st(0) = float(maxDist)
    fld dword       [ebp-44]          ; st(0) = dist, st(1) = maxDist
    fdiv st0, st1                     ; st(0) = dist/maxDist, st(1) = maxDist
    fld1                              ; st(0) = 1.0, st(1) = dist/maxDist, st(2) = maxDist
    fsub st0, st1                     ; st(0) = 1.0 - dist/maxDist, st(1) = dist/maxDist, st(2) = maxDist
    
    fstp dword      [ebp-56]          ; store swirl factor in [ebp-56], pop
    fstp st0                          ; pop dist/maxDist
    fstp st0                          ; pop maxDist
    
    ; now [ebp-56] = swirl amount factor (1.0 - dist/maxDist)
    ; so we can calculate new angle = current angle + strength * swirl amount factor
    fld             dword [ebp+28]    ; st(0) = strength
    fld             dword [ebp-56]    ; st(0) = swirl amount factor, st(1) = strength
    fmul st0, st1                     ; st(0) = strength * swirl amount factor, st(1) = strength
    fstp            st1               ; pop strength, st(0) = strength * swirl amount factor
    fld             dword [ebp-48]    ; st(0) = current angle, st(1) = strength * swirl amount factor
    fadd st0, st1                     ; st(0) = current angle + strength * swirl amount factor
    fstp            dword [ebp-60]    ; store new angle in [ebp-60]
    fstp            st0               ; pop leftover strength * swirl amount factor

    ; now [ebp-60] = new calculated angle
    
    ; source coordinates:  srcX = centerX + (dist * cos(newAngle))
    ;                                srcY = centerY + (dist * sin(newAngle))
    
    fld             dword [ebp-60]    ; st(0) = newAngle
    fsincos                           ; st(0) = cos(newAngle), st(1) = sin(newAngle)
    
    ; srcX = centerX + (dist * cos(newAngle))
    fld             dword [ebp-44]    ; st(0) = dist, st(1) = cos, st(2) = sin
    fmul            st0, st1          ; st(0) = dist*cos, st(1) = cos, st(2) = sin
    fild dword      [ebp+32]          ; st(0) = centerX, st(1) = dist*cos, st(2) = cos, st(3) = sin
    fadd            st0, st1          ; st(0) = centerX + dist*cos = srcX, st(1) = dist*cos, st(2) = cos, st(3) = sin
    fstp            dword [ebp-64]    ; store srcX, pop
    fstp            st0               ; pop dist*cos
    fstp            st0               ; pop cos
    
    ; srcY = centerY + (dist * sin(newAngle))
    fld             dword [ebp-44]    ; st(0) = dist, st(1) = sin
    fmul            st0, st1          ; st(0) = dist*sin, st(1) = sin
    fild dword      [ebp+36]          ; st(0) = centerY, st(1) = dist*sin, st(2) = sin
    fadd            st0, st1          ; st(0) = centerY + dist*sin = srcY, st(1) = dist*sin, st(2) = sin
    fstp            dword [ebp-68]    ; store srcY, pop
    fstp            st0               ; pop dist*sin
    fstp            st0               ; pop sin
    
    ; now [ebp-64] = srcX (float), [ebp-68] = srcY (float)

    ;  floats to integers (nearest)
    fld             dword [ebp-64]    ; srcX (float)
    fistp           dword [ebp-36]    ; srcX (int) -> reuse [ebp-36]
    fld             dword [ebp-68]    ; srcY (float)
    fistp           dword [ebp-40]    ; srcY (int) -> reuse [ebp-40]

    ; clamp srcX to [0, width-1]
    mov             eax, [ebp-36]
    cmp             eax, 0
    jge             .srcx_nonneg 
    mov             eax, 0
    mov             [ebp-36], eax ; clamp to 0 if negative
.srcx_nonneg:
    cmp             eax, [ebp-16] ; compare with width
    jl              .srcx_inrange
    mov             eax, [ebp-16]
    dec             eax
    mov             [ebp-36], eax ; clamp to width-1 if >= width
.srcx_inrange:

    ; clamp srcY to [0, height-1]
    mov             eax, [ebp-40] ;
    cmp             eax, 0
    jge             .srcy_nonneg
    mov             eax, 0
    mov             [ebp-40], eax ; clamp to 0 if negative
.srcy_nonneg:
    cmp             eax, [ebp-20] ; compare with height
    jl              .srcy_inrange
    mov             eax, [ebp-20]
    dec             eax
    mov             [ebp-40], eax ; clamp to height-1 if >= height
.srcy_inrange:

    ; compute srcOffset = (srcY * width + srcX) * channels
    mov             eax, [ebp-40]     ; srcY
    imul            eax, [ebp-16]     ; srcY * width
    add             eax, [ebp-36]     ; + srcX
    imul            eax, [ebp-24]     ; * channels

    lea             ebx, [esi + eax]  ; ebx = &imageData[srcOffset]
    mov             edx, [ebp-52]     ; destOffset
    lea             ecx, [edi + edx]  ; ecx = &outBuffer[destOffset]

    ; copy each channel from source to destination
    xor             edx, edx          ; edx = channel index

.copy_channels:
    cmp             edx, [ebp-24]
    jge             .end_copy_channels

    ; outBuffer[destOffset + channel] = imageData[srcOffset + channel]
    movzx           eax, byte [ebx + edx]
    mov             [ecx + edx], al

    inc             edx
    jmp             .copy_channels

.end_copy_channels:
    ; ========================================================================
    ; END OF TRANSFORMATION SECTION
    ; ========================================================================

    ; x++
    inc              dword [ebp-32]
    jmp              .loop_x

.end_loop_x:
    ; y++
    inc              dword [ebp-28]
    jmp              .loop_y

.end_loop_y:
    add              esp, 68 ; restore stack
    pop              edi
    pop              esi
    pop              ebx
    pop              ebp
    ret
