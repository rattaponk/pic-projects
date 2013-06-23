;===============================================================================
; Vetenari Clock
;-------------------------------------------------------------------------------


;===============================================================================

                include P12F683.inc

                errorlevel -312
                errorlevel -302

#define M(X)    (1<<(X))

;===============================================================================
; Hardware Configuration
;-------------------------------------------------------------------------------

OSC             equ     .4000000        ; Use built in oscilator

MAGL_PIN        equ     .1
MAGR_PIN        equ     .2

TRISIO_INIT     equ     ~(M(MAGR_PIN)|M(MAGL_PIN))

;===============================================================================
; Device Configuration
;-------------------------------------------------------------------------------

CONFIG_STD      equ     _INTOSCIO & _MCLRE_ON & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF
CONFIG_DEV      equ     _WDT_OFF & _PWRTE_ON & _CP_OFF & _CPD_OFF

                __config CONFIG_STD & CONFIG_DEV

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
                movlw   M(T1OSCEN)|M(TMR1CS)
                movwf   T1CON



                banksel T1CON           ; And start the timer
                bsf     T1CON,TMR1ON

;-------------------------------------------------------------------------------




                goto    $


                end