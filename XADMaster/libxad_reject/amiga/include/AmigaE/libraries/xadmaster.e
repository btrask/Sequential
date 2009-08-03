/*  $Id: xadmaster.e,v 1.3 2005/06/23 15:47:23 stoecker Exp $
    xadmaster.library defines and structures

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk Stöcker <soft@dstoecker.de>

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

OPT MODULE
OPT EXPORT
OPT PREPROCESS

CONST XADFALSE =       0
CONST XADTRUE =        1
CONST XADMEMF_ANY =    $00000000
CONST XADMEMF_CLEAR =  $00010000
CONST XADMEMF_PUBLIC = $00000001

MODULE 'exec/libraries'    -> Import definition of lib
MODULE 'exec/execbase'     -> Import definition of execbase
MODULE 'dos/dosextens'     -> Import definition of dosbase
MODULE 'utility/utility'   -> Import definition of utilitybase
MODULE 'utility/tagitem'   -> Import definition of TAG_USER

#define XADNAME 'xadmaster.library'

CONST TAG_PTR = TAG_USER
CONST TAG_INT = TAG_USER
CONST TAG_SIZ = TAG_USER

/* NOTE: Nearly all structures need to be allocated using the
   xadAllocObject function. */

/************************************************************************
*                                                                       *
*    library base structure                                             *
*                                                                       *
************************************************************************/

OBJECT xadMasterBase
    xmb_LibNode:lib
    xmb_SysBase:PTR TO execbase
    xmb_DOSBase:PTR TO doslibrary
    xmb_UtilityBase:PTR TO utilitybase
    xmb_RecogSize:LONG          /* read only */
    xmb_DefaultName:PTR TO CHAR /* name for XADFIF_NOFILENAME (V6) */
ENDOBJECT

/************************************************************************
*                                                                       *
*    tag-function call flags                                            *
*                                                                       *
************************************************************************/

/* input tags for xadGetInfo, only one can be specified per call */
CONST XAD_INSIZE =              TAG_USER+  1 /* input data size */
CONST XAD_INFILENAME =          TAG_USER+  2
CONST XAD_INFILEHANDLE =        TAG_USER+  3
CONST XAD_INMEMORY =            TAG_USER+  4
CONST XAD_INHOOK =              TAG_USER+  5
CONST XAD_INSPLITTED =          TAG_USER+  6 /* (V2) */
CONST XAD_INDISKARCHIVE =       TAG_USER+  7 /* (V4) */
CONST XAD_INXADSTREAM =         TAG_USER+  8 /* (V8) */
CONST XAD_INDEVICE =            TAG_USER+  9 /* (V11) */

/* output tags, only one can be specified per call, xadXXXXUnArc */
CONST XAD_OUTSIZE =             TAG_USER+ 10 /* output data size */
CONST XAD_OUTFILENAME =         TAG_USER+ 11
CONST XAD_OUTFILEHANDLE =       TAG_USER+ 12
CONST XAD_OUTMEMORY =           TAG_USER+ 13
CONST XAD_OUTHOOK =             TAG_USER+ 14
CONST XAD_OUTDEVICE =           TAG_USER+ 15
CONST XAD_OUTXADSTREAM =        TAG_USER+ 16 /* (V8) */

/* object allocation tags for xadAllocObjectA */
CONST XAD_OBJNAMESIZE =         TAG_USER+ 20 /* XADOBJ_FILEINFO, size of needed name space */
CONST XAD_OBJCOMMENTSIZE =      TAG_USER+ 21 /* XADOBJ_FILEINFO, size of needed comment space */
CONST XAD_OBJPRIVINFOSIZE =     TAG_USER+ 22 /* XADOBJ_FILEINFO & XADOBJ_DISKINFO, self use size */
CONST XAD_OBJBLOCKENTRIES =     TAG_USER+ 23 /* XADOBJ_DISKINFO, number of needed entries */

/* tags for xadGetInfo, xadFileUnArc and xadDiskUnArc */
CONST XAD_NOEXTERN =            TAG_USER+ 50 /* do not use extern clients */
CONST XAD_PASSWORD =            TAG_USER+ 51 /* password when needed */
CONST XAD_ENTRYNUMBER =         TAG_USER+ 52 /* number of wanted entry */
CONST XAD_PROGRESSHOOK =        TAG_USER+ 53 /* the progress hook */
CONST XAD_OVERWRITE =           TAG_USER+ 54 /* overwrite file ? */
CONST XAD_MAKEDIRECTORY =       TAG_USER+ 55 /* create directory tree */
CONST XAD_IGNOREGEOMETRY =      TAG_USER+ 56 /* ignore drive geometry ? */
CONST XAD_LOWCYLINDER =         TAG_USER+ 57 /* lowest cylinder */
CONST XAD_HIGHCYLINDER =        TAG_USER+ 58 /* highest cylinder */
CONST XAD_VERIFY =              TAG_USER+ 59 /* verify for disk hook */
CONST XAD_NOKILLPARTIAL =       TAG_USER+ 60 /* do not delete partial/corrupt files (V3.3) */
CONST XAD_FORMAT =              TAG_USER+ 61 /* format output device (V5) */
CONST XAD_USESECTORLABELS =     TAG_USER+ 62 /* sector labels are stored on disk (V9) */
CONST XAD_IGNOREFLAGS =         TAG_USER+ 63 /* ignore the client, if certain flags are set (V11) */
CONST XAD_ONLYFLAGS =           TAG_USER+ 64 /* ignore the client, if certain flags are NOT set (V11) */

/* input tags for xadConvertDates, only one can be passed */
CONST XAD_DATEUNIX =            TAG_USER+ 70 /* unix date variable */
CONST XAD_DATEAMIGA =           TAG_USER+ 71 /* Amiga date variable */
CONST XAD_DATEDATESTAMP =       TAG_USER+ 72 /* Amiga struct DateStamp */
CONST XAD_DATEXADDATE =         TAG_USER+ 73 /* struct xadDate */
CONST XAD_DATECLOCKDATA =       TAG_USER+ 74 /* Amiga struct ClockData */
CONST XAD_DATECURRENTTIME =     TAG_USER+ 75 /* input is system time */
CONST XAD_DATEMSDOS =           TAG_USER+ 76 /* MS-DOS packed format (V2) */
CONST XAD_DATEMAC =             TAG_USER+ 77 /* Mac date variable (V8) */
CONST XAD_DATECPM =             TAG_USER+ 78 /* CP/M data structure (V10) */
CONST XAD_DATECPM2 =            TAG_USER+ 79 /* CP/M data structure type 2 (V10) */
CONST XAD_DATEISO9660 =         TAG_USER+300 /* ISO9660 date structure (V11) */

