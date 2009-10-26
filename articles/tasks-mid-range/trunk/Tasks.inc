;===============================================================================
; Task Switching Macros
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

                ifndef  TASK_NO_EXTERNS

                extern  TaskStart
                extern  TaskFindSlot
                extern  TaskSchedule

                extern  TASK_PTR

                endif

;===============================================================================
; Constants
;-------------------------------------------------------------------------------

TASK_TCB_SIZE   equ     .3

TASK_PRIORITY   equ     h'0f'
TASK_FLAGS      equ     h'f0'

; Bits for task states

TASK_STOPPED    equ     .4
TASK_PENDING    equ     .5
TASK_RUNNING    equ     .6
TASK_WAITING    equ     .7

;===============================================================================
; Macros
;-------------------------------------------------------------------------------


TASK_DATA       macro   MAX_TASKS

                global  TASK_TCBS
                global  TASK_TCBS_END

TASK_TCBS       res     TASK_TCB_SIZE * MAX_TASKS
TASK_TCBS_END:

                endm

;-------------------------------------------------------------------------------

TASK_START      macro   
                lcall   TaskStart
                endm

; The TASK_CREATE creates a new entry in the task table for a routine that
; is located at the indicated _TASK address. The task is assigned the given
; _PRIORITY.

TASK_CREATE     macro   _TASK,_PRIORITY
                lcall   TaskFindSlot
                movlw   (1<<TASK_RUNNING)|(_PRIORITY & h'0f')
                movwf   INDF
                incf    FSR,F
                movlw   high _TASK
                movwf   INDF
                incf    FSR,F
                movlw   low _TASK
                movwf   INDF
                decf    FSR,F
                decf    FSR,W
                endm

; The TASK_YIELD macro causes the current task to be suspended at the next
; eligible task with the highest priority is resumed.

TASK_YIELD      macro
                local   ReEntry
        
                banksel TASK_PTR
                incf    TASK_PTR,W
                movwf   FSR
                bankisel TASK_TCBS
                movlw   high ReEntry
                movwf   INDF
                movlw   low ReEntry
                lgoto   TaskSchedule                
ReEntry:
                endm

; The TASK_STOP macro causes the task referenced by WREG to be placed in the stopped
; state, then control yields to the next task.

TASK_STOP       macro
                local   ReEntry

                movwf   FSR
                bankisel TASK_TCBS
                bcf     INDF,TASK_RUNNING
                bsf     INDF,TASK_STOPPED
                incf    FSR,F
                movlw   high ReEntry            ; Save the PCH of the reentry point       
                movwf   INDF
                movlw   low ReEntry             ; And pass the PCL to the scheduler
                lgoto   TaskSchedule
ReEntry:
                endm

; The TASK_STOP macro causes the current task to be placed in the stopped
; state, then control yields to the next task.

TASK_STOPSELF   macro
                banksel TASK_PTR
                movf    TASK_PTR,W              ; Point FSR into current task area
                
                TASK_STOP
                endm