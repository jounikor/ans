;-----------------------------------------------------------------------------
; 
; v0.2 (c) 2026 Jouni 'Mr.Spiv' Korhonen
; Byte-wise input version.
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

; with 8 bits the L_BIT_LOW becomes 0x0100, which allows byte-wise input
; from the compressed data stream during state renormalization.
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
		ld		hl,encoded_end-1
		exx
		ld		bc,NUM_SYMBOLS
		exx

;-----------------------------------------------------------------------------
; Init rABS decoder

		ld		d,(hl)
		dec		hl
		ld		e,(hl)
		dec		hl
		ld		a,INIT_PROP_FOR_0_
		ld		(state_x),de
		ld		de,decoded_end-1
		;
		; Registers:
		;  DE   = ptr to destination
		;  HL   = ptr to compressed data
		;  BC'  = counter how many symbols to decode
		;   A   = propability of 0
		;  (SP) = state
		;
_decoding_loop:
		push	de
		ld		de,(state_x)
		call	decode_symbol
		ld		(state_x),de
		call	update_propability
		pop		de
		push	af
		ld		a,b
		ld		(de),a
		dec		de
		pop		af
		exx
		dec		c
		exx
		jr nz,	_decoding_loop
		ret

state_x:
		dw		0


;-----------------------------------------------------------------------------
; Input:
;  DE = state
;  HL = ptr to compressed file
;   A = frequency/propability of symbol 0
;
; Return:
;   C_flag = 0 or 1 for the symbol
;    A = frequency/propability of 0 symbol
;    B = 0
;   DE = new_state
;   HL = possibly updated ptr to compressed file
;
; Trashes:
;   B,C
decode_symbol:
		cp		e						; 1
		jr nz,	_not_zero				; 2
		; handle special case E == A
		scf								; 1
_not_zero:
		push	af						; 1
		push	hl						; 1
		ld		b,0						; 2
		jr nc,	_symbol_0				; 2

_symbol_1:
		; A = Fs = M - prop_of_0
		; C = Is = prop_of_0
		ld		c,a						; 1
		neg								; 2
		db		$fe						; 1
_symbol_0:
		; A = Fs = prop_of_0
		; C = Is = 0
		ld		c,b						; 1
_new_state:
		; new_state = d * Fs - Is + r
		;           = d * Fs + (r - Is)
		ex		de,hl					; 1
		ld		e,a						; 1
		ld		d,b						; 1
		ld		a,l						; 1
		ld		l,b						; 1 -> 20
		;  H = (d = state // M)
		;  L = 0
		; DE = Fs
		; BC = Is
		;  A = r = state & (M - 1)
		ld		b,8						; 2
_umulDxL_HL:
		add		hl,hl					; 1
		jr nc,	$+3						; 2
		add		hl,de					; 1
		djnz	_umulDxL_HL				; 2
		; C_flag is always cleared
		sbc		hl,bc
		ld		c,a
		add		hl,bc					; 1
		ex		de,hl					; 1
		pop		hl						; 1

		; while (new_state < L_BIT_LOW)
		; L_BIT_LOW == 256
		ld		a,d						; 1
		and		a						; 1
		jr nz,	_end_while				; 2
		ld		d,e						; 1
		ld		e,(hl)					; 1
		dec		hl						; 1
_end_while:
		pop		af						; 1
		ret								; 1 -> 43

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
