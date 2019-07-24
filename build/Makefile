## General Flags
PROJECT = clock
MCU = atmega8
F_CPU=8000000L
PROGRAMMATOR_COM_PORT = /dev/ttyACM1

INCLUDES = -I"../"

SOURCES = $(wildcard ../*.c)
OBJECTS = $(SOURCES:.c=.o)


############################################
TARGET = $(PROJECT).elf
CC = avr-gcc

## Options common to compile, link and assembly rules
COMMON = -mmcu=$(MCU)

## Compile options common for all C compilation units.
CFLAGS = $(COMMON)
CFLAGS += -Wall -gdwarf-2 -std=gnu99   -DF_CPU=$(F_CPU) -Os -funsigned-char -funsigned-bitfields -fpack-struct -fshort-enums
CFLAGS += -MD -MP -MT $(*F).o -MF dep/$(@F).d 

## Assembly specific flags
ASMFLAGS = $(COMMON)
ASMFLAGS += $(CFLAGS)
ASMFLAGS += -x assembler-with-cpp -Wa,-gdwarf2

## Linker flags
LDFLAGS = $(COMMON)
LDFLAGS +=  -Wl,-Map=$(PROJECT).map


## Intel Hex file production flags
HEX_FLASH_FLAGS = -R .eeprom -R .fuse -R .lock -R .signature

HEX_EEPROM_FLAGS = -j .eeprom
HEX_EEPROM_FLAGS += --set-section-flags=.eeprom="alloc,load"
HEX_EEPROM_FLAGS += --change-section-lma .eeprom=0 --no-change-warnings

## Objects explicitly added by the user
LINKONLYOBJECTS = 

## Build
all: $(TARGET) $(PROJECT).hex $(PROJECT).eep $(PROJECT).lss size
	@ echo 'all'
	@ echo avrdude -c avr910 -p m8 -P $(PROGRAMMATOR_COM_PORT) -U flash:w:$(PROJECT).hex > prorgamm.sh

## Compile
%.o : %.c
	@ echo 'Compiling' $<
	@ $(CC) $(INCLUDES) $(CFLAGS) -c  $< -o $@

##Link
$(TARGET): $(OBJECTS)
	@ echo 'linking'
	 $(CC) $(LDFLAGS) $(OBJECTS) $(LINKONLYOBJECTS) $(LIBDIRS) $(LIBS) -o $(TARGET)

%.hex: $(TARGET)
	@ echo 'hex' $<
	avr-objcopy -O ihex $(HEX_FLASH_FLAGS)  $< $@

%.eep: $(TARGET)
	@ echo 'eep' $<
	-avr-objcopy $(HEX_EEPROM_FLAGS) -O ihex $< $@ || exit 0

%.lss: $(TARGET)
	@ echo 'lss' $<
	avr-objdump -h -S $< > $@

size: ${TARGET}
	@ echo 'size' $<
	avr-size -C --mcu=${MCU} ${TARGET}

## Clean target
.PHONY: clean
clean:
	@ echo 'cleaning'
	-rm -rf $(OBJECTS) $(PROJECT).elf dep/* $(PROJECT).hex $(PROJECT).eep $(PROJECT).lss $(PROJECT).map


## Other dependencies
-include $(shell mkdir -p dep) $(wildcard dep/*)

