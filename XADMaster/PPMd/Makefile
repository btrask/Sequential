CFLAGS=-std=c99 -g

LDFLAGS=
LIBS=

CC=gcc
LD=gcc

PPMD_C_FILES=Context.c \
             RangeCoder.c \
             SubAllocatorBrimstone.c \
             SubAllocatorVariantG.c \
             SubAllocatorVariantH.c \
             SubAllocatorVariantI.c \
             VariantG.c \
             VariantH.c \
             VariantI.c

SIMPLEDECOMPRESSOR_C_FILES=SimpleDecompressor.c

FUZZER_C_FILES=Fuzzer.c

ALL_C_FILES=$(PPMD_C_FILES) $(SIMPLEDECOMPRESSOR_C_FILES) $(FUZZER_C_FILES)

ALL_OBJS=$(ALL_C_FILES:.c=.o)
SIMPLEDECOMPRESSOR_OBJS=$(SIMPLEDECOMPRESSOR_C_FILES:.c=.o) $(PPMD_C_FILES:.c=.o)
FUZZER_OBJS=$(FUZZER_C_FILES:.c=.o) $(PPMD_C_FILES:.c=.o)

all: SimpleDecompressor Fuzzer

Fuzzer: $(FUZZER_OBJS)
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

SimpleDecompressor: $(SIMPLEDECOMPRESSOR_OBJS)
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

clean:
	rm -rf $(ALL_OBJS) SimpleDecompressor Fuzzer

depend:
	$(CC) -MM $(CFLAGS) $(ALL_C_FILES) >Dependencies.tmp
	sed 's/.*: *\([^ ]*\)\.\([^ ]*\)/\1.o: \1.\2/g' <Dependencies.tmp >Dependencies
	rm Dependencies.tmp

include Dependencies
