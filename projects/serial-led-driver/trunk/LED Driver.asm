;===============================================================================
; Serial LED Driver
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
; 2009-10-21 Initial version
;-------------------------------------------------------------------------------
; $Id$
;-------------------------------------------------------------------------------

                errorlevel -302
                errorlevel -312

                include P16F690.inc

;===============================================================================
; Fuse Configuration
;-------------------------------------------------------------------------------

CONFIG_STD      equ     _FCMEN_OFF & _IESO_OFF & _BOR_ON & _MCLRE_OFF & _INTOSC

                ifdef   __DEBUG
CONFIG_BUILD    equ     _CPD_OFF & _CP_OFF & _PWRTE_OFF & _WDT_OFF
                else
CONFIG_BUILD    equ     _CPD_ON & _CP_ON & _PWRTE_ON & _WDT_ON
                endif

                __config CONFIG_STD & CONFIG_BUILD

;-------------------------------------------------------------------------------

                __idlocs h'0010'

;===============================================================================
; Macros
;-------------------------------------------------------------------------------

#define M(_X)   (.1 << (_X))

;===============================================================================
; Hardware Configuration
;-------------------------------------------------------------------------------

OSC             equ     .4000000                ; Internal 4Mhz oscillator

;-------------------------------------------------------------------------------

TMR0_HZ         equ     .200                    ; 
TMR0_POSTSCALE  equ     .128

TMR0_PERIOD     equ     OSC / (.4 * TMR0_HZ * TMR0_POSTSCALE)

                if      TMR0_PERIOD & h'ffffff00'
                error   "TMR0 Period bigger than 8-bits - Adjust postscaler"
                endif

;-------------------------------------------------------------------------------

TMR1_HZ         equ     .100                    
TMR1_PRESCALE   equ     .1

TMR1_PERIOD     equ     OSC / (.4 * TMR1_PRESCALE * TMR1_HZ)

                if      TMR1_PERIOD & h'ffff0000'
                error   "TMR1 Period bigger than 16-bits - Adjust postscaler"
                endif

;-------------------------------------------------------------------------------

TMR2_HZ         equ     .1024                   ; PWM Frequency
TMR2_PRESCALE   equ     .16

TMR2_PERIOD     equ     OSC / (.4 * TMR2_PRESCALE * TMR2_HZ)

                if      TMR2_PERIOD & h'ffffff00'
                error   "TMR2 Period bigger than 8-bits - Adjust pre/postscaler"
                endif

;-------------------------------------------------------------------------------

; Calculate BRG values for when BRG16 = 1 and BRGH = 1

BRG9600         equ     OSC / (.4 *  .9600) - .1
BRG19200        equ     OSC / (.4 * .19200) - .1

RX_SIZE         equ     .32
TX_SIZE         equ     .32

;-------------------------------------------------------------------------------

; Digit select pins on PORTA

LED_D1          equ     .0
LED_D2          equ     .1
LED_D3          equ     .2
LED_D4          equ     .4

; Physical LED segment pins on PORTA/PORTC

LED_A           equ     .0
LED_B           equ     .1
LED_C           equ     .2
LED_D           equ     .3
LED_E           equ     .4
LED_F           equ     .5
LED_G           equ     .6
LED_DP          equ     .7

PORT_BAUD       equ     PORTB
PIN_BAUD        equ     .6

; Logical LED Segments

SEG_A           equ     .0
SEG_B           equ     .1
SEG_C           equ     .2
SEG_D           equ     .3
SEG_E           equ     .4
SEG_F           equ     .5
SEG_G           equ     .6
SEG_DP          equ     .7

;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

; Save area for key registers during interrupt processing

.InterruptArea  udata_shr

_WREG           res     .1 
_STATUS         res     .1
_PCLATH         res     .1
_FSR            res     .1

TICKS           res     .1

; Display state registers

.LedState       udata_shr