/* output tags, there can be specified multiple tags for one call */
CONST XAD_GETDATEUNIX =         TAG_USER+ 80 /* unix date variable */
CONST XAD_GETDATEAMIGA =        TAG_USER+ 81 /* Amiga date variable */
CONST XAD_GETDATEDATESTAMP =    TAG_USER+ 82 /* Amiga struct DateStamp */
CONST XAD_GETDATEXADDATE =      TAG_USER+ 83 /* struct xadDate */
CONST XAD_GETDATECLOCKDATE =    TAG_USER+ 84 /* Amiga struct ClockData */
CONST XAD_GETDATEMSDOS =        TAG_USER+ 86 /* MS-DOS packed format (V2) */
CONST XAD_GETDATEMAC =          TAG_USER+ 87 /* Mac date variable (V8) */
CONST XAD_GETDATECPM =          TAG_USER+ 88 /* CP/M data structure (V10) */
CONST XAD_GETDATECPM2 =         TAG_USER+ 89 /* CP/M data structure type 2 (V10) */
CONST XAD_GETDATEISO9660 =      TAG_USER+320 /* ISO9660 date structure (V11) */

/* following tags need locale.library to be installed */
CONST XAD_MAKEGMTDATE =         TAG_USER+ 90 /* make local to GMT time */
CONST XAD_MAKELOCALDATE =       TAG_USER+ 91 /* make GMT to local time */

/* tags for xadHookTagAccess (V3) */
CONST XAD_USESKIPINFO =         TAG_USER+104 /* the hook uses xadSkipInfo (V3) */
CONST XAD_SECTORLABELS =        TAG_USER+105 /* pass sector labels with XADAC_WRITE (V9) */

CONST XAD_GETCRC16 =            TAG_USER+120 /* pointer to UWORD value (V3) */
CONST XAD_GETCRC32 =            TAG_USER+121 /* pointer to ULONG value (V3) */

CONST XAD_CRC16ID =             TAG_USER+130 /* ID for crc calculation (V3) */
CONST XAD_CRC32ID =             TAG_USER+131 /* ID for crc calculation (V3) */

/* tags for xadConvertProtection (V4) */
CONST XAD_PROTAMIGA =           TAG_USER+160 /* Amiga type protection bits (V4) */
CONST XAD_PROTUNIX =            TAG_USER+161 /* protection bits in UNIX mode (V4) */
CONST XAD_PROTMSDOS =           TAG_USER+162 /* MSDOS type protection bits (V4) */
CONST XAD_PROTFILEINFO =        TAG_USER+163 /* input is a xadFileInfo structure (V11) */

CONST XAD_GETPROTAMIGA =        TAG_USER+170 /* return Amiga protection bits (V4) */
CONST XAD_GETPROTUNIX =         TAG_USER+171 /* return UNIX protection bits (V11) */
CONST XAD_GETPROTMSDOS =        TAG_USER+172 /* return MSDOS protection bits (V11) */
CONST XAD_GETPROTFILEINFO =     TAG_USER+173 /* fill xadFileInfo protection fields (V11) */

/* tags for xadGetDiskInfo (V7) */
CONST XAD_STARTCLIENT =         TAG_USER+180 /* the client to start with (V7) */
CONST XAD_NOEMPTYERROR =        TAG_USER+181 /* do not create XADERR_EMPTY (V8) */

/* tags for xadFreeHookAccess (V8) */
CONST XAD_WASERROR =            TAG_USER+190 /* error occured, call abort method (V8) */

/* tags for miscellaneous stuff */
CONST XAD_ARCHIVEINFO =         TAG_USER+200 /* xadArchiveInfo for stream hooks (V8) */
CONST XAD_ERRORCODE =           TAG_USER+201 /* error code of function (V12) */
CONST XAD_EXTENSION =           TAG_USER+202 /* argument for xadGetDefaultName() (V13) */

/* tags for xadAddFileEntry and xadAddDiskEntry (V10) */
CONST XAD_SETINPOS =            TAG_USER+240 /* set xai_InPos after call (V10) */
CONST XAD_INSERTDIRSFIRST =     TAG_USER+241 /* insert dirs at list start (V10) */

/* tags for xadConvertName (V12) */
CONST XAD_PATHSEPERATOR =       TAG_USER+260 /* UWORD *, default is {'/','\\',0} in source charset (V12) */
CONST XAD_CHARACTERSET =        TAG_USER+261 /* the characterset of string (V12) */
CONST XAD_STRINGSIZE =          TAG_USER+262 /* maximum size of following (V12) */
CONST XAD_CSTRING =             TAG_USER+263 /* zero-terminated string (V12) */
CONST XAD_PSTRING =             TAG_USER+264 /* lengthed Pascal string (V12) */
CONST XAD_XADSTRING =           TAG_USER+265 /* an xad string (V12) */
CONST XAD_ADDPATHSEPERATOR =    TAG_USER+266 /* default is TRUE (V12) */

/* tags for xadGetFilename (V12) */
CONST XAD_NOLEADINGPATH =       TAG_USER+280 /* default is FALSE (V12) */
CONST XAD_NOTRAILINGPATH =      TAG_USER+281 /* default is FALSE (V12) */
CONST XAD_MASKCHARACTERS =      TAG_USER+282 /* default are #?()[]~%*:|",1-31,127-160 (V12) */
CONST XAD_MASKINGCHAR =         TAG_USER+283 /* default is '_' (V12) */
CONST XAD_REQUIREDBUFFERSIZE =  TAG_USER+284 /* pointer which should hold buf size (V12) */


/* Places 300-339 used for dates! */

/************************************************************************
*                                                                       *
*    objects for xadAllocObjectA                                        *
*                                                                       *
************************************************************************/

CONST XADOBJ_ARCHIVEINFO =      $0001 /* struct xadArchiveInfo */
CONST XADOBJ_FILEINFO =         $0002 /* struct xadFileInfo */
CONST XADOBJ_DISKINFO =         $0003 /* struct xadDiskInfo */
CONST XADOBJ_HOOKPARAM =        $0004 /* struct HookParam */
CONST XADOBJ_DEVICEINFO =       $0005 /* struct xadDeviceInfo */
CONST XADOBJ_PROGRESSINFO =     $0006 /* struct xadProgressInfo */
CONST XADOBJ_TEXTINFO =         $0007 /* struct xadTextInfo */
CONST XADOBJ_SPLITFILE =        $0008 /* struct xadSplitFile (V2) */
CONST XADOBJ_SKIPINFO =         $0009 /* struct xadSkipInfo (V3) */
CONST XADOBJ_IMAGEINFO =        $000A /* struct xadImageInfo (V4) */
CONST XADOBJ_SPECIAL =          $000B /* struct xadSpecial (V11) */

