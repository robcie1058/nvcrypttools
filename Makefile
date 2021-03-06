#!/usr/bin/make
CROSS_COMPILE ?= arm-linux-androideabi-

CC := $(CROSS_COMPILE)gcc
LD := $(CROSS_COMPILE)ld
OBJCOPY := $(CROSS_COMPILE)objcopy
MAKE ?= make

CFLAGS := -std=gnu99 -O0 -g -DNVAES_DEBUG_ENABLE -DNVAES_DEBUG_CRYPT -DNVAES_DEBUG_RAW_CRYPT -DNVAES_DEBUG_DATA -DENABLE_DEBUG -Wall -Wno-unused-variable -I.
LDFLAGS := 
STRIP := $(CROSS_COMPILE)strip

SHARED_OBJS := nvrcm.o

ifneq ($(CROSS_COMPILE),)
	SHARED_OBJS += nvaes.o
	CFLAGS += -D__ANDROID_API__=17 -static -march=armv7-a -mthumb
else
	SHARED_OBJS += nvaes-non-device.o
	CFLAGS += -lmbedcrypto -fsanitize=undefined
endif

#NVBLOB2GO_OBJS = gpiokeys.o scrollback.o

DEVICE_DIRS = $(shell gfind devices/ -mindepth 1 -maxdepth 1 -type d)
DEVICE_TARGETS = $(patsubst devices/%,%, $(DEVICE_DIRS))
DEVICE_RAMDISKS = $(patsubst %, %.cpio.gz, $(DEVICE_TARGETS))
DEVICE_BOOTIMGS = $(patsubst %, %.img, $(DEVICE_TARGETS))

all: nvsign nvencrypt nvdecrypt mknvfblob warmboot-tf101.bin warmboot-n7.bin warmboot-n7-pwn.bin warmboot-h4x $(DEVICE_TARGETS)

$(DEVICE_TARGETS): nvblob2go.c $(SHARED_OBJS) bins
	$(CC) $(CFLAGS) -Idevices/$@ -o $@ nvblob2go.c $(SHARED_OBJS) $(LDFLAGS) && \
		$(STRIP) $@

%.cpio.gz: %
	@echo "Creating ramdisk $@"
	@rm -rf $<_ramdisk
	@rm -f $@
	@mkdir $<_ramdisk
	@cp $< $<_ramdisk/init
	@cp vfat.img $<_ramdisk/
	@cd $<_ramdisk && find|cpio -o -H newc|gzip -c > ../$@
	@rm -rf $<_ramdisk
	@echo Done

%.img: % %.cpio.gz
	@echo "Creating $@"
	mkbootimg --kernel devices/$</kernel.gz --ramdisk $<.cpio.gz -o $@

mknvfblob: mknvfblob.c $(SHARED_OBJS)
	$(CC) $(CFLAGS) -o $@ $@.c $(SHARED_OBJS) && \
		$(STRIP) $@

nvsign: nvsign.c $(SHARED_OBJS)
	$(CC) $(CFLAGS) -o $@ $@.c $(SHARED_OBJS)

nvencrypt: nvencrypt.c $(SHARED_OBJS)
	$(CC) $(CFLAGS) -o $@ $@.c $(SHARED_OBJS)

nvdecrypt: nvdecrypt.c $(SHARED_OBJS)
	$(CC) $(CFLAGS) -o $@ $@.c $(SHARED_OBJS)

warmboot-h4x: warmboot-h4x.c $(SHARED_OBJS)
	$(CC) $(CFLAGS) -o $@ $@.c $(SHARED_OBJS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

warmboot-tf101.o: warmboot-tf101.S
	arm-linux-androideabi-gcc -O0 -g -Wall -march=armv4t -mtune=arm7tdmi -marm -c -o $@ $<

warmboot-tf101.elf: warmboot-tf101.o warmboot-tf101.lds
	arm-linux-androideabi-ld -T warmboot-tf101.lds -marm -o $@ $<

warmboot-tf101.bin: warmboot-tf101.elf
	arm-linux-androideabi-objcopy -v -O binary $< $@

warmboot-tf101-pwn.o: warmboot-tf101-pwn.S
	arm-linux-androideabi-gcc -O0 -g -Wall -march=armv4t -mtune=arm7tdmi -marm -c -o $@ $<

warmboot-tf101-pwn.elf: warmboot-tf101-pwn.o warmboot-tf101-pwn.lds
	arm-linux-androideabi-ld -T warmboot-tf101-pwn.lds -marm -o $@ $<

warmboot-tf101-pwn.bin: warmboot-tf101-pwn.elf
	arm-linux-androideabi-objcopy -v -O binary $< $@

warmboot-n7.o: warmboot-n7.S
	arm-linux-androideabi-gcc -O0 -g -Wall -march=armv4t -mtune=arm7tdmi -marm -c -o $@ $<

warmboot-n7.elf: warmboot-n7.o warmboot-n7.lds
	arm-linux-androideabi-ld -T warmboot-n7.lds -marm -o $@ $<

warmboot-n7.bin: warmboot-n7.elf
	arm-linux-androideabi-objcopy -v -O binary $< $@

warmboot-n7-pwn.o: warmboot-n7-pwn.S
	arm-linux-androideabi-gcc -O0 -g -Wall -march=armv4t -mtune=arm7tdmi -marm -c -o $@ $<

warmboot-n7-pwn.elf: warmboot-n7-pwn.o warmboot-n7-pwn.lds
	arm-linux-androideabi-ld -T warmboot-n7-pwn.lds -marm -o $@ $<

warmboot-n7-pwn.bin: warmboot-n7-pwn.elf
	arm-linux-androideabi-objcopy -v -O binary $< $@

bins:
	$(MAKE) -C devices


ramdisks: $(DEVICE_RAMDISKS)

bootimgs: $(DEVICE_BOOTIMGS)

clean: 
	@rm -f mknvfblob nvencrypt nvdecrypt nvsign $(SHARED_OBJS) \
		$(DEVICE_TARGETS) $(DEVICE_RAMDISKS) \
		warmboot-tf101.o warmboot-tf101.elf warmboot-tf101.bin \
		warmboot-n7.o warmboot-n7.elf warmboot-n7.bin \
		warmboot-n7-pwn.o warmboot-n7-pwn.elf warmboot-n7-pwn.bin \
		warmboot-h4x
	@make -C devices clean

.PHONY: all clean bins ramdisks
