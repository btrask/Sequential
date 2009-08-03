#ifndef SDI_ASM_STD_PROTOS_H
#define SDI_ASM_STD_PROTOS_H

/* Includeheader

        Name:           SDI_ASM_STD_protos
        Versionstring:  $VER: SDI_ASM_STD_protos.h 1.22 (03.07.2004)
        Author:         SDI
        Distribution:   PD
        Description:    my replacement for standard ANSI functions

 1.9   18.11.96 : converted text into english language, changed C++ comments
        to C ones
 1.10  29.11.96 : added printf
 1.11  06.02.97 : added exit prototype
 1.12  28.03.97 : added some additionally defines (AMIGA_TO_ANSI), added
        vsprintf
 1.13  31.05.97 : fixed SDI_isprintf
 1.14  20.07.97 : changed UBYTE ** to STRPTR *
 1.15  27.07.97 : fixed SDI_printf
 1.16  20.02.98 : made code more compiler independent
 1.17  25.02.98 : added vprintf
 1.18  25.06.98 : now uses SDI_compiler.h
 1.19  29.07.98 : isupper define was missing
 1.20  29.09.01 : added isalpha
 1.21  04.04.04 : added strcat and strncat
 1.22  03.07.04 : changed types to ANSI C types, added const (Ronald van Dijk)
*/

/* These are mainly the normal ANSI C functions, but with an ASM interface.
You can replace them by their normal functions supplied with your compiler,
but do not mix them up (one object file standard, the other one SDI).

differences:
 toupper and tolower: chars (0x41 to 0x5A) and (0xC0 to 0xDE) are upper
  chars (0x61 to 0x79) and (0xE0 to 0xFE) are lower (some more than in ANSI)
 isprint: chars (0x20 to 0x7E) and (0xA0 to 0xFF) are printable
 sprintf and printf: only support exec/RawDoFmt format strings
  and some I do not remember.
 strtoul and strtol: return NULL in errpos, when '\0'-Byte was last scanned
  character. I do not know, if this is really correct for ANSI.

 all: return values may not match ANSI-C ones

printf: Use this function only for programs need to work under OS1.3. For
OS2.0 (and up) programs should use dos.library/amiga.lib Printf function.
*/

#if defined(SDI_TO_ANSI) && defined(__GNUC__)
  #include <string.h>
  #include <stdlib.h>
  #include <stdio.h>
  #include <ctype.h>
#else

#include "SDI_compiler.h"

#ifdef __cplusplus
extern "C" {
#endif

ASM(signed char) SDI_strnicmp( REG(a0,const char *),   /* string 1                    */
                               REG(a1,const char *),   /* string 2                    */
                               REG(d1,unsigned long)); /* highest testlength          */
ASM(signed char) SDI_strncmp(  REG(a0,const char *),   /* string 1                    */
                               REG(a1,const char *),   /* string 2                    */
                               REG(d1,unsigned long)); /* highest testlength          */
ASM(char) SDI_tolower(         REG(d0,char));          /* character to convert        */
ASM(char) SDI_toupper(         REG(d0,char));          /* character to convert        */
ASM(unsigned long) SDI_strlen( REG(a0,const char *));  /* string                      */
ASM(long) SDI_isprint(         REG(d0,unsigned char)); /* character to test           */
ASM(long) SDI_isdigit(         REG(d0,unsigned char)); /* character to test           */
ASM(long) SDI_isxdigit(        REG(d0,unsigned char)); /* character to test           */
ASM(long) SDI_isalnum(         REG(d0,unsigned char)); /* character to test           */
ASM(long) SDI_isalpha(         REG(d0,unsigned char)); /* character to test           */
ASM(long) SDI_isupper(         REG(d0,unsigned char)); /* character to test           */
ASM(unsigned long) SDI_strtoul(REG(a1,const char *),   /* buffer                      */
                               REG(a0,char **),        /* char var for error position */
                               REG(d2,unsigned char)); /* base                        */
ASM(long) SDI_strtol(          REG(a1,const char *),   /* buffer                      */
                               REG(a0,char **),        /* char var for error position */
                               REG(d2,unsigned char)); /* base                        */
ASM(char *) SDI_strncpy(       REG(a1,char *),         /* string 1                    */
                               REG(a0,const char *),   /* string 2                    */
                               REG(d1,unsigned long)); /* highest copy number         */
ASM(void) SDI_memset(          REG(a1,void *),         /* buffer                      */
                               REG(d0,unsigned char),  /* fill character              */
                               REG(d1,unsigned long)); /* number of bytes             */
ASM(char *) SDI_strchr(        REG(a1,const char *),   /* buffer                      */
                               REG(d0,char));          /* character to scan for       */
ASM(void) SDI_vsprintf(        REG(a3,char *),         /* buffer                      */
                               REG(a0,const char *),   /* formatstring                */
                               REG(a1,void *));        /* data                        */
ASM(void) SDI_vprintf(         REG(a0,const char *),   /* formatstring                */
                               REG(a1,void *));        /* data                        */
void SDI_sprintf(char *, const char *, ...);           /* buffer, formatstring, data  */
void SDI_printf(const char *, ...);                    /* formatstring, data          */

#ifdef __cplusplus
}
#endif

