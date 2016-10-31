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
WAIT	equ	BUFZ-ITER-4	; suck up the balance of samples remaining
				; by waiting for the sdc to "seek" next sector

buf	equ	$2000		; buffer for lba reading data
gfx	equ	$2200		; graphics screen
therm	equ	gfx+(32*(192-3)) ; thermometer location
dir	equ	$4000		; directory
	
	org	$e00

	;; storage for our current lsn
	;; we can cue by simply modding this.
lsnh	.db	0		; lsn high byte
lsnm	.db	0		; lsn middle byte
lsnl	.db	0		; lsn low byte
mlsnh	.db	0		; max lsn high byte
mlsnm	.db	0		; max lsn middle byte
mlsnl	.db	0		; max lsn low byte
tenh	.db	0		; 10 sec high
tenm	.db	$2		; 10 sec middle
tenl	.db	$58		; 10 sec low
minh	.db	0		; 1 min high
minm	.db	$e		; 1 min middle
minl	.db	$6b		; 1 min low
tbyte	.dw	0		; screen location of our thermometer
tbit	.db	0		; bits in our thermometer
tick	.dw	1		; ticked every sector for thermoter redraw
	
start
	orcc	#$50		; shut off interrupts (just in case)
	sta	$ffd8		; force low speed
	lda	$ff23		; enable sound
	ora	#$8
	sta	$ff23
	;; setup sdc
        ldb     #$43            ; write $43 to the controller..s/b 0x0B for Dragon (sixxie)
	stb     CTRLATCH        ; ..latch to select Enhanced Mode
	ldu	#buf
	jmp	newmenu		; goto menu
;;;
;;; Our grand loop.
;;;
play	orcc	#$50
	jsr	display		; put title's image
	jsr	redrawt		; draw thermometer
	;; setup pias
	lda	$ff01		; enable pia's irq handling for hsync
	ora	#$01		;
	sta	$ff01		;
	lda	$ff03		; disable pi's irq handling for vsync
	anda	#~$01		;
	sta	$ff03		;
	;; wipe buffer, well use this a little bit at our first
	;; sector seek wait so clean it up.
	jsr	rsetb	 	; reset sample buffer
	ldy     #PREG2          ; set Y to point at Data Register A
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
	;; test for a key
play3	clr	$ff02
	lda	$ff00		; get key rows
	coma			; flip
	asla
	bne	key		; key pushed
	;; wait for next sync
play2	sync			; yada,yada,yada
	lda	,u+
	ora	#$02
	sta	$ff20
	tst	$ff00
	;; check lsn for max
	ldd	lsnh
	cmpd	mlsnh
	bne	g@
	lda	lsnl
	cmpa	mlsnl
	bhi	out@
	;; wait for next sync
g@	sync			; yada,yada,yada
	lda	,u+
	ora	#$02
	sta	$ff20
	tst	$ff00
	;; update thermometer?
	ldd	tick
	subd	#1
	beq	ut@
	std	tick
	;; wait for next sync
	sync			; yada,yada,yada
	lda	,u+
	ora	#$02
	sta	$ff20
	tst	$ff00
	;; 
	jmp	b@		; jump to start
	;; yup update therm
ut@	ldd	mlsnh
	std	tick
	jsr	redrawt
	;; jump to start of loop
	jmp	b@
	;; leave this silly mode
out@	jsr	gotmode
	jmp	menu


	
key	jsr	$a1c1
	cmpa	#$20
	lbeq	pause
	jsr	repeat
	clr	$ff02		; strobe all keys again
	cmpa	#3
	beq	exit@
	cmpa	#9
	beq	right@
	cmpa	#8
	beq	left@
	cmpa	#94
	beq	up@
	cmpa	#10
	beq	down@
	jmp	play2
exit@	jsr	gotmode		; switch to text screen
	jsr	norepeat	; prevent key repeat
	jmp	menu		; go do menu
right@	ldx	#lsnh
	ldu	#tenh
	ldd	1,x
	addd	1,u
	std	1,x
	ldb	,x
	adcb	,u
	stb	,x
	bra	tmax