DIGIT           res     .1                      ; The next digit to display
SEGMENTS        res     .4                      ; Segment patterns for each LED

                udata

DELAY           res     .1
CONTROL         res     .1

BINARY_MODE     equ     .7

DISPLAY         res     .4

; Communications buffers and pointers

.Comms          udata

RX_HEAD         res     .1                      ; Index of first character
RX_TAIL         res     .1                      ; Index of last character

TX_HEAD         res     .1                      ; Index of first character
TX_TAIL         res     .1                      ; Index of last character

.CommsRx        udata

RX_BUFFER       res     RX_SIZE                 ; Receive FIFO buffer

.CommsTx        udata

TX_BUFFER       res     TX_SIZE                 ; Transmit FIFO buffer

; General non-interrupt scratch space

.Temporary      udata_shr

TEMP            res     .1

;===============================================================================
; Interrupt Handler
;-------------------------------------------------------------------------------

.Interrupt      code    h'004'

                movwf   _WREG                   ; Save key registers
                swapf   STATUS,W
                movwf   _STATUS
                movf    PCLATH,W
                movwf   _PCLATH
                movf    FSR,W
                movwf   _FSR

                clrf    PCLATH                  ; Ensure PCLATH is correct

        banksel PORTB
        bsf     PORTB,.4

;-------------------------------------------------------------------------------

                btfss   INTCON,T0IF             ; Timer0 overflowed?
                goto    Timer0Handled           ; No.
                bcf     INTCON,T0IF             ; Yes. 

                banksel TMR0                    ; Reset counter for next period
                movlw   low -TMR0_PERIOD
                addwf   TMR0,F

                movf    TICKS,F                 ; Decrement timing counter
                btfss   STATUS,Z
                decf    TICKS,F

                banksel PORTA                   ; Clear current display
                movlw   b'11001000'
                andwf   PORTA,F
                movlw   b'00100000'
                andwf   PORTC,F

                bankisel SEGMENTS               ; Point FSR at the segment data
                movlw   SEGMENTS
                addwf   DIGIT,W
                movwf   FSR

                movf    DIGIT,W                 ; Use a jump table to obtain
                addwf   DIGIT,W                 ; .. digit select mask
                addwf   PCL,F

                movlw   M(LED_D1)
                goto    UpdateDisplay
                movlw   M(LED_D2)
                goto    UpdateDisplay
                movlw   M(LED_D3)
                goto    UpdateDisplay
                movlw   M(LED_D4)
                goto    UpdateDisplay

UpdateDisplay:
                btfsc   INDF,.5                 ; Merge in state of segment
                iorlw   b'00100000'             ; .. on PORTA

                iorwf   PORTA,F                 ; Set digit select
                movf    INDF,W                  ; Fetch segment pattern
                andlw   b'11011111'             ; .. remove bit on PORTA
                iorwf   PORTC,F                 ; .. and merge into PORTC

                incf    DIGIT,W                 ; Increment the digit select
                andlw   .3                      ; .. wrap around
                movwf   DIGIT                   ; .. and store back
Timer0Handled:

;-------------------------------------------------------------------------------

                banksel PIR1                    ; USART receive interrupt?
                btfss   PIR1,RCIF
                goto    UsartRxHandled          ; No.

                bankisel RX_BUFFER              ; Point FSR at end of buffer
                movlw   RX_BUFFER
                banksel RX_TAIL
                addwf   RX_TAIL,W
                movwf   FSR

                banksel RCREG
                movf    RCREG,W                 ; Copy received character to
                movwf   INDF                    ; .. end of RX data FIFO               
                
                banksel RX_TAIL
                incf    RX_TAIL,W               ; Bump tail pointer by one
                xorlw   RX_SIZE                 ; .. and handle wrap around
                btfss   STATUS,Z
                xorlw   RX_SIZE
                movwf   RX_TAIL
UsartRxHandled:

