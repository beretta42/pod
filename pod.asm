;;;
;;;  Podcast Player for CoCo
;;;



	org	$e00

frame	.dw	0		; entry frame pointer to exiting to BASIC
irqs	.dw	0		; saved BASIC firq
sndptr	.dw	$2000
DCSTAT	.db	0		; read return status
DCBPT	.dw	$2000		; drive buffer pointer
lsnh	.db	0		; lsn no
lsnm	.db	0
lsnl	.db	0

	
start
	orcc	#$50		; shut off interrupts (just in case)
	sta	$ffd9		; high speed <-- FIXME
	sts	frame		; save BASIC frame ptr
	ldx	$10d		; save BASIC's firq ptr
	stx	irqs		;
	ldx	#noplay		; install out do nothing handler
	stx	$10d		;
	lda	$ff01		; enable pia's irq handling for hsync
	ora	#$01		;
	sta	$ff01		;
	lda	$ff03		; disable pi's irq handling for vsync
	anda	#~$01		;
	sta	$ff03
	lda	$ff23		; enable sound
	ora	#$8
	sta	$ff23
	;; put sound in buffer
a@	ldd	#$2000
	std	DCBPT
	lda	#$20
	pshs	a
b@	ldb	lsnh
	ldx	lsnm
	jsr	setup
	jsr	execmd
	inc	DCBPT
	inc	lsnl
	bne	c@
	inc	lsnm
	bne	c@
	inc	lsnh
c@	dec	,s
	bne	b@
	leas	1,s
	andcc	#~$50		; turn on interrupts
d@	lda	sndptr
	cmpa	#$38		; at half way mark?
	blo	d@
	bra	a@		; loop


;;; This firq handler does nothing
noplay
	tst	$ff00		; clear pia
	ldx	sndptr		; get next DAC byte and 
	lda	,x+		; 
	sta	$ff20		; send it to pia
	cmpx	#$4000		; wrap buffer?
	bne	out@		; nope
	;; wrap buffer
	ldx	#$2000
out@	stx	sndptr
	rti			; return



CTRLATCH    equ    $FF40          ; controller latch (write)
CMDREG      equ    $FF48          ; command register (write)
STATREG     equ    $FF48          ; status register (read)
PREG1       equ    $FF49          ; param register 1
PREG2       equ    $FF4A          ; param register 2
PREG3       equ    $FF4B          ; param register 3
DATREGA     equ    PREG2          ; first data register
DATREGB     equ    PREG3          ; second data register

	
* SETUP - Setup the Command Packet
* Setup VCMD with command, LSN and option byte
* Entry: B = Bits 23-16 of LSN
*        X = Bits 15-0  of LSN  
setup
	clr	DCSTAT		; clear error
        ldy     #PREG2          ; set Y to point at Data Register A
        stb     -1,y            ; store LSN in the three..
        stx     ,y              ; ..Block Address registers
        ldb     #$43            ; write $43 to the controller..s/b 0x0B for Dragon (sixxie)
        stb     CTRLATCH        ; ..latch to select Enhanced Mode
        ;; a wait should happen here, but the vectored routines and normal
        ;; subroutining should give enough time already for the SDC to
        ;; accept the control code.
        rts

* Entry: A = DW opcode
execmd
        ldy     #PREG2          ; set Y to point at data reg a
        lda     #$80            ; setup Read Sector command for target device
        sta     -2,y            ; send to command register (FF48)
        exg     a,a             ; some time to digest the command
        *** Wait for Controller Ready or Failed.
        ldx     #0              ; long timeout counter = 65536
rdWait  lda     -2,y            ; read controller status
*       bmi     rdFail          ; branch if FAILED bit is set
        bita    #0x9c           ; any set bit is failure (autodetect)
        bne     rdFail          ; yes then fail
        bita    #2              ; test the READY bit and..
        bne     rdRdy           ; ..branch if ready
        leax    -1,x            ; decrement timeout counter
        bne     rdWait          ; continue polling until timeout
rdFail  clr     CTRLATCH        ; return controller to emulation mode
        ldb     #$80
        stb     DCSTAT         ; set carry for failure
        rts                     ; restore registers and return
        *** Controller Ready. Read the Sector Data. Uses partial loop unrolling.
rdRdy   ldx     DCBPT           ; move buffer ptr from U to X
        ldd     #32*256+8       ; A = chunk count (32), B = bytes per chunk (8)
rdChnk  ldu     ,y              ; read 1st pair of bytes for the chunk
        stu     ,x              ; store to buffer
        ldu     ,y              ; bytes 3 and 4 of..
        stu     2,x             ; ..the chunk
        ldu     ,y              ; bytes 5 and 6 of..
        stu     4,x             ; ..the chunk
        ldu     ,y              ; bytes 7 and 8 of..
        stu     6,x             ; ..the chunk
        abx                     ; increment X by chunk size (8)
        deca                    ; decrement loop counter
        bne     rdChnk          ; loop if more chunks to read
        *** Return Success.
        clr     CTRLATCH        ; clear carry / return controller to emulation mode
        rts                     ; restore registers and return



	end	start