left@	ldx	#lsnh
	ldu	#tenh
	ldd	1,x
	subd	1,u
	std	1,x
	ldb	,x
	sbcb	,u
	stb	,x
	bra	tmin
up@	ldx	#lsnh
	ldu	#minh
	ldd	1,x
	addd	1,u
	std	1,x
	ldb	,x
	adcb	,u
	stb	,x
	bra	tmax
down@	ldx	#lsnh
	ldu	#minh
	ldd	1,x
	subd	1,u
	std	1,x
	ldb	,x
	sbcb	,u
	stb	,x
	bra	tmin
	
;;; test for minimum lsn
tmin	tst	,x
	bmi	reset@
	bne	out@
	tst	1,x
	bne	out@
	ldb	2,x
	cmpb	#$19
	bhs	out@
reset@	clr	,x
	clr	1,x
	ldb	#$19
	stb	2,x
out@	jsr	redrawt
	jsr	rsetb
	jmp	play3

;;; test for maximum lsn
tmax	ldu	#mlsnh
	lda	,x
	cmpa	,u
	blo	out@
	lda	1,x
	cmpa	1,u
	blo	out@
	lda	2,x
	cmpa	2,u
	blo	out@
	ldd	,u
	std	,x
	ldb	2,u
	stb	2,x
out@	jsr	redrawt
	jsr	rsetb
	jmp	play3

;;; Reset smaple buffer
rsetb
	ldx	#buf
	tfr	x,u
	ldd	#$0080
a@	stb	,x+
	deca
	bne	a@
	tfr	u,x
	rts
	
;;; pause
pause	
a@	jsr	$a1c1
	cmpa	#$20
	bne	a@
	clr	$ff02		; check for anykey
b@	lda	$ff00		; get keys
	coma
	asla
	bne	b@		; loop until no keys down.
	jmp	play2
	
norepeat
	ldx	#$152		; set rollover to clear keys holddown
	clra			;
	clrb			;
	std	,x++		;
	std	,x++		;
	std	,x++		;
	sta	,x++		;
	rts

repeat	pshs	d,x
	ldx	#$152
	ldd	#$ff08
a@	sta	,x+
	decb	b
	bne	a@
	puls	d,x,pc

	
curs	.dw	$4000		; directory cursor
page	.dw	$4000		; page no.
	
;;; do a menu
newmenu
	ldd	#dir
	std	curs
	std	page
	jsr	getdir
	jsr	sort
menu
	;; setup pias
	lda	$ff01		; enable pia's irq handling for hsync
	anda	#~$01		;
	sta	$ff01		;
	lda	$ff03		; disable pi's irq handling for vsync
	ora	#$01		;
	sta	$ff03		;
	andcc	#~$10		; turn on interrupts
a@	jsr	draw
b@	jsr	$a1c1		; get key
	beq	b@
	cmpa	#10
	beq	down@
	cmpa	#$20
	beq	select@
	cmpa	#$03
	beq	escape@
	cmpa	#94
	beq	up@
	jsr	scan
	bra	a@
down@	ldd	curs
	tfr	d,x
	tst	16,x		; last?
	beq	a@		; yup, do nothing
	addd	#16
	std	curs
	subd	page
	cmpd	#$100
	blo	a@
	ldd	page
	addd	#16
	std	page
	bra	a@
up@	ldd	curs
	cmpd	#$4000		; first?
	beq	a@		; yup, do nothing
	subd	#16
	std	curs
	subd	page
	bpl	a@
	ldd	page
	subd	#16
	std	page
	bra	a@
select@	ldx	curs		; get cursor
	ldb	11,x		; get attribute
	bitb	#$10		; is directory?
	bne	chdir
	jmp	mount
escape@	jmp	[$fffe]


;;; change directory
chdir
	ldu	#buf
	ldd	#'D*256+':
	std	,u++
	jsr	namecpy
	ldb	#0
	ldu	#buf
	jsr	send
	bcs	b@
	jmp	newmenu
b@	jmp	menu