;-------------------------------------------------------------------------------

                banksel PIE1                    ; Is USART transmit enabled?
                btfss   PIE1,TXIE
                goto    UsartTxHandled          ; No.

                banksel PIR1                    ; USART transmit interrupt?
                btfss   PIR1,TXIF
                goto    UsartTxHandled          ; No.

                banksel TX_HEAD
                movf    TX_HEAD,W               ; Any data left to send?
                xorwf   TX_TAIL,W
                btfss   STATUS,Z
                goto    TxNextByte              ; Yes, at least one more

                banksel PIE1
                bcf     PIE1,TXIE               ; No, disable interrupt
                goto    UsartTxHandled

TxNextByte:
                bankisel TX_BUFFER              ; Point FSR at next character
                movlw   TX_BUFFER
                addwf   TX_HEAD,W
                movwf   FSR

                banksel TXREG
                movf    INDF,W                  ; Copy next characater to
                movwf   TXREG                   ; .. transmit register

                banksel TX_HEAD
                incf    TX_HEAD,W               ; Bump head pointer by one
                xorlw   TX_SIZE                 ; .. and handle wrap around
                btfss   STATUS,Z
                xorlw   TX_SIZE
                movwf   TX_HEAD
UsartTxHandled:

;-------------------------------------------------------------------------------

        banksel PORTB
        bcf     PORTB,.4

                movf    _FSR,W                  ; Restore saved registers
                movwf   FSR
                movf    _PCLATH,W
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
                movlw   b'00000110'             ; Configure device options
;                         0-------                PORTA/B Weak pull ups enabled
;                         -x------                INT edge
;                         --0-----                Timer0 clock source internal
;                         ---0----                Increment on rising edge   
;                         ----0---                Prescaler assigned to Timer0
;                         -----110                /128 prescaler
                movwf   OPTION_REG

;-------------------------------------------------------------------------------

                banksel PORTA                   ; Clear all I/O ports
                clrf    PORTA
                clrf    PORTB
                clrf    PORTC
                banksel ANSEL                   ; And make them digital
                clrf    ANSEL
                clrf    ANSELH

                banksel TRISA                   ; Set pin mode to match usage
                movlw   b'00001000'
                movwf   TRISA
                movlw   b'01100000'
                movwf   TRISB
                movlw   b'00000000'
                movwf   TRISC

                banksel WPUB                    ; And enable weak pull on
                bsf     WPUB,PIN_BAUD           ; .. baud rate selection pin

;-------------------------------------------------------------------------------

                banksel TMR0                    ; Reset Timer0
                clrf    TMR0

                clrf    DIGIT                   ; Reset digit multiplex count
                movlw   h'ff'
                movwf   SEGMENTS+.0
                movwf   SEGMENTS+.1
                movwf   SEGMENTS+.2
                movwf   SEGMENTS+.3

                bsf     INTCON,T0IE             ; Enable Timer0 interrupts
                bsf     INTCON,T0IF             ; .. and force an initial one

;-------------------------------------------------------------------------------

                banksel PR2                     ; Set period for PWM signal
                movlw   TMR2_PERIOD
                movwf   PR2

                banksel CCP1CON                 ; Configure module for PWM
                movlw   b'00001100'
;                         00------                Single output
;                         --00----                MSB of duty cycle
;                         ----1100                PWM Mode
                movwf   CCP1CON

                banksel CCPR1L
                movlw   TMR2_PERIOD / .2        ; 50% Duty cycle
                movwf   CCPR1L

                banksel T2CON
                movlw   b'00000110'
;                         -xxxx---                16x Postscale
;                         -----1--                On
;                         ------10                16x Prescale
                movwf   T2CON

;-------------------------------------------------------------------------------

                banksel PORT_BAUD               ; Read baud rate selection pin
                btfss   PORTB,PIN_BAUD          ; Is it pulled hi?
                goto    SetHiBaud               ; No, externally pulled low
        
