;;;
;;;  Podcast Player for CoCo
;;;

CTRLATCH    equ    $FF40          ; controller latch (write)
CMDREG      equ    $FF48          ; command register (write)
STATREG     equ    $FF48          ; status register (read)
PREG1       equ    $FF49          ; param register 1
PREG2       equ    $FF4A          ; param register 2
PREG3       equ    $FF4B          ; param register 3
DATREGA     equ    PREG2          ; first data register
DATREGB     equ    PREG3          ; second data register


BUFZ	equ	256		; buffer size in bytes
ITER	equ	BUFZ/4		; read 4 bytes at a time from sdc
WAIT	equ	BUFZ-ITER-1	; suck up the balance of samples remaining
				; by waiting for the sdc to "seek" next sector

buf	equ	$2000

	org	$e00

	;; storage for our current lsn
	;; we can cue by simply modding this.
lsnh	.db	0		; lsn high byte
lsnm	.db	0		; lsn middle byte
lsnl	.db	0		; lsn low byte

start
	orcc	#$50		; shut off interrupts (just in case)
	;; wipe buffer, well use this a little bit at our first
	;; sector seek wait so clean it up.
	clra
	ldx	#buf
f@	clr	,x+
	deca
	bne	f@
	;; setup pias
	sta	$ffd8		; force low speed
	lda	$ff01		; enable pia's irq handling for hsync
	ora	#$01		;
	sta	$ff01		;
	lda	$ff03		; disable pi's irq handling for vsync
	anda	#~$01		;
	sta	$ff03
	lda	$ff23		; enable sound
	ora	#$8
	sta	$ff23
	;; setup sdc
	ldy     #PREG2          ; set Y to point at Data Register A
        ldb     #$43            ; write $43 to the controller..s/b 0x0B for Dragon (sixxie)
	stb     CTRLATCH        ; ..latch to select Enhanced Mode
	ldu	#buf
;;;
;;; Our grand loop.
;;; 
	;; read issue sector read command
b@	ldb	lsnh		; send LSN to sdc
	ldx	lsnm		;
        stb     -1,y            ;
        stx     ,y              ;
        lda     #$80            ; setup Read Sector command for target device
        sta     -2,y            ; send to command register (FF48)
	;; wait for balance of bytes in buffer ( 128 samples )
	ldb	#WAIT		; set counter
c@	sync			; wait for hsync
	lda	,u+		; get a byte from buffer
	ora	#$02		; set serial in mark state
	sta	$ff20		; send to DAC
	tst	$ff00		; clear interrupt
	decb			; bump counter
	bne	c@		; repeat if not done
	;; Wait for Controller Ready or Failed. ;
rdWait  lda     -2,y            ; read controller status
        bita    #2              ; test the READY bit and..
        beq     rdWait          ; repeat if not ready (jitter time!)
	;; read bytes into buffer
	;; and interleave with syncs and writes to DAC
	lda	#ITER		; set counter
	pshs	a		;
	ldx	#buf		; X will be our writer
	tfr	x,u		; U will be our reader
e@	ldd	,y		; get four bytes at time
	std	,x++		;
	ldd	,y		;
	std	,x++		;
	;; wait for next sync
	sync			; wait for sync
	lda	,u+		; get next sample from buffer
	ora	#$02		; set serial marking
	sta	$ff20		; send to DAC
	tst	$ff00		; reset interrupt
	dec	,s		; bump counter
	bne	e@		; repeat if not done
	leas	1,s		; remove counter
	;; increment lsn to get ready for next sector read
	inc	lsnl		; inc low byte
	bne	d@		; continue if not wrapped
	inc	lsnm		; inc middle byte
	bne	d@		; continue if not wrapped
	inc	lsnh		; inc high byte
	;; wait for next sync
d@	sync			; yada,yada,yada
	lda	,u+
	ora	#$02
	sta	$ff20
	tst	$ff00
	jmp	b@		; start of grand loop


	end	start