;;; mount a file
mount	pshs	x
	ldu	#buf
	ldd	#'M*256+':
	std	,u++
	jsr	namecpy
	ldb	#0
	ldu	#buf
	jsr	send
	bcs	c@
	tstb
	bne	c@
	;; clear lsn
	clr	lsnh
	clr	lsnm
	ldb	#$19
	stb	lsnl
	puls	x
	;; set max lsn
	ldd	12,x
	std	mlsnh
	lda	14,x
	sta	mlsnl
	;; test max for zero (file too short)
	ldd	12,x		; high bytes
	bne	d@
	lda	14,x
	beq	e@
d@	jmp	play
c@	leas	2,s
e@	jmp	menu


;;; copy name to buffer
;;; takes: X = src, U = dest
;;; modifies U,D
namecpy	pshs	x
	ldb	#8
	jsr	strscpy
	leax	8,x
	lda	,x
	beq	out@
	cmpa	#$20
	beq	out@
	ldb	#'.
	stb	,u+
	ldb	#3
	jsr	strscpy
out@	clr	,u+
	puls	x,pc
	
	
draw
	;; clear screen
	ldx	#$400
	ldd	#$2020
a@	std	,x+
	cmpx	#$600
	bne	a@
	;; display directory
	ldu	#$400
	ldx	page
b@	cmpx	curs		; are we at cursor
	bne	d@		; nope
	ldd	#$2d3e		; put a "->"
	std	,u		;
	ldd	#$3c2d		; put a "<-"
	std	17,u
d@	tst	,x		; end of dir?
	beq	out@		; yes then continue
	ldb	11,x		; get attribute
	bitb	#$10		; directory?
	beq	c@
	ldb	#'/		; put a "/"
	stb	2,u
c@	pshs	u,x
	leau	3,u
	ldb	#8
	jsr	strncpy
	leax	8,x
	leau	10,u
	ldb	#3
	jsr	strncpy
	puls	u,x
	leax	16,x
	leau	32,u
	cmpu	#$600		; end of screen?
	bne	b@
out@	rts

	;; 
	;; get a directory of the SDC
	;; 
getdir	ldy	#PREG2		; Y to point to data regsiter
	ldx	#dirstr		; copy string to data buffer
	ldu	#buf		;
	jsr	strcpy		;
	jsr	send		;
	ldu	#dir		; screen
a@	ldb	#$3e		; get directory data command
	jsr	recv		; 
	bcs	done@		; done on error
	cmpu	#$7e00		; out of mem?
	bne	a@		; nope get next directory
done@	rts
dirstr	fcn	"L:*.*"

	

;;; send data to sdc
;;;  takes: B - command to send, U - data buffer ptr
;;;  returns: C on fail
;;;  modifies: a bunch 
send	stb	PREG1
	ldb	#$e0
	stb	CMDREG		; send command to SDC
	exg	a,a		; wait some time
	exg	a,a		;
	;; wait for rdy
b@	ldb	STATREG		; get status
	bmi	fail@
	bitb	#2		; ready?
	beq	b@
	;; send command string	
	lda	#128		; buffer
a@	ldx	,u++		; grab a word
	stx	,y		; sendto SDC
	deca			; bump counter
	bne	a@		; done?
d@	ldb	STATREG		; wait till SDC isn't busy
	bitb	#1		;
	bne	d@		;
	clra			; clear carry
	rts			; return
fail@	coma			; set error
	rts			; return

	
;;; recv data to sdc
;;;  takes: B - command to send, U - data buffer ptr
;;;  returns: C on fail
;;;  modifies: a bunch 
recv	stb	PREG1
	ldb	#$c0
	stb	CMDREG		; send command to SDC
	exg	a,a		; wait some time
	exg	a,a		;
	;; wait for rdy
b@	ldb	STATREG		; get status
	bmi	fail@
	bitb	#2		; ready?
	beq	b@
	;; recv command string	
	lda	#128		; buffer
a@	ldx	,y		; grab a word
	stx	,u++		; sendto SDC
	deca			; bump counter
	bne	a@		; done?
