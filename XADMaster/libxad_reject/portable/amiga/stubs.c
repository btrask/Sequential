#ifdef NO_INLINE_STDARG

#include "stubs.h"

/* XPK stubs */

LONG _xpkExamineTags (APTR XpkBase,struct XpkFib *fib,Tag tag,...)
{ return XpkExamine(fib,(struct TagItem *)&tag); }

LONG _xpkUnpackTags(APTR XpkBase,ULONG tag,...)
{ return XpkUnpack((struct TagItem *)&tag); }

/* XAD stubs */

xadERROR _xadAddDiskEntry(APTR xadMasterBase,struct xadDiskInfo *di,struct xadArchiveInfo *ai,xadTag tag,...)
{ return xadAddDiskEntryA(di,ai,(xadTAGPTR)&tag); }

xadERROR _xadAddFileEntry(APTR xadMasterBase,struct xadFileInfo *fi,struct xadArchiveInfo *ai,xadTag tag,...)
{ return xadAddFileEntryA(fi,ai,(xadTAGPTR)&tag); }

xadPTR _xadAllocObject(APTR xadMasterBase,xadUINT32 type,xadTag tag,...)
{ return xadAllocObjectA(type,(xadTAGPTR)&tag); }

xadERROR _xadConvertDates(APTR xadMasterBase,xadTag tag,...)
{ return xadConvertDatesA((xadTAGPTR)&tag); }

xadSTRPTR _xadConvertName(APTR xadMasterBase,xadUINT32 charset,xadTag tag,...)
{ return xadConvertNameA(charset,(xadTAGPTR)&tag); }

xadERROR _xadConvertProtection(APTR xadMasterBase,xadTag tag,...)
{ return xadConvertProtectionA((xadTAGPTR)&tag); }

xadERROR _xadDiskUnArc(APTR xadMasterBase,struct xadArchiveInfo *ai,xadTag tag,...)
{ return xadDiskUnArcA(ai,(xadTAGPTR)&tag); }

void _xadFreeHookAccess(APTR xadMasterBase,struct xadArchiveInfo *ai,xadTag tag,...)
{ xadFreeHookAccessA(ai,(xadTAGPTR)&tag); }

xadSTRPTR _xadGetDefaultName(APTR xadMasterBase,xadTag tag,...)
{ return xadGetDefaultNameA((xadTAGPTR)&tag); }

xadERROR _xadHookTagAccess(APTR xadMasterBase,xadUINT32 command,xadSignSize data,xadPTR buffer,struct xadArchiveInfo *ai,xadTag tag,...)
{ return xadHookTagAccessA(command,data,buffer,ai,(xadTAGPTR)&tag); }

#ifdef DEBUG

LONG _Printf(APTR DOSBase,CONST_STRPTR fmt,...)
{ CONST_STRPTR *p=&fmt; return VPrintf(*p,p+1); }

#endif /* DEBUG */

#endif /* NO_INLINE_STDARG */

/* the following functions are here to make -mregparm work */

/* ctype (not required;) */

//void isxdigit() {}
//void isdigit() {}

/* stricmp */

#include <ctype.h>

int stricmp(const char *s1,const char *s2)
{ unsigned char c1,c2;
  int r;
  for(;;) {
    c1=*s1++;
    if (isupper(c1))
      c1+='a'-'A';
    c2=*s2;
    if (isupper(c2))
      c2+='a'-'A';
    if ((r=(char)c1-(char)c2)!=0)
      break;
    if (!*s2++)
      break;
  }
  return r;
}

/* bcopy */

void
#if __GNUC__ < 3
__stdargs
#endif
bcopy(const void *s1,void *s2,unsigned int n)
{ if(n) do;while(*((char *)s2)=*((char *)s1),s1=((char *)s1)+sizeof(char),s2=((char *)s2)+sizeof(char),--n); }

#if defined(DEBUG) || defined(DEBUGRESOURCE)

/* debug */

#include <exec/types.h>

LONG __stdargs KPutChar(LONG c) {
  register LONG ret asm("d0");
  register void *const base __asm("a6") = *(void **)4L;
  register LONG arg asm("d0") = c;
  __asm __volatile("jsr a6@(-0x204:W)"
  : "=r" (ret) : "r" (base), "rf"(arg) : "d1", "a0", "a1");
  return ret;
}

LONG __stdargs DPutChar(LONG c) {
  return 0;
}

#endif