/* result type of xadAllocVec */
CONST XADOBJ_MEMBLOCK =         $0100 /* memory of requested size and type */
/* private type */
CONST XADOBJ_STRING =           $0101 /* a typed XAD string (V12) */

/************************************************************************
*                                                                       *
*    modes for xadCalcCRC126 and xadCalcCRC32                           *
*                                                                       *
************************************************************************/

CONST XADCRC16_ID1 =            $A001
CONST XADCRC32_ID1 =            $EDB88320

/************************************************************************
*                                                                       *
*    hook related stuff                                                 *
*                                                                       *
************************************************************************/

CONST XADHC_READ =             1 /* read data into buffer */
CONST XADHC_WRITE =            2 /* write buffer data to file/memory */
CONST XADHC_SEEK =             3 /* seek in file */
CONST XADHC_INIT =             4 /* initialize the hook */
CONST XADHC_FREE =             5 /* end up hook work, free stuff */
CONST XADHC_ABORT =            6 /* an error occured, delete partial stuff */
CONST XADHC_FULLSIZE =         7 /* complete input size is needed */
CONST XADHC_IMAGEINFO =        8 /* return disk image info (V4) */

OBJECT xadHookParam
    xhp_Command:LONG
    xhp_CommandData:LONG
    xhp_BufferPtr:PTR TO CHAR
    xhp_BufferSize:LONG
    xhp_DataPos:LONG            /* current seek position */
    xhp_PrivatePtr:PTR TO CHAR
    xhp_TagList:PTR TO CHAR     /* allows to transport tags to hook (V9) */
ENDOBJECT

/* xadHookAccess commands */
CONST XADAC_READ =              10 /* get data */
CONST XADAC_WRITE =             11 /* write data */
CONST XADAC_COPY =              12 /* copy input to output */
CONST XADAC_INPUTSEEK =         13 /* seek in input file */
CONST XADAC_OUTPUTSEEK =        14 /* seek in output file */

/************************************************************************
*                                                                       *
*    support structures                                                 *
*                                                                       *
************************************************************************/

/* Own date structure to cover all possible dates in a human friendly
   format. xadConvertDates may be used to convert between different date
   structures and variables. */
OBJECT xadDate
    xd_Micros:LONG      /* values 0 to 999999     */
    xd_Year:LONG        /* values 1 to 2147483648 */
    xd_Month:CHAR       /* values 1 to 12         */
    xd_WeekDay:CHAR     /* values 1 to 7          */
    xd_Day:CHAR         /* values 1 to 31         */
    xd_Hour:CHAR        /* values 0 to 23         */
    xd_Minute:CHAR      /* values 0 to 59         */
    xd_Second:CHAR      /* values 0 to 59         */
ENDOBJECT

CONST XADDAY_MONDAY =           1 /* monday is the first day and */
CONST XADDAY_TUESDAY =          2
CONST XADDAY_WEDNESDAY =        3
CONST XADDAY_THURSDAY =         4
CONST XADDAY_FRIDAY =           5
CONST XADDAY_SATURDAY =         6
CONST XADDAY_SUNDAY =           7 /* sunday the last day of a week */

OBJECT xadDeviceInfo            /* for XAD_OUTDEVICE tag */
    xdi_DeviceName:PTR TO CHAR  /* name of device */
    xdi_Unit:LONG               /* unit of device */
    xdi_DOSName:PTR TO CHAR     /* instead of Device+Unit, dos name without ':' */
ENDOBJECT

OBJECT xadSplitFile             /* for XAD_INSPLITTED */
    xsf_Next:PTR TO xadSplitFile
    xsf_Type:LONG               /* XAD_INFILENAME, XAD_INFILEHANDLE, XAD_INMEMORY, XAD_INHOOK */
    xsf_Size:LONG               /* necessary for XAD_INMEMORY, useful for others */
    xsf_Data:LONG               /* FileName, Filehandle, Hookpointer or Memory */
ENDOBJECT

OBJECT xadSkipInfo
    xsi_Next:PTR TO xadSkipInfo
    xsi_Position:LONG           /* position, where it should be skipped */
    xsi_SkipSize:LONG           /* size to skip */
ENDOBJECT

OBJECT xadImageInfo             /* for XADHC_IMAGEINFO */
    xii_SectorSize:LONG         /* usually 512 */
    xii_FirstSector:LONG        /* of the image file */
    xii_NumSectors:LONG         /* of the image file */
    xii_TotalSectors:LONG       /* of this device type */
ENDOBJECT
/* If the image file holds total data of disk xii_TotalSectors equals
   xii_NumSectors and xii_FirstSector is zero. Addition of xii_FirstSector
   and xii_NumSectors cannot exceed xii_TotalSectors value!
*/

/************************************************************************
*                                                                       *
*    system information structure                                       *
*                                                                       *
************************************************************************/

OBJECT xadSystemInfo
    xsi_Version:INT                     /* master library version */
    xsi_Revision:INT                    /* master library revision */
    xsi_RecogSize:LONG                  /* size for recognition */
ENDOBJECT

/************************************************************************
*                                                                       *
*    information structures                                             *
*                                                                       *
************************************************************************/

OBJECT xadArchiveInfo
    xai_Client:PTR TO xadClient         /* pointer to unarchiving client */
    xai_PrivateClient:PTR TO CHAR       /* private client data */
    xai_Password:PTR TO CHAR            /* password for crypted archives */
    xai_Flags:LONG                      /* read only XADAIF_ flags */
    xai_LowCyl:LONG                     /* lowest cylinder to unarchive */
    xai_HighCyl:LONG                    /* highest cylinder to unarchive */
    xai_InPos:LONG                      /* input position, read only */
    xai_InSize:LONG                     /* input size, read only */
    xai_OutPos:LONG                     /* output position, read only */
    xai_OutSize:LONG                    /* output file size, read only */
    xai_FileInfo:PTR TO xadFileInfo     /* data pointer for file arcs */
    xai_DiskInfo:PTR TO xadDiskInfo     /* data pointer for disk arcs */
    xai_CurFile:PTR TO xadFileInfo      /* data pointer for current file arc */
    xai_CurDisk:PTR TO xadDiskInfo      /* data pointer for current disk arc */
    xai_LastError:LONG                  /* last error, when XADAIF_FILECORRUPT (V2) */
    xai_MultiVolume:PTR TO LONG         /* array of start offsets from parts (V2) */
    xai_SkipInfo:PTR TO xadSkipInfo     /* linked list of skip entries (V3) */
    xai_ImageInfo:PTR TO xadImageInfo   /* for filesystem clients (V5) */
    xai_InName:PTR TO CHAR              /* Input archive name if available (V7) */
ENDOBJECT
/* This structure is nearly complete private to either xadmaster or its
clients. An application program may access for reading only xai_Client,
xai_Flags, xai_FileInfo and xai_DiskInfo. For xai_Flags only XADAIF_CRYPTED
and XADAIF_FILECORRUPT are useful. All the other stuff is private and should
not be accessed! */