SetLoBaud:           
                banksel SPBRG
                movlw   low BRG9600             ; Set baud rate generator for
                movwf   SPBRG                   ; .. 9600 baud
                movlw   high BRG9600
                movwf   SPBRGH
                goto    EnableUsart    

SetHiBaud:      
                banksel SPBRG
                movlw   low BRG19200            ; Set baud rate generator for
                movwf   SPBRG                   ; .. 19200 baud
                movlw   high BRG19200
                movwf   SPBRGH

EnableUsart: 
                movlw   b'00001000'             ; Configure baud rate generator
;                         x-------                Auto-baud detect overflow
;                         -x------                Recieve idle flag
;                         ---0----                Transmit non-inverted data
;                         ----1---                16-bit baud rate generator
;                         ------0-                Wake up disabled
;                         -------0                Auto baud detect disabled
                movwf   BAUDCTL
                
                movlw   b'00100100'             ; Configure Transmit module
;                         x-------                CSRC - Don't care
;                         -0------                8-bit transmission
;                         --1-----                Transmit enabled
;                         ---0----                Asynchronous mode
;                         ----0---                Not sending break
;                         -----1--                BRGH - High speed
;                         ------x-                Shift register status
;                         -------x                Ninth bit
                movwf   TXSTA

                banksel RCSTA
                movlw   b'10010000'             ; Configure Receive module
;                         1-------                Enable USART
;                         -0------                8-bit reception
;                         --x-----                Single recieve
;                         ---1----                Continuous reception
;                         ----x---                Address detect
;                         -----x--                Framing error
;                         ------x-                Overrun error
;                         -------x                Ninth bit
                movwf   RCSTA

                movf    RCREG,W                 ; Discard any pending data

                banksel PIE1                    ; And enable interrupts
                bsf     PIE1,RCIE
                bcf     PIE1,TXIE

;-------------------------------------------------------------------------------

                clrf    RX_HEAD                 ; Mark receive buffer as empty
                clrf    RX_TAIL
                clrf    TX_HEAD                 ; Mark transmit buffer as empty
                clrf    TX_TAIL

                bsf     INTCON,PEIE
                bsf     INTCON,GIE              ; Start interrupt processing

;===============================================================================
; Main Task
;-------------------------------------------------------------------------------

WaitForCommand:
                call    UsartRx

                xorlw   'A'                     ; Set ASCII encoding
                btfsc   STATUS,Z
                goto    SetAscii
                xorlw   'B'^'A'                 ; Set Binary encoding
                btfsc   STATUS,Z
                goto    SetBinary
                xorlw   'C'^'B'                 ; Clear Display
                btfsc   STATUS,Z
                goto    ClearDisplay

                xorlw   'D'^'C'                 ; Direct Display
                btfsc   STATUS,Z
                goto    DirectDisplay

                goto    WaitForCommand


;-------------------------------------------------------------------------------

SetAscii:
                banksel CONTROL
                bcf     CONTROL,BINARY_MODE
                goto    WaitForCommand


SetBinary:
                banksel CONTROL
                bsf     CONTROL,BINARY_MODE
                goto    WaitForCommand

;-------------------------------------------------------------------------------

ClearDisplay:
                banksel DISPLAY                 ; Clear the display values
                clrf    DISPLAY+.0
                clrf    DISPLAY+.1
                clrf    DISPLAY+.2
                clrf    DISPLAY+.3
                goto    DirectUpdate

DirectDisplay:
                call    ReadDisplay             ; Read the display values
DirectUpdate:
                banksel DISPLAY                 ; Copy the display data direct
                movf    DISPLAY+.0,W            ; .. to the LEDs
                movwf   SEGMENTS+.0
                movf    DISPLAY+.1,W
                movwf   SEGMENTS+.1
                movf    DISPLAY+.2,W
                movwf   SEGMENTS+.2
                movf    DISPLAY+.3,W
                movwf   SEGMENTS+.3
                goto    WaitForCommand


