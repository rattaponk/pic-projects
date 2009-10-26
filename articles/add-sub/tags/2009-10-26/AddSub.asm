;===============================================================================
; 16/24/32-Bit Addition and Subtraction Examples
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
; 2009-09-15 Initial version
;-------------------------------------------------------------------------------
; $Id$
;-------------------------------------------------------------------------------

                ifdef   __12F510
                include P12F510.inc

__ARCH12        equ     .1
                endif

;-------------------------------------------------------------------------------

                ifdef   __16F628A
                include P16F628A.inc

__ARCH14        equ     .1
                endif

;-------------------------------------------------------------------------------

                ifdef   __16F1933
                include P16F1933.inc

__ARCH14        equ     .1
__ARCH14E	equ	.1
                endif

;-------------------------------------------------------------------------------

                ifdef   __18F4680
                include P18F4680.inc

__ARCH16        equ     .1
                endif

;-------------------------------------------------------------------------------

                ifndef  __ARCH12
__ARCH12        equ     .0
                endif

                ifndef  __ARCH14
__ARCH14        equ     .0
                endif

                ifndef  __ARCH16
__ARCH16        equ     .0
                endif

                if      (__ARCH12 | __ARCH14 | __ARCH16) == 0
                error   "One of the device family symbols must be set"
                endif

                ifndef  __ARCH14E
__ARCH14E       equ     .0
                endif

;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

                udata

; Result area for R += A, R -= A, R = A + B and R = A - B operations

R0              res     .1
R1              res     .1
R2              res     .1
R3              res     .1

; Argument A

A0              res     .1
A1              res     .1
A2              res     .1
A3              res     .1

; Argument B

B0              res     .1
B1              res     .1
B2              res     .1
B3              res     .1

;===============================================================================
; Test Code
;-------------------------------------------------------------------------------

                code    h'000'

                banksel A0                      ; Ensure correct bank selected

;------------------------------------------------------------------------------

; Set test value that are not changed

                call    SetA
                call    SetB

; 16-bit Addition (All Devices)

                call    SetR                    ; Load test for R

                movf    A0,W                    ; R += A
                addwf   R0,F
                movf    A1,W
                btfsc   STATUS,C
                incfsz  A1,W
                addwf   R1,F

                nop                             ; R0-1 should be h'eca8'

                movf    B0,W                    ; R = A + B
                addwf   A0,W
                movwf   R0
                movf    A1,W
                movwf   R1
                movf    B1,W
                btfsc   STATUS,C
                incfsz  B1,W
                addwf   R1,F

                nop                             ; R0-1 should still be h'eca8'

                if      __ARCH14E | __ARCH16

                call    SetR                    ; Reload R value

                movf    A0,W                    ; R += A
                addwf   R0,F
                movf    A1,W
                addwfc  R1,F

                nop                             ; R0-1 should be h'eca8'

                movf    B0,W                    ; R = A + B
                addwf   A0,W
                movwf   R0
                movf    B1,W
                addwfc  A1,W
                movwf   R1
                
                nop                             ; R0-1 should still be h'eca8'

                endif

; 24-bit Addition (All Devices)   
 
                call    SetR                    ; Load test for R

                movf    A0,W                    ; R = A + B
                addwf   R0,F
                movf    A1,W
                btfsc   STATUS,C
                incfsz  A1,W
                addwf   R1,F
                movf    A2,W
                btfsc   STATUS,C
                incfsz  A2,W
                addwf   R2,F

                nop                             ; R0-2 should be h'30eca8'

                movf    B0,W                    ; R = A + B
                addwf   A0,W
                movwf   R0
                movf    A1,W
                movwf   R1
                movf    B1,W
                btfsc   STATUS,C
                incfsz  B1,W
                addwf   R1,F
                movf    A2,W
                movwf   R2
                movf    B2,W
                btfsc   STATUS,C
                incfsz  B2,W
                addwf   R2,F

                nop                             ; R0-2 should still be h'30eca8'

