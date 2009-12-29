;===============================================================================
; Electronic Dice
;-------------------------------------------------------------------------------
; Copyright (C)2009 PIC-Projects.net
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions
; are met:
;
; 1. Redistributions of source code must retain the above copyright
;    notice, this list of conditions and the following disclaimer.
; 2. Redistributions in binary form must reproduce the above copyright
;    notice, this list of conditions and the following disclaimer in the
;    documentation and/or other materials provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ''AS IS'' AND
; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
; OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
; HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
; LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
; OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
; SUCH DAMAGE.
;===============================================================================
; Revision History:
;
; 2009-09-09 Initial version
;-------------------------------------------------------------------------------
; $Id$
;-------------------------------------------------------------------------------

                errorlevel -312

;===============================================================================
; Fuse Configuration
;-------------------------------------------------------------------------------

                ifdef   __12F508
                include P12F508.inc

                ifdef   __DEBUG
 __config _MCLRE_OFF & _CP_OFF & _WDT_OFF & _IntRC_OSC
                else
 __config _MCLRE_OFF & _CP_ON & _WDT_OFF & _IntRC_OSC
                endif
                endif

                ifdef   __12F509
                include P12F509.inc

                ifdef   __DEBUG
 __config _MCLRE_OFF & _CP_OFF & _WDT_OFF & _IntRC_OSC
                else
 __config _MCLRE_OFF & _CP_ON & _WDT_OFF & _IntRC_OSC
                endif
                endif

;-------------------------------------------------------------------------------

; The BIT macro converts a bit number into its corresponding value (e.g. bit 2
; equals 1 << 2 which evaluates to 4).
		
#define BIT(_X)	(.1 << (_X))

;===============================================================================
; Hardware Configuration
;-------------------------------------------------------------------------------
		
OSC             equ     .4000000        ; The internal oscillator frequency
FOSC            equ     OSC / .4

;-------------------------------------------------------------------------------

TMR0_HZ         equ     .100            ; The required timer rollover frequency
TMR0_PRESCALE   equ     .128            ; The prescaler setting

TMR0_PERIOD     equ     FOSC / (TMR0_HZ * TMR0_PRESCALE) 

POWEROFF_PERIOD equ     .15 * TMR0_HZ   ; The auto-power off period

;------------------------------------------------------------------------------

SWITCH          equ     .3              ; The switch is connected to GP3

LED_A           equ     .5              ; The output pins connected to the LEDs
LED_B           equ     .4
LED_C           equ     .1
LED_D           equ     .0

;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

; The 12F508 only has a single bank of data memory so SFRs and users registers
; will always be accessable at the same time without need for bank switching.
;
; The 12F509 has two banks of data memory but a small region between h'07' and 
; h'0f' is a shared across across both banks. By using 'udata_shr' rather than
; 'udata' we can force the linker to put the variables there. 

                ifdef   __12F509
                udata_shr               ; Use udata_shr on 12F509
                else
                udata                   ; And udata on 12F508
                endif

DICE            res     .1              ; The current dice value (0 - 5)
LEDS            res     .1              ; Hold the rolled dice LED pattern

TICKS           res     .1              ; A counter used for short delays 

COUNTL          res     .1              ; A 16-bit counter used to detect
COUNTH          res     .1              ; .. auto-power off

;===============================================================================
; Reset Vector
;-------------------------------------------------------------------------------

                code	h'000'

                goto	PowerOnReset		; Jump to initialisation

;===============================================================================
; Subroutines
;-------------------------------------------------------------------------------
; On base line micro-controllers subroutines must be located in the first half
; of the program memory page. 
;-------------------------------------------------------------------------------

; Convert the dice value (0 to 5) in WREG into the bit pattern needed to light
; the corresponding LEDs.

GetDicePattern:
                addwf	PCL,F                   ; Perform a computed jump
                retlw   BIT(LED_A)
                retlw   BIT(LED_B)
                retlw   BIT(LED_A)|BIT(LED_C)
                retlw   BIT(LED_B)|BIT(LED_C)
                retlw   BIT(LED_A)|BIT(LED_B)|BIT(LED_C)
                retlw   BIT(LED_B)|BIT(LED_C)|BIT(LED_D)

; Increments the dice value (0 thru 5) by one and wraps six back to zero.

SpinDice
                incf    DICE,W                  ; Bump dice value by one
                xorlw   .6                      ; Too big?		
                btfss   STATUS,Z
                xorlw   .6                      ; No, undo comparison
                movwf   DICE                    ; And save result
                retlw   .0

; Displays the LED pattern indicated by WREG and then delays for a short time. 