;-------------------------------------------------------------------------------

ReadDisplay:
                banksel CONTROL                 ; Are we in binary mode?
                btfss   CONTROL,BINARY_MODE
                goto    ReadAscii

ReadBinary:
                call    UsartRx
                call    ConvertBits
                banksel DISPLAY
                movwf   DISPLAY+.0
                call    UsartRx
                call    ConvertBits
                banksel DISPLAY
                movwf   DISPLAY+.1
                call    UsartRx
                call    ConvertBits
                banksel DISPLAY
                movwf   DISPLAY+.2
                call    UsartRx
                call    ConvertBits
                banksel DISPLAY
                movwf   DISPLAY+.3
                return

; Read a sequence of ([ 0-9a-F][.]?){4}

ReadAscii:
                banksel DISPLAY                 ; Clear the display values
                clrf    DISPLAY+.0
                clrf    DISPLAY+.1
                clrf    DISPLAY+.2
                clrf    DISPLAY+.3

ReadDigit1:
                call    UsartRx
                call    ConvertHex
                call    ConvertBits
                banksel DISPLAY
                movwf   DISPLAY+.3
                call    UsartPeek
                xorlw   '.'                     ; Trailing decimal point?
                btfss   STATUS,Z
                goto    ReadDigit2              ; No.
                banksel DISPLAY
                bsf     DISPLAY+.3,LED_DP       ; Yes, add DP
                call    UsartRx                 ; Discard full stop
ReadDigit2:
                call    ShiftDisplay            
                call    UsartRx
                call    ConvertHex
                call    ConvertBits
                banksel DISPLAY
                movwf   DISPLAY+.3
                call    UsartPeek
                xorlw   '.'                     ; Trailing decimal point?
                btfss   STATUS,Z
                goto    ReadDigit3              ; No.
                banksel DISPLAY
                bsf     DISPLAY+.3,LED_DP       ; Yes, add DP
                call    UsartRx                 ; Discard full stop
ReadDigit3:
                call    ShiftDisplay
                call    UsartRx           
                call    ConvertHex
                call    ConvertBits
                banksel DISPLAY
                movwf   DISPLAY+.3
                call    UsartPeek
                xorlw   '.'                     ; Trailing decimal point?
                btfss   STATUS,Z
                goto    ReadDigit4              ; No.
                banksel DISPLAY
                bsf     DISPLAY+.3,LED_DP       ; Yes, add DP
                call    UsartRx                 ; Discard full stop
ReadDigit4:
                call    ShiftDisplay
                call    UsartRx              
                call    ConvertHex
                call    ConvertBits
                banksel DISPLAY
                movwf   DISPLAY+.3
                call    UsartPeek
                xorlw   '.'                     ; Trailing decimal point?
                btfss   STATUS,Z
                return                          ; No.
                banksel DISPLAY
                bsf     DISPLAY+.3,LED_DP       ; Yes, add DP
                goto    UsartRx                 ; Discard full stop


ShiftDisplay:
                banksel DISPLAY
                movf    DISPLAY+.1,W
                movwf   DISPLAY+.0
                movf    DISPLAY+.2,W
                movwf   DISPLAY+.1
                movf    DISPLAY+.3,W
                movwf   DISPLAY+.2
                clrf    DISPLAY+.3
                return

;-------------------------------------------------------------------------------

