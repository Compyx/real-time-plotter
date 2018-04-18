; vim: set et ts=8 sw=8 sts=8 fdm=marker syntax=64tass:

; This is supposed to be example code of how to do a simple plotter
;
; Unfortunately the actual plotting got lost in a macro mess.
;
; (c) 2018  Bas Wassink (compyx/focus) <b.wassink@ziggo.nl>


        ZP = $10

        GRID_LINE = 0
        GRID_COLUMN = 12
        GRID_POS = $0400 + (GRID_LINE * 40) + GRID_COLUMN

        BG_COLOR = 6

        PLOTTER = $2000

        SID_LOAD = $1000
        SID_INIT = $1000
        SID_PLAY = $1003
        SID_NAME = "Bones_plus.sid"

        JOY_UP = $01
        JOY_DOWN = $02
        JOY_LEFT = $04
        JOY_RIGHT = $08
        JOY_FIRE = $10

        plot_params = ZP + 16

        xidx1 = ZP + 16
        xidx2 = ZP + 17
        xadd1 = ZP + 18
        xadd2 = ZP + 19
        xspd1 = ZP + 20
        xspd2 = ZP + 21

        yidx1 = ZP + 22
        yidx2 = ZP + 23
        yadd1 = ZP + 24
        yadd2 = ZP + 25
        yspd1 = ZP + 26
        yspd2 = ZP + 27

; @brief        Add 40 to word at \1
;
; @clobbers     A,C
; @safe         X,Y
add40 .macro
        lda \1
        clc
        adc #40
        sta \1
        bcc +
        inc \1 + 1
+
.endm


;------------------------------------------------------------------------------
; BASIC SYS line
;------------------------------------------------------------------------------
        * = $0801

        .word (+), 2017
        .null $9e, format("%d", start)
+       .word 0

start
        jsr $fda3
        sei
        lda #$7f
        sta $dc0d
        ldx #0
        stx $dc0e
        inx
        stx $d01a
        lda #0
        sta $d020
        lda #BG_COLOR
        sta $d021
        jsr clear_screen
        jsr clear_plotter
        jsr setup_vidram
        jsr render_text
        ldx #0
-       lda params,x
        sta ZP + 16,x
        inx
        cpx #params_end - params
        bne -

        jsr render_all_params

        lda #0
        jsr SID_INIT

        lda $dc0d
        lda $dd0d
        lda $d019

        lda #$1b
        sta $d011
        lda #$52
        ldx #<irq1
        ldy #>irq1
        sta $d012
        stx $0314
        sty $0315
        lda #1
        sta $d019
        lda #$08
        sta $d016
        lda #$18
        sta $d018
        cli
        jmp *


irq1
        lda #4
        sta $d020
        jsr joy_handle
        jsr joy_display
        lda #$0f
        sta $d020
        jsr SID_PLAY
        lda #0
        sta $d020

        lda #$b1
        ldx #<irq2
        ldy #>irq2
do_irq
        sta $d012
        stx $0314
        sty $0315
        inc $d019
        jmp $ea81

irq2
        ldx #13
-       dex
        bpl -
        lda #$17
        sta $d018
        lda #$05
        sta $d020
        jsr plotter_clear
        lda #$08
        sta $d020
        jsr calc_plots
        lda #$02
        sta $d020
        jsr plotter_plot
        lda #0
        sta $d020
        lda #$18
        sta $d018

        lda #$52
        ldx #<irq1
        ldy #>irq1
        jmp do_irq


clear_screen .proc
        ldx #$00
        txa
-       sta $0400,x
        sta $0500,x
        sta $0600,x
        sta $06e8,x
        lda #BG_COLOR
        sta $d800,x
        sta $d900,x
        sta $da00,x
        sta $dae8,x
        inx
        bne -
        rts
.pend

render_text
        ldx #0
-       lda some_text,x
        sta $0680,x
        lda #$0f
        sta $da80,x
        inx
        bne -
        ldx #$67
-       lda some_text + 256,x
        sta $0780,x
        lda #$0f
        sta $db80,x
        dex
        bpl -
        rts


; @brief        Clear charset used for the plotter
;
clear_plotter .proc
        ldx #0
        txa
-
    .for row = 0, row < 8, row += 1
        sta PLOTTER + (256 * row),x
    .next
        bne -
        rts
.pend


; @brief        Setup the plotter charset grid
setup_vidram .proc

        vidram = ZP
        colram = ZP + 2

        lda #<GRID_POS
        ldx #>GRID_POS
        sta vidram
        stx vidram + 1
        sta colram
        txa
        and #$03
        clc
        adc #$d8
        sta colram + 1

        ldx #0
-
        ldy #0
