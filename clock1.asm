.include "m8def.inc"
.def tmp=r16
.def tmp2=r17
.def tmp3=r18
.def tmp4=r19
.def ss=r20
.def mm=r21
.def hh=r22
.def rejim=r23
.def adcbut=r24
.def butzad=r25
.def rejimwait=r26
.def tochki=r27
.def tmp5=r28

.equ second=15625	;1 sec on 1Mhz and clock/64 delitel
.equ zaderjka1=0	;0.25s
.equ zaderjka2=155	;0.1s
.equ rejimzad=5		;5s zaderjka rejimov D,B1,B2,T1,T2,M
.equ timer0cr=0x05	;delitel 1024 (1ms)
.equ timer2cr=0x04	;delitel 8 (128khz) - min out 512hz
.equ eeprom=0		;adres zapisi chisla i mesyaca v eeprom
.equ numb1=0x00		;adres SRAM dlya zapisi cifer (4bytes)
.equ numb2=0x01		
.equ numb3=0x02		
.equ numb4=0x03		
.equ temp1=0x04		;adres SRAM temperatura vnutri
.equ temp2=0x05		;adres SRAM	temperatura na ulice
.equ chislo=0x06	;adres SRAM chislo
.equ mesyac=0x07	;adres SRAM chislo
.equ bud1hh=0x08	;adres SRAM budilnikov 1 i 2
.equ bud1mm=0x09
.equ bud2hh=0x0A
.equ bud2mm=0x0B
.equ bud1vkl=0x0C	;sostoyaniye budilnika
.equ bud2vkl=0x0D
.cseg
.org 0
	rjmp reset ;
	reti ; INT0
	reti ; INT1
	reti ; TIMER2COMP
	reti ;rjmp timer2ovf ; TIMER2OVF
	reti ; TIMER1CAPT
	rjmp timer1compa ; TIMER1COMPA
	reti ; TIMER1COMPB
	reti ; TIMER1OVF
	rjmp timer0ovf ; TIMER0OVF
	reti ; SPI, STC
	reti ; USART, RXC
	reti ; USART, UDRE
	reti ; USART, TXC
	rjmp adcint; ADC
	reti ; EE_RDY
	reti ; ANA_COMP
	reti ; TWI
	reti ; SPM_RDY

reset:
	ldi tmp, low(RAMEND)
	out SPL,tmp
	ldi tmp, high(RAMEND)
	out SPH, tmp
;PORTS
;PD0-PD7 - diode matrix catodes (minus)
	ser tmp
	out PORTD, tmp
	out DDRD, tmp
	clr tmp
	out PORTB, tmp
;PB0-PB3 - diode matrix anodes (plus) PB4-PB5 - bud1,bud2 diodes.
	ldi tmp, 0b00111111
	out DDRB, tmp
	clr tmp
	out PORTC, tmp
;PC0 - buttons, PC1,PC2 - termistors, PC5 - dynamic
	ldi tmp, 0b00100000
	out DDRC, tmp
;ADC
	ldi tmp, (1<<ADEN)|(1<<ADIE)|(1<<ADFR)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0) ; adc ~600hz preobrazovaniy
	out ADCSRA, tmp
	ldi tmp, 0b00100000 ; adc in from pc0, left adjust adc data register, ref from AREF
	out ADMUX, tmp
;TIMER 1
	ldi tmp, low(second)
	out OCR1AL, tmp
	ldi tmp, high(second)
	out OCR1AH, tmp
	clr tmp
	out TCNT1L,tmp
	out TCNT1H,tmp
	ldi tmp, 0b00000000	;
	out TCCR1A, tmp
	ldi tmp, 0b00000011 ; clock/64 delitel
	out TCCR1B, tmp
;TIMER 2
	clr tmp
	out TCCR2, tmp
;TIMER INTERRUPTS OCIE2=1 and OCIE1A=1 and TOIE0=1
	ldi tmp,0b10010001
	out TIMSK,tmp
;ENABLE INTERRUPTS
	sei
;TIME
	clr ss
	clr mm
	clr hh
;DATA from EEPROM
eeprom1:
	sbic eecr,eewe
	rjmp eeprom1
	cbi EEARH,0
	ldi tmp, eeprom
	out EEARL, tmp
	sbi EECR,EERE
	in tmp, EEDR
	cpi tmp, 31
	brlo eeprom11
	clr tmp
eeprom11:
	sts chislo,tmp