ConvertHex:
                xorlw   ' '                     ; Blank?
                btfsc   STATUS,Z
                retlw   .0
                xorlw   '0'^' '                 ; 0?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_B)|M(SEG_C)|M(SEG_D)|M(SEG_E)|M(SEG_F)
                xorlw   '1'^'0'                 ; 1?
                btfsc   STATUS,Z
                retlw   M(SEG_B)|M(SEG_C)
                xorlw   '2'^'1'                 ; 2?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_B)|M(SEG_D)|M(SEG_E)|M(SEG_G)
                xorlw   '3'^'2'                 ; 3?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_B)|M(SEG_C)|M(SEG_D)|M(SEG_G)
                xorlw   '4'^'3'                 ; 4?
                btfsc   STATUS,Z
                retlw   M(SEG_B)|M(SEG_C)|M(SEG_F)|M(SEG_G)
                xorlw   '5'^'4'                 ; 5?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_C)|M(SEG_D)|M(SEG_F)|M(SEG_G)
                xorlw   '6'^'5'                 ; 6?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_C)|M(SEG_D)|M(SEG_E)|M(SEG_F)|M(SEG_G)
                xorlw   '7'^'6'                 ; 7?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_B)|M(SEG_C)
                xorlw   '8'^'7'                 ; 8?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_B)|M(SEG_C)|M(SEG_D)|M(SEG_E)|M(SEG_F)|M(SEG_G)
                xorlw   '9'^'8'                 ; 9?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_B)|M(SEG_C)|M(SEG_F)|M(SEG_G)
                xorlw   'A'^'9'                 ; A?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_B)|M(SEG_C)|M(SEG_E)|M(SEG_F)|M(SEG_G)
                xorlw   'a'^'A'                 ; a?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_B)|M(SEG_C)|M(SEG_E)|M(SEG_F)|M(SEG_G)
                xorlw   'B'^'a'                 ; B?
                btfsc   STATUS,Z
                retlw   M(SEG_C)|M(SEG_D)|M(SEG_E)|M(SEG_F)|M(SEG_G)
                xorlw   'b'^'B'                 ; b?
                btfsc   STATUS,Z
                retlw   M(SEG_C)|M(SEG_D)|M(SEG_E)|M(SEG_F)|M(SEG_G)
                xorlw   'C'^'b'                 ; C?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_D)|M(SEG_E)|M(SEG_F)
                xorlw   'c'^'C'                 ; c?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_D)|M(SEG_E)|M(SEG_F)
                xorlw   'D'^'c'                 ; D?
                btfsc   STATUS,Z
                retlw   M(SEG_B)|M(SEG_C)|M(SEG_D)|M(SEG_E)|M(SEG_G)
                xorlw   'd'^'D'                 ; d?
                btfsc   STATUS,Z
                retlw   M(SEG_B)|M(SEG_C)|M(SEG_D)|M(SEG_E)|M(SEG_G)
                xorlw   'E'^'d'                 ; E?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_D)|M(SEG_E)|M(SEG_F)|M(SEG_G)
                xorlw   'e'^'E'                 ; e?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_D)|M(SEG_E)|M(SEG_F)|M(SEG_G)
                xorlw   'F'^'e'                 ; F?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_E)|M(SEG_F)|M(SEG_G)
                xorlw   'f'^'F'                 ; f?
                btfsc   STATUS,Z
                retlw   M(SEG_A)|M(SEG_E)|M(SEG_F)|M(SEG_G)

                retlw   M(SEG_A)|M(SEG_D)|M(SEG_G)


ConvertBits:
                movwf   TEMP
                clrw
                btfsc   TEMP,SEG_A
                iorlw   M(LED_A)
                btfsc   TEMP,SEG_B
                iorlw   M(LED_B)
                btfsc   TEMP,SEG_C
                iorlw   M(LED_C)
                btfsc   TEMP,SEG_D
                iorlw   M(LED_D)
                btfsc   TEMP,SEG_E
                iorlw   M(LED_E)
                btfsc   TEMP,SEG_F
                iorlw   M(LED_F)
                btfsc   TEMP,SEG_G
                iorlw   M(LED_G)
                btfsc   TEMP,SEG_DP
                iorlw   M(LED_DP)
                return


;===============================================================================
; Serial FIFO Interface
;-------------------------------------------------------------------------------

; Reads the next characater from the recieved data FIFO. If the buffer is empty
; wait for some data to arrive.

