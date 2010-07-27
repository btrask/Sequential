// Kludged for XADMaster

#ifndef _RAR_RARCOMMON_
#define _RAR_RARCOMMON_

#include <stdlib.h>
#include <string.h>

#define FALSE 0
#define TRUE  1

#define ENABLE_ACCESS

#define  NM  1024

  #if defined(__BIG_ENDIAN__) && !defined(BIG_ENDIAN)
    #define BIG_ENDIAN
    #undef LITTLE_ENDIAN
  #endif
  #if defined(__i386__) && !defined(LITTLE_ENDIAN)
    #define LITTLE_ENDIAN
    #undef BIG_ENDIAN
  #endif

#if !defined(BIG_ENDIAN) && !defined(_WIN_CE) && defined(_WIN_32)
/* allow not aligned integer access, increases speed in some operations */
#define ALLOW_NOT_ALIGNED_INT
#endif

#define rarmalloc malloc
#define rarcalloc calloc
#define rarrealloc realloc
#define rarfree free
#define rarstrdup strdup

class Unpack;

class ErrorHandler
{
	public:
	void MemoryError();
};

//#include "raros.hpp"
//#include "os.hpp"

//#include "version.hpp"
#include "rartypes.hpp"
#include "rardefs.hpp"
//#include "rarlang.hpp"
#include "int64.hpp"
//#include "unicode.hpp"
//#include "errhnd.hpp"
#include "array.hpp"
//#include "timefn.hpp"
//#include "options.hpp"
//#include "headers.hpp"
//#include "rarfn.hpp"
//#include "pathfn.hpp"
//#include "strfn.hpp"
//#include "strlist.hpp"
//#include "file.hpp"
//#include "sha1.hpp"
//#include "crc.hpp"
//#include "rijndael.hpp"
//#include "crypt.hpp"
//#include "filefn.hpp"
//#include "filestr.hpp"
//#include "find.hpp"
//#include "scantree.hpp"
//#include "savepos.hpp"
#include "getbits.hpp"
//#include "rdwrfn.hpp"
//#include "archive.hpp"
//#include "match.hpp"
//#include "cmddata.hpp"
//#include "filcreat.hpp"
//#include "consio.hpp"
//#include "system.hpp"
//#include "isnt.hpp"
//#include "log.hpp"
//#include "rawread.hpp"
//#include "encname.hpp"
//#include "resource.hpp"
#include "compress.hpp"

#include "rarvm.hpp"
#include "model.hpp"
#include "unpack.hpp"

//#include "extinfo.hpp"
//#include "extract.hpp"
//#include "list.hpp"
//#include "rs.hpp"
//#include "recvol.hpp"
//#include "volume.hpp"
//#include "smallfn.hpp"
//#include "ulinks.hpp"
//#include "global.hpp"

uint CRC(uint StartCRC,const void *Addr,uint Size);

struct RARUnpacker;

class ComprDataIO
{
	public:
	ComprDataIO(RARUnpacker *unpacker);
	int UnpRead(byte *Addr,uint Count);
	void UnpWrite(byte *Addr,uint Count);

	RARUnpacker *unpacker;
};

#endif
