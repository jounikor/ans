;-----------------------------------------------------------------------------
; 
; v0.1 (c) 2026 Jouni 'Mr.Spiv' Korhonen
; THIS IS STILL WORK IN PROGRESS..
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

; with 1 bit the L_BIT_LOW becomes 0x8000, which allows sign optimizations.
; Also, we will only input one bit at time.
L_BITS_				equ	1
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

main:

		ret
;
; Input:
;  HL = state
;  DE = ptr to compressed file
;   A = frequency/propability of 0 symbol
;  A' = bit buffer
;
; Return:
;   C_flag = 0 or 1 for the symbol
;    A = frequency/propability of 0 symbol
;   A' = bitbuffer
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
		jr c,	_symbol_1

_symbol_0:
		; Fs = prop_of_0
		; Is = 0
		ld		c,0
		jr		_new_state

_symbol_1:
		; Fs = M - prop_of_0
		; Is = prop_of_0
		ld		c,a
		neg
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
		ld		d,0
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
		adc		hl,de			; May set C_flag
		pop		de

		; while (new_state < L_BIT_LOW)
		jp m,	_end_while		; 10
		ex		af,af'
_while_loop:
		add		a,a				; 4
		jr nz,	_not_empty		; 
		ld		a,(de)
		adc		a,a
		dec		de
_not_empty:
		adc		hl,hl			; 15
		jp p,	_while_loop		; 10
		ex		af,af'
_end_while:
		pop		af
		ret


;
; Input:
;  C_flag = symbol (0 or 1)
;  A = symbol propability/frequency
;
; Return:
;  A = Updated propability/frequency
;
; Trashes:
;  B
;
update_propability:
		ld		b,a
		jr c,	_symbol_1
_symbol_0:
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
		sub		b
		neg
		ret nz
		ld		a,1
		ret
_symbol_1:
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
		add		a,b
		ret nc
		ld		a,M_-1
		ret

		END	main
