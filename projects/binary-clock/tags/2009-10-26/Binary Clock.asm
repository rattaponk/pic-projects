;===============================================================================
; Binary Clock
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
; 2009-06-10 Initial version
;-------------------------------------------------------------------------------
; $Id$
;-------------------------------------------------------------------------------

; Notes:
;
; This firmware implements a simple 24-hour binary clock that displays the time
; using a set of 20 LEDs connected to the output pins of the micro-controller.
; The LEDs are grouped into six sets representing the tens and units of the hour,
; minute and second values of the time.
;
; The micro-controller is configured to use its internal oscillator to drive
; program execution but the timing for the clock is derived from an external
; 32768Hz watch crystal used in conjunction with the Timer1 peripheral.
;
; Two push buttons are provided to adjust the hours and minutes for time setting.
; Between button presses and timer updates the micro-controller enters a low
; power state.

                errorlevel -302
                errorlevel -312

;===============================================================================
; Fuse Configuration
;-------------------------------------------------------------------------------

                ifdef   __16F882
                include P16F882.inc

CONFIG_STD      equ     _LVP_OFF & _FCMEN_OFF & _IESO_OFF & _BOR_OFF & _MCLRE_ON & _INTOSCIO
                ifdef   __DEBUG
CONFIG_BUILD    equ     _DEBUG_ON &  _CPD_OFF & _CP_OFF & _PWRTE_OFF & _WDT_OFF
                else
CONFIG_BUILD    equ     _DEBUG_ON &  _CPD_ON & _CP_ON & _PWRTE_ON & _WDT_ON
                endif

 __config _CONFIG1, CONFIG_STD & CONFIG_BUILD
 __config _CONFIG2, _WRT_OFF & _BOR40V
                endif

;-------------------------------------------------------------------------------

                ifdef   __16F886
                include P16F886.inc

CONFIG_STD      equ     _LVP_OFF & _FCMEN_OFF & _IESO_OFF & _BOR_OFF & _MCLRE_ON & _INTOSCIO
                ifdef   __DEBUG
CONFIG_BUILD    equ     _DEBUG_ON &  _CPD_OFF & _CP_OFF & _PWRTE_OFF & _WDT_OFF
                else
CONFIG_BUILD    equ     _DEBUG_ON &  _CPD_ON & _CP_ON & _PWRTE_ON & _WDT_ON
                endif

 __config _CONFIG1, CONFIG_STD & CONFIG_BUILD
 __config _CONFIG2, _WRT_OFF & _BOR40V
                endif

;-------------------------------------------------------------------------------

 __idlocs h'0100'

;===============================================================================
; Hardware Configuration
;-------------------------------------------------------------------------------

FOSC             equ     .4000000               ; Internal 4Mhz oscillator

;-------------------------------------------------------------------------------

TMR0_HZ         equ     .100                    ; Frequency of Timer0 interrupts
TMR0_PRESCALE   equ     .128

; Derive the corresponding number of timer increments per period

TMR0_COUNT      equ     FOSC / (.4 * TMR0_HZ * TMR0_PRESCALE)

                if      TMR0_COUNT > .255
                error   "TMR0 count too big - Adjust prescaler"
                endif

;-------------------------------------------------------------------------------

; The display LEDs are connected to the pins of PORT A, B & C in an order that
; makes a single sided PCB possible for the circuit. The following definitions
; relate bits in the time values with the associated output pin.

APORT           equ     .0
BPORT           equ     .1
CPORT           equ     .2

HH0_PORT        equ     APORT
HH0_BIT         equ     .0
HH1_PORT        equ     BPORT
HH1_BIT         equ     .5

HL0_PORT        equ     APORT
HL0_BIT         equ     .1
HL1_PORT        equ     APORT
HL1_BIT         equ     .2
HL2_PORT        equ     BPORT
HL2_BIT         equ     .4
HL3_PORT        equ     APORT
HL3_BIT         equ     .3

MH0_PORT        equ     APORT
MH0_BIT         equ     .4
MH1_PORT        equ     BPORT
MH1_BIT         equ     .2
MH2_PORT        equ     BPORT
MH2_BIT         equ     .3

