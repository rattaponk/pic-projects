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
 __config _MCLRE_OFF & _CP_ON & _WDT_OOFF & _IntRC_OSC
                endif
                endif

;-------------------------------------------------------------------------------

; The BIT macro converts a bit number into its corresponding value (e.g. bit 2
; equals 1 << 2 which evaluates to 4).
		
#define BIT(_X)	(.1 << (_X))

;===============================================================================
; Hardware Configuration
;-------------------------------------------------------------------------------
		
OSC             equ     .4000000
FOSC            equ     OSC / .4

;-------------------------------------------------------------------------------

TMR0_HZ         equ     .100
TMR0_PRESCALE   equ     .128

TMR0_PERIOD     equ     FOSC / (TMR0_HZ * TMR0_PRESCALE) 

;------------------------------------------------------------------------------

SWITCH          equ     .3

LED_A           equ     .0
LED_B           equ     .1
LED_C           equ     .2
LED_D           equ     .4

POWEROFF_PERIOD equ     .60 * TMR0_HZ

;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

                udata

DICE            res     .1              ; The current dice value (0 - 5)

LEDS            res     .1

TICKS           res     .1              ; A counter 

COUNTL          res     .1
COUNTH          res     .1

;===============================================================================
;-------------------------------------------------------------------------------

                code	h'000'

                btfss   STATUS,NOT_PD           ; Is this a power on reset?
                goto    WaitForRelease          ; No, its a wake up
                goto	PowerOnReset		; Yes, do full initialisation

;===============================================================================
;-------------------------------------------------------------------------------

; Convert the dice value (0 to 5) in WREG into the bit pattern needed to light
; the corresponding LEDs.

GetDicePattern:
                addwf	PCL,F
                retlw   BIT(LED_A)
                retlw   BIT(LED_B)
                retlw   BIT(LED_A)|BIT(LED_C)
                retlw   BIT(LED_B)|BIT(LED_C)
                retlw   BIT(LED_A)|BIT(LED_B)|BIT(LED_C)
                retlw   BIT(LED_B)|BIT(LED_C)|BIT(LED_D)

; Delay for WREG ticks but keep changing the dice value during this time to
; randomise it.

TickDelay:
                movwf   TICKS
ResetTimer:
                movlw   low -TMR0_PERIOD
                movwf   TMR0
Spinning:
                incf    DICE,W                  ; Bump dice value by one
                xorlw   .6                      ; Too big?		
                btfss   STATUS,Z
                xorlw   .6                      ; No, undo comparison
                movwf   DICE                    ; And save result

                movf    TMR0,W                  ; Has the timer reached zero?
                btfss   STATUS,Z
                goto    Spinning                ; No, wait some more

                decfsz  TICKS,F                 ; End of the delay?
                goto    ResetTimer              ; No.
 
                retlw   .0


ShowLedPatternShort:
                movwf   GPIO
                movlw   .10
                goto    TickDelay

ShowLedPatternLong:
                movwf   GPIO
                movlw   .30
                goto    TickDelay

;==============================================================================
;------------------------------------------------------------------------------

PowerOnReset:
                movlw	b'00000110'
;                         0-------              ; Enable Wakeup on GPIO change
;			  -0------              ; Enable Weak pullups
;			  --0-----              ; Timer0 uses internal clock
;			  ---x----              ; Timer0 src edge (don't care)
;			  ----0---              ; Prescaler assigned to timer0
;			  -----110              ; /128
                option                          ; Set option bits

                movlw	BIT(SWITCH)             ; Make all LED pins outputs
                tris	GPIO
                clrf	GPIO                    ; And switch them off

                banksel DICE
                clrf    DICE

WaitForRelease:
                movlw   .1                      ; Wait for one tick period
                call    TickDelay
                btfss   GPIO,SWITCH             ; Is the switch released
                goto    WaitForRelease          ; No. wait some more

                movlw   BIT(LED_A)|BIT(LED_B)
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

                clrw
                call    ShowLedPatternLong
                movf    LEDS,W
                call    ShowLedPatternLong

                clrw
                call    ShowLedPatternLong
                movf    LEDS,W
                call    ShowLedPatternLong

                clrw
                call    ShowLedPatternLong
                movf    LEDS,W
                call    ShowLedPatternLong

                movlw   low POWEROFF_PERIOD
                movwf   COUNTL
                movlw   high POWEROFF_PERIOD
                movwf   COUNTH

WaitForPress:
                btfss   GPIO,SWITCH             ; Is the switch pressed?
                goto    DebouncePress           ; Yes, try debouncing it

                movlw   .1                      ; Wait one tick period
                call    TickDelay
                decfsz  COUNTL,F                ; Reduce power off counter
                goto    WaitForPress
                decfsz  COUNTH,F
                goto    WaitForPress
                
                sleep                           ; Sleep to save power

DebouncePress:
                movlw   .1                      ; Wait one tick period
                call    TickDelay
                btfsc   GPIO,SWITCH             ; Switch still pressed?
                goto    WaitForPress            ; No, it was a bounce
                goto    WaitForRelease          ; Yes, start roll when released

                end