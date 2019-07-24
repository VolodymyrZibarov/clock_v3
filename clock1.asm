.include "m8def.inc"
.def tmp=r16
.def tmp2=r17
.def tmp3=r18
.def ss=r20
.def mm=r21
.def hh=r22
.def rejim=r23
.def adcbut=r24
.def butzad=r25
.def rejimwait=r26
.def tochki=r27
.def filter=r28
.def budton=r19
.def budmel=r29
.def melhigh=r2

;sekunda - pervaya korekciya +4 (5 sec otstavaniya za 10:50 )
.equ second=31248	;1 sec on 8Mhz and clock/256 delitel 
.equ gromkost=255	;gromkost 1-255
.equ rejimzad=5		;5s zaderjka rejimov D,B1,B2,T1,T2,M
.equ timer0cr=0x04	;delitel 256 (1ms/32)
.equ zaderjka1=600	;ms - pervoye povtorenie knopki
.equ zaderjka2=150	;ms - posleduyuschiye povtoreniya knopki
.equ timer2cr=0b00000101	;delitel 128 (1/62500s) - min 244hz 
.equ adcmuxbutcr=0b00100000	;ADCMUX constants
.equ adcmuxtemp1cr=0b00000001
.equ adcmuxtemp2cr=0b00000010
.equ budnots=97		;kolivo zapisey v 1y melodii (db /2)
.equ eeprom=0		;adres zapisi chisla i mesyaca v eeprom
.equ adcfilter=250	;filter adc - dlya 600*8hz  - 2xT zaryadki C 100n
.equ numb1=0xf0		;adres SRAM dlya zapisi cifer (4bytes)
.equ numb2=0xf1		
.equ numb3=0xf2		
.equ numb4=0xf3		
;equ temp1=0xf4		;adres SRAM temperatura vnutri
;equ temp2=0xf5		;adres SRAM	temperatura na ulice
.equ chislo=0xf6	;adres SRAM chislo
.equ mesyac=0xf7	;adres SRAM chislo
.equ bud1hh=0xf8	;adres SRAM budilnikov 1 i 2
.equ bud1mm=0xf9
.equ bud2hh=0xfA
.equ bud2mm=0xfB
.equ bud1vkl=0xfC	;sostoyaniye budilnika
.equ bud2vkl=0xfD
.equ bud1mel=0xfe	;nomer melodii bud1
.equ bud2mel=0xff	;nomer melodii bud2
.equ budrejim=0x100	;rejim budilnika
.equ tempadc=0x101	;dlya termometra
.equ temp1L=0x102	;
.equ temp1H=0x103	;
.equ temp2L=0x104	;
.equ temp2H=0x105	;

.cseg
.org 0
	rjmp reset ;
	reti ; INT0
	reti ; INT1
	reti; TIMER2COMP
	rjmp timer2ovf ;TIMER2OVF
	reti ; TIMER1CAPT
	reti ;TIMER1COMPA
	reti ; TIMER1COMPB
	rjmp timer1ovf ; TIMER1OVF
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

; PROVERKA DInAMIKA
/*	sbi DDRC,5
reset1:
	sbi PORTC,5
	rcall reswait
	cbi PORTC,5
	rcall reswait
	rjmp reset1
reswait:
	ldi tmp,2
res11:
	ldi tmp2,255
res12:
	dec tmp2
	brne res12
	dec tmp
	brne res11
	ret
*/

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
	ldi tmp, (1<<ADEN)|(1<<ADSC)|(1<<ADIE)|(1<<ADFR)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0) ; adc ~600hz preobrazovaniy
	out ADCSRA, tmp
	ldi tmp, adcmuxbutcr ; adc in from pc0, left adjust adc data register, ref from AREF
	out ADMUX, tmp
;TIMER 1
	ldi tmp, high(65535-second)
	out TCNT1H, tmp
	ldi tmp, low(65535-second)
	out TCNT1L, tmp
	ldi tmp, 0b00000000	;
	out TCCR1A, tmp
	ldi tmp, 0b00000100 ; clock/256 delitel
	out TCCR1B, tmp
