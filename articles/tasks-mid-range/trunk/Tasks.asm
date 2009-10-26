;===============================================================================
; Mid-Range Task Switching
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

TASK_NO_EXTERNS equ     .1

                include Tasks.inc

                extern  TASK_TCBS
                extern  TASK_TCBS_END

                global  TASK_PTR

                global  TaskStart
                global  TaskFindSlot
                global  TaskSchedule

#define M(_X)   (.1 << (_X))

;===============================================================================
; Generic Mid-Range Device Constants
;-------------------------------------------------------------------------------

INDF            equ     h'000'
PCL             equ     h'002'
STATUS          equ     h'003'
FSR             equ     h'004'
PCLATH          equ     h'00a'

Z               equ     .2
C               equ     .0

;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

                udata

TASK_PTR        res     .1                      ; Active task pointer
TASK_NXT        res     .1                      ; Task to be switched to
TASK_TMP        res     .1

;===============================================================================
; Task Code
;-------------------------------------------------------------------------------

                code

TaskStart:
                movlw   TASK_TCBS_END           ; Set FSR past end of task area
                movwf   FSR
                bankisel TASK_TCBS
TaskInitLoop:
                movlw   -TASK_TCB_SIZE          ; Move back one control block
                addwf   FSR,F
                clrf    INDF                    ; .. and clear the state flags
                movlw   TASK_TCBS
                xorwf   FSR,W                   ; Repeat until first block reached
                btfss   STATUS,Z
                goto    TaskInitLoop
                movf    FSR,W                   ; Set the active task pointer 
                banksel TASK_TCBS
                movwf   TASK_PTR
                movlw   M(TASK_RUNNING)|h'07'   ; And mark as running priority 7
                movwf   INDF
                return

;-------------------------------------------------------------------------------

TaskFindSlot:
                movlw   TASK_TCBS               ; Point FSR at task area
                movwf   FSR
                bankisel TASK_TCBS
FindSlotLoop:
                movf    INDF,W                  ; Is the task slot free?
                andlw   TASK_FLAGS
                btfsc   STATUS,Z
                retlw   0                       ; Yes
                movlw   TASK_TCB_SIZE           ; No, try the next
                addwf   FSR,F
                movlw   TASK_TCBS_END           ; Reached the end yet?
                xorwf   FSR,W
                btfss   STATUS,Z           
                goto    FindSlotLoop            ; No, more slots left
                retlw   1      

;--------------------------------------------------------------------------------

TaskSchedule:
                incf    FSR,F                   ; SAVE PCL into current task area
                movwf   INDF
                
                movf    TASK_PTR,W
                movwf   FSR
                bsf     TASK_TMP,.7
TaskScanLoop:
                movlw   TASK_TCB_SIZE           ; Examine the next task block
                addwf   FSR,F
                movlw   TASK_TCBS_END           ; Reached the of the tasks?
                xorwf   FSR,W
                movlw   TASK_TCBS     
                btfsc   STATUS,Z
                movwf   FSR                     ; Yes, wrap back to start

                movf    INDF,W                  ; Is the task active?
                andlw   M(TASK_PENDING)|M(TASK_RUNNING)
                btfsc   STATUS,Z        
                goto    TaskScanNext            ; No.

                movf    TASK_TMP,W              ; Get the best so far
                subwf   INDF,W                  ; and compare
                btfsc   STATUS,C                ; Better than current
                goto    TaskScanNext            ; No.

                movf    INDF,W                  ; Yes, save the details
                movwf   TASK_TMP
                movf    FSR,W
                movwf   TASK_NXT

TaskScanNext:
                movf    FSR,W                   ; Reached the original entry?
                xorwf   TASK_PTR,W
                btfss   STATUS,Z
                goto    TaskScanLoop            ; No, not yet

                btfsc   TASK_TMP,.7             ; Found a task to run?
                goto    TaskScanLoop            ; No, look again  

                movf    TASK_NXT,W              ; Set up the pointer to the new task
                movwf   TASK_PTR        
               
                movwf   FSR                     ; Mark task as running
                bcf     INDF,TASK_PENDING
                bsf     INDF,TASK_RUNNING
                incf    FSR,F                   ; Then jump back to the re-entry point
                movf    INDF,W
                movwf   PCLATH
                incf    FSR,F
                movf    INDF,W
                movwf   PCL

                end