CONST XADAIB_CRYPTED =          0  /* archive entries are encrypted */
CONST XADAIB_FILECORRUPT =      1  /* file is corrupt, but valid entries are in the list */
CONST XADAIB_FILEARCHIVE =      2  /* unarchive file entry */
CONST XADAIB_DISKARCHIVE =      3  /* unarchive disk entry */
CONST XADAIB_OVERWRITE =        4  /* overwrite the file (PRIVATE) */
CONST XADAIB_MAKEDIRECTORY =    5  /* create directory when missing (PRIVATE) */
CONST XADAIB_IGNOREGEOMETRY =   6  /* ignore drive geometry (PRIVATE) */
CONST XADAIB_VERIFY =           7  /* verify is turned on for disk hook (PRIVATE) */
CONST XADAIB_NOKILLPARTIAL =    8  /* do not delete partial files (PRIVATE) */
CONST XADAIB_DISKIMAGE =        9  /* is disk image extraction (V5) */
CONST XADAIB_FORMAT =           10 /* format in disk hook (PRIVATE) */
CONST XADAIB_NOEMPTYERROR =     11 /* do not create empty error (PRIVATE) */
CONST XADAIB_ONLYIN =           12 /* in stuff only (PRIVATE) */
CONST XADAIB_ONLYOUT =          13 /* out stuff only (PRIVATE) */
CONST XADAIB_USESECTORLABELS =  14 /* use SectorLabels (PRIVATE) */

CONST XADAIF_CRYPTED =          $00000001
CONST XADAIF_FILECORRUPT =      $00000002
CONST XADAIF_FILEARCHIVE =      $00000004
CONST XADAIF_DISKARCHIVE =      $00000008
CONST XADAIF_OVERWRITE =        $00000010
CONST XADAIF_MAKEDIRECTORY =    $00000020
CONST XADAIF_IGNOREGEOMETRY =   $00000040
CONST XADAIF_VERIFY =           $00000080
CONST XADAIF_NOKILLPARTIAL =    $00000100
CONST XADAIF_DISKIMAGE =        $00000200
CONST XADAIF_FORMAT =           $00000400
CONST XADAIF_NOEMPTYERROR =     $00000800
CONST XADAIF_ONLYIN =           $00001000
CONST XADAIF_ONLYOUT =          $00002000
CONST XADAIF_USESECTORLABELS =  $00004000

OBJECT xadFileInfo
    xfi_Next:PTR TO xadFileInfo
    xfi_EntryNumber:LONG                /* number of entry */
    xfi_EntryInfo:PTR TO CHAR           /* additional archiver text */
    xfi_PrivateInfo:PTR TO CHAR         /* client private, see XAD_OBJPRIVINFOSIZE */
    xfi_Flags:LONG                      /* see XADFIF_xxx defines */
    xfi_FileName:PTR TO CHAR            /* see XAD_OBJNAMESIZE tag */
    xfi_Comment:PTR TO CHAR             /* see XAD_OBJCOMMENTSIZE tag */
    xfi_Protection:LONG                 /* AmigaOS3 bits (including multiuser) */
    xfi_OwnerUID:LONG                   /* user ID */
    xfi_OwnerGID:LONG                   /* group ID */
    xfi_UserName:PTR TO CHAR            /* user name */
    xfi_GroupName:PTR TO CHAR           /* group name */
    xfi_Size:LONG                       /* size of this file */
    xfi_GroupCrSize:LONG                /* crunched size of group */
    xfi_CrunchSize:LONG                 /* crunched size */
    xfi_LinkName:PTR TO CHAR            /* name and path of link */
    xfi_Date:xadDate
    xfi_Generation:INT                  /* File Generation [0...0xFFFF] (V3) */
    xfi_DataPos:LONG                    /* crunched data position (V3) */
    xfi_MacFork:PTR TO xadFileInfo      /* pointer to 2nd fork for Mac (V7) */
    xfi_UnixProtect:INT                 /* protection bits for Unix (V11) */
    xfi_DosProtect:CHAR                 /* protection bits for MS-DOS (V11) */
    xfi_FileType:CHAR                   /* XADFILETYPE to define type of exe files (V11) */
    xfi_Special:PTR TO xadSpecial       /* pointer to special data (V11) */
ENDOBJECT

/* These are used for xfi_FileType to define file type. (V11) */
CONST XADFILETYPE_DATACRUNCHER =        1  /* infile was only one data file */
CONST XADFILETYPE_TEXTLINKER =          2  /* infile was text-linked */

CONST XADFILETYPE_AMIGAEXECRUNCHER =    11 /* infile was an Amiga exe cruncher */
CONST XADFILETYPE_AMIGAEXELINKER =      12 /* infile was an Amiga exe linker */
CONST XADFILETYPE_AMIGATEXTLINKER =     13 /* infile was an Amiga text-exe linker */
CONST XADFILETYPE_AMIGAADDRESS =        14 /* infile was an Amiga address cruncher */

CONST XADFILETYPE_UNIXBLOCKDEVICE =     21 /* this file is a block device */
CONST XADFILETYPE_UNIXCHARDEVICE =      22 /* this file is a character device */
CONST XADFILETYPE_UNIXFIFO =            23 /* this file is a named pipe */
CONST XADFILETYPE_UNIXSOCKET =          24 /* this file is a socket */

CONST XADFILETYPE_MSDOSEXECRUNCHER =    31 /* infile was an MSDOS exe cruncher */

CONST XADSPECIALTYPE_UNIXDEVICE =       1  /* xadSpecial entry is xadSpecialUnixDevice */
CONST XADSPECIALTYPE_AMIGAADDRESS =     2  /* xadSpecial entry is xadSpecialAmigaAddress */
CONST XADSPECIALTYPE_CBM8BIT =          3  /* xadSpecial entry is xadSpecialCBM8bit */

OBJECT xadSpecial
    xfis_Type:LONG                      /* XADSPECIALTYPE to define type of block (V11) */
    xfis_Next:PTR TO xadSpecial         /* pointer to next entry */
ENDOBJECT

OBJECT xadSpecialUnixDevice
    xfis_Special:xadSpecial
    xfis_MajorVersion:LONG      /* major device version */
    xfis_MinorVersion:LONG      /* minor device version */
ENDOBJECT

OBJECT xadSpecialAmigaAddress
    xfis_Special:xadSpecial
    xfis_JumpAddress:LONG       /* code execution start address */
    xfis_DecrunchAddress:LONG   /* decrunch start of code */
ENDOBJECT

