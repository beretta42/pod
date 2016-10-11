;;;
;;;  Podcast Player for CoCo
;;;



	org	$e00

frame	.dw	0		; entry frame pointer to exiting to BASIC
irqs	.dw	0		; saved BASIC firq
sndptr	.dw	$2000	

start
	orcc	#$50		; shut off interrupts (just in case)
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
	ldx	#$2000
	clra
b@	sta	,x+
	adda	#$1
	cmpx	#$4000
	bne	b@
	andcc	#~$50		; turn on interrupts
a@	bra	a@		; loop


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

	end	start