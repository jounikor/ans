;-----------------------------------------------------------------------------
; 
; v0.1 (c) 2026 Jouni 'Mr.Spiv' Korhonen
; Byte input version.
;
; To assemble:
;  pasmo -d -1 --tapbas --alocal z80_rabs_decoder.asm tst.tap tst.map
;
;
;
        org     $8000

;-----------------------------------------------------------------------------
;
; Change the following constants accordingly based on your encoder.
;
M_					equ	256
M_BITS_				equ	8

; with 8 bits the L_BIT_LOW becomes 0x0100, which allows byte input for
; new state.
L_BITS_				equ	8
L_BIT_LOW_			equ	0x10000 >> L_BITS_

; Propability is INIT_PROP_FOR_0 / 256
INIT_PROP_FOR_0_	equ	128

; Update rate must be a power of two as it is implemented as bit shifts
UPDATE_RATE_		equ	5		; number of right shifts
UPDATE_RATE_MASK_	equ	0x7		; remining bits after the right shift

;
; The main driver is only for testing purposes.
;
;

NUM_SYMBOLS			equ	34
INIT_STATE			equ	$0303

main:
		ld		hl,decoded_end-1
		ld		de,encoded_end-1
		exx
		ld		bc,NUM_SYMBOLS
		exx

;-----------------------------------------------------------------------------
; Init rABS decoder

		push	hl
		ld		a,(de)
		ld		h,a
		dec		de
		ld		a,(de)
		ld		l,a
		dec		de
		ld		a,INIT_PROP_FOR_0_
		ex		(sp),hl
		;
		; Registers:
		;  HL   = ptr to destination
		;  DE   = ptr to compressed data
		;  BC'  = counter how many symbols to decode
		;   A   = propability of 0
		;  (SP) = state
		;
_decoding_loop:
		ex		(sp),hl
		call	decode_symbol
		call	update_propability
		ex		(sp),hl
		ld		(hl),b
		dec		hl
		exx
		dec		c
		exx
		jr nz,	_decoding_loop
		pop		hl
		ret


;-----------------------------------------------------------------------------
; Input:
;  HL = state
;  DE = ptr to compressed file
;   A = frequency/propability of 0
;
; Return:
;   C_flag = 0 or 1 for the symbol
;    A = frequency/propability of 0 symbol
;    B = 0
;   HL = new_state
;   DE = possibly updated ptr to compressed file
;
; Trashes:
;   B,C
decode_symbol:
		cp		l
		jr nz,	_not_zero
		; handle special case L == A
		scf
_not_zero:
		push	af
		push	de
		ld		d,0
		jr nc,	_symbol_0

_symbol_1:
		; Fs = M - prop_of_0
		; Is = prop_of_0
		ld		c,a
		neg
		db		$fe	
_symbol_0:
		; Fs = prop_of_0
		; Is = 0
		ld		c,d

_new_state:
		ld		e,a
		ld		a,l
		;
		; E = Fs
		; C = Is
		; H = d = state // M
		; A = r = state & (M - 1)
		;
		; Input:
		;  H = value 1
		;  E = value 2
		;
		; Return:
		;  HL = result
		;  E remains unchanged
		;  D = 0
		;
_umulHxE_HL:
		ld		b,8
		ld		l,d
_mul_loop:
		add		hl,hl
		jr nc,	$+3
		add		hl,de
		djnz	_mul_loop
		; C_flag is always cleared
		; new_state = HL = d * Fs - Is + r
		ld		e,c
		sbc		hl,de			; Always clears C_flag
		ld		e,a
		add		hl,de			; May set C_flag
		pop		de

		; while (new_state < L_BIT_LOW)
		; L_BIT_LOW == 256
		ld		a,h
		and		a
		jr nz,	_end_while
		ld		a,(de)
		dec		de
		ld		h,l
		ld		l,a
_end_while:
		pop		af
		ret


;-----------------------------------------------------------------------------
; Input:
;  C_flag = symbol (0 or 1)
;  A = symbol propability/frequency
;  B = 0
;
; Return:
;  A = Updated propability/frequency
;  B = symbol
;
; Trashes:
;  C
;
update_propability:
		ld		c,a
		jr nc,	_symbol_0
_symbol_1:
		inc		b
		; M - A == -A, since M = 0x100 i.e. 0x00
		neg

		IF		UPDATE_RATE_ > 4
		REPT	8-UPDATE_RATE_
		rlca
		ENDM
		ELSE
		REPT	UPDATE_RATE_
		rrca
		ENDM
		ENDIF
		
		and		UPDATE_RATE_MASK_
		jr nz,	_not_zero_0
		ld		a,1
_not_zero_0:
		sub		c
		neg
		ret nz
		ld		a,1
		ret
_symbol_0:
		IF		UPDATE_RATE_ > 4
		REPT	8-UPDATE_RATE_
		rlca
		ENDM
		ELSE
		REPT	UPDATE_RATE_
		rrca
		ENDM
		ENDIF
	
		and		UPDATE_RATE_MASK_
		jr nz,	_not_zero_1
		ld		a,1
_not_zero_1:
		add		a,c
		ret nc
		ld		a,M_-1
		ret


;-----------------------------------------------
;
; These are just for testing purposes..
;
; output..
; 0,0,0,0,0,0,0,0,  0,0,0,1,0,1,1,1, 1,0,0,1,1,1,1,1, 0,1,0,0,0,1,0,1,   1, 0, 1, 1, 0, 1, 1, 0

encoded_sta:
		db	143,126,251,128
		dw	INIT_STATE
encoded_end:

; Original input 34 symbols
; [0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0]

		db	$ff,$ff
		ds	NUM_SYMBOLS
decoded_end:
		db	$ff,$ff



		END	main