;TIMER 2
	clr tmp
	out TCCR2, tmp
;TIMER INTERRUPTS TOIE2=1 and toie1=1 and TOIE0=1
	ldi tmp,0b01000101
	out TIMSK,tmp
;ENABLE INTERRUPTS
	sei
;TIME
	clr ss
	clr mm
	clr hh
	clr tmp
	sts chislo,tmp
	sts mesyac,tmp
	sts bud1hh,tmp
	sts bud1mm,tmp
	sts bud2hh,tmp
	sts bud2mm,tmp
	sts bud1mel,tmp
	sts bud2mel,tmp
	sts budrejim,tmp
;DATE from EEPROM
;eeprom1:
;	sbic eecr,eewe
;	rjmp eeprom1
;	cbi EEARH,0
;	ldi tmp, eeprom
;	out EEARL, tmp
;	sbi EECR,EERE
;	in tmp, EEDR
;	cpi tmp, 31
;	brlo eeprom11
;	clr tmp
;eeprom11:
;	sts chislo,tmp
;eeprom2:
;	sbic eecr,eewe
;	rjmp eeprom2
;	cbi EEARH,0
;	ldi tmp, eeprom+1
;	out EEARL, tmp
;	sbi EECR,EERE
;	in tmp, EEDR
;	cpi tmp, 12
;	brlo eeprom21
;	clr tmp
;eeprom21:
;	sts mesyac,tmp
	clr rejim
	clr rejimwait
	clr tochki
	clr butzad
	clr adcbut
	rcall convert
;	rcall budtest
main:
	rcall diodes
	rjmp main

diodes:
	ldi ZH,high(numb1)
	ldi ZL,low(numb1)
	clr tmp2
diodes1:
	inc tmp2
	cpi tmp2,2
	breq d12
	cpi tmp2,3
	breq d13
	cpi tmp2,4
	breq d14
	sbi PORTB,0
	rjmp d15
d12:
	cbi PORTB,0
	sbi PORTB,1
	rjmp d15
d13:
	cbi PORTB,1
	sbi PORTB,2
	rjmp d15
d14:
	cbi PORTB,2
	sbi PORTB,3
d15:
	ld tmp,Z+
	sbrc tmp,0
	cbi PORTD,0
	rcall diodeswait
	sbi PORTD,0
	sbrc tmp,1
	cbi PORTD,1
	rcall diodeswait
	sbi PORTD,1
	sbrc tmp,2
	cbi PORTD,2
	rcall diodeswait
	sbi PORTD,2
	sbrc tmp,3
	cbi PORTD,3
	rcall diodeswait
	sbi PORTD,3
	sbrc tmp,4
	cbi PORTD,4
	rcall diodeswait
	sbi PORTD,4
	sbrc tmp,5
	cbi PORTD,5
	rcall diodeswait
	sbi PORTD,5
	sbrc tmp,6
	cbi PORTD,6
	rcall diodeswait
	sbi PORTD,6
	sbrc tmp,7
	cbi PORTD,7
	rcall diodeswait
	sbi PORTD,7
diodes3:
	cpi tmp2,4
	brlo diodes1
	cbi PORTB,3
	ret

diodeswait:
		push tmp
		ldi tmp,100
diodeswait1:
		dec tmp
		brne diodeswait1
		pop tmp
		ret

timer1ovf:
	push ZH
	push ZL
	push tmp
	push tmp2
	push tmp3
	in tmp, SREG
	push tmp
	ldi tmp, high(65535-second)
	out TCNT1H, tmp
	ldi tmp, low(65535-second)
	out TCNT1L, tmp
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
	rcall budtest
	cpi mm,60
	brlo time1end
	clr mm
	inc hh
	rcall budtest
	cpi hh,24
	brlo time1end
	clr hh
	rcall budtest
	lds tmp, chislo
	inc tmp
	lds tmp2,mesyac
	ldi ZH, high(dney*2)
	ldi ZL, low(dney*2)
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
;time1eeprom1:
;	sbic eecr,eewe
;	rjmp time1eeprom1
;	cbi EEARH,0
;	ldi tmp3, eeprom
;	out EEARL, tmp3
;	out EEDR, tmp
;	sbi EECR,EEMWE
;	sbi EECR,EEWE
;time1eeprom2:
;	sbic eecr,eewe
;	rjmp time1eeprom2
;	cbi EEARH,0
;	ldi tmp3, eeprom+1
;	out EEARL, tmp3
;	out EEDR, tmp2
;	sbi EECR,EEMWE
;	sbi EECR,EEWE
time1end:
	rcall convert
	ldi tmp,adcmuxtemp1cr
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
	brne conv101
	rjmp conv1