d@	ldb	STATREG		; wait till SDC isn't busy
	bitb	#1		;
	bne	d@		;
	clra			; clear carry
	rts			; return
fail@	coma			; set error
	rts			; return


;;; recv data to sdc
;;;  takes: U - data buffer ptr
;;;  returns: C on fail
;;;  modifies: a bunch 
read	ldb	#$80
	stb	CMDREG		; send command to SDC
	exg	a,a		; wait some time
	exg	a,a		;
	;; wait for rdy
b@	ldb	STATREG		; get status
	bmi	fail@
	bitb	#2		; ready?
	beq	b@
	;; recv command string	
	lda	#128		; buffer
a@	ldx	,y		; grab a word
	stx	,u++		; sendto SDC
	deca			; bump counter
	bne	a@		; done?
d@	ldb	STATREG		; wait till SDC isn't busy
	bitb	#1		;
	bne	d@		;
	clra			; clear carry
	rts			; return
fail@	coma			; set error
	rts			; return
	
;;; Copy a string to sdc buff
;;; takes: X = string ptr, U = dest pointer
;;; modifies: nothing
strcpy
	pshs	a,x,u
a@	lda	,x+
	sta	,u+
	bne	a@
	puls	a,x,u,pc

;;; copy a string w/ len
;;; takes: B = len, X = string ptr, U = dest pointer
;;; modifies: nothing
strncpy
	pshs	d,x,u
	tstb
	beq	out@
a@	lda	,x+
	sta	,u+
	decb
	bne	a@
out@	puls	d,x,u,pc

;;; copy a 8:3 name string
;;;  takes: X = name ptr, U = dest ptr
;;;  modifies: U
strscpy
	pshs	d,x
	tstb
	beq	out@
a@	lda	,x+
	beq	out@
	cmpa	#$20
	beq	out@
	sta	,u+
	decb
	bne	a@
out@	puls	d,x,pc

;;; Compare two dir entries
;;; takes: X = ptr to string name
;;; returns: C set on 1 > 2
strncmp	pshs	d,x,u
	leau	16,x		; U = second name
	ldb	#8
a@	lda	,x+		; get byte from 1
	cmpa	,u+		; compare to byte from 2
	bhi	sw@		; switch
	blo	nosw@
	decb
	bne	a@		; try for next byte
nosw@	clra
	puls	d,x,u,pc
sw@	coma
	puls	d,x,u,pc

;;; exchange two dir entries
;;; takes: X = ptr to string name
;;; modifies: nothing
exchnam	pshs	d,x,u
	leau	16,x
	ldb	#16
a@	lda	,x
	sta	temp@
	lda	,u
	sta	,x+
	lda	temp@
	sta	,u+
	decb
	bne	a@	
	puls	d,x,u,pc
temp@	.db	0


;;; sort directory
sort	pshs	d,x
b@	lda	#$ff
	pshs	a
	ldx	#dir
a@	tst	,x
	beq	out@
	tst	16,x
	beq	out@
	jsr	strncmp		; compare
	bcs	sw@
inc@	leax	16,x
	bra	a@
sw@	jsr	exchnam
	clr	,s
	bra	inc@
out@	tst	,s+
	beq	b@
	puls	d,x,pc


;;; scan for dirent
;;;  takes: A = ascii to scan for
;;;  returns: X = first entry
scan
	pshs	d,x
	ldx	#dir
a@	tst	,x
	beq	nf@
	cmpa	,x
	beq	out@
	leax	16,x
	bra	a@
out@	stx	curs
b@	tfr	x,d
	subd	page
	cmpd	#$100
	blo	nf@
	addd	page
	std	page
nf@	puls	d,x,pc


