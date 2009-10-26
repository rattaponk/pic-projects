;===============================================================================
; Example Task Switching Application
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
; 2009-06-21 Initial version
;-------------------------------------------------------------------------------
; $Id$
;-------------------------------------------------------------------------------

                errorlevel -302
                errorlevel -312

                ifdef   __16F628A
                include P16F628A.inc

__ARCH14        equ     .1
                endif

                include Tasks.inc

;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

                udata

; Use the TASK_DATA

                TASK_DATA .3            ; Reserve space for 3 tasks

TEMP            res     .1              ; Reset

;===============================================================================
; Power On Reset
;-------------------------------------------------------------------------------

.ResetVector    code    h'000'

                lgoto   PowerOnReset            ; Redirect to main routine

;-------------------------------------------------------------------------------

                code

PowerOnReset:
                TASK_START                      ; Initialise the task code
                TASK_CREATE TaskB,.7            ; Create a second task
                TASK_CREATE TaskC,.7            ; .. and a third

TaskA:
                TASK_YIELD
                goto    TaskA

TaskB:
                TASK_YIELD
                goto    TaskB

TaskC:
                TASK_YIELD
                goto    TaskC

		end