OBJECT xadSpecialCBM8bit
    xfis_Special:xadSpecial
    xfis_FileType:CHAR          /* File type XADCBM8BITTYPE_xxx */
    xfis_RecordLength:CHAR      /* record length if relative file */
ENDOBJECT

CONST XADCBM8BITTYPE_UNKNOWN =  $00 /*        Unknown / Unused */
CONST XADCBM8BITTYPE_BASIC =    $01 /* Tape - BASIC program file */
CONST XADCBM8BITTYPE_DATA =     $02 /* Tape - Data block (SEQ file) */
CONST XADCBM8BITTYPE_FIXED =    $03 /* Tape - Fixed addres program file */
CONST XADCBM8BITTYPE_SEQDATA =  $04 /* Tape - Sequential data file */
CONST XADCBM8BITTYPE_SEQ =      $81 /* Disk - Sequential file "SEQ" */
CONST XADCBM8BITTYPE_PRG =      $82 /* Disk - Program file "PRG" */
CONST XADCBM8BITTYPE_USR =      $83 /* Disk - User-defined file "USR" */
CONST XADCBM8BITTYPE_REL =      $84 /* Disk - Relative records file "REL" */
CONST XADCBM8BITTYPE_CBM =      $85 /* Disk - CBM (partition) "CBM" */

/* Multiuser fields (xfi_OwnerUID, xfi_OwnerUID, xfi_UserName, xfi_GroupName)
   and multiuser bits (see <dos/dos.h>) are currently not supported with normal
   Amiga filesystem. But the clients support them, if archive format holds
   such information.

   The protection bits (all 3 fields) should always be set using the
   xadConvertProtection procedure. Call it with as much protection information
   as possible. It extracts the relevant data at best (and also sets the 2 flags).
   DO NOT USE these fields directly, but always through xadConvertProtection
   call.
*/

CONST XADFIB_CRYPTED =          0  /* entry is crypted */
CONST XADFIB_DIRECTORY =        1  /* entry is a directory */
CONST XADFIB_LINK =             2  /* entry is a link */
CONST XADFIB_INFOTEXT =         3  /* file is an information text */
CONST XADFIB_GROUPED =          4  /* file is in a crunch group */
CONST XADFIB_ENDOFGROUP =       5  /* crunch group ends here */
CONST XADFIB_NODATE =           6  /* no date supported, CURRENT date is set */
CONST XADFIB_DELETED =          7  /* file is marked as deleted (V3) */
CONST XADFIB_SEEKDATAPOS =      8  /* before unarchiving the datapos is set (V3) */
CONST XADFIB_NOFILENAME =       9  /* there was no filename, using internal one (V6) */
CONST XADFIB_NOUNCRUNCHSIZE =   10 /* file size is unknown and thus set to zero (V6) */
CONST XADFIB_PARTIALFILE =      11 /* file is only partial (V6) */
CONST XADFIB_MACDATA =          12 /* file is Apple data fork (V7) */
CONST XADFIB_MACRESOURCE =      13 /* file is Apple resource fork (V7) */
CONST XADFIB_EXTRACTONBUILD =   14 /* allows extract file during scanning (V10) */
CONST XADFIB_UNIXPROTECTION =   15 /* UNIX protection bits are present (V11) */
CONST XADFIB_DOSPROTECTION =    16 /* MSDOS protection bits are present (V11) */
CONST XADFIB_ENTRYMAYCHANGE =   17 /* this entry may change until GetInfo is finished (V11) */
CONST XADFIB_XADSTRFILENAME =   18 /* the xfi_FileName fields is an XAD string (V12) */
CONST XADFIB_XADSTRLINKNAME =   19 /* the xfi_LinkName fields is an XAD string (V12) */
CONST XADFIB_XADSTRCOMMENT =    20 /* the xfi_Comment fields is an XAD string (V12) */


CONST XADFIF_CRYPTED =          $00000001
CONST XADFIF_DIRECTORY =        $00000002
CONST XADFIF_LINK =             $00000004
CONST XADFIF_INFOTEXT =         $00000008
CONST XADFIF_GROUPED =          $00000010
CONST XADFIF_ENDOFGROUP =       $00000020
CONST XADFIF_NODATE =           $00000040
CONST XADFIF_DELETED =          $00000080
CONST XADFIF_SEEKDATAPOS =      $00000100
CONST XADFIF_NOFILENAME =       $00000200
CONST XADFIF_NOUNCRUNCHSIZE =   $00000400
CONST XADFIF_PARTIALFILE =      $00000800
CONST XADFIF_MACDATA =          $00001000
CONST XADFIF_MACRESOURCE =      $00002000
CONST XADFIF_EXTRACTONBUILD =   $00004000
CONST XADFIF_UNIXPROTECTION =   $00008000
CONST XADFIF_DOSPROTECTION =    $00010000
CONST XADFIF_ENTRYMAYCHANGE =   $00020000
CONST XADFIF_XADSTRFILENAME =   $00040000
CONST XADFIF_XADSTRLINKNAME =   $00080000
CONST XADFIF_XADSTRCOMMENT =    $00100000

/* NOTE: the texts passed with that structure must not always be printable.
   Although the clients should add an additional (not counted) zero at the text
   end, the whole file may contain other unprintable stuff (e.g. for DMS).
   So when printing this texts do it on a byte for byte base including
   printability checks.
*/

OBJECT xadTextInfo
    xti_Next:PTR TO xadTextInfo
    xti_Size:LONG               /* maybe zero - no text - e.g. when crypted */
    xti_Text:PTR TO CHAR        /* and there is no password in xadGetInfo() */
    xti_Flags:LONG              /* see XADTIF_xxx defines */
ENDOBJECT

CONST XADTIB_CRYPTED =          0 /* entry is empty, as data was crypted */
CONST XADTIB_BANNER =           1 /* text is a banner */
CONST XADTIB_FILEDIZ =          2 /* text is a file description */

CONST XADTIF_CRYPTED =          $00000001
CONST XADTIF_BANNER =           $00000002
CONST XADTIF_FILEDIZ =          $00000004

OBJECT xadDiskInfo
    xdi_Next:PTR TO xadDiskInfo
    xdi_EntryNumber:LONG                /* number of entry */
    xdi_EntryInfo:PTR TO CHAR           /* additional archiver text */
    xdi_PrivateInfo:PTR TO CHAR         /* client private, see XAD_OBJPRIVINFOSIZE */
    xdi_Flags:LONG                      /* see XADDIF_xxx defines */
    xdi_SectorSize:LONG
    xdi_TotalSectors:LONG               /* see devices/trackdisk.h */
    xdi_Cylinders:LONG                  /* to find out what these */
    xdi_CylSectors:LONG                 /* fields mean, they are equal */
    xdi_Heads:LONG                      /* to struct DriveGeometry */
    xdi_TrackSectors:LONG
    xdi_LowCyl:LONG                     /* lowest cylinder stored */
    xdi_HighCyl:LONG                    /* highest cylinder stored */
    xdi_BlockInfoSize:LONG              /* number of BlockInfo entries */
    xdi_BlockInfo:PTR TO CHAR           /* see XADBIF_xxx defines and XAD_OBJBLOCKENTRIES tag */
    xdi_TextInfo:PTR TO xadTextInfo     /* linked list with info texts */
    xdi_DataPos:LONG                    /* crunched data position (V3) */
