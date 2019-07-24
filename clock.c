/*****************************************************
This program was produced by the
CodeWizardAVR V1.24.6 Standard
Automatic Program Generator
© Copyright 1998-2005 Pavel Haiduc, HP InfoTech s.r.l.
http://www.hpinfotech.com
e-mail:office@hpinfotech.com

Project : clock
Version : 2.0
Date    : 17.09.2009
Author  : Gogan            
Company : Home              
Comments: 


Chip type           : ATmega8
Program type        : Application
Clock frequency     : 8,000000 MHz
Memory model        : Small
External SRAM size  : 0
Data Stack size     : 256
*****************************************************/

#include <mega8.h>   
#include <stdlib.h>

#define dig1 PORTB.0 
#define dig2 PORTB.1 
#define dig3 PORTB.2 
#define dig4 PORTB.3 
#define a PORTD.0 
#define b PORTD.1 
#define c PORTD.2 
#define d PORTD.3 
#define e PORTD.4 
#define f PORTD.5 
#define g PORTD.6 
#define uclc PORTD.7 

#define temp1 PINC.1  //not used
#define temp2 PINC.2  //not used

#define vd_alarm1 PORTB.5 
#define vd_alarm2 PORTB.4 

#define buzzer PORTC.5   

#define adc_filter 250   // 125000/13=9615 (have_adc per sec)
#define button_delay1 5769 // 600/1000*9615   // 600ms 
#define button_delay2 1442 // 150/1000*9615   // 150ms          
    
bit have_adc=0;
unsigned char button=0;                           
unsigned int button_delay_count=0;
unsigned char button_being_pressed=0;
unsigned char ss=0,mm=0,hh=0;
unsigned char mm1=0,hh1=0,mm2=0,hh2=0;       
unsigned char mm0,hh0;
unsigned char status=0;
        // status=0     - HH:MM         blinking is on
        // status=1     - alarm1 HH:MM  no blinking
        // status=2     - alarm2 HH:MM  no blinking  
        // status=3     - seconds MM:SS blinking is on 
unsigned char n[4];
unsigned char digs[4]; 
unsigned char status_clk=0;  
                   
#define melodies 4
flash const unsigned int melody1[144]={523,240,622,240,784,240,622,240,698,480,622,240,587,240,784,480,698,480,523,960,622,240,784,240,932,240,932,240,1047,480,932,240,831,240,784,960,880,480,988,480,1175,240,1047,240,784,960,587,240,523,240,784,240,698,240,831,960,932,240,831,240,784,480,698,240,622,240,784,480,698,480,523,960};
flash const unsigned int melody2[172]={1175,480,1397,480,1175,240,1175,240,880,480,1175,480,1397,480,1175,240,1175,240,932,480,784,480,932,480,880,240,880,240,659,480,880,240,784,240,698,240,784,240,880,240,0,240,880,240,0,240,1175,480,1397,480,1175,240,1175,240,880,480,1175,480,1397,480,1175,240,1175,240,932,480,784,480,932,480,880,240,880,240,659,480,880,240,784,240,698,240,659,240,587,240};
flash const unsigned int melody3[108]={784,240,622,240,622,240,622,240,622,240,622,480,587,240,587,240,698,240,698,240,622,240,587,240,587,480,523,240,523,240,523,240,523,240,523,240,523,240,932,240,622,240,784,240,784,240,698,480,784,240,831,240,784,480};
flash const unsigned int melody4[124]={1568,238,1397,238,1568,238,1175,238,932,238,1175,238,784,476,1568,238,1397,238,1568,238,1175,238,932,238,1175,238,784,476,1568,238,1760,238,1865,238,1568,119,1865,238,1568,119,1865,238,1760,238,1397,119,1760,238,1397,119,1760,238,1568,238,1397,238,1175,238,1397,238,1568,476};
unsigned int melody_k[melodies]={72,86,54,62};
//float freq=40;           

unsigned char play_mel=0;
unsigned int melody_pos=0;
volatile unsigned int melody_clk=0;    
bit buzzer_on=1;     
unsigned char alarm1_mel=1,alarm2_mel=2,mel_mel=0;
bit nostop_mel=0;
                         
void start_mel(unsigned char n){
        play_mel=n;
        if(play_mel>melodies){play_mel=0;nostop_mel=0;}
        melody_pos=0;
        melody_clk=0;
} 

void stop_mel(void){
        play_mel=0;
        melody_pos=0;
        melody_clk=0;
        nostop_mel=0;
}