conv101:
	cpi rejim,2
	brne conv20
	rjmp conv2
conv20:
	cpi rejim,3
	brne conv30
	rjmp conv3
conv30:
	cpi rejim,4
	brne conv40
	rjmp conv4
conv40:
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
	lds tmp3,temp1L
	lds tmp2,temp1H
	rjmp convert2
;rejim=6 temp2
convtemp2:
	lds tmp3,temp2L
	lds tmp2,temp2H
convert2:
	ldi ZH,high(tempdata*2)
	ldi ZL,low(tempdata*2)
	add ZL,tmp3
	brcc convert21
	inc ZH
convert21:
	add ZH,tmp2
	lpm tmp3,Z
	clr tmp2
	bst tmp3,7
	bld tmp2,6
	sts numb1,tmp2
	brtc convert22
	com tmp3
	inc tmp3
convert22:
	clr tmp
conv9:
	cpi tmp3,10
	brlo conv10
	inc tmp
	subi tmp3, 10
	rjmp conv9
conv10:
	ldi ZH, high(cifri*2)
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
	push tmp3
	in tmp, SREG
	push tmp
	in tmp, ADMUX
	bst tmp,0
	brtc adcbut0
	rjmp adctemp1
adcbut0:
	bst tmp,1
	brtc adcbut01
	rjmp adctemp2
adcbut01:
	in tmp, ADCH
	ldi tmp2,12
	cpi tmp,10
	brlo adcbut1
	dec tmp2
	cpi tmp,31
	brlo adcbut1
	dec tmp2
	cpi tmp,51
	brlo adcbut1
	dec tmp2
	cpi tmp,71
	brlo adcbut1
	dec tmp2
	cpi tmp,91
	brlo adcbut1
	dec tmp2
	cpi tmp,111
	brlo adcbut1
	dec tmp2
	cpi tmp,131
	brlo adcbut1
	dec tmp2
	cpi tmp,151
	brlo adcbut1
	dec tmp2
	cpi tmp,173
	brlo adcbut1
	dec tmp2
	cpi tmp,195
	brlo adcbut1
	dec tmp2
	cpi tmp,218
	brlo adcbut1
	dec tmp2
adcbut1:
	cp tmp2,adcbut
	breq adcbut2
	mov adcbut,tmp2
	clr filter
	rjmp adcend
adcbut2:
	inc filter
	cpi filter,adcfilter
	brlo adcend
	dec filter
	cpi tmp2,12
	brlo adcbut21
	clr butzad
	rjmp adcend
adcbut21:
	cpi butzad,2
	brlo adcbut22
	rjmp adcend
adcbut22:
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
	lds tmp,tempadc
	inc tmp
	sts tempadc,tmp
	cpi tmp,3
	brlo adcend
	in tmp, ADCL
	sts temp1L,tmp
	in tmp, ADCH
	sts temp1H, tmp
	ldi tmp, adcmuxtemp2cr ; adc in from pc2, for temp2
	out ADMUX,tmp
	rjmp adcend
adctemp2:
	lds tmp,tempadc
	inc tmp
	sts tempadc,tmp
	cpi tmp,5
	brlo adcend
	in tmp, ADCL
	sts temp2L,tmp
	in tmp, ADCH
	sts temp2H, tmp
	ldi tmp, adcmuxbutcr ; adc in from pc0, for buttons
	out ADMUX,tmp
	clr tmp
	sts tempadc,tmp
	rjmp adcend