ENDOBJECT

/* BlockInfo points to a UBYTE field for every track from first sector of
   lowest cylinder to last sector of highest cylinder. When not used,
   pointer must be 0. Do not use it, when there are no entries!
   This is just for information. The applications still asks the client
   to unarchive whole cylinders and not archived blocks are cleared for
   unarchiving.
*/

CONST XADDIB_CRYPTED =           0  /* entry is crypted */
CONST XADDIB_SEEKDATAPOS =       1  /* before unarchiving the datapos is set (V3) */
CONST XADDIB_SECTORLABELS =      2  /* the clients delivers sector labels (V9) */
CONST XADDIB_EXTRACTONBUILD =    3  /* allows extract disk during scanning (V10) */
CONST XADDIB_ENTRYMAYCHANGE =    4  /* this entry may change until GetInfo is finished (V11) */

/* Some of the crunchers do not store all necessary information, so it
may be needed to guess some of them. Set the following flags in that case
and geometry check will ignore these fields. */
CONST XADDIB_GUESSSECTORSIZE =   5  /* sectorsize is guessed (V10) */
CONST XADDIB_GUESSTOTALSECTORS = 6  /* totalsectors number is guessed (V10) */
CONST XADDIB_GUESSCYLINDERS =    7  /* cylinder number is guessed */
CONST XADDIB_GUESSCYLSECTORS =   8  /* cylsectors is guessed */
CONST XADDIB_GUESSHEADS =        9  /* number of heads is guessed */
CONST XADDIB_GUESSTRACKSECTORS = 10 /* tracksectors is guessed */
CONST XADDIB_GUESSLOWCYL =       11 /* lowcyl is guessed */
CONST XADDIB_GUESSHIGHCYL =      12 /* highcyl is guessed */

/* If it is impossible to set some of the fields, you need to set some of
these flags. NOTE: XADDIB_NOCYLINDERS is really important, as this turns
off usage of lowcyl and highcyl keywords. When you have cylinder information,
you should not use these and instead use guess flags and calculate
possible values for the missing fields. */
CONST XADDIB_NOCYLINDERS =       15 /* cylinder number is not set */
CONST XADDIB_NOCYLSECTORS =      16 /* cylsectors is not set */
CONST XADDIB_NOHEADS =           17 /* number of heads is not set */
CONST XADDIB_NOTRACKSECTORS =    18 /* tracksectors is not set */
CONST XADDIB_NOLOWCYL =          19 /* lowcyl is not set */
CONST XADDIB_NOHIGHCYL =         20 /* highcyl is not set */

CONST XADDIF_CRYPTED =           $00000001
CONST XADDIF_SEEKDATAPOS =       $00000002
CONST XADDIF_SECTORLABELS =      $00000004
CONST XADDIF_EXTRACTONBUILD =    $00000008
CONST XADDIF_ENTRYMAYCHANGE =    $00000010

CONST XADDIF_GUESSSECTORSIZE =   $00000020
CONST XADDIF_GUESSTOTALSECTORS = $00000040
CONST XADDIF_GUESSCYLINDERS =    $00000080
CONST XADDIF_GUESSCYLSECTORS =   $00000100
CONST XADDIF_GUESSHEADS =        $00000200
CONST XADDIF_GUESSTRACKSECTORS = $00000400
CONST XADDIF_GUESSLOWCYL =       $00000800
CONST XADDIF_GUESSHIGHCYL =      $00001000

CONST XADDIF_NOCYLINDERS =       $00008000
CONST XADDIF_NOCYLSECTORS =      $00010000
CONST XADDIF_NOHEADS =           $00020000
CONST XADDIF_NOTRACKSECTORS =    $00040000
CONST XADDIF_NOLOWCYL =          $00080000
CONST XADDIF_NOHIGHCYL =         $00100000

/* defines for BlockInfo */
CONST XADBIB_CLEARED =           0 /* this block was cleared for archiving */
CONST XADBIB_UNUSED =            1 /* this block was not archived */

CONST XADBIF_CLEARED =           $00000001
CONST XADBIF_UNUSED =            $00000002

/************************************************************************
*                                                                       *
*    progress report stuff                                              *
*                                                                       *
************************************************************************/

OBJECT xadProgressInfo
    xpi_Mode:LONG                       /* work modus */
    xpi_Client:PTR TO xadClient         /* the client doing the work */
    xpi_DiskInfo:PTR TO xadDiskInfo     /* current diskinfo, for disks */
    xpi_FileInfo:PTR TO xadFileInfo     /* current info for files */
    xpi_CurrentSize:LONG                /* current filesize */
    xpi_LowCyl:LONG                     /* for disks only */
    xpi_HighCyl:LONG                    /* for disks only */
    xpi_Status:LONG                     /* see XADPIF flags */
    xpi_Error:LONG                      /* any of the error codes */
    xpi_FileName:PTR TO CHAR            /* name of file to overwrite (V2) */
    xpi_NewName:PTR TO CHAR             /* new name buffer, passed by hook (V2) */
ENDOBJECT
/* NOTE: For disks CurrentSize is Sector*SectorSize, where SectorSize can
be found in xadDiskInfo structure. So you may output the sector value. */

/* different progress modes */
CONST XADPMODE_ASK =            1
CONST XADPMODE_PROGRESS =       2
CONST XADPMODE_END =            3
CONST XADPMODE_ERROR =          4
CONST XADPMODE_NEWENTRY =       5 /* (V10) */
CONST XADPMODE_GETINFOEND =     6 /* (V11) */

/* flags for progress hook and ProgressInfo status field */
CONST XADPIB_OVERWRITE =        0  /* overwrite the file */
CONST XADPIB_MAKEDIRECTORY =    1  /* create the directory */
CONST XADPIB_IGNOREGEOMETRY =   2  /* ignore drive geometry */
CONST XADPIB_ISDIRECTORY =      3  /* destination is a directory (V10) */
CONST XADPIB_RENAME =           10 /* rename the file (V2) */
CONST XADPIB_OK =               16 /* all ok, proceed */
CONST XADPIB_SKIP =             17 /* skip file */

