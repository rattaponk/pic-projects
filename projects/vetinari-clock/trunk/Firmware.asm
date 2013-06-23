;===============================================================================
; Vetinari Clock
;-------------------------------------------------------------------------------


;===============================================================================

                include P12F683.inc

                errorlevel -312
                errorlevel -302

#define M(X)    (1<<(X))

#define HI(X)   (((X) >> .8) & h'ff')
#define LO(X)   (((X) >> .0) & h'ff')

;===============================================================================
; Hardware Configuration
;-------------------------------------------------------------------------------

OSC             equ     .4000000        ; Use built in oscilator

MAGL_PIN        equ     .1
MAGR_PIN        equ     .2

CHARGE_MS       equ     .50

TMR0_HZ         equ     .1000
TMR0_PRESCALE   equ     .32

TMR0_PERIOD     equ     OSC / (.4 * TMR0_HZ * TMR0_PRESCALE)

TMR1_HZ         equ     .32768
TMR1_PRESCALE   equ     .4

TICKS_PER_SEC   equ     TMR1_HZ / TMR1_PRESCALE

TICKS_NORM      equ     TICKS_PER_SEC
TICKS_SHORT     equ     .1 * TICKS_NORM / .2
TICKS_LONG      equ     .3 * TICKS_NORM / .2

TRISIO_INIT     equ     ~(M(MAGR_PIN)|M(MAGL_PIN))

;===============================================================================
; Device Configuration
;-------------------------------------------------------------------------------

CONFIG_STD      equ     _INTOSCIO & _MCLRE_ON & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF
CONFIG_DEV      equ     _WDT_OFF & _PWRTE_ON & _CP_OFF & _CPD_OFF

                __config CONFIG_STD & CONFIG_DEV

;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

                udata_shr

LFSR            res     .2                      ; Current LFSR value

COUNT           res     .1                      ; MS Delay counter

;===============================================================================
; Interrupt Handler
;-------------------------------------------------------------------------------

.Interrupt      code    h'004'

                retfie

;===============================================================================
; Power On Reset
;-------------------------------------------------------------------------------

.ResetVector    code    h'000'

                clrf    STATUS
                pagesel PowerOnReset
                goto    PowerOnReset

;-------------------------------------------------------------------------------

                code
PowerOnReset:
                banksel OPTION_REG
                movlw   b'10000100'
;                         1-------              GPIO pull-ups disabled
;                         -x------              Interrupt edge select 
;                         --0-----              TMR0 uses instruction clock
;                         ---x----              Source edge select
;                         ----0---              Prescaler assigned to TMR0
;                         -----100              Prescate 1:32
                movwf   OPTION_REG

;-------------------------------------------------------------------------------

                banksel GPIO            ; Initialise the GPIO port
                clrf    GPIO
                movlw   h'07'           ; Turn the comparator off
                movwf   CMCON0
                banksel ANSEL           ; Turn analog inputs off
                clrf    ANSEL

                movlw   TRISIO_INIT     ; Set the pin I/O states
                movwf   TRISIO

;-------------------------------------------------------------------------------

                banksel T1CON           ; Configure Timer1 to use watch crystal
                movlw   b'00101110'
;                         0-------              Timer gate is not inverted
;                         -0------              Timer gate is not enabled
;                         --10----              Prescaler 1:4
;                         ----1---              Oscillator is enabled
;                         -----1--              Asynchronous external input
;                         ------1-              External input enabled
;                         -------0              Timer disabled
                movwf   T1CON

                clrf    TMR1L
                clrf    TMR1H

                banksel T1CON           ; And start the timer
                bsf     T1CON,TMR1ON

                banksel PIE1            ; Enable interrupts to allow wake-up
                bsf     PIE1,TMR1IE
                bsf     INTCON,PEIE

;-------------------------------------------------------------------------------

                movlw   h'ff'
                movwf   LFSR+.0
                movwf   LFSR+.1

;===============================================================================
; Main Task
;-------------------------------------------------------------------------------

MainTask:
                movlw   high JumpTable
                movwf   PCLATH
                movf    LFSR+.0,W
                andlw   h'0f'
                addlw   low JumpTable
                btfsc   STATUS,C
                incf    PCLATH,F
                movwf   PCL

JumpTable
                goto    Pattern0
                goto    Pattern0
                goto    Pattern1
                goto    Pattern0
                goto    Pattern2
                goto    Pattern0
                goto    Pattern0
                goto    Pattern1
                goto    Pattern0
                goto    Pattern3
                goto    Pattern0
                goto    Pattern1
                goto    Pattern0
                goto    Pattern2
                goto    Pattern0
                goto    Pattern0

