#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <functions.h>
#include <stdio.h>

char *tagName(xadTAGPTR tag) {
  switch (tag->ti_Tag) {
  case TAG_DONE: return "TAG_DONE";
  case TAG_IGNORE: return "TAG_IGNORE";
  case TAG_MORE: return "TAG_MORE";
  case TAG_SKIP: return "TAG_SKIP";
  case XAD_INSIZE: return "XAD_INSIZE";
  case XAD_INFILENAME: return "XAD_INFILENAME";
  case XAD_INFILEHANDLE: return "XAD_INFILEHANDLE";
  case XAD_INMEMORY: return "XAD_INMEMORY";
  case XAD_INHOOK: return "XAD_INHOOK";
  case XAD_INSPLITTED: return "XAD_INSPLITTED";
  case XAD_INDISKARCHIVE: return "XAD_INDISKARCHIVE";
  case XAD_INXADSTREAM: return "XAD_INXADSTREAM";
#ifdef AMIGA
  case XAD_INDEVICE: return "XAD_INDEVICE";
#endif
  case XAD_OUTSIZE: return "XAD_OUTSIZE";
  case XAD_OUTFILENAME: return "XAD_OUTFILENAME";
  case XAD_OUTFILEHANDLE: return "XAD_OUTFILEHANDLE";
  case XAD_OUTMEMORY: return "XAD_OUTMEMORY";
  case XAD_OUTHOOK: return "XAD_OUTHOOK";
#ifdef AMIGA
  case XAD_OUTDEVICE: return "XAD_OUTDEVICE";
#endif
  case XAD_OUTXADSTREAM: return "XAD_OUTXADSTREAM";
  case XAD_OBJNAMESIZE: return "XAD_OBJNAMESIZE";
  case XAD_OBJCOMMENTSIZE: return "XAD_OBJCOMMENTSIZE";
  case XAD_OBJPRIVINFOSIZE: return "XAD_OBJPRIVINFOSIZE";
  case XAD_OBJBLOCKENTRIES: return "XAD_OBJBLOCKENTRIES";
  case XAD_NOEXTERN: return "XAD_NOEXTERN";
  case XAD_PASSWORD: return "XAD_PASSWORD";
  case XAD_ENTRYNUMBER: return "XAD_ENTRYNUMBER";
  case XAD_PROGRESSHOOK: return "XAD_PROGRESSHOOK";
  case XAD_OVERWRITE: return "XAD_OVERWRITE";
  case XAD_MAKEDIRECTORY: return "XAD_MAKEDIRECTORY";
#ifdef AMIGA
  case XAD_IGNOREGEOMETRY: return "XAD_IGNOREGEOMETRY";
#endif
  case XAD_LOWCYLINDER: return "XAD_LOWCYLINDER";
  case XAD_HIGHCYLINDER: return "XAD_HIGHCYLINDER";
#ifdef AMIGA
  case XAD_VERIFY: return "XAD_VERIFY";
#endif
  case XAD_NOKILLPARTIAL: return "XAD_NOKILLPARTIAL";
#ifdef AMIGA
  case XAD_FORMAT: return "XAD_FORMAT";
  case XAD_USESECTORLABELS: return "XAD_USESECTORLABELS";
#endif
  case XAD_IGNOREFLAGS: return "XAD_IGNOREFLAGS";
  case XAD_ONLYFLAGS: return "XAD_ONLYFLAGS";
  case XAD_DATEUNIX: return "XAD_DATEUNIX";
  case XAD_DATEAMIGA: return "XAD_DATEAMIGA";
  case XAD_DATEDATESTAMP: return "XAD_DATEDATESTAMP";
  case XAD_DATEXADDATE: return "XAD_DATEXADDATE";
  case XAD_DATECLOCKDATA: return "XAD_DATECLOCKDATA";
  case XAD_DATECURRENTTIME: return "XAD_DATECURRENTTIME";
  case XAD_DATEMSDOS: return "XAD_DATEMSDOS";
  case XAD_DATEMAC: return "XAD_DATEMAC";
  case XAD_DATECPM: return "XAD_DATECPM";
  case XAD_DATECPM2: return "XAD_DATECPM2";
  case XAD_DATEISO9660: return "XAD_DATEISO9660";
  case XAD_GETDATEUNIX: return "XAD_GETDATEUNIX";
  case XAD_GETDATEAMIGA: return "XAD_GETDATEAMIGA";
#ifdef AMIGA
  case XAD_GETDATEDATESTAMP: return "XAD_GETDATEDATESTAMP";
#endif
  case XAD_GETDATEXADDATE: return "XAD_GETDATEXADDATE";
#ifdef AMIGA
  case XAD_GETDATECLOCKDATA: return "XAD_GETDATECLOCKDATA";
#endif
  case XAD_GETDATEMSDOS: return "XAD_GETDATEMSDOS";
  case XAD_GETDATEMAC: return "XAD_GETDATEMAC";
  case XAD_GETDATECPM: return "XAD_GETDATECPM";
  case XAD_GETDATECPM2: return "XAD_GETDATECPM2";
  case XAD_GETDATEISO9660: return "XAD_GETDATEISO9660";
  case XAD_MAKEGMTDATE: return "XAD_MAKEGMTDATE";
  case XAD_MAKELOCALDATE: return "XAD_MAKELOCALDATE";
  case XAD_USESKIPINFO: return "XAD_USESKIPINFO";
  case XAD_SECTORLABELS: return "XAD_SECTORLABELS";
  case XAD_GETCRC16: return "XAD_GETCRC16";
  case XAD_GETCRC32: return "XAD_GETCRC32";
  case XAD_CRC16ID: return "XAD_CRC16ID";
  case XAD_CRC32ID: return "XAD_CRC32ID";
  case XAD_PROTAMIGA: return "XAD_PROTAMIGA";
  case XAD_PROTUNIX: return "XAD_PROTUNIX";
  case XAD_PROTMSDOS: return "XAD_PROTMSDOS";
  case XAD_PROTFILEINFO: return "XAD_PROTFILEINFO";
  case XAD_GETPROTAMIGA: return "XAD_GETPROTAMIGA";
  case XAD_GETPROTUNIX: return "XAD_GETPROTUNIX";
  case XAD_GETPROTMSDOS: return "XAD_GETPROTMSDOS";
  case XAD_GETPROTFILEINFO: return "XAD_GETPROTFILEINFO";
  case XAD_STARTCLIENT: return "XAD_STARTCLIENT";
  case XAD_NOEMPTYERROR: return "XAD_NOEMPTYERROR";
  case XAD_WASERROR: return "XAD_WASERROR";
  case XAD_ARCHIVEINFO: return "XAD_ARCHIVEINFO";
  case XAD_ERRORCODE: return "XAD_ERRORCODE";
  case XAD_EXTENSION: return "XAD_EXTENSION";
  case XAD_SETINPOS: return "XAD_SETINPOS";
  case XAD_INSERTDIRSFIRST: return "XAD_INSERTDIRSFIRST";
  case XAD_PATHSEPERATOR: return "XAD_PATHSEPERATOR";
  case XAD_CHARACTERSET: return "XAD_CHARACTERSET";
  case XAD_STRINGSIZE: return "XAD_STRINGSIZE";
  case XAD_CSTRING: return "XAD_CSTRING";
  case XAD_PSTRING: return "XAD_PSTRING";
  case XAD_XADSTRING: return "XAD_XADSTRING";
  case XAD_ADDPATHSEPERATOR: return "XAD_ADDPATHSEPERATOR";
  case XAD_NOLEADINGPATH: return "XAD_NOLEADINGPATH";
  case XAD_NOTRAILINGPATH: return "XAD_NOTRAILINGPATH";
  case XAD_MASKCHARACTERS: return "XAD_MASKCHARACTERS";
  case XAD_MASKINGCHAR: return "XAD_MASKINGCHAR";
  case XAD_REQUIREDBUFFERSIZE: return "XAD_REQUIREDBUFFERSIZE";
  }
  return "unknown";
}

