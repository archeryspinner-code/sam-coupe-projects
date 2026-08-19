; ==========================================================
; RNG — 16-bit Galois LFSR + uniform ranged random via multiply-scale
; ==========================================================

RNG_SEED: DEFW &ACE1

; RND_BYTE — OUTPUT: A = random 0-255   CORRUPTS: A,HL   PRESERVES: BC,DE
RND_BYTE:
    LD   HL,(RNG_SEED)
    SRL  H
    RR   L
    JR   NC,RB_NOTAP
    LD   A,H
    XOR  &B4
    LD   H,A
RB_NOTAP:
    LD   (RNG_SEED),HL
    LD   A,H
    RET

; RND_RANGE — uniform random in 0..(range-1), range in A (1-255)
; OUTPUT: A = result   CORRUPTS: A,BC,DE,HL
RND_RANGE:
    LD   C,A
    CALL RND_BYTE
    LD   B,A
    LD   HL,0
    LD   D,0
    LD   E,B
    LD   A,C
    LD   B,8
RR_MUL:
    ADD  HL,HL
    RLCA
    JR   NC,RR_SKIP
    ADD  HL,DE
RR_SKIP:
    DJNZ RR_MUL
    LD   A,H
    RET