UsartRx:
                call    UsartPeek               ; Get the next character
                movwf   TEMP                    ; And save it

                incf    RX_HEAD,W               ; Increment the head pointer
                xorlw   RX_SIZE                 ; .. and wrap around
                btfss   STATUS,Z
                xorlw   RX_SIZE
                movwf   RX_HEAD 

                movf    TEMP,W                  ; Return the character
                return

;

UsartPeek:
                banksel RX_HEAD
                call    WaitForData

                bankisel RX_BUFFER              ; Point FSR at head character
                movlw   RX_BUFFER
                addwf   RX_HEAD,W
                movwf   FSR
                movf    INDF,W                  ; Recover the data
                return

WaitForData:
                clrwdt
                movf    RX_HEAD,W               ; Is the buffer empty?
                xorwf   RX_TAIL,W
                btfsc   STATUS,Z
                goto    WaitForData             ; Yes, wait for some to arrive

                bankisel RX_BUFFER              ; Point FSR at head character
                movlw   RX_BUFFER
                addwf   RX_HEAD,W
                movwf   FSR

                movf    INDF,W                  ; And recover the data
                return

; Adds character to the transmit FIFO and ensures that the transmit interrupt
; is enabled. If the buffer is full then wait for a space before adding the
; character

UsartTx:
                movwf   TEMP                    ; Save the new character
                banksel TX_TAIL 
WaitForSpace:
                clrwdt                          ; Test if the buffer is full
                incf    TX_TAIL,W
                xorlw   TX_SIZE
                btfss   STATUS,Z
                xorlw   TX_SIZE
                xorwf   TX_HEAD,W
                btfsc   STATUS,Z                
                goto    WaitForSpace            ; And loop until a space

                bankisel TX_BUFFER              ; Point FSR at the tail         
                movlw   TX_BUFFER
                addwf   TX_TAIL,W
                movwf   FSR

                movf    TEMP,W                  ; And insert the character
                movwf   INDF
                
                incf    TX_TAIL,W               ; Then move the tail pointer
                xorlw   TX_SIZE                 ; .. and wrap around
                btfss   STATUS,Z
                xorlw   TX_SIZE
                movwf   TX_TAIL

                banksel PIE1                    ; Enable transmit interrupts
                bsf     PIE1,TXIE
                return

;===============================================================================
; EEPROM Memory Access
;-------------------------------------------------------------------------------

; Sets the address that the next EEPROM read or write will access.

EepromSetAddr:
                banksel EEADR
                movwf   EEADR                   ; Save target address
                return

; Perform a read from EEPROM return the byte in WREG and incrementing the
; address of the next access.

EepromRead:
                banksel EECON1
                bcf     EECON1,EEPGD            ; Set to read data
                bsf     EECON1,RD               ; And start a read
                banksel EEDAT
                movf    EEDAT,W                 ; Fetch the data
                incf    EEADR,F                 ; And move the address on
                return

; Perform a write to EEPROM of the byte in WREG and increment the address ready
; for the next access.

EepromWrite:
                banksel EEDAT
                movwf   EEDAT                   ; Save target data
                banksel EECON1
                bcf     EECON1,EEPGD            ; Set to write data
                bsf     EECON1,WREN             ; And write enable
                rlf     STATUS,W                ; Copy GIE state to carry 
                bcf     INTCON,GIE              ; Disable interrupts
                btfsc   INTCON,GIE
                goto    $-.2
                movlw   h'55'                   ; Perform unlock sequence
                movwf   EECON2
                movlw   h'aa'
                movwf   EECON2
                bsf     EECON1,WR               ; Start write operation
                btfsc   STATUS,C                ; Restore interrupt state
                bsf     INTCON,GIE
                btfsc   EECON1,WR               ; Wait for write to complete
                goto    $-.1
                bcf     EECON1,WREN             ; Disable writes
                banksel EEADR
                incf    EEADR,F                 ; And increment target address
                return

                end