void myFuncA(struct xadArchiveInfo *ai, xadTAGPTR tags) {
  xadTag tag;
  do {
    if (tags->ti_Tag & TAG_PTR) {
      printf("%s: %p\n", tagName(tags), tags->ti_Data & 0xFFFFFFFF);
    }
    else if (tags->ti_Tag & TAG_SIZ) {
      printf("%s: %lld\n", tagName(tags), tags->ti_Data);
    }
    else {
      printf("%s: %d\n", tagName(tags), (xadINT32) tags->ti_Data);
    }
    tag = tags->ti_Tag;
    tags++;
  } while ((tag != TAG_DONE) && (tag != TAG_MORE));
}

#define XAD_MAX_CONVTAGS (64)
void myFunc(struct xadArchiveInfo *ai, xadTag tag, ...) {
  XAD_CONVTAGS
  myFuncA(ai, &convtags[0]);
}


int main() {
  char *hi = "hi";
  xadSize offset = 100000000ULL;
  puts("test 1");
  myFunc(NULL,
	 TAG_IGNORE, 1234,
	 TAG_SKIP, 3,
	 XAD_INFILENAME, hi,
	 XAD_NOEXTERN, 65537,
	 XAD_SETINPOS, offset,
	 TAG_MORE, hi,
	 TAG_SKIP, 9,
	 TAG_SKIP, 9,
	 TAG_SKIP, 9);

  puts("test 2");
  myFunc(NULL,
	 TAG_SKIP, 3,
	 XAD_INFILENAME, hi,
	 XAD_SETINPOS, offset,
	 TAG_IGNORE, 1234,
	 XAD_NOEXTERN, 65537,
	 TAG_DONE);

  puts("test 3");
  myFunc(NULL,
	 TAG_SKIP, 1,
	 TAG_SKIP, 2,
	 TAG_SKIP, 3,
	 TAG_SKIP, 4,
	 TAG_SKIP, 5,
	 TAG_SKIP, 6,
	 TAG_SKIP, 7,
	 TAG_SKIP, 8,
	 TAG_SKIP, 9,
	 TAG_SKIP, 10,
	 TAG_SKIP, 11,
	 TAG_SKIP, 12,
	 TAG_SKIP, 13,
	 TAG_SKIP, 14,
	 TAG_SKIP, 15,
	 TAG_SKIP, 16,
	 TAG_SKIP, 17,
	 TAG_SKIP, 18,
	 TAG_SKIP, 19,
	 TAG_SKIP, 20,
	 TAG_SKIP, 21,
	 TAG_SKIP, 22,
	 TAG_SKIP, 23,
	 TAG_SKIP, 24,
	 TAG_SKIP, 25,
	 TAG_SKIP, 26,
	 TAG_SKIP, 27,
	 TAG_SKIP, 28,
	 TAG_SKIP, 29,
	 TAG_SKIP, 30,
	 TAG_SKIP, 31,
	 TAG_SKIP, 32,
	 TAG_SKIP, 33,
	 TAG_SKIP, 34,
	 TAG_SKIP, 35,
	 TAG_SKIP, 36,
	 TAG_SKIP, 37,
	 TAG_SKIP, 38,
	 TAG_SKIP, 39,
	 TAG_SKIP, 40,
	 TAG_SKIP, 41,
	 TAG_SKIP, 42,
	 TAG_SKIP, 43,
	 TAG_SKIP, 44,
	 TAG_SKIP, 45,
	 TAG_SKIP, 46,
	 TAG_SKIP, 47,
	 TAG_SKIP, 48,
	 TAG_SKIP, 49,
	 TAG_SKIP, 50,
	 TAG_SKIP, 51,
	 TAG_SKIP, 52,
	 TAG_SKIP, 53,
	 TAG_SKIP, 54,
	 TAG_SKIP, 55,
	 TAG_SKIP, 56,
	 TAG_SKIP, 57,
	 TAG_SKIP, 58,
	 TAG_SKIP, 59,
	 TAG_SKIP, 60,
	 TAG_SKIP, 61,
	 TAG_SKIP, 62,
	 TAG_SKIP, 63,
	 TAG_SKIP, 64,
	 TAG_SKIP, 65,
	 TAG_SKIP, 66,
	 TAG_SKIP, 67,
	 TAG_SKIP, 68,
	 TAG_SKIP, 69,
	 TAG_SKIP, 70,
	 TAG_DONE);

  return 0;
}
