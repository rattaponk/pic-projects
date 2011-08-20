;===============================================================================
; Simple Enhanced Mid-Range Task Switching
;-------------------------------------------------------------------------------
; Copyright (C)2011 PIC-Projects.net
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
; 2011-08-20 Initial version
;-------------------------------------------------------------------------------
; $Id$
;-------------------------------------------------------------------------------

                errorlevel -302
                errorlevel -312

                include P12F1822.inc

;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

                udata_shr

; The _STKPTR register holds the value of the device's STKPTR register for the
; task that is not executing. 

_STKPTR         res     .1

;===============================================================================
; Power on Reset and Initialisation
;-------------------------------------------------------------------------------

.ResetVector    code    h'000'

                lgoto   PowerOnReset            ; Jump to initialisation code

;-------------------------------------------------------------------------------

                code

PowerOnReset:
                call    TaskSetup               ; Initialise and start task 1
                bra     TaskTwo                 ; On return start task 2

;===============================================================================
; Task Switching Code
;-------------------------------------------------------------------------------

; Adjust the CPU's 16 level stack so that it is divided into two areas of 8
; levels each. The CPU STKPTR register points to the active area while the
; _STKPTR register holds pointer for inactive task. Once the stack is split
; jump to start of the first task.

TaskSetup:
                banksel STKPTR
                movf    STKPTR,W                ; Save current stack pointer
                movwf   _STKPTR                 ; .. for other task
                addlw   .7                      ; Then adjust the pointer
                movwf   STKPTR                  ; .. for this task

                bra     TaskOne                 ; And start it

; Swap the value of the CPU STKPTR register with value of the other tasks
; stack pointer. When this routine returns the new task will continue 
; executing from the point it performed its last switch. 

TaskSwitch:
                banksel STKPTR
                movf    _STKPTR,W               ; Swap the stack pointers
                xorwf   STKPTR,F
                xorwf   STKPTR,W
                xorwf   STKPTR,F
                movwf   _STKPTR
                return                          ; The continue the new task

;===============================================================================
; Tasks
;-------------------------------------------------------------------------------

TaskOne:
                nop                             ; .. Waste some cycles
                nop
                call    TaskSwitch              ; Then switch to other task
                bra     TaskOne                 ; And repeat task one

TaskTwo:
                nop                             ; .. Waste some cycles
                nop
                call    TaskSwitch              ; Then switch to other task
                bra     TaskTwo                 ; And repeat task two

                end