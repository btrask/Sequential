CFLAGS=-std=c99 -g

LDFLAGS=
LIBS=

CC=gcc
LD=gcc

ALL_C_FILES=ArithmeticDecoder.c \
            Decompressor.c \
            JPEG.c \
            RawDecoder.c \
            Test.c \
            ../lzma/LzmaDec.c \

RAWDECODER_C_FILES=ArithmeticDecoder.c \
                   Decompressor.c \
                   JPEG.c \
                   RawDecoder.c \
                   ../lzma/LzmaDec.c \

TEST_C_FILES=ArithmeticDecoder.c \
             Test.c

ALL_OBJS=$(ALL_C_FILES:.c=.o)
RAWDECODER_OBJS=$(RAWDECODER_C_FILES:.c=.o)
TEST_OBJS=$(TEST_C_FILES:.c=.o)

all: RawDecoder Test

RawDecoder: $(RAWDECODER_OBJS)
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

Test: $(TEST_OBJS)
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

clean:
	rm -rf $(ALL_OBJS) RawDecoder Test

depend:
	$(CC) -MM $(CFLAGS) $(ALL_C_FILES) >Dependencies.tmp
	sed 's/.*: *\([^ ]*\)\.\([^ ]*\)/\1.o: \1.\2/g' <Dependencies.tmp >Dependencies
	rm Dependencies.tmp

include Dependencies