;;; display header picture
display	ldy	#PREG2
	;; load first sector
	clr	PREG1
	clr	PREG2
	clr	PREG3
	ldu	#buf
	jsr	read
	;; check for pbm signature (yup... I'm lazy)
	ldd	buf
	cmpd	#'P*256+'4
	beq	c@
	jmp	menu
	;; count header bytes (3 nl's)
c@	ldx	#buf
	ldb	#3
a@	lda	,x+
	cmpa	#$0a
	bne	a@
	decb
	bne	a@
	tfr	x,d
	subd	#buf
	pshs	d
	ldd	#gfx
	subd	,s++
	tfr	d,u
	;; load picture
	ldd	#0
	pshs	d
	ldb	#25
	pshs	b
b@	clr	PREG1
	ldd	1,s
	std	,y
	jsr	read
	ldd	1,s
	addd	#1
	std	1,s
	dec	,s
	bne	b@
	leas	3,s
	jsr	gogmode
	;; return
	rts

;;; Goto pmode 4 graphics mode
gogmode
	;; set SAM for mode 6R
	clr	$ffc0		; 0
	clr	$ffc3		; 1
	clr	$ffc5		; 1
	;; display at $2200 ( $11 )
	clr	$ffc7		; 1
	clr	$ffc8		; 0
	clr	$ffca		; 0
	clr	$ffcc		; 0
	clr	$ffcf		; 1
	clr	$ffd0		; 0
	clr	$ffd2		; 0
	;; Set VDG mode 6R
	lda	$ff22
	ora	#$f0		; set G, CSS
	sta	$ff22
	rts

;;; Goto text mode
gotmode
	;; Set SAM for text mode
	clr	$ffc0		; 0
	clr	$ffc2		; 0
	clr	$ffc4		; 0
	;; display at $400 ($2 )
	clr	$ffc6		; 0
	clr	$ffc9		; 1
	clr	$ffca		; 0
	clr	$ffcc		; 0
	clr	$ffce		; 0
	clr	$ffd0		; 0
	clr	$ffd2		; 0
	;; Set VDG for text mode
	lda	$ff22
	anda	#~$f0
	sta	$ff22
	rts

;;; Calc thermometer from current lsn
	;; calc screen position
calct
	pshs	d,x
	ldb	lsnh		; put copy of lsn for accumulation
	ldx	lsnm		;
	pshs	b,x		;
	ldx	#0		; X is our quotient
a@	ldd	1,s		; get low word
	subd	mlsnh		; subtract divisor (high word of max lsn)
	std	1,s		; store in accum
	bcc	b@		; borrow?
	dec	,s		; yes then decrement high byte of accum
b@	tst	,s		; is accumulator negative?
	bmi	c@		; yup then quit
	leax	1,x		; nope then increment quotient
	bra	a@		; subtract again
c@	tfr	x,d		; B is our quotient
	pshs	b		; save a copy
	clra			; A is our bit map
	andb	#$7		; low three bytes is bits
	beq	e@		; if zero then done
d@	lsra			; rotate in 1's
	ora	#$80
	decb
	bne	d@
e@	sta	tbit
	clra
	puls	b		; get copy of quotient
	lsrb			; divide by 8 to get horizontal pos ( 0-31)
	lsrb			;
	lsrb			;
	addd	#therm		; FIXME: now top of screen s/b bottom?
	std	tbyte
	leas	3,s
	puls	d,x,pc
	
;;; redraw thermometer
redrawt	pshs	d,x
	jsr	calct		; calculate position
	;; clear therm
	ldx	#therm		; FIXME: now top of screen s/b bottom?
	ldb	#32
a@	clr	,x+
	decb
	bne	a@
	;; put 1's until tbyte is met
	clrb
	ldx	#therm		; FIXME: now top of screen s/b bottom?
	lda	#$ff
b@	cmpx	tbyte		; at screen location?
	beq	c@		; yes then quit this loop
	sta	,x+		; store one's
	bra	b@		; next byte
c@	lda	tbit		; draw the partial byte
	sta	,x+
f@	cmpx	#therm+32	; FIXME: top of screen, zeros to rest of line
	beq	e@
	clr	,x+
	bra	f@
	;; redraw line a few times
e@	ldx	#therm		; FIXME: now top of screen s/b bottom?
	ldb	#32
d@	lda	,x+
	sta	31,x
	sta	63,x
	decb
	bne	d@
	puls	d,x,pc
	
	end	start