CONST XADPIF_OVERWRITE =        $00000001
CONST XADPIF_MAKEDIRECTORY =    $00000002
CONST XADPIF_IGNOREGEOMETRY =   $00000004
CONST XADPIF_ISDIRECTORY =      $00000008
CONST XADPIF_RENAME =           $00000400
CONST XADPIF_OK =               $00010000
CONST XADPIF_SKIP =             $00020000

/************************************************************************
*                                                                       *
*    errors                                                             *
*                                                                       *
************************************************************************/

CONST XADERR_OK =               $0000 /* no error */
CONST XADERR_UNKNOWN =          $0001 /* unknown error */
CONST XADERR_INPUT =            $0002 /* input data buffers border exceeded */
CONST XADERR_OUTPUT =           $0003 /* output data buffers border exceeded */
CONST XADERR_BADPARAMS =        $0004 /* function called with illegal parameters */
CONST XADERR_NOMEMORY =         $0005 /* not enough memory available */
CONST XADERR_ILLEGALDATA =      $0006 /* data is corrupted */
CONST XADERR_NOTSUPPORTED =     $0007 /* command is not supported */
CONST XADERR_RESOURCE =         $0008 /* required resource missing */
CONST XADERR_DECRUNCH =         $0009 /* error on decrunching */
CONST XADERR_FILETYPE =         $000A /* unknown file type */
CONST XADERR_OPENFILE =         $000B /* opening file failed */
CONST XADERR_SKIP =             $000C /* file, disk has been skipped */
CONST XADERR_BREAK =            $000D /* user break in progress hook */
CONST XADERR_FILEEXISTS =       $000E /* file already exists */
CONST XADERR_PASSWORD =         $000F /* missing or wrong password */
CONST XADERR_MAKEDIR =          $0010 /* could not create directory */
CONST XADERR_CHECKSUM =         $0011 /* wrong checksum */
CONST XADERR_VERIFY =           $0012 /* verify failed (disk hook) */
CONST XADERR_GEOMETRY =         $0013 /* wrong drive geometry */
CONST XADERR_DATAFORMAT =       $0014 /* unknown data format */
CONST XADERR_EMPTY =            $0015 /* source contains no files */
CONST XADERR_FILESYSTEM =       $0016 /* unknown filesystem */
CONST XADERR_FILEDIR =          $0017 /* name of file exists as directory */
CONST XADERR_SHORTBUFFER =      $0018 /* buffer was too short */
CONST XADERR_ENCODING =         $0019 /* text encoding was defective */

/************************************************************************
*                                                                       *
*    characterset and filename conversion                               *
*                                                                       *
************************************************************************/

CONST CHARSET_HOST =                            0   /* this is the ONLY destination setting for clients! */

CONST CHARSET_UNICODE_UCS2_HOST =               10  /* 16bit Unicode (usually no source type) */
CONST CHARSET_UNICODE_UCS2_BIGENDIAN =          11  /* 16bit Unicode big endian storage */
CONST CHARSET_UNICODE_UCS2_LITTLEENDIAN =       12  /* 16bit Unicode little endian storage */
CONST CHARSET_UNICODE_UTF8 =                    13  /* variable size unicode encoding */

/* all the 1xx types are generic types which also maybe a bit dynamic */
CONST CHARSET_AMIGA =                           100 /* the default Amiga charset */
CONST CHARSET_MSDOS =                           101 /* the default MSDOS charset */
CONST CHARSET_MACOS =                           102 /* the default MacOS charset */
CONST CHARSET_C64 =                             103 /* the default C64 charset */
CONST CHARSET_ATARI_ST =                        104 /* the default Atari ST charset */
CONST CHARSET_WINDOWS =                         105 /* the default Windows charset */

/* all the 2xx to 9xx types are real charsets, use them whenever you know
   what the data really is */
CONST CHARSET_ASCII =                           200 /* the lower 7 bits of ASCII charsets */
CONST CHARSET_ISO_8859_1 =                      201 /* the base charset */
CONST CHARSET_ISO_8859_15 =                     215 /* Euro-sign fixed ISO variant */
CONST CHARSET_ATARI_ST_US =                     300 /* Atari ST (US) charset */
CONST CHARSET_PETSCII_C64_LC =                  301 /* C64 lower case charset */
CONST CHARSET_CODEPAGE_437 =                    400 /* IBM Codepage 437 charset */
CONST CHARSET_CODEPAGE_1252 =                   401 /* Windows Codepage 1252 charset */

/************************************************************************
*                                                                       *
*    client related stuff                                               *
*                                                                       *
************************************************************************/

OBJECT xadForeman
    xfm_Security:LONG                   /* should be XADFOREMAN_SECURITY */
    xfm_ID:LONG                         /* must be XADFOREMAN_ID */
    xfm_Version:INT                     /* set to XADFOREMAN_VERSION */
    xfm_Reserved:INT
    xfm_VersString:PTR TO CHAR          /* pointer to $VER: string */
    xfm_FirstClient:PTR TO xadClient    /* pointer to first client */
ENDOBJECT

CONST XADFOREMAN_SECURITY =     $70FF4E75 /* MOVEQ #-1,D0 and RTS */
CONST XADFOREMAN_ID =           $58414446 /* 'XADF' identification ID */
CONST XADFOREMAN_VERSION =      1

OBJECT xadClient
    xc_Next:PTR TO xadClient
    xc_Version:INT                      /* set to XADCLIENT_VERSION */
    xc_MasterVersion:INT
    xc_ClientVersion:INT
    xc_ClientRevision:INT
    xc_RecogSize:LONG                   /* needed size to recog the type */
    xc_Flags:LONG                       /* see XADCF_xxx defines */
    xc_Identifier:LONG                  /* ID of internal clients */
    xc_ArchiverName:PTR TO CHAR
    xc_RecogData:PTR TO LONG
    xc_GetInfo:PTR TO LONG
    xc_UnArchive:PTR TO LONG
    xc_Free:PTR TO LONG
ENDOBJECT

/* function interface
ASM(BOOL) xc_RecogData(REG(d0, ULONG size), REG(a0, STRPTR data),
                REG(a6, struct xadMasterBase *xadMasterBase));
ASM(LONG) xc_GetInfo(REG(a0, struct xadArchiveInfo *ai),
                REG(a6, struct xadMasterBase *xadMasterBase));
ASM(LONG) xc_UnArchive(REG(a0, struct xadArchiveInfo *ai),
                REG(a6, struct xadMasterBase *xadMasterBase));
ASM(void) xc_Free(REG(a0, struct xadArchiveInfo *ai),
                REG(a6, struct xadMasterBase *xadMasterBase));
*/

/* xc_RecogData returns 1 when recognized and 0 when not, all the others
   return 0 when ok and XADERR values on error. xc_Free has no return
   value.

   Filesystem clients need to clear xc_RecogSize and xc_RecogData. The
   recognition is automatically done by GetInfo. XADERR_FILESYSTEM is
   returned in case of unknown format. If it is known detection should
   go on and any other code may be returned, if it fails.
   The field xc_ArchiverName means xc_FileSystemName for filesystem
   clients.
*/

