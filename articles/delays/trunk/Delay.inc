;===============================================================================
; Delay Definitions
;-------------------------------------------------------------------------------
; Copyright (C)2010 PIC-Projects.net
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
; 2010-03-30 Initial version
;-------------------------------------------------------------------------------
; $Id$
;-------------------------------------------------------------------------------

                extern  Delay4
                extern  Delay8
                extern  Delay16
                extern  Delay32
                extern  Delay64

;===============================================================================
; Macros
;-------------------------------------------------------------------------------

; The DELAY macro generates a series of CALL, BRA and NOP instructions that will
; take USEC to execute (based on the configured oscillator).

DELAY           macro   USEC
                nolist
                local   cycles
cycles          =       (USEC * (FOSC / .1000000) / .4)

                while   cycles >= .64
                list
                call    Delay64
                nolist
cycles          -=      .64
                endw

                if      cycles >= .32
                list
                call    Delay32
                nolist
cycles          -=      .32
                endif

                if      cycles >= .16
                list
                call    Delay16
                nolist
cycles          -=      .16
                endif

                if      cycles >= .8
                list
                call    Delay8
                nolist
cycles          -=      .8
                endif

                if      cycles >= .4
                list
                call    Delay4
                nolist
cycles          -=      .4
                endif

                if      cycles >= .2
                list
                bra     $+.2
                nolist
cycles          -=      .2
                endif

                if      cycles >= .1
                list
                nop
                nolist
cycles          -=      .1
                endif

                list
                endm