eeprom2:
	sbic eecr,eewe
	rjmp eeprom2
	cbi EEARH,0
	ldi tmp, eeprom+1
	out EEARL, tmp
	sbi EECR,EERE
	in tmp, EEDR
	cpi tmp, 12
	brlo eeprom21
	clr tmp
eeprom21:
	sts mesyac,tmp
	clr rejim
	clr rejimwait
	clr tochki
	clr butzad
	clr adcbut
main:
	rcall diodes
	rjmp main

diodes:
	ser tmp5
	in tmp2,PORTB
	ldi tmp3,0x01
	ldi ZL,low(numb1)
	ldi ZH,high(numb1)
diodes1:
	or tmp2,tmp3
	out PORTB,tmp2
	ld tmp,Z+
	ldi tmp4,0xFE
	ror tmp
	brcc diodes2
	out PORTD, tmp4
	rcall diodeswait
diodes2:
	sec
	rol tmp4
	brcc diodes3
	ror tmp
	brcc diodes21
	out PORTD, tmp4
	rcall diodeswait
	rjmp diodes2
diodes21:
	out PORTD, tmp5
	rcall diodeswait
	rjmp diodes2
diodes3:
	out PORTD, tmp4
	com tmp3
	and tmp2,tmp3
	out PORTB,tmp2
	com tmp3
	clc
	rol tmp3
	cpi tmp3,0x09
	brlo diodes1
	ret

diodeswait:
		push tmp
		ldi tmp,10
diodeswait1:
		dec tmp
		brne diodeswait1
		pop tmp
		ret

timer1compa:
	push ZH
	push ZL
	push tmp
	push tmp2
	push tmp3
	in tmp, SREG
	push tmp
	ldi tmp,10
	out TCNT1L,tmp
	clr tmp
	out TCNT1H,tmp
	com tochki
	cpi rejimwait,0
	breq timer1inc
	dec rejimwait
	brne timer1inc
	clr rejim
timer1inc:
	inc ss
	cpi ss,60
	brlo time1end
	clr ss
	inc mm
	cpi mm,60
	brlo time1end
	clr mm
	inc hh
	cpi hh,24
	brlo time1end
	clr hh
	lds tmp, chislo
	inc tmp
	lds tmp2,mesyac
	ldi ZL, low(dney*2)
	ldi ZH, high(dney*2)
	add ZL,tmp2
	lpm
	mov tmp3, r0
	cp tmp, tmp3
	brlo time1dateout
	clr tmp
	inc tmp2
	cpi tmp2, 12
	brlo time1dateout
	clr tmp2
time1dateout:
	sts chislo,tmp
	sts mesyac,tmp2
time1eeprom1:
	sbic eecr,eewe
	rjmp time1eeprom1
	cbi EEARH,0
	ldi tmp3, eeprom
	out EEARL, tmp3
	out EEDR, tmp
	sbi EECR,EEMWE
	sbi EECR,EEWE
time1eeprom2:
	sbic eecr,eewe
	rjmp time1eeprom2
	cbi EEARH,0
	ldi tmp3, eeprom+1
	out EEARL, tmp3
	out EEDR, tmp2
	sbi EECR,EEMWE
	sbi EECR,EEWE
time1end:
	rcall convert
	ldi tmp, 0b00100001 ; adc in from pc1, for temp1
	out ADMUX, tmp
	pop tmp
	out SREG,tmp
	pop tmp3
	pop tmp2
	pop tmp
	pop ZL
	pop ZH
	reti

convert:
	cpi rejim,1
	breq conv1
	cpi rejim,2
	breq conv2
	cpi rejim,3
	breq conv3
	cpi rejim,4
	breq conv4
	cpi rejim,5
	breq convtemp1
	cpi rejim,6
	breq convtemp2
;rejim=0 TIME
	mov tmp2,hh
	mov tmp3,mm
	rjmp convert1
;rejim=5 temp1
convtemp1:
	lds tmp3,temp1
	rjmp convert2
;rejim=6 temp2
convtemp2:
	lds tmp3,temp2
convert2:
	clr tmp2
	bst tmp3,7
	bld tmp2,6
	sts numb1,tmp2
	cbr tmp3,0x80
	clr tmp
conv9:
	cpi tmp3,10
	brlo conv10
	inc tmp
	subi tmp3, 10
	rjmp conv9
conv10:
	ldi ZL, low(cifri*2)
	add ZL,tmp
	lpm
	mov tmp, r0
	ldi ZL, low(cifri*2)
	add ZL,tmp3
	lpm
	mov tmp3, r0
	sts numb2,tmp
	sts numb3,tmp3
	ldi tmp,0b00111001
	sts numb4,tmp
	rjmp convend