adcend:
	pop tmp
	out SREG,tmp
	pop tmp3
	pop tmp2
	pop tmp
	pop ZL
	pop ZH
	reti

button:
	rjmp buttonCH
	rjmp buttonD
	rjmp buttonM
	rjmp buttonS
	rjmp buttonT1
	rjmp buttonB2
	rjmp buttonT2
	rjmp buttonB1
	rjmp buttonMel
	rjmp buttonOtk
	rjmp buttonPer
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
	cpi rejim,2
	breq bch2
	cpi rejim,3
	breq bch3
	cpi rejim,4
	breq bch4
	cpi rejim,5
	breq bch2
	cpi rejim,6
	breq bch2
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
	ldi rejimwait,rejimzad
;bch1ee1:
;	sbic eecr,eewe
;	rjmp bch1ee1
;	cbi EEARH,0
;	ldi tmp2, eeprom
;	out EEARL, tmp2
;	out EEDR, tmp
;	sbi EECR,EEMWE
;	sbi EECR,EEWE
	ret
bch2:
	clr rejim
	clr rejimwait
	ret
bch3:
	ldi rejimwait,rejimzad
	lds tmp,bud1hh
	inc tmp
	cpi tmp,24
	brlo bch31
	clr tmp
bch31:
	sts bud1hh,tmp
	ret
bch4:
	ldi rejimwait,rejimzad
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
	ldi rejimwait,rejimzad
;bm1ee1:
;	sbic eecr,eewe
;	rjmp bm1ee1
;	cbi EEARH,0
;	ldi tmp2, eeprom+1
;	out EEARL, tmp2
;	out EEDR, tmp
;	sbi EECR,EEMWE
;	sbi EECR,EEWE
	ret
bm2:
	clr ss
	ret
bm3:
	ldi rejimwait,rejimzad
	lds tmp,bud1mm
	inc tmp
	cpi tmp,60
	brlo bm31
	clr tmp
bm31:
	sts bud1mm,tmp
	ret
bm4:
	ldi rejimwait,rejimzad
	lds tmp,bud2mm
	inc tmp
	cpi tmp,60
	brlo bm41
	clr tmp
bm41:
	sts bud2mm,tmp
	ret

buttonD:
	cpi rejim,1
	breq bd1
	ldi rejim,1
	ldi rejimwait,rejimzad
	ret
bd1:
	ldi rejim,0
	clr rejimwait
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
	cpi rejim,5
	breq bt15
	ldi rejim,5
	ldi rejimwait,20
	ret
bt15:
	clr rejim
	clr rejimwait
	ret
buttonT2:
	cpi rejim,6
	breq bt25
	ldi rejim,6
	ldi rejimwait,20
	ret
bt25:
	clr rejim
	clr rejimwait
	ret
buttonB1:
	cpi rejim,3
	breq bb13
	sbi PORTB,4
	ldi rejim,3
	ldi rejimwait,rejimzad
	rcall budtest
	ret
bb13:
	clr rejim
	clr rejimwait
	ret
buttonB2:
	cpi rejim,4
	breq bb24
	sbi PORTB,5
	ldi rejim,4
	ldi rejimwait,rejimzad
	rcall budtest
	ret
bb24:
	clr rejim
	clr rejimwait
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
	sbis PINB,4
	rjmp botk01
	lds tmp,bud1mm
	cp mm,tmp
	brne botk01
	lds tmp,bud1hh
	cp hh,tmp
	brne botk01
	cbi PORTB,4
	rcall budtest
	ret
botk01:
	sbis PINB,5
	rjmp botk02
	lds tmp,bud2mm
	cp mm,tmp
	brne botk02
	lds tmp,bud2hh
	cp hh,tmp
	brne botk02
	cbi PORTB,5
	rcall budtest
	ret
botk02:
	cbi PORTB,5
	cbi PORTB,5
	rcall budtest
	ret
botk1:
	cbi PORTB,4
	clr rejim
	clr rejimwait
	ret
botk2:
	cbi PORTB,5
	clr rejim
	clr rejimwait
	ret