; 32-bit Addition (All devices)

                call    SetR                    ; Load test for R

                movf    A0,W                    ; R += A
                addwf   R0,F  
                movf    A1,W
                btfsc   STATUS,C
                incfsz  A1,W
                addwf   R1,F  
                movf    A2,W
                btfsc   STATUS,C
                incfsz  A2,W
                addwf   R2,F
                movf    A3,W
                btfsc   STATUS,C
                incfsz  A3,W
                addwf   R3,F

                nop                             ; R0-3 should be h'7530eca8'

                movf    B0,W                    ; R = A + B
                addwf   A0,W
                movwf   R0
                movf    A1,W
                movwf   R1
                movf    B1,W
                btfsc   STATUS,C
                incfsz  B1,W
                addwf   R1,F
                movf    A2,W
                movwf   R2
                movf    B2,W
                btfsc   STATUS,C
                incfsz  B2,W
                addwf   R2,F
                movf    A3,W
                movwf   R3
                movf    B3,W
                btfsc   STATUS,C
                incfsz  B3,W
                addwf   R3,F

                nop                             ; R0-3 should still be h'7530eca8'


;-------------------------------------------------------------------------------

; 16-bit Subtraction (All Devices)

                call    SetR                    ; Load test for R

                movf    A0,W                    ; R -= A
                subwf   R0,F
                movf    A1,W
                btfss   STATUS,C
                incfsz  A1,W
                subwf   R1,F

                nop                             ; R0-1 should be h'7778'

                movf    B0,W                    ; R = A - B
                subwf   A0,W
                movwf   R0
                movf    A1,W
                movwf   R1
                movf    B1,W
                btfss   STATUS,C
                incfsz  B1,W
                subwf   R1,F

                nop                             ; R0-1 should be h'8888'

; 24-bit Subtraction (All Devices)   
 
                call    SetR                    ; Load test for R

                movf    A0,W                    ; R -= A
                subwf   R0,F
                movf    A1,W
                btfss   STATUS,C
                incfsz  A1,W
                subwf   R1,F
                movf    A2,W
                btfss   STATUS,C
                incfsz  A2,W
                subwf   R2,F

                nop                             ; R0-2 should be h'777778'

                movf    B0,W                    ; R = A - B
                subwf   A0,W
                movwf   R0
                movf    A1,W
                movwf   R1
                movf    B1,W
                btfss   STATUS,C
                incfsz  B1,W
                subwf   R1,F
                movf    A2,W
                movwf   R2
                movf    B2,W
                btfss   STATUS,C
                incfsz  B2,W
                subwf   R2,F

                nop                             ; R0-2 should be h'88888'

; 32-bit Subtraction (All devices)

                call    SetR                    ; Load test for R

                movf    A0,W                    ; R -= A
                subwf   R0,F  
                movf    A1,W
                btfss   STATUS,C
                incfsz  A1,W
                subwf   R1,F  
                movf    A2,W
                btfss   STATUS,C
                incfsz  A2,W
                subwf   R2,F
                movf    A3,W
                btfss   STATUS,C
                incfsz  A3,W
                subwf   R3,F

                nop                             ; R0-3 should be h'77777778'

                movf    B0,W                    ; R = A + B
                subwf   A0,W
                movwf   R0
                movf    A1,W
                movwf   R1
                movf    B1,W
                btfss   STATUS,C
                incfsz  B1,W
                subwf   R1,F
                movf    A2,W
                movwf   R2
                movf    B2,W
                btfss   STATUS,C
                incfsz  B2,W
                subwf   R2,F
                movf    A3,W
                movwf   R3
                movf    B3,W
                btfss   STATUS,C
                incfsz  B3,W
                subwf   R3,F

                nop                             ; R0-3 should still be h'88888888'

;-------------------------------------------------------------------------------

                goto    $                       ; All done.

;-------------------------------------------------------------------------------

; The same test data is used all operations but the 16- and 24- bit routines
; only use the least significant part of the values.

SetR:
                movlw   h'10'                   ; R = h'76543210'
                movwf   R0
                movlw   h'32'
                movwf   R1
                movlw   h'54'
                movwf   R2
                movlw   h'76'
                movwf   R3
                retlw   .0

SetA:
                movlw   h'98'                   ; A = h'fedcba98'
                movwf   A0
                movlw   h'ba'
                movwf   A1
                movlw   h'dc'
                movwf   A2
                movlw   h'fe'
                movwf   A3
                retlw   .0

SetB:
                movlw   h'10'                   ; B = h'76543210'
                movwf   B0
                movlw   h'32'
                movwf   B1
                movlw   h'54'
                movwf   B2
                movlw   h'76'
                movwf   B3
                retlw   .0

                end