ShowLedPatternShort:
                movwf   GPIO                    ; Set the LED pattern
                movlw   .10                     ; Then delay 0.1 secs
                goto    TickDelay

; Displays the LED pattern indicated by WREG and then delays for a longer time.
 
ShowLedPatternLong:
                movwf   GPIO                    ; Set the LED pattern
                movlw   .30                     ; Then delay 0.3 secs

; Generates a delay based on WREG timer overflows.

TickDelay:
                movwf   TICKS                   ; Save the rollover count
ResetTimer:
                movlw   low -TMR0_PERIOD        ; Set the timer for one period 
                movwf   TMR0
DelayWait:
                movf    TMR0,W                  ; Has the timer reached zero?
                btfss   STATUS,Z
                goto    DelayWait               ; No, wait some more

                decfsz  TICKS,F                 ; Decrement the counter and
                goto    ResetTimer              ; .. wait again if not zero
                retlw   .0                      ; Otherwise all done

;==============================================================================
; Power On Reset
;------------------------------------------------------------------------------

PowerOnReset:
                movlw	b'00000110'
;                         0-------              ; Enable Wakeup on GPIO change
;                         -0------              ; Enable Weak pullups
;                         --0-----              ; Timer0 uses internal clock
;                         ---x----              ; Timer0 src edge (don't care)
;                         ----0---              ; Prescaler assigned to timer0
;                         -----110              ; /128 prescaler
                option                          ; Set option bits

                movlw	BIT(SWITCH)             ; Make all LED pins outputs
                tris	GPIO
                clrf	GPIO                    ; And switch them off
                clrf    DICE                    ; Reset the dice value

WaitForRelease:
                movlw   low -TMR0_PERIOD        ; Prime the timer with debounce
                movwf   TMR0                    ; period
DebounceRelease:
                call    SpinDice
                btfss   GPIO,SWITCH             ; Is the switch released
                goto    WaitForRelease          ; No. wait some more
                movf    TMR0,W                  ; Completed debounce?
                btfss   STATUS,Z
                goto    DebounceRelease         ; No, wait some more

                movlw   BIT(LED_A)|BIT(LED_B)   ; Display a 'spinning' pattern
                call    ShowLedPatternShort
                movlw   BIT(LED_A)|BIT(LED_D)
                call    ShowLedPatternShort
                movlw   BIT(LED_A)|BIT(LED_C)
                call    ShowLedPatternShort
                movlw   BIT(LED_A)|BIT(LED_D)
                call    ShowLedPatternShort

                movlw   BIT(LED_A)|BIT(LED_B)
                call    ShowLedPatternShort
                movlw   BIT(LED_A)|BIT(LED_D)
                call    ShowLedPatternShort
                movlw   BIT(LED_A)|BIT(LED_C)
                call    ShowLedPatternShort
                movlw   BIT(LED_A)|BIT(LED_D)
                call    ShowLedPatternShort

                movf    DICE,W                  ; Get the current dice value
                call    GetDicePattern          ; Convert to LED bit pattern
                movwf   LEDS

                clrw                            ; Then flash the dice patten
                call    ShowLedPatternLong      ; once ..
                movf    LEDS,W
                call    ShowLedPatternLong

                clrw
                call    ShowLedPatternLong      ; ..twice ..
                movf    LEDS,W
                call    ShowLedPatternLong

                clrw                            ; .. thrice ..
                call    ShowLedPatternLong
                movf    LEDS,W
                call    ShowLedPatternLong

                movlw   low POWEROFF_PERIOD     ; Load the auto-power off count
                movwf   COUNTL
                movlw   high POWEROFF_PERIOD
                movwf   COUNTH

WaitForPress:
                btfss   GPIO,SWITCH             ; Is the switch pressed?
                goto    DebouncePress           ; Yes, try debouncing it

                movlw   .1                      ; Wait one tick period
                call    TickDelay

                movf    COUNTL,W                ; Reduce power off counter
                btfsc   STATUS,Z
                decf    COUNTH,F
                decf    COUNTL,F                

                movf    COUNTL,W                ; Has it reached zero?
                iorwf   COUNTH,W
                btfss   STATUS,Z
                goto    WaitForPress
                
                clrf    GPIO                    ; All LEDs off
                movf    GPIO,W                  ; Read GPIO state then ...
                sleep                           ; Sleep to save power
                nop

DebouncePress:
                movlw   .1                      ; Wait one tick period
                call    TickDelay
                btfsc   GPIO,SWITCH             ; Switch still pressed?
                goto    WaitForPress            ; No, it was a bounce
                goto    WaitForRelease          ; Yes, start roll when released

                end