#define SDI_stricmp(a,b)        SDI_strnicmp(a,b,~0)
#define SDI_strcmp(a,b)         SDI_strncmp(a,b,~0)
#define SDI_strcpy(a,b)         SDI_strncpy(a,b,~0)
#define SDI_strcat(a,b)         SDI_strncpy(a+SDI_strlen(a),b,~0)
#define SDI_strncat(a,b,c)      SDI_strncpy((a)+SDI_strlen(a),b,c)

/* Set SDI_TO_ANSI if you want to use normal ANSI names. Do not include
the ANSI files stdio.h / stdlib.h ... , because this may result in an error */

#ifdef SDI_TO_ANSI
  #define strnicmp      SDI_strnicmp
  #define strncmp       SDI_strncmp
  #define stricmp       SDI_stricmp
  #define strcmp        SDI_strcmp
  #define tolower       SDI_tolower
  #define toupper       SDI_toupper
  #define strlen        SDI_strlen
  #define isprint       SDI_isprint
  #define isdigit       SDI_isdigit
  #define isxdigit      SDI_isxdigit
  #define isalnum       SDI_isalnum
  #define isalpha       SDI_isalpha
  #define isupper       SDI_isupper
  #define strtoul       SDI_strtoul
  #define strtol        SDI_strtol
  #define strncat       SDI_strncat
  #define strncpy       SDI_strncpy
  #define strcat        SDI_strcat
  #define strcpy        SDI_strcpy
  #define strchr        SDI_strchr
  #define memset        SDI_memset
  #define sprintf       SDI_sprintf
  #define printf        SDI_printf
  #define vsprintf      SDI_vsprintf
  #define vprintf       SDI_vprintf

  extern void exit(int);
  typedef unsigned long size_t;
#endif

/* Use the following with care, as they may collide with ANSI-C Standard
   a lot more, than the above ones. The FILE * parameter of the functions
   is converted into a filehandle of dos.library. Do not mix normal ANSI-C
   and these functions! */

/* These defines are in experimental state !!! */

#ifdef AMIGA_TO_ANSI
  #define memcpy(a,b,c)         CopyMem(b,a,c)
  #define remove(a)             !DeleteFile(a)
  #define rename(a,b)           !Rename(a,b)
  #define putchar(a)            FPutC(Output(),a)
  #define putc(a, b)            FPutC((BPTR) b, a)
  #define getchar()             FGetC(Input())
  #define getc(a)               FGetC((BPTR) a)
  #define ungetc(a,b)           UnGetC((BPTR) b,a)
  #define vprintf(a,b)          VPrintf(a,b)
  #define vfprintf(a,b,c)       VFPrintf((BPTR) a, b, c)
  #define fclose(a)             Close(a)
#endif

#endif /* SDI_TO_ANSI && __GNUC__ */
#endif /* SDI_ASM_STD_PROTOS_H */