;rejim=1 DATA
conv1:
	lds tmp2,chislo
	inc tmp2
	lds tmp3,mesyac
	inc tmp3
	rjmp convert1
;rejim=2 SECONDS
conv2:
	mov tmp2,mm
	mov tmp3,ss
	rjmp convert1
;rejim=3 BUDILNIK1
conv3:
	lds tmp2,bud1hh
	lds tmp3,bud1mm
	rjmp convert1
;rejim=4 BUDILNIK2
conv4:
	lds tmp2,bud2hh
	lds tmp3,bud2mm
convert1:
;1ya i 2ya cifri
	clr tmp
conv5:
	cpi tmp2,10
	brlo conv6
	inc tmp
	subi tmp2, 10
	rjmp conv5
conv6:
	ldi ZH, high(cifri*2)
	ldi ZL, low(cifri*2)
	add ZL,tmp
	lpm
	mov tmp, r0
	ldi ZL, low(cifri*2)
	add ZL,tmp2
	lpm
	mov tmp2, r0
	sts numb1,tmp
	sts numb2,tmp2
;3ya i 4ya cifri
	clr tmp
conv7:
	cpi tmp3,10
	brlo conv8
	inc tmp
	subi tmp3, 10
	rjmp conv7
conv8:
	ldi ZL, low(cifri*2)
	add ZL,tmp
	lpm
	mov tmp, r0
	ldi ZL, low(cifri*2)
	add ZL,tmp3
	lpm
	mov tmp3, r0
	cpi rejim,0
	breq conv8r0
	cpi rejim,1
	breq conv8r1
	sbr tmp,0x80
	sbr tmp3,0x80
	rjmp conv8sts
conv8r0:
	bst tochki,1
	brts conv8sts
	sbr tmp,0x80
	sbr tmp3,0x80
	rjmp conv8sts
conv8r1:
	sbr tmp3,0x80	
conv8sts:
	sts numb3,tmp
	sts numb4,tmp3
convend:
	ret

adcint:
	push ZH
	push ZL
	push tmp
	push tmp2
	in tmp, SREG
	push tmp
	in tmp, ADMUX
	bst tmp,0
	brts adctemp1
	bst tmp,1
	brts adctemp2
	clr tmp2
	in tmp, ADCH
	ldi ZH,high(knopki*2)
	ldi ZL,low(knopki*2)
adcbut1:
	lpm
	cp tmp,r0
	inc ZL
	inc tmp2
	brlo adcbut1
	cp tmp2,adcbut
	breq adcbut2
	mov adcbut,tmp2
	rjmp adcend
adcbut2:
	bst butzad,0
	brts adcend
	rcall buttonzaderjka
	ldi ZH,high(button)
	ldi ZL,low(button)
	dec tmp2
	add ZL,tmp2
	brcc adcbut3
	inc ZH
adcbut3:
	icall
	rcall convert
	rjmp adcend
adctemp1:
	in tmp, ADCH
	sts temp1,tmp
	ldi tmp, 0b00100010 ; adc in from pc2, for temp2
	rjmp adcend
adctemp2:
	in tmp, ADCH
	sts temp2,tmp
	ldi tmp, 0b00100000 ; adc in from pc0, for buttons
	rjmp adcend
adcend:
	pop tmp
	out SREG,tmp
	pop tmp2
	pop tmp
	pop ZL
	pop ZH
	reti

timer2comp:
	push tmp
	in tmp, SREG
	push tmp

	pop tmp
	out SREG,tmp
	pop tmp
	reti

button:
	rjmp buttonCH
	rjmp buttonD
	rjmp buttonM
	rjmp buttonS
	rjmp buttonT1
	rjmp buttonB1
	rjmp buttonT2
	rjmp buttonB2
	rjmp buttonMel
	rjmp buttonOtk
	rjmp buttonPer
	rjmp buttonNone	
;REJIMI:
;0 - chasi HH:MM
;1 - data DD:MM
;2 - secundi MM:SS
;3 - bud1
;4 - bud2
;5 - temp1
;6 - temp2
;7 - vibor melodii
buttonCH:
	cpi rejim,0
	breq bch0
	cpi rejim,1
	breq bch1
	cpi rejim,3
	breq bch3
	cpi rejim,4
	breq bch4
	ret
bch0:
	inc hh
	cpi hh,24
	brlo bch01
	clr hh
bch01:
	ret