CONST XADCLIENT_VERSION =       1

CONST XADCB_FILEARCHIVER =      0 /* archiver is a file archiver */
CONST XADCB_DISKARCHIVER =      1 /* archiver is a disk archiver */
CONST XADCB_EXTERN =            2 /* external client, set by xadmaster */
CONST XADCB_FILESYSTEM =        3 /* filesystem clients (V5) */
CONST XADCB_NOCHECKSIZE =       4 /* do not check size for recog call (V6) */
CONST XADCB_DATACRUNCHER =      5 /* file archiver is plain data file (V11) */
CONST XADCB_EXECRUNCHER =       6 /* file archiver is executable file (V11) */
CONST XADCB_ADDRESSCRUNCHER =   7 /* file archiver is address crunched file (V11) */
CONST XADCB_LINKER =            8 /* file archiver is a linker file (V11) */
CONST XADCB_FREEXADSTRINGS =    25 /* master frees XAD strings (V12) */
CONST XADCB_FREESPECIALINFO =   26 /* master frees xadSpecial  structures (V11) */
CONST XADCB_FREESKIPINFO =      27 /* master frees xadSkipInfo structures (V3) */
CONST XADCB_FREETEXTINFO =      28 /* master frees xadTextInfo structures (V2) */
CONST XADCB_FREETEXTINFOTEXT =  29 /* master frees xadTextInfo text block (V2) */
CONST XADCB_FREEFILEINFO =      30 /* master frees xadFileInfo structures (V2) */
CONST XADCB_FREEDISKINFO =      31 /* master frees xadDiskInfo structures (V2) */

CONST XADCF_FILEARCHIVER =      $00000001
CONST XADCF_DISKARCHIVER =      $00000002
CONST XADCF_EXTERN =            $00000004
CONST XADCF_FILESYSTEM =        $00000008
CONST XADCF_NOCHECKSIZE =       $00000010
CONST XADCF_DATACRUNCHER =      $00000020
CONST XADCF_EXECRUNCHER =       $00000040
CONST XADCF_ADDRESSCRUNCHER =   $00000080
CONST XADCF_LINKER =            $00000100
CONST XADCF_FREEXADSTRINGS =    $02000000
CONST XADCF_FREESPECIALINFO =   $04000000
CONST XADCF_FREESKIPINFO =      $08000000
CONST XADCF_FREETEXTINFO =      $10000000
CONST XADCF_FREETEXTINFOTEXT =  $20000000
CONST XADCF_FREEFILEINFO =      $40000000
CONST XADCF_FREEDISKINFO =      $80000000

/* The types 5 to 9 always need XADCB_FILEARCHIVER set also. These only specify
the type of the archiver somewhat better. Do not mix real archivers and these
single file data clients. */

/************************************************************************
*                                                                       *
*    client ID's                                                        *
*                                                                       *
************************************************************************/

/* If an external client has set the xc_Identifier field, the internal
client is replaced. */

/* disk archivers start with 1000 */
CONST XADCID_XMASH =            1000
CONST XADCID_SUPERDUPER3 =      1001
CONST XADCID_XDISK =            1002
CONST XADCID_PACKDEV =          1003
CONST XADCID_ZOOM =             1004
CONST XADCID_ZOOM5 =            1005
CONST XADCID_CRUNCHDISK =       1006
CONST XADCID_PACKDISK =         1007
CONST XADCID_MDC =              1008
CONST XADCID_COMPDISK =         1009
CONST XADCID_LHWARP =           1010
CONST XADCID_SAVAGECOMPRESSOR = 1011
CONST XADCID_WARP =             1012
CONST XADCID_GDC =              1013
CONST XADCID_DCS =              1014
CONST XADCID_MSA =              1015
CONST XADCID_COP =              1016
CONST XADCID_DIMP =             1017
CONST XADCID_DIMPSFX =          1018

/* file archivers start with 5000 */
CONST XADCID_TAR =              5000
CONST XADCID_SDSSFX =           5001
CONST XADCID_LZX =              5002
CONST XADCID_MXMSIMPLEARC =     5003
CONST XADCID_LHPAK =            5004
CONST XADCID_AMIGAPLUSUNPACK =  5005
CONST XADCID_AMIPACK =          5006
CONST XADCID_LHA =              5007
CONST XADCID_LHASFX =           5008
CONST XADCID_PCOMPARC =         5009
CONST XADCID_SOMNI =            5010
CONST XADCID_LHSFX =            5011
CONST XADCID_XPKARCHIVE =       5012
CONST XADCID_SHRINK =           5013
CONST XADCID_SPACK =            5014
CONST XADCID_SPACKSFX =         5015
CONST XADCID_ZIP =              5016
CONST XADCID_WINZIPEXE =        5017
CONST XADCID_GZIP =             5018
CONST XADCID_ARC =              5019
CONST XADCID_ZOO =              5020
CONST XADCID_LHAEXE =           5021
CONST XADCID_ARJ =              5022
CONST XADCID_ARJEXE =           5023
CONST XADCID_ZIPEXE =           5024
CONST XADCID_LHF =              5025
CONST XADCID_COMPRESS =         5026
CONST XADCID_ACE =              5027
CONST XADCID_ACEEXE =           5028
CONST XADCID_GZIPSFX =          5029
CONST XADCID_HA =               5030
CONST XADCID_SQ =               5031
CONST XADCID_LHAC64SFX =        5032
CONST XADCID_SIT =              5033
CONST XADCID_SIT5 =             5034
CONST XADCID_SIT5EXE =          5035
CONST XADCID_MACBINARY =        5036
CONST XADCID_CPIO =             5037
CONST XADCID_PACKIT =           5038
CONST XADCID_CRUNCH =           5039
CONST XADCID_ARCCBM =           5040
CONST XADCID_ARCCBMSFX =        5041
CONST XADCID_CAB =              5042
CONST XADCID_CABMSEXE =         5043
CONST XADCID_RPM =              5044
CONST XADCID_BZIP2 =            5045
CONST XADCID_BZIP2SFX =         5046
CONST XADCID_BZIP =             5047
CONST XADCID_IDPAK =            5048
CONST XADCID_IDWAD =            5049
CONST XADCID_IDWAD2 =           5050

/* filesystem client start with 8000 */

CONST XADCID_FSAMIGA =          8000
CONST XADCID_FSSANITYOS =       8001
CONST XADCID_FSFAT =            8002
CONST XADCID_FSTRDOS =          8003

/* mixed archivers start with 9000 */
CONST XADCID_DMS =              9000
CONST XADCID_DMSSFX =           9001