-
        tya
        asl a
        asl a
        asl a
        asl a
        sta xtmp + 1
        txa
        clc
xtmp    adc #0
        sta (vidram),y
        lda #1
        sta (colram),y
        iny
        cpy #16
        bne -

        #add40 vidram
        #add40 colram
        inx
        cpx #16
        bne --
        rts
.pend



params
        .byte 32        ; xidx1
        .byte 64        ; xidx2
        .byte $04       ; xadd1
        .byte $05       ; xadd2
        .byte $02       ; xspd1
        .byte $ff       ; xspd2

        .byte 128       ; yidx1
        .byte 32        ; yidx2
        .byte $fe       ; yadd1
        .byte $fb       ; yadd2
        .byte $fd       ; yspd1
        .byte $04       ; yspd2
params_end


some_text
        .enc "screen"
        ;      0123456789abcdef0123456789abcdef01234567
        .text "Simple 64 pixels plotter, using a double"
        .text "sinus for both X and Y positions.       "
        .text "Green: clear    Brown: calc    Red: plot"
        .text "Purple: UI handling,         Grey: music"
        .text "                                        "
        .text "                                        "
        .text "xadd1 $00 xadd2 $00 yadd1 $00, yadd2 $00"
        .text "xspd1 $00 xspd2 $00 yspd1 $00, yspd2 $00"
        .text "(use joy#2 to alter params, fire: reset)"
some_text_end


param_index .byte 0


param_indici
        .word xadd1, $0777
        .word xadd2, $0781
        .word yadd1, $078b
        .word yadd2, $0796
        .word xspd1, $0777 + 40
        .word xspd2, $0781 + 40
        .word yspd1, $078b + 40
        .word yspd2, $0796 + 40
param_indici_end


param_colors
        .byte $04, $0e, $0f, $07, $01, $01, $01, $01, $07, $0f, $0e, $04, $ff
param_col_index
        .byte 0


; @brief        Handle joystick input
;
joy_handle .proc

        tmp = ZP + 32

delay   lda #5
        beq +
        dec delay +1
-       rts
+
        lda $dc00
        cmp #$ff
        beq -
        sta tmp

        and #JOY_LEFT
        beq joy_left
        lda tmp
        and #JOY_RIGHT
        beq joy_right

        lda tmp
        and #JOY_UP
        beq joy_up

        lda tmp
        and #JOY_DOWN
        beq joy_down

        lda tmp
        and #JOY_FIRE
        beq joy_fire
joy_end
        lda #5
        sta delay + 1
        rts
joy_left
        lda param_index
        sec
        sbc #1
        and #7
        sta param_index
        jmp joy_end
joy_right
        lda param_index
        clc
        adc #1
        and #7
        sta param_index
        jmp joy_end
joy_up
        lda #1
        sta param_update + 1
        lda param_index
        asl a
        asl a
        tax
        lda param_indici,x
        sta tmp
        lda param_indici + 1,x
        sta tmp + 1
        ldy #0
        lda (tmp),y
        clc
param_update
        adc #1
        sta (tmp),y
        jmp joy_end
joy_down
        lda #$ff
        bne joy_up + 2
joy_fire
        lda #0
        sta xadd1
        sta xadd2
        sta yadd1
        sta yadd2
        sta xspd1
        sta xspd2
        sta yspd1
        sta yspd2
        jsr render_all_params
        jmp joy_end

.pend


; Display the adjustable parameters
;
; @clobbers     all
;
joy_display .proc

        colram = ZP
        vidram = ZP + 2
        param = ZP + 4

        ; reset colors
        ldx #0
-       lda param_indici + 2,x
        sta colram
        lda param_indici + 3,x
        clc
        adc #$d4
        sta colram + 1
        lda #$01
        ldy #0
        sta (colram),y
        iny
        sta (colram),y
        inx
        inx
        inx
        inx
        cpx #param_indici_end - param_indici
        bne -

        ; plot current param value in hex

        ; color-cycle current selected param
        lda param_index
        asl a
        asl a
        tax
        lda param_indici + 2,x
        sta colram
        sta vidram
        lda param_indici + 0,x
        sta param
        lda param_indici + 3,x
        clc
        sta vidram + 1
        adc #$d4
        sta colram + 1
        lda param_indici + 1,x
        sta param + 1

        ldx param_col_index
        lda param_colors,x
        bpl +
        ldx #0
        stx param_col_index
        lda param_colors,x
+
        ldy #0
        sta (colram),y
        iny
        sta (colram),y

        ldy #0
        lda (param),y
        jsr hexdigits

        ldy #0
        sta (vidram),y
        iny
        txa
        sta (vidram),y