bch1:
	lds tmp,chislo
	inc tmp
	lds tmp2,mesyac
	ldi ZL, low(dney*2)
	ldi ZH, high(dney*2)
	add ZL,tmp2
	lpm
	mov tmp2, r0
	cp tmp, tmp2
	brlo bch1out
	clr tmp
bch1out:
	sts chislo,tmp
bch1ee1:
	sbic eecr,eewe
	rjmp bch1ee1
	cbi EEARH,0
	ldi tmp2, eeprom
	out EEARL, tmp2
	out EEDR, tmp
	sbi EECR,EEMWE
	sbi EECR,EEWE
	ret
bch3:
	lds tmp,bud1hh
	inc tmp
	cpi tmp,24
	brlo bch31
	clr tmp
bch31:
	sts bud1hh,tmp
	ret
bch4:
	lds tmp,bud2hh
	inc tmp
	cpi tmp,24
	brlo bch41
	clr tmp
bch41:
	sts bud2hh,tmp
	ret

buttonM:
	cpi rejim,0
	breq bm0
	cpi rejim,1
	breq bm1
	cpi rejim,2
	breq bm2
	cpi rejim,3
	breq bm3
	cpi rejim,4
	breq bm4
	ret
bm0:
	inc mm
	cpi mm,60
	brlo bm01
	clr mm
bm01:
	ret
bm1:
	lds tmp,mesyac
	inc tmp
	cpi tmp,12
	brlo bm1out
	clr tmp
bm1out:
	sts mesyac,tmp
bm1ee1:
	sbic eecr,eewe
	rjmp bm1ee1
	cbi EEARH,0
	ldi tmp2, eeprom+1
	out EEARL, tmp2
	out EEDR, tmp
	sbi EECR,EEMWE
	sbi EECR,EEWE
	ret
bm2:
	clr ss
	ret
bm3:
	lds tmp,bud1mm
	inc tmp
	cpi tmp,60
	brlo bm31
	clr tmp
bm31:
	sts bud1mm,tmp
	ret
bm4:
	lds tmp,bud2mm
	inc tmp
	cpi tmp,60
	brlo bm41
	clr tmp
bm41:
	sts bud2mm,tmp
	ret

buttonD:
	ldi rejim,1
	ldi rejimwait,rejimzad
	ret
buttonS:
	cpi rejim,2
	breq bs1
	ldi rejim,2
	clr rejimwait
	ret
bs1:
	clr rejim
	clr rejimwait
	ret
buttonT1:
	ldi rejim,5
	ldi rejimwait,rejimzad
	ret
buttonT2:
	ldi rejim,6
	ldi rejimwait,rejimzad
	ret
buttonB1:
	sbi PORTB,4
	ldi rejim,3
	ldi rejimwait,rejimzad
	ret
buttonB2:
	sbi PORTB,5
	ldi rejim,4
	ldi rejimwait,rejimzad
	ret
buttonMel:
	ldi rejim,7
	ldi rejimwait,rejimzad
	ret
buttonOtk:
	cpi rejim,3
	breq botk1
	cpi rejim,4
	breq botk2
	ret
botk1:
	cbi PORTB,4
	ret
botk2:
	cbi PORTB,5
	ret
buttonPer:
	ret
buttonNone:
	clr butzad
	ret

buttonzaderjka:
	cpi butzad,0
	breq butzad0
	cpi butzad,2
	breq butzad2
	ret
butzad0:
	ldi tmp, zaderjka1
	out TCNT0,tmp
	ldi tmp, timer0cr
	out TCCR0,tmp
	ldi butzad,1
	ret
butzad2:
	ldi tmp, zaderjka2
	out TCNT0,tmp
	ldi tmp, timer0cr
	out TCCR0,tmp
	ldi butzad,3
	ret

timer0ovf:
	push tmp
	in tmp,SREG
	push tmp
	clr tmp
	out TCCR0,tmp
	ldi butzad,2
	pop tmp
	out SREG,tmp
	pop tmp
	reti	

.org 0x0800
dney:
.db	31,28,31,30,31,30,31,31,30,31,30,31
cifri:
;0-3
.db 0b00111111,0b00000110,0b01011011,0b01001111
;4-7
.db 0b01100110,0b01101101,0b01111101,0b00000111
;8-B
.db 0b01111111,0b01101111,0b01110111,0b01111100
;C-F
.db 0b00111001,0b01011110,0b01111001,0b01110001
knopki:
.db 218,195,173,151,131,111,91,71,51,31,10,0
.EXIT