// Timer 0 overflow interrupt service routine   //   ~3.9khz
interrupt [TIM0_OVF] void timer0_ovf_isr(void)
{
// Place your code here
        static unsigned char dign=0,dighalf=0;
        dighalf++;
        if(dighalf>4){
                dighalf=0;
                dign++;
                if(dign>3){
                        dign=0;
                }
        }
        PORTD=0xff;
        PORTB&=0xf0;
        PORTB|=(1<<dign);
        if(dighalf==0){PORTD=~(digs[dign]&0x0f);}
        else if(dighalf==1){PORTD=~(digs[dign]&0xf0);}
}
                 
void update_numbers(void){
        unsigned char i;
        bit blinking=0;
        switch(status){
                case 0:
                        hh0=hh;
                        mm0=mm;   
                        blinking=1;
                        break;
                case 1:
                        hh0=hh1;
                        mm0=mm1; 
                        blinking=0;
                        break;
                case 2:
                        hh0=hh2;
                        mm0=mm2;
                        blinking=0;
                        break;                        
                case 3:
                        hh0=mm;
                        mm0=ss;
                        blinking=1;
                        break;                        
        }
        n[0]=hh0/10;
        n[1]=hh0-n[0]*10;
        n[2]=mm0/10;
        n[3]=mm0-n[2]*10;
        for(i=0;i<4;i++){
                switch(n[i]){
                        case 0: digs[i]=0b00111111;
                                break;
                        case 1: digs[i]=0b00000110;
                                break;
                        case 2: digs[i]=0b01011011;
                                break;
                        case 3: digs[i]=0b01001111;
                                break;
                        case 4: digs[i]=0b01100110;
                                break;
                        case 5: digs[i]=0b01101101;
                                break;
                        case 6: digs[i]=0b01111101;
                                break;
                        case 7: digs[i]=0b00000111;
                                break;
                        case 8: digs[i]=0b01111111;
                                break;
                        case 9: digs[i]=0b01101111;
                                break;
                        default:
                                digs[i]=0x00;
                                break;
                }
        }
        if(blinking && ss & 0x01 || !blinking){
                digs[2]|=0x80;
                digs[3]|=0x80;
        }
}                

void set_tone(float freq){
        float tmp1;
        unsigned char presc=1;
        if(freq==0){
                TCCR2=0x08;
                OCR2=0xff;
        }else{
                tmp1=8000000L/freq;
                while(tmp1>255){
                        switch(presc){
                                case 1:
                                        tmp1=tmp1/8;
                                        break;
                                case 2:
                                        tmp1=tmp1/4;
                                        break;
                                case 3:
                                        tmp1=tmp1/2;
                                        break;
                                case 4:
                                        tmp1=tmp1/2;
                                        break;
                                case 5:
                                        tmp1=tmp1/2;
                                        break;
                                case 6:
                                        tmp1=tmp1/4;  
                                        if(tmp1>255){tmp1=255;}
                                        break;
                        }
                        presc++;
                }
                OCR2=tmp1; 
                TCCR2=0x08;
                TCNT2=0;
                TCCR2=presc | 0x08;
        }
}
     

    
// Timer 1 output compare A interrupt service routine
interrupt [TIM1_COMPA] void timer1_compa_isr(void)
{
// Place your code here   
        ss++;
        if(ss>59){
                ss=0;
                mm++;
                if(mm>59){
                        mm=0;
                        hh++;
                        if(hh>23){
                                hh=0;
                        } 
                }
                if(vd_alarm1 && mm==mm1 && hh==hh1){
                        start_mel(alarm1_mel);
                }else if(vd_alarm2 && mm==mm2 && hh==hh2){
                        start_mel(alarm2_mel);
                }else if(!nostop_mel){stop_mel();}
        }
        if(status_clk>0){
                status_clk--;
                if(status_clk==0){status=0;}
        }
        update_numbers();
}        

interrupt [TIM2_COMP] void timer2_comp_isr(void)
{                                             
        if(buzzer_on){buzzer=!buzzer;}
        else{buzzer=0;}
        if(melody_clk>0){melody_clk--;}
}

#define FIRST_ADC_INPUT 0
#define LAST_ADC_INPUT 0
unsigned char adc_data[LAST_ADC_INPUT-FIRST_ADC_INPUT+1];
#define ADC_VREF_TYPE 0x20

// ADC interrupt service routine
// with auto input scanning
interrupt [ADC_INT] void adc_isr(void)
{                
have_adc=1;
register static unsigned char input_index=0;
// Read the 8 most significant bits
// of the AD conversion result
adc_data[input_index]=ADCH;
// Select next ADC input
if (++input_index > (LAST_ADC_INPUT-FIRST_ADC_INPUT))
   input_index=0;
ADMUX=(FIRST_ADC_INPUT|ADC_VREF_TYPE)+input_index;
// Start the AD conversion
ADCSRA|=0x40;
}