delay   lda #5
        beq +
        dec delay + 1
        rts
+       lda #5
        sta delay + 1
        inc param_col_index
        rts
.pend


render_all_params .proc

        vidram = ZP
        param = ZP + 2
        index = ZP + 4

        lda #0
        sta index
-
        asl a
        asl a
        tax
        lda param_indici + 0,x
        sta param + 0
        lda param_indici + 1,x
        sta param + 1
        lda param_indici + 2,x
        sta vidram + 0
        lda param_indici + 3,x
        sta vidram + 1

        ldy #0
        lda (param),y
        jsr hexdigits
        sta (vidram),y
        iny
        txa
        sta (vidram),y

        inc index
        lda index
        cmp #8
        bne -
        rts
.pend


; Translate A into hex digits
;
; @param A      input
;
; @return       A = LSB. X = MSB
; @stack        1
;
hexdigits .proc

        pha
        and #$0f
        cmp #$0a
        bcc +
        sbc #$39
+       adc #$30
        tax
        pla
        lsr a
        lsr a
        lsr a
        lsr a
        cmp #$0a
        bcc +
        sbc #$39
+       adc #$30
        rts
.pend



        .align 256

; Horribly slow plot location calculations, but flexible, ie you can add a
; joystick routine to allow people to change the movements
;
calc_plots .proc

        tmp = ZP


        lda #0
        sta tmp

        ldx xidx1
        ldy xidx2
-
        lda sinus1,x
        clc
        adc sinus2,y
        stx xtmp1 + 1
        ldx tmp
        sta xsinus,x
xtmp1   lda #0
        clc
        adc xadd1
        tax
        tya
        clc
        adc xadd2
        tay

        inc tmp
        lda tmp
        cmp #64
        bne -

        lda xidx1
        clc
        adc xspd1
        sta xidx1
        lda xidx2
        clc
        adc xspd2
        sta xidx2

        lda #0
        sta tmp

        ldx yidx1
        ldy yidx2
-
        lda sinus1,x
        clc
        adc sinus2,y
        stx xtmp2 + 1
        ldx tmp
        sta ysinus,x
xtmp2   lda #0
        clc
        adc yadd1
        tax
        tya
        clc
        adc yadd2
        tay

        inc tmp
        lda tmp
        cmp #64
        bne -

        lda yidx1
        clc
        adc yspd1
        sta yidx1
        lda yidx2
        clc
        adc yspd2
        sta yidx2
        rts
.pend


;------------------------------------------------------------------------------
; Load SID tune at its location ($1000 in this case)
;------------------------------------------------------------------------------

        * = SID_LOAD
.binary SID_NAME, $7e


;------------------------------------------------------------------------------
; $2000-$27ff is used for the plotter
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Data after the plotter data, tables not going over page breaks for speed
;------------------------------------------------------------------------------
        * = $2800

xlo
    .for col = 0, col < 16, col += 2
        .fill 8, $00
        .fill 8, $80
    .next

xhi
    .for col = 0, col < 8, col += 1
        .fill 16, >(PLOTTER + (col * $100))
    .next


xbits
    .for pixel = 0, pixel < 128, pixel += 1
        .byte (1 << ((7 - pixel) & 7))
    .next

xsinus  .byte range(0, 64, 1)
ysinus  .byte range(0, 64, 1)

; 0-47
sinus1  .byte 47.5 + 47 * sin(range(256) * rad(360.0/256))
; 0-15
sinus2  .byte 15.5 + 15 * sin(range(256) * rad(360.0/256))


;------------------------------------------------------------------------------
; Plot and clear routines
;------------------------------------------------------------------------------
        * = $3000


; Clear routine: write 0 to each byte the plot routine wrote to
;
; The plotter_plot routine uses the X-position LSB and MSB and stores them
; in this routine for each pixel rendered.
plotter_clear .proc
        lda #0
   .for px = 0, px < 64, px += 1

        ldy ysinus + px
        sta $fce2,y     ; adjusted by plotter_plot
    .next
        rts
.pend


        .align 256

; Render plots and update the clear routine
;
plotter_plot .proc

        mem = ZP

   .for px = 0, px < 64, px += 1

        ldx xsinus + px
        ldy ysinus + px
        lda xlo,x
        sta mem
        sta plotter_clear + 6 + (px * 6)        ; LSB of operand of sta $xxxx,y
                                                ; in the plotter_clear code
        lda xhi,x
        sta plotter_clear + 7 + (px * 6)        ; MSB of operand of sta $xxxx,y
                                                ; the the plotter_clear code
        sta mem + 1
        lda (mem),y
        ora xbits,x
        sta (mem),y
    .next
        rts
.pend