buttonPer:
	ret

buttonzaderjka:
	cpi butzad,0
	breq butzad0
	cpi butzad,1
	breq butzad2
	ret
butzad0:
	ldi butzad, zaderjka1*32/256+1
	clr tmp
	out TCNT0,tmp
	ldi tmp, timer0cr
	out TCCR0,tmp
	ret
butzad2:
	ldi butzad, zaderjka2*32/256+1
	clr tmp
	out TCNT0,tmp
	ldi tmp, timer0cr
	out TCCR0,tmp
	ret

timer0ovf:
	push tmp
	in tmp,SREG
	push tmp
	push tmp2
	push ZH
	push ZL
	lds tmp,budrejim
	cpi tmp,0
	breq timer0but
	cpi budmel,0
	breq timer0bud
	dec budmel
	rjmp timer0end
timer0bud:
	clr ZL
	mov ZH, melhigh
	ldi tmp2,budnots*2+2
	sub tmp2,tmp
	add ZL,tmp2
	subi tmp,2
	cpi tmp,0
	brne timer0bud1
	rcall budtest
	rjmp timer0end
timer0bud1:
	sts budrejim,tmp
	dec ZL
	lpm
	mov budton, r0
	dec ZL
	lpm
	mov budmel,r0
	rjmp timer0end
timer0but:
	cpi butzad,2
	brlo timer0otk
	dec butzad
	rjmp timer0end
timer0otk:
	clr tmp
	out TCCR0,tmp
timer0end:
	pop ZL
	pop ZH
	pop tmp2
	pop tmp
	out SREG,tmp
	pop tmp
	reti	

budtest:
	sbis PINB,4
	rjmp budtest2
	lds tmp,bud1mm
	cp mm,tmp
	brne budtest2
	lds tmp,bud1hh
	cp hh,tmp
	brne budtest2
	ldi tmp,budnots*2
	sts budrejim,tmp
	ldi tmp,timer2cr
	out TCCR2,tmp
	ldi tmp, timer0cr
	out TCCR0,tmp
	ser budton
	clr budmel
	ldi tmp,high(2*melody)
	mov melhigh,tmp
	ret
budtest2:
	sbis PINB,5
	rjmp budend
	lds tmp,bud2mm
	cp mm,tmp
	brne budend
	lds tmp,bud2hh
	cp hh,tmp
	brne budend
	ldi tmp,budnots*2
	sts budrejim,tmp
	ldi tmp,timer2cr
	out TCCR2,tmp
	ldi tmp, timer0cr
	out TCCR0,tmp
	ser budton
	clr budmel
	ldi tmp,high(2*melody2)
	mov melhigh,tmp
	ret
budend:
	clr tmp
	sts budrejim,tmp
	out TCCR2,tmp
	out TCCR0,tmp
	ret

timer2ovf:
	push tmp
	cpi budton,255
	breq timer2ovf2
	sbic PINC,5
	rjmp timer2ovf1
	sbi PORTC,5
	out TCNT2,budton
	pop tmp
	reti
timer2ovf1:
	cbi PORTC,5
	out TCNT2,budton
	pop tmp
	reti
