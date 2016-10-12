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


BUFZ	equ	240
ITER	equ	BUFZ/4
WAIT	equ	BUFZ-ITER-1
NORM	equ	(256-BUFZ)/2

buf	equ	$2000	

	org	$e00

frame	.dw	0		; entry frame pointer to exiting to BASIC
lsnh	.db	0		; lsn no
lsnm	.db	0
lsnl	.db	0
	
start
	orcc	#$50		; shut off interrupts (just in case)
	sta	$ffd8		; force low speed
	sts	frame		; save BASIC frame ptr
	lda	$ff01		; enable pia's irq handling for hsync
	ora	#$01		;
	sta	$ff01		;
	lda	$ff03		; disable pi's irq handling for vsync
	anda	#~$01		;
	sta	$ff03
	lda	$ff23		; enable sound
	ora	#$8
	sta	$ff23
	ldy     #PREG2          ; set Y to point at Data Register A
        ldb     #$43            ; write $43 to the controller..s/b 0x0B for Dragon (sixxie)
	stb     CTRLATCH        ; ..latch to select Enhanced Mode
	ldu	#buf
	;; read issue sector read
b@	ldb	lsnh
	ldx	lsnm
	;; start of read sector
        stb     -1,y            ; store LSN in the three..
        stx     ,y              ; ..Block Address registers
        lda     #$80            ; setup Read Sector command for target device
        sta     -2,y            ; send to command register (FF48)
	;; wait for 17 sync (hopefull enough time to finish seek)
	ldb	#WAIT
c@	sync
	lda	,u+
	ora	#$02
	sta	$ff20
	tst	$ff00
	decb
	bne	c@
	;; Wait for Controller Ready or Failed. ;
rdWait  lda     -2,y            ; read controller status
        bita    #2              ; test the READY bit and..
        beq     rdWait          ; ..branch if ready
	ldx     #NORM           ; move buffer ptr from U to X
rdChnk	ldd	,y
	ora	#$02		; rs232 data out in mark
	sync
	sta	$ff20	
	tst	$ff00
	orb	#$02
	sync
	stb	$ff20
	tst	$ff00
	leax	-1,x
        bne     rdChnk          ; loop if more chunks to read
	;; get 32 bytes fast
	lda	#ITER
	pshs	a
	ldx	#buf		; X will be our writer
	tfr	x,u		; U will be our reader
e@	ldd	,y
	std	,x++
	ldd	,y
	std	,x++
	;; wait for next sync
	sync
	lda	,u+
	ora	#$02
	sta	$ff20
	tst	$ff00
	dec	,s
	bne	e@
	leas	1,s
	;; increment lsn to get ready for next sector read
	inc	lsnl
	bne	d@
	inc	lsnm
	bne	d@
	inc	lsnh
	;; wait for next sync
d@	sync
	lda	,u+
	ora	#$02
	sta	$ff20
	tst	$ff00
	jmp	b@		; loop


	end	start