ML0_PORT        equ     APORT
ML0_BIT         equ     .5
ML1_PORT        equ     BPORT
ML1_BIT         equ     .1
ML2_PORT        equ     BPORT
ML2_BIT         equ     .0
ML3_PORT        equ     APORT
ML3_BIT         equ     .7

SH0_PORT        equ     CPORT
SH0_BIT         equ     .6
SH1_PORT        equ     CPORT
SH1_BIT         equ     .7
SH2_PORT        equ     APORT
SH2_BIT         equ     .6

SL0_PORT        equ     CPORT
SL0_BIT         equ     .2
SL1_PORT        equ     CPORT
SL1_BIT         equ     .5
SL2_PORT        equ     CPORT
SL2_BIT         equ     .3
SL3_PORT        equ     CPORT
SL3_BIT         equ     .4

; Two pins on PORTB (with internal weak pull ups are used for the time
; adjustment switches.

SW_HRS          equ     .7
SW_MIN          equ     .6

;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

                udata_shr

; Key register save area during interrupts

_WREG           res     .1
_STATUS         res     .1
_PCLATH         res     .1

; The current time in BCD

HRS             res     .1
MIN             res     .1
SEC             res     .1

; Counter used for switch debouncing and auto repeat

TICKS           res     .1

; Shadow registers use to compose the bits for the I/O ports

BITS            res     .3

;===============================================================================
; Interrupt Handler
;-------------------------------------------------------------------------------

.Interrupt      code    h'004'

                movwf   _WREG                   ; Save key registers
                swapf   STATUS,W
                movwf   _STATUS
                movf    PCLATH,W
                movwf   _PCLATH

                pagesel $                       ; Ensure PCLATH is correct

;-------------------------------------------------------------------------------

                btfss   INTCON,TMR0IF           ; Has Timer0 overflowed?  
                goto    Timer0Handled           ; No.
                bcf     INTCON,TMR0IF

                banksel TMR0
                movlw   -TMR0_COUNT             ; Reset counter for next period
                addwf   TMR0,F

                movf    TICKS,W                 ; If tick counter is not zero
                btfss   STATUS,Z
                decf    TICKS,F                 ; .. decrement it by one
Timer0Handled:

;-------------------------------------------------------------------------------

                banksel PIR1
                btfss   PIR1,TMR1IF             ; Has Timer1 overflowed?
                goto    Timer1Handled           ; No.
                bcf     PIR1,TMR1IF

                banksel TMR1H
                movlw   h'80'                   ; Reset the counter
                movwf   TMR1H

                movf    SEC,W                   ; Increment seconds by one
                lcall   AddOne
                pagesel $
                movwf   SEC
                xorlw   h'60'                   ; Reached 60?
                btfss   STATUS,Z
                goto    Timer1Handled           ; Not yet.

                clrf    SEC                     ; Yes, reset to zero and ..
                movf    MIN,W                   ; Increment minutes by one
                lcall   AddOne
                pagesel $
                movwf   MIN
                xorlw   h'60'                   ; Reached 60?
                btfss   STATUS,Z
                goto    Timer1Handled           ; Not yet.

                clrf    MIN                     ; Yes, reset to zero and ..
                movf    HRS,W
                lcall   AddOne
                pagesel $
                movwf   HRS
                xorlw   h'24'                   ; Reached 24?
                btfsc   STATUS,Z
                clrf    HRS                     ; Yes, reset to midnight
Timer1Handled:

;-------------------------------------------------------------------------------

                btfss   INTCON,RBIF             ; Has PORTB changed?
                goto    PortBHandled            ; No.
                bcf     INTCON,RBIF

                banksel PORTB                   ; Yes, re-sample the port
                movf    PORTB,W
PortBHandled:

;-------------------------------------------------------------------------------
    
                movf    _PCLATH,W               ; Restore key registers
                movwf   PCLATH
                swapf   _STATUS,W
                movwf   STATUS
                swapf   _WREG,F
                swapf   _WREG,W
                retfie                          ; And continue

;===============================================================================
; Power On Reset
;-------------------------------------------------------------------------------

.ResetVector    code    h'000'

                lgoto   PowerOnReset

;-------------------------------------------------------------------------------

                code

PowerOnReset:
                banksel OPTION_REG
                movlw   b'00000110'
;                         0-------                PORTB pullups enabled
;                         -----110                TMR0 Prescaler /128
                movwf   OPTION_REG

;-------------------------------------------------------------------------------

                banksel PORTA                   ; Clear all port registers
                clrf    PORTA
                clrf    PORTB
                clrf    PORTB
                banksel ANSEL                   ; Disable analog features
                clrf    ANSEL
                clrf    ANSELH

                banksel TRISA                   ; And configure output pins 
                movlw   h'00'
                movwf   TRISA
                movlw   h'c0'
                movwf   TRISB
                movlw   h'01'
                movwf   TRISC

                banksel WPUB                    ; Enable pullups on switch pins
                movlw   h'c0'
                movwf   WPUB

                bsf     INTCON,RBIE             ; Enable interrupt on change

;-------------------------------------------------------------------------------

                banksel TMR0                    ; Clear Timer0 value
                clrf    TMR0

                bsf     INTCON,TMR0IE           ; Enable overflow interrupt
                bsf     INTCON,TMR0IF           ; .. and force an initial one

;-------------------------------------------------------------------------------

                banksel T1CON                   ; Configure Timer1
                movlw   b'00001110'
;                         ----1---                LP oscillator enabled
;                         -----1--                Asynchronis clock input
;                         ------1-                External clock source
;                         -------0                Timer off (for now)
                movwf   T1CON

                banksel TMR1L                   ; Clear the timer value
                clrf    TMR1L
                clrf    TMR1H

                banksel PIE1                    ; Enable overflow interrupt
                bsf     PIE1,TMR1IE
                banksel PIR1                    ; .. and force an initial one
                bsf     PIR1,TMR1IF

;--------------------------------------------------------------------------------

                clrf    HRS                     ; Reset time to midnight
                clrf    MIN
                clrf    SEC

                bsf     INTCON,PEIE             ; Enable peripheral interrupts
                bsf     INTCON,GIE              ; and start interrupt processing

                movlw   .5                      ; Wait a while LP oscillator
                movwf   TICKS                   ; .. becomes stable
WaitTillStable:
                clrwdt
                movf    TICKS,W
                btfss   STATUS,Z
                goto    WaitTillStable

                banksel T1CON                   ; Then enable the Timer1
                bsf     T1CON,TMR1ON

;===============================================================================
; Main Task
;-------------------------------------------------------------------------------

; The code spends most of its time here updating the LEDs to show the current
; time and testing the switch inputs.

DisplayTime:
                clrwdt
                call    UpdateTime              ; Update the displayed time

                banksel PORTB                   ; Hour adjustment pressed?
                btfss   PORTB,SW_HRS
                goto    AdjustHours             ; Yes.
                btfss   PORTB,SW_MIN            ; Minute adjustment pressed?
                goto    AdjustMinutes

                sleep                           ; Sleep until something happens
                nop
                nop
                goto    DisplayTime

;-------------------------------------------------------------------------------

AdjustHours:
                movlw   .3                      ; Set counter for debounce time
                movwf   TICKS
DebounceHours:
                clrwdt
                banksel PORTB
                btfsc   PORTB,SW_HRS            ; Is the switch still pressed?
                goto    DisplayTime             ; No, must have been a bounce
                movf    TICKS,W                 ; End of debounce period?
                btfss   STATUS,Z
                goto    DebounceHours           ; Not yet.
 
IncrementHours:
                movf    HRS,W                   ; Increment hours by one
                call    AddOne
                xorlw   h'24'                   ; Reached 24?
                btfss   STATUS,Z
                xorlw   h'24'                   ; Not yet, restore value
                movwf   HRS                     ; Save new value
                call    UpdateTime              ; Change LEDs to match

                movlw   .50                     ; Set counter for auto-repeat
                movwf   TICKS
AutoRepeatHours:
                clrwdt
                banksel PORTB
                btfsc   PORTB,SW_HRS            ; Is the switch still pressed?
                goto    DisplayTime             ; No, its been released
                movf    TICKS,W                 ; End of auto-repeat delay?
                btfss   STATUS,Z
                goto    AutoRepeatHours         ; Not yet
                goto    IncrementHours          ; Yes, adjust again

;-------------------------------------------------------------------------------

AdjustMinutes:
                movlw   .3                      ; Set counter for debounce time
                movwf   TICKS
DebounceMinutes:
                clrwdt
                banksel PORTB
                btfsc   PORTB,SW_MIN            ; Is the switch still pressed?
                goto    DisplayTime             ; No, must have been a bounce
                movf    TICKS,W                 ; End of debounce period?
                btfss   STATUS,Z
                goto    DebounceMinutes         ; Not yet.
 
IncrementMinutes:
                movf    MIN,W                   ; Increment minutes by one
                call    AddOne
                xorlw   h'60'                   ; Reached 60?
                btfss   STATUS,Z
                xorlw   h'60'                   ; Not yet, restore value
                movwf   MIN                     ; Save new value
                clrf    SEC                     ; Reset seconds
                call    UpdateTime              ; Change LEDs to match

                movlw   .50                     ; Set counter for auto-repeat
                movwf   TICKS
AutoRepeatMinutes:
                clrwdt
                banksel PORTB
                btfsc   PORTB,SW_MIN            ; Is the switch still pressed?
                goto    DisplayTime             ; No, its been released
                movf    TICKS,W                 ; End of auto-repeat delay?
                btfss   STATUS,Z
                goto    AutoRepeatMinutes       ; Not yet
                goto    IncrementMinutes        ; Yes, adjust again

;===============================================================================
; BCD Maths Routines
;-------------------------------------------------------------------------------

; Adds one to the BCD value in WREG.

AddOne:
                addlw   h'07'
                btfss   STATUS,DC
                addlw   -h'06'
                return

;===============================================================================
; LED Update
;-------------------------------------------------------------------------------

; Converts the current time into the pattern of port pin bits that will display
; it on the LEDs.

UpdateTime:
                clrf    BITS+.0                 ; Clear all pins then ..
                clrf    BITS+.1
                clrf    BITS+.2

                btfsc   HRS,.4                  ; Set bits for hours
                bsf     BITS+HH0_PORT,HH0_BIT
                btfsc   HRS,.5
                bsf     BITS+HH1_PORT,HH1_BIT

                btfsc   HRS,.0
                bsf     BITS+HL0_PORT,HL0_BIT
                btfsc   HRS,.1
                bsf     BITS+HL1_PORT,HL1_BIT
                btfsc   HRS,.2
                bsf     BITS+HL2_PORT,HL2_BIT
                btfsc   HRS,.3
                bsf     BITS+HL3_PORT,HL3_BIT

                btfsc   MIN,.4                  ; And bits for minutes
                bsf     BITS+MH0_PORT,MH0_BIT
                btfsc   MIN,.5
                bsf     BITS+MH1_PORT,MH1_BIT
                btfsc   MIN,.6
                bsf     BITS+MH2_PORT,MH2_BIT

                btfsc   MIN,.0
                bsf     BITS+ML0_PORT,ML0_BIT
                btfsc   MIN,.1
                bsf     BITS+ML1_PORT,ML1_BIT
                btfsc   MIN,.2
                bsf     BITS+ML2_PORT,ML2_BIT
                btfsc   MIN,.3
                bsf     BITS+ML3_PORT,ML3_BIT

                btfsc   SEC,.4                  ; And bits for seconds
                bsf     BITS+SH0_PORT,SH0_BIT
                btfsc   SEC,.5
                bsf     BITS+SH1_PORT,SH1_BIT
                btfsc   SEC,.6
                bsf     BITS+SH2_PORT,SH2_BIT

                btfsc   SEC,.0
                bsf     BITS+SL0_PORT,SL0_BIT
                btfsc   SEC,.1
                bsf     BITS+SL1_PORT,SL1_BIT
                btfsc   SEC,.2
                bsf     BITS+SL2_PORT,SL2_BIT
                btfsc   SEC,.3
                bsf     BITS+SL3_PORT,SL3_BIT

                banksel PORTA                   ; Copy bits to port pins
                movf    BITS+.0,W
                movwf   PORTA
                movf    BITS+.1,W
                movwf   PORTB
                movf    BITS+.2,W
                movwf   PORTC
                return

                end