timer2ovf2:
	cbi PORTC,5
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
.org 0x0900
melody:
;768 bytes max
; zaderjka2 tonalnost2 zaderjka1 tonalnost1
; tonalnost ot 0 (244hz/2) do 194 (1000hz/2), 0 for no sound
;zaderjka chislo*32/4ms 
.db 37,137
.db 0,255
.db 74,167
.db 0,255
.db 37,137
.db 0,255
.db 37,150
.db 0,255
.db 74,161
.db 0,255
.db 37,114
.db 0,255
.db 37,114
.db 0,255
.db 74,150
.db 0,255
.db 37,137
.db 0,255
.db 37,122
.db 0,255
.db 74,137
.db 0,255
.db 37,77
.db 0,255
.db 37,77
.db 0,255
.db 74,97
.db 0,255
.db 37,97
.db 0,255
.db 37,114
.db 0,255
.db 74,122
.db 0,255
.db 37,122
.db 0,255
.db 37,137
.db 0,255
.db 74,150
.db 0,255
.db 37,161
.db 0,255
.db 37,167
.db 0,255
.db 74,176
.db 0,255
.db 37,255
.db 0,255
.db 37,137
.db 0,255
.db 74,185
.db 0,255
.db 37,176
.db 0,255
.db 37,167
.db 0,255
.db 74,176
.db 0,255
.db 37,161
.db 0,255
.db 37,137
.db 0,255
.db 74,167
.db 0,255
.db 37,161
.db 0,255
.db 37,150
.db 0,255
.db 74,161
.db 0,255
.db 37,114
.db 0,255
.db 37,114
.db 0,255
.db 74,150
.db 0,255
.db 37,137
.db 0,255
.db 37,122
.db 0,255
.db 74,137
.db 0,255
.db 37,77
.db 0,255
.db 37,77
.db 0,255
.db 74,167
.db 0,255
.db 37,161
.db 0,255
.db 37,150
.db 0,255
.db 74,137
.db 0,255
.db 74,137
.db 0,255

.org 0x0a00
melody2:
.db 149,255
.db 0,255
.db 37,255
.db 0,255
.db 18,172
.db 0,255
.db 18,172
.db 0,255
.db 18,172
.db 0,255
.db 18,161
.db 0,255
.db 18,150
.db 0,255
.db 18,143
.db 0,255
.db 74,129
.db 0,255
.db 37,172
.db 0,255
.db 74,161
.db 0,255
.db 18,161
.db 0,255
.db 18,161
.db 0,255
.db 18,161
.db 0,255
.db 18,150
.db 0,255
.db 18,143
.db 0,255
.db 18,129
.db 0,255
.db 74,114
.db 0,255
.db 37,172
.db 0,255
.db 74,150
.db 0,255
.db 18,172
.db 0,255
.db 18,172
.db 0,255
.db 18,172
.db 0,255
.db 18,161
.db 0,255
.db 18,150
.db 0,255
.db 18,143
.db 0,255
.db 74,129
.db 0,255
.db 37,172
.db 0,255
.db 74,161
.db 0,255
.db 37,150
.db 0,255
.db 37,143
.db 0,255
.db 149,150
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255
.db 0,255




