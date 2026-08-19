; ==========================================================
; INPUT — QAOP + Space, polled every frame (real-time, not turn-based:
; holding a direction moves continuously, no press/release gating needed)
; ==========================================================

ROW_SPC   EQU &7FFE
ROW_POIUY EQU &DFFE
ROW_QWERT EQU &FBFE
ROW_ASDFG EQU &FDFE

INPUT_STATE: DEFB 0

; READ_KEYS — polls Q/A/O/P/SPACE into INPUT_STATE bits.  CORRUPTS: A,BC
READ_KEYS:
    XOR  A
    LD   (INPUT_STATE),A

    LD   BC,ROW_QWERT
    IN   A,(C)
    CPL
    AND  &01                          ; Q = up
    JR   Z,RK1
    LD   A,(INPUT_STATE)
    OR   INP_UP
    LD   (INPUT_STATE),A
RK1:
    LD   BC,ROW_ASDFG
    IN   A,(C)
    CPL
    AND  &01                          ; A = down
    JR   Z,RK2
    LD   A,(INPUT_STATE)
    OR   INP_DOWN
    LD   (INPUT_STATE),A
RK2:
    LD   BC,ROW_POIUY
    IN   A,(C)
    CPL
    AND  &02                          ; O = left
    JR   Z,RK3
    LD   A,(INPUT_STATE)
    OR   INP_LEFT
    LD   (INPUT_STATE),A
RK3:
    LD   BC,ROW_POIUY
    IN   A,(C)
    CPL
    AND  &01                          ; P = right
    JR   Z,RK4
    LD   A,(INPUT_STATE)
    OR   INP_RIGHT
    LD   (INPUT_STATE),A
RK4:
    LD   BC,ROW_SPC
    IN   A,(C)
    CPL
    AND  &01                          ; SPACE = fire
    JR   Z,RK5
    LD   A,(INPUT_STATE)
    OR   INP_FIRE
    LD   (INPUT_STATE),A
RK5:
    RET