unsigned char check_buttons(void){
        unsigned char adc_now;
        static unsigned char adc_prev;
        static unsigned int filter_count=0;
        adc_now=adc_data[0];
        if(adc_now>adc_prev+1 || adc_now<adc_prev-1 || adc_now<10){
//        if(adc_now!=adc_prev || adc_now<10){
//                adc_prev=adc_now;
                if(adc_now>adc_prev){adc_prev++;}
                else if(adc_now<adc_prev){adc_prev--;}
                filter_count=0;
                return 0;
        }else{
                filter_count++;
                if(filter_count>=adc_filter){
                        filter_count--;
                        if(adc_now<31){
                                return 1;
                        }else if(adc_now<51){
                                return 2;
                        }else if(adc_now<71){
                                return 3;
                        }else if(adc_now<91){
                                return 4;
                        }else if(adc_now<111){
                                return 5;
                        }else if(adc_now<131){
                                return 6;
                        }else if(adc_now<151){
                                return 7;
                        }else if(adc_now<173){
                                return 8;
                        }else if(adc_now<195){
                                return 9;
                        }else if(adc_now<218){
                                return 10;
                        }else{
                                return 11;
                        }
                }else{
                        return 0;
                }
        }
        
}

// Declare your global variables here

void main(void)
{
// Declare your local variables here

// Input/Output Ports initialization
// Port B initialization
// Func7=In Func6=In Func5=Out Func4=Out Func3=Out Func2=Out Func1=Out Func0=Out 
// State7=T State6=T State5=0 State4=0 State3=0 State2=0 State1=0 State0=0 
PORTB=0x00;
DDRB=0x3F;

// Port C initialization
// Func6=In Func5=Out Func4=In Func3=In Func2=In Func1=In Func0=In 
// State6=T State5=0 State4=T State3=T State2=T State1=T State0=T 
PORTC=0x00;
DDRC=0x20;

// Port D initialization
// Func7=Out Func6=Out Func5=Out Func4=Out Func3=Out Func2=Out Func1=Out Func0=Out 
// State7=1 State6=1 State5=1 State4=1 State3=1 State2=1 State1=1 State0=1 
PORTD=0xFF;
DDRD=0xFF;

// Timer/Counter 0 initialization
// Clock source: System Clock
// Clock value: 1000,000 kHz
TCCR0=0x02;
TCNT0=0x00;

// Timer/Counter 1 initialization
// Clock source: System Clock
// Clock value: 31,250 kHz
// Mode: CTC top=OCR1A
// OC1A output: Discon.
// OC1B output: Discon.
// Noise Canceler: Off
// Input Capture on Falling Edge
// Timer 1 Overflow Interrupt: Off
// Input Capture Interrupt: Off
// Compare A Match Interrupt: On
// Compare B Match Interrupt: Off
TCCR1A=0x00;
TCCR1B=0x0C;
TCNT1H=0x00;
TCNT1L=0x00;
ICR1H=0x00;
ICR1L=0x00;
OCR1AH=0x7A;
OCR1AL=0x12;
OCR1BH=0x00;
OCR1BL=0x00;

// Timer/Counter 2 initialization
// Clock source: System Clock
// Clock value: Timer 2 Stopped
// Mode: Normal top=FFh
// OC2 output: Disconnected
ASSR=0x00;
TCCR2=0x00;
TCNT2=0x00;
OCR2=0x00;

// External Interrupt(s) initialization
// INT0: Off
// INT1: Off
MCUCR=0x00;

// Timer(s)/Counter(s) Interrupt(s) initialization
TIMSK=0x11 | (1<<7);

// Analog Comparator initialization
// Analog Comparator: Off
// Analog Comparator Input Capture by Timer/Counter 1: Off
ACSR=0x80;
SFIOR=0x00;

// ADC initialization
// ADC Clock frequency: 125,000 kHz
// ADC Voltage Reference: AREF pin
// Only the 8 most significant bits of
// the AD conversion result are used
ADMUX=FIRST_ADC_INPUT|ADC_VREF_TYPE;
ADCSRA=0xCE;

// Global enable interrupts
#asm("sei")

while (1)
      {
      // Place your code here
      if(have_adc){     // BUTTONS  
        button=check_buttons();
        if(button>0){
                button_delay_count++;
                if(button_being_pressed==0 || button_being_pressed==1 && button_delay_count>button_delay1 || 
                   button_being_pressed==2 && button_delay_count>button_delay2){
                        button_being_pressed++;
                        if(button_being_pressed>2){button_being_pressed=2;}
                        button_delay_count=0;
                }else{
                        button=0;
                }
        }else{
                button_delay_count=0;
                button_being_pressed=0;
        }                                           
        switch(button){
                case 1:         // snooth
                        break;           
                case 2:         // stop alarm (OTK)  
                        stop_mel();
                        switch(status){
                                case 0:
                                        if(vd_alarm1){
                                                vd_alarm1=0;
                                        }else if(vd_alarm2){
                                                vd_alarm2=0;
                                        }
                                        break;
                                case 1:       
                                        vd_alarm1=0;
                                        status=0;
                                        status_clk=0;
                                        break;
                                case 2:
                                        vd_alarm2=0;
                                        status=0;
                                        status_clk=0;
                                        break;
                        }
                        break;           
                case 3:         // mel (vibor melodii)
                        nostop_mel=1; 
                        switch(status){
                                case 0:      
                                        mel_mel++;
                                        if(mel_mel>melodies){mel_mel=0;}
                                        start_mel(mel_mel);
                                        break;
                                case 1:       
                                        if(play_mel==0){
                                                start_mel(alarm1_mel);
                                        }else{
                                                alarm1_mel++;
                                                if(alarm1_mel>melodies){alarm1_mel=1;}
                                                start_mel(alarm1_mel);
                                        }
                                        break;
                                case 2:
                                        if(play_mel==0){
                                                start_mel(alarm2_mel);
                                        }else{
                                                alarm2_mel++;
                                                if(alarm2_mel>melodies){alarm2_mel=1;}
                                                start_mel(alarm2_mel);
                                        }
                                        break;
                        }
                        break;           
                case 4:         // B2 (alarm 2)  
                        if(status!=2){
                                status=2;
                                status_clk=5;
                                vd_alarm2=1;
                        }else{
                                status=0;
                                status_clk=0;
                        }
                        break;           
                case 5:         // T2 (temp 2)
                        break;           
                case 6:         // B1 (alarm 1)
                        if(status!=1){ 
                                status=1;
                                status_clk=5;
                                vd_alarm1=1;
                        }else{
                                status=0;
                                status_clk=0;
                        }
                        break;           
                case 7:         // T1 (temp 1)
                        break;           
                case 8:         // S (seconds)
                        if(status==3){
                                status=0;
                        }else{
                                status=3;
                        }
                        break;           
                case 9:         // M (minutes)
                        switch(status){
                                case 0:
                                        mm++;
                                        if(mm>59){mm=0;}
                                        break;
                                case 1:       
                                        mm1++;
                                        if(mm1>59){mm1=0;}
                                        break;
                                case 2:
                                        mm2++;
                                        if(mm2>59){mm2=0;}
                                        break;
                        }
                        break;           
                case 10:        // D (date)
                        break;           
                case 11:        // CH (hours)
                        switch(status){
                                case 0:
                                        hh++;
                                        if(hh>23){hh=0;}
                                        break;
                                case 1:       
                                        hh1++;
                                        if(hh1>23){hh1=0;}
                                        break;
                                case 2:
                                        hh2++;
                                        if(hh2>23){hh2=0;}
                                        break;
                        }
                        break;           
        }
        if(button>0){
                update_numbers();
                if(status_clk>0){status_clk=5;}
        }
        have_adc=0;
      }
      if(play_mel>0 && melody_clk==0){
        if(melody_pos>melody_k[play_mel-1]*2-1){
                melody_pos=0;
        }            
        switch(play_mel){
                case 1:
                        if(melody1[melody_pos]>0){
                                buzzer_on=1;
                                set_tone((float)melody1[melody_pos]);
                                melody_clk=(float)melody1[melody_pos+1]/1000*melody1[melody_pos];
                        }else{
                                buzzer_on=0;
                                set_tone(1000);
                                melody_clk=melody1[melody_pos+1];
                        }
                        break;
                case 2:
                        if(melody2[melody_pos]>0){
                                buzzer_on=1;
                                set_tone((float)melody2[melody_pos]);
                                melody_clk=(float)melody2[melody_pos+1]/1000*melody2[melody_pos];
                        }else{
                                buzzer_on=0;
                                set_tone(1000);
                                melody_clk=melody2[melody_pos+1];
                        }
                        break;
                case 3:
                        if(melody3[melody_pos]>0){
                                buzzer_on=1;
                                set_tone((float)melody3[melody_pos]);
                                melody_clk=(float)melody3[melody_pos+1]/1000*melody3[melody_pos];
                        }else{
                                buzzer_on=0;
                                set_tone(1000);
                                melody_clk=melody3[melody_pos+1];
                        }
                        break;
                case 4:
                        if(melody4[melody_pos]>0){
                                buzzer_on=1;
                                set_tone((float)melody4[melody_pos]);
                                melody_clk=(float)melody4[melody_pos+1]/1000*melody4[melody_pos];
                        }else{
                                buzzer_on=0;
                                set_tone(1000);
                                melody_clk=melody4[melody_pos+1];
                        }
                        break;
        }
        melody_pos+=2;
      }
      if(play_mel==0){set_tone(0);}

      };
}