.org 0x0B00
tempdata:
.db 98,98,98,98,97,97,97,97,97,97,97,96,96,96,96,96,96,96,96,95,95,95,95,95,95,95,94,94,94,94,94,94,94,93,93,93,93,93,93,93,93,92,92,92,92,92,92,92,91,91,91,91,91,91,91,90,90,90,90,90,90,90,90,89,89,89,89,89,89,89,88,88,88,88,88,88,88,87,87,87,87,87,87,87,87,86,86,86,86,86,86,86,85,85,85,85,85,85,85,84,84,84,84,84,84,84,84,83,83,83,83,83,83,83,82,82,82,82,82,82,82,81,81,81,81,81,81,81,81,80,80,80,80,80,80,80,79,79,79,79,79,79,79,78,78,78,78,78,78,78,78,77,77,77,77,77,77,77,76,76,76,76,76,76,76,75,75,75,75,75,75,75,75,74,74,74,74,74,74,74,73,73,73,73,73,73,73,72,72,72,72,72,72,72,72,71,71,71,71,71,71,71,70,70,70,70,70,70,70,69,69,69,69,69,69,69,69,68,68,68,68,68,68,68,67,67,67,67,67,67,67,66,66,66,66,66,66,66,66,65,65,65,65,65,65,65,64,64,64,64,64,64,64,63,63,63
.db 63,63,63,63,63,62,62,62,62,62,62,62,61,61,61,61,61,61,61,60,60,60,60,60,60,60,60,59,59,59,59,59,59,59,58,58,58,58,58,58,58,57,57,57,57,57,57,57,57,56,56,56,56,56,56,56,55,55,55,55,55,55,55,54,54,54,54,54,54,54,54,53,53,53,53,53,53,53,52,52,52,52,52,52,52,51,51,51,51,51,51,51,51,50,50,50,50,50,50,50,49,49,49,49,49,49,49,48,48,48,48,48,48,48,48,47,47,47,47,47,47,47,46,46,46,46,46,46,46,45,45,45,45,45,45,45,45,44,44,44,44,44,44,44,43,43,43,43,43,43,43,43,42,42,42,42,42,42,42,41,41,41,41,41,41,41,40,40,40,40,40,40,40,40,39,39,39,39,39,39,39,38,38,38,38,38,38,38,37,37,37,37,37,37,37,37,36,36,36,36,36,36,36,35,35,35,35,35,35,35,34,34,34,34,34,34,34,34,33,33,33,33,33,33,33,32,32,32,32,32,32,32,31,31,31,31,31,31,31,31,30,30,30,30,30,30,30,29,29,29,29,29,29,29,28,28
.db 28,28,28,28,28,28,27,27,27,27,27,27,27,26,26,26,26,26,26,26,25,25,25,25,25,25,25,25,24,24,24,24,24,24,24,23,23,23,23,23,23,23,22,22,22,22,22,22,22,22,21,21,21,21,21,21,21,20,20,20,20,20,20,20,19,19,19,19,19,19,19,19,18,18,18,18,18,18,18,17,17,17,17,17,17,17,16,16,16,16,16,16,16,16,15,15,15,15,15,15,15,14,14,14,14,14,14,14,13,13,13,13,13,13,13,13,12,12,12,12,12,12,12,11,11,11,11,11,11,11,10,10,10,10,10,10,10,10,9,9,9,9,9,9,9,8,8,8,8,8,8,8,7,7,7,7,7,7,7,7,6,6,6,6,6,6,6,5,5,5,5,5,5,5,4,4,4,4,4,4,4,4,3,3,3,3,3,3,3,2,2,2,2,2,2,2,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-2,-2,-2,-2,-2,-2,-2,-2,-3,-3,-3,-3,-3,-3,-3,-4,-4,-4,-4,-4,-4,-4,-5,-5,-5,-5,-5,-5,-5,-5,-6,-6,-6,-6,-6,-6,-6,-7
.db -7,-7,-7,-7,-7,-7,-8,-8,-8,-8,-8,-8,-8,-8,-9,-9,-9,-9,-9,-9,-9,-10,-10,-10,-10,-10,-10,-10,-11,-11,-11,-11,-11,-11,-11,-11,-12,-12,-12,-12,-12,-12,-12,-13,-13,-13,-13,-13,-13,-13,-14,-14,-14,-14,-14,-14,-14,-14,-15,-15,-15,-15,-15,-15,-15,-16,-16,-16,-16,-16,-16,-16,-17,-17,-17,-17,-17,-17,-17,-17,-18,-18,-18,-18,-18,-18,-18,-19,-19,-19,-19,-19,-19,-19,-20,-20,-20,-20,-20,-20,-20,-20,-21,-21,-21,-21,-21,-21,-21,-22,-22,-22,-22,-22,-22,-22,-23,-23,-23,-23,-23,-23,-23,-23,-24,-24,-24,-24,-24,-24,-24,-25,-25,-25,-25,-25,-25,-25,-26,-26,-26,-26,-26,-26,-26,-26,-27,-27,-27,-27,-27,-27,-27,-28,-28,-28,-28,-28,-28,-28,-28,-29,-29,-29,-29,-29,-29,-29,-30,-30,-30,-30,-30,-30,-30,-31,-31,-31,-31,-31,-31,-31,-31,-32,-32,-32,-32,-32,-32,-32,-33,-33,-33,-33,-33,-33,-33,-34,-34,-34,-34,-34,-34,-34,-34,-35,-35,-35,-35,-35,-35,-35,-36,-36,-36,-36,-36,-36,-36,-37,-37,-37,-37,-37,-37,-37,-37,-38,-38,-38,-38,-38,-38,-38,-39,-39,-39,-39,-39,-39,-39,-40,-40,-40,-40,-40,-40,-40,-40,-41,-41,-41,-41,-41,-41,-41
.EXIT