;-------------------------------------------------------------------------------

Pattern0:
                call    NormalTickL     ; Normal pattern of eight ticks
                call    NormalTickR
                call    NormalTickL
                call    NormalTickR
                call    NormalTickL
                call    NormalTickR
                call    NormalTickL
                call    NormalTickR
                goto    MainTask

Pattern1:
                call    ShortTickL     ; One irregular tick
                call    NormalTickR
                call    NormalTickL
                call    NormalTickR
                call    LongTickL
                call    NormalTickR
                call    NormalTickL
                call    NormalTickR
                goto    MainTask

Pattern2:
                call    ShortTickL     ; Two irregular ticks
                call    ShortTickR
                call    NormalTickL
                call    NormalTickR
                call    LongTickL
                call    NormalTickR
                call    LongTickL
                call    NormalTickR
                goto    MainTask

Pattern3:
                call    ShortTickL     ; Three irregular ticks
                call    ShortTickR
                call    NormalTickL
                call    ShortTickR
                call    LongTickL
                call    LongTickR
                call    NormalTickL
                call    LongTickR
                goto    MainTask

;-------------------------------------------------------------------------------

NormalTickL:
                banksel T1CON           ; Stop the timer
                bcf     T1CON,TMR1ON
                movlw   HI(-TICKS_NORM) ; Load count for next period
                movwf   TMR1H
                movlw   LO(-TICKS_NORM)
                movwf   TMR1L
                goto    LeftPulse

ShortTickL:
                banksel T1CON           ; Stop the timer
                bcf     T1CON,TMR1ON
                movlw   HI(-TICKS_SHORT); Load count for next period
                movwf   TMR1H
                movlw   LO(-TICKS_SHORT)
                movwf   TMR1L
                goto    LeftPulse

LongTickL:
                banksel T1CON           ; Stop the timer
                bcf     T1CON,TMR1ON
                movlw   HI(-TICKS_LONG) ; Load count for next period
                movwf   TMR1H
                movlw   LO(-TICKS_LONG)
                movwf   TMR1L

LeftPulse:
                bsf     T1CON,TMR1ON    ; Restart the timer

                banksel GPIO
                bsf     GPIO,MAGL_PIN
                call    PulseDelay
                bcf     GPIO,MAGL_PIN

                call    Shift
                banksel PIR1            ; Clear the interrupt flag
                bcf     PIR1,TMR1IF
                sleep

                nop
                return

;-------------------------------------------------------------------------------

NormalTickR:
                banksel T1CON           ; Stop the timer
                bcf     T1CON,TMR1ON
                movlw   HI(-TICKS_NORM) ; Load count for next period
                movwf   TMR1H
                movlw   LO(-TICKS_NORM)
                movwf   TMR1L
                goto    RightPulse

ShortTickR:
                banksel T1CON           ; Stop the timer
                bcf     T1CON,TMR1ON
                movlw   HI(-TICKS_SHORT); Load count for next period
                movwf   TMR1H
                movlw   LO(-TICKS_SHORT)
                movwf   TMR1L
                goto    RightPulse

LongTickR:
                banksel T1CON           ; Stop the timer
                bcf     T1CON,TMR1ON
                movlw   HI(-TICKS_LONG) ; Load count for next period
                movwf   TMR1H
                movlw   LO(-TICKS_LONG)
                movwf   TMR1L

RightPulse:
                bsf     T1CON,TMR1ON    ; Restart the timer

                banksel GPIO
                bsf     GPIO,MAGR_PIN
                call    PulseDelay
                bcf     GPIO,MAGR_PIN

                call    Shift
                banksel PIR1            ; Clear the interrupt flag
                bcf     PIR1,TMR1IF
                sleep

                nop
                return

;===============================================================================
; MS Delay
;-------------------------------------------------------------------------------

PulseDelay:
                movlw   CHARGE_MS
                movwf   COUNT

DelayLoop:
                banksel TMR0
                movlw   LO(-TMR0_PERIOD)
                movwf   TMR0

                bcf     INTCON,T0IF
                btfss   INTCON,T0IF
                goto    $-1

                decfsz  COUNT,F
                goto    DelayLoop
                return

;===============================================================================
; Random Number Generator
;-------------------------------------------------------------------------------

Shift:
                bcf     STATUS,C        ; Shift the LFSR one bit
                rrf     LFSR+.1,F
                rrf     LFSR+.0,F
                btfss   STATUS,C
                return
                movlw   h'b4'           ; And XOR back it dropped bits
                xorwf   LFSR+.1,F
                return

                end