	IFND	LIBRARIES_XADMASTER_I
LIBRARIES_XADMASTER_I	SET	1

*
*   $Id: xadmaster.i,v 13.3 2005/06/23 15:47:23 stoecker Exp $
*   xadmaster.library defines and structures
*
*   XAD library system for archive handling
*   Copyright (C) 1998 and later by Dirk Stöcker <soft@dstoecker.de>
*
*   This library is free software; you can redistribute it and/or
*   modify it under the terms of the GNU Lesser General Public
*   License as published by the Free Software Foundation; either
*   version 2.1 of the License, or (at your option) any later version.
*
*   This library is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
*   Lesser General Public License for more details.
*
*   You should have received a copy of the GNU Lesser General Public
*   License along with this library; if not, write to the Free Software
*   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*

XADFALSE		EQU	0
XADTRUE			EQU	1
XADMEMF_ANY		EQU	(0)
XADMEMF_CLEAR		EQU	(1<<16)
XADMEMF_PUBLIC		EQU	(1<<0)

	IFND	EXEC_LIBRARIES_I
	INCLUDE "exec/libraries.i"
	ENDC

	IFND	UTILITY_TAGITEM_I
	INCLUDE "utility/tagitem.i"
	ENDC

XADNAME MACRO
	DC.B  'xadmaster.library',0
	ENDM

TAG_PTR			EQU	TAG_USER
TAG_INT			EQU	TAG_USER
TAG_SIZ			EQU	TAG_USER

* NOTE: The structures do not have size labels, as they have no fixed
* size. You always need to call xadAllocObject to get them

*************************************************************************
*									*
*    library base structure						*
*									*
*************************************************************************

	STRUCTURE xadMasterBase,LIB_SIZE
	IFD	XAD_OBSOLETE
	APTR	xmb_SysBase
	APTR	xmb_DOSBase
	APTR	xmb_UtilityBase
	ULONG	xmb_RecogSize		* read only
	APTR	xmb_DefaultName 	* name for XADFIF_NOFILENAME (V6)
	ENDC

*************************************************************************
*									*
*    tag-function call flags						*
*									*
*************************************************************************

* input tags for xadGetInfo, only one can be specified per call
XAD_INSIZE		EQU	(TAG_USER+001) * input data size
XAD_INFILENAME		EQU	(TAG_USER+002)
XAD_INFILEHANDLE	EQU	(TAG_USER+003)
XAD_INMEMORY		EQU	(TAG_USER+004)
XAD_INHOOK		EQU	(TAG_USER+005)
XAD_INSPLITTED		EQU	(TAG_USER+006) * (V2)
XAD_INDISKARCHIVE	EQU	(TAG_USER+007) * (V4)
XAD_INXADSTREAM 	EQU	(TAG_USER+008) * (V8)
XAD_INDEVICE		EQU	(TAG_USER+009) * (V11)

* output tags, only one can be specified per call, xadXXXXUnArc
XAD_OUTSIZE		EQU	(TAG_USER+010) * output data size
XAD_OUTFILENAME 	EQU	(TAG_USER+011)
XAD_OUTFILEHANDLE	EQU	(TAG_USER+012)
XAD_OUTMEMORY		EQU	(TAG_USER+013)
XAD_OUTHOOK		EQU	(TAG_USER+014)
XAD_OUTDEVICE		EQU	(TAG_USER+015)
XAD_OUTXADSTREAM	EQU	(TAG_USER+016) * (V8)

* object allocation tags for xadAllocObjectA
XAD_OBJNAMESIZE 	EQU	(TAG_USER+020) * XADOBJ_FILEINFO, size of needed name space
XAD_OBJCOMMENTSIZE	EQU	(TAG_USER+021) * XADOBJ_FILEINFO, size of needed comment space
XAD_OBJPRIVINFOSIZE	EQU	(TAG_USER+022) * XADOBJ_FILEINFO & XADOBJ_DISKINFO, self use size
XAD_OBJBLOCKENTRIES	EQU	(TAG_USER+023) * XADOBJ_DISKINFO, number of needed entries

* tags for xadGetInfo, xadFileUnArc and xadDiskUnArc
XAD_NOEXTERN		EQU	(TAG_USER+050) * do not use extern clients
XAD_PASSWORD		EQU	(TAG_USER+051) * password when needed
XAD_ENTRYNUMBER 	EQU	(TAG_USER+052) * number of wanted entry
XAD_PROGRESSHOOK	EQU	(TAG_USER+053) * the progress hook
XAD_OVERWRITE		EQU	(TAG_USER+054) * overwrite file ?
XAD_MAKEDIRECTORY	EQU	(TAG_USER+055) * create directory tree
XAD_IGNOREGEOMETRY	EQU	(TAG_USER+056) * ignore drive geometry ?
XAD_LOWCYLINDER 	EQU	(TAG_USER+057) * lowest cylinder
XAD_HIGHCYLINDER	EQU	(TAG_USER+058) * highest cylinder
XAD_VERIFY		EQU	(TAG_USER+059) * verify for disk hook
XAD_NOKILLPARTIAL	EQU	(TAG_USER+060) * do not delete partial/corrupt files (V3.3)
XAD_FORMAT		EQU	(TAG_USER+061) * format output device (V5)
XAD_USESECTORLABELS	EQU	(TAG_USER+062) * sector labels are stored on disk (V9)
XAD_IGNOREFLAGS 	EQU	(TAG_USER+063) * ignore the client, if certain flags are set (V11)
XAD_ONLYFLAGS		EQU	(TAG_USER+064) * ignore the client, if certain flags are NOT set (V11)

* input tags for xadConvertDates, only one can be passed
XAD_DATEUNIX		EQU	(TAG_USER+070) * unix date variable
XAD_DATEAMIGA		EQU	(TAG_USER+071) * Amiga date variable
XAD_DATEDATESTAMP	EQU	(TAG_USER+072) * Amiga struct DateStamp
XAD_DATEXADDATE 	EQU	(TAG_USER+073) * struct xadDate
XAD_DATECLOCKDATA	EQU	(TAG_USER+074) * Amiga struct ClockData
XAD_DATECURRENTTIME	EQU	(TAG_USER+075) * input is system time
XAD_DATEMSDOS		EQU	(TAG_USER+076) * MS-DOS packed format (V2)
XAD_DATEMAC		EQU	(TAG_USER+077) * Mac date variable (V8)
XAD_DATECPM		EQU	(TAG_USER+078) * CP/M data structure (V10)
XAD_DATECPM2		EQU	(TAG_USER+079) * CP/M data structure type 2 (V10)
XAD_DATEISO9660 	EQU	(TAG_USER+300) * ISO9660 date structure (V11)

* output tags, there can be specified multiple tags for one call
XAD_GETDATEUNIX 	EQU	(TAG_USER+080) * unix date variable
XAD_GETDATEAMIGA	EQU	(TAG_USER+081) * Amiga date variable
XAD_GETDATEDATESTAMP	EQU	(TAG_USER+082) * Amiga struct DateStamp
XAD_GETDATEXADDATE	EQU	(TAG_USER+083) * struct xadDate
XAD_GETDATECLOCKDATA	EQU	(TAG_USER+084) * Amiga struct ClockData
XAD_GETDATEMSDOS	EQU	(TAG_USER+086) * MS-DOS packed format (V2)
XAD_GETDATEMAC		EQU	(TAG_USER+087) * Mac date variable (V8)
XAD_GETDATECPM		EQU	(TAG_USER+088) * CP/M data structure (V10)
XAD_GETDATECPM2 	EQU	(TAG_USER+089) * CP/M data structure type 2 (V10)
XAD_GETDATEISO9660	EQU	(TAG_USER+320) * ISO9660 date structure (V11)

* following tags need locale.library to be installed
XAD_MAKEGMTDATE 	EQU	(TAG_USER+090) * make local to GMT time
XAD_MAKELOCALDATE	EQU	(TAG_USER+091) * make GMT to local time

* tags for xadHookTagAccess (V3)
XAD_USESKIPINFO 	EQU	(TAG_USER+104) * the hook uses xadSkipInfo (V3)
XAD_SECTORLABELS	EQU	(TAG_USER+105) * pass sector labels with XADAC_WRITE (V9)

XAD_GETCRC16		EQU	(TAG_USER+120) * pointer to UWORD value (V3)
XAD_GETCRC32		EQU	(TAG_USER+121) * pointer to ULONG value (V3)

XAD_CRC16ID		EQU	(TAG_USER+130) * ID for crc calculation (V3)
XAD_CRC32ID		EQU	(TAG_USER+131) * ID for crc calculation (V3)

* tags for xadConvertProtection (V4)
XAD_PROTAMIGA		EQU	(TAG_USER+160) * Amiga type protection bits (V4)
XAD_PROTUNIX		EQU	(TAG_USER+161) * protection bits in UNIX mode (V4)
XAD_PROTMSDOS		EQU	(TAG_USER+162) * MSDOS type protection bits (V4)
XAD_PROTFILEINFO	EQU	(TAG_USER+163) * input is a xadFileInfo structure (V11)

XAD_GETPROTAMIGA	EQU	(TAG_USER+170) * return Amiga protection bits (V4)
XAD_GETPROTUNIX 	EQU	(TAG_USER+171) * return UNIX protection bits (V11)
XAD_GETPROTMSDOS	EQU	(TAG_USER+172) * return MSDOS protection bits (V11)
XAD_GETPROTFILEINFO	EQU	(TAG_USER+173) * fill xadFileInfo protection fields (V11)

* tags for xadGetDiskInfo (V7)
XAD_STARTCLIENT 	EQU	(TAG_USER+180) * the client to start with (V7)
XAD_NOEMPTYERROR	EQU	(TAG_USER+181) * do not create XADERR_EMPTY (V8)

* tags for xadFreeHookAccess (V8)
XAD_WASERROR		EQU	(TAG_USER+190) * error occured, call abort method (V8)

* tags for miscellaneous stuff
XAD_ARCHIVEINFO 	EQU	(TAG_USER+200) * xadArchiveInfo for stream hooks (V8)
XAD_ERRORCODE		EQU	(TAG_USER+201) * error code of function (V12)
XAD_EXTENSION		EQU	(TAG_USER+202) * argument for xadGetDefaultName() (V13)

* tags for xadAddFileEntry and xadAddDiskEntry (V10)
XAD_SETINPOS		EQU	(TAG_USER+240) * set xai_InPos after call (V10)
XAD_INSERTDIRSFIRST	EQU	(TAG_USER+241) * insert dirs at list start (V10)

* tags for xadConvertName (V12)
XAD_PATHSEPERATOR	EQU	(TAG_USER+260) * UWORD *, default is {'/','\\',0} in source charset (V12)
XAD_CHARACTERSET	EQU	(TAG_USER+261) * the characterset of string (V12)
XAD_STRINGSIZE		EQU	(TAG_USER+262) * maximum size of following (V12)
XAD_CSTRING		EQU	(TAG_USER+263) * zero-terminated string (V12)
XAD_PSTRING		EQU	(TAG_USER+264) * lengthed Pascal string (V12)
XAD_XADSTRING		EQU	(TAG_USER+265) * an xad string (V12)
XAD_ADDPATHSEPERATOR	EQU	(TAG_USER+266) * default is TRUE (V12)

* tags for xadGetFilename (V12)
XAD_NOLEADINGPATH	EQU	(TAG_USER+280) * default is FALSE (V12)
XAD_NOTRAILINGPATH	EQU	(TAG_USER+281) * default is FALSE (V12)
XAD_MASKCHARACTERS	EQU	(TAG_USER+282) * default are #?()[]~%*:|",1-31,127-160 (V12)
XAD_MASKINGCHAR 	EQU	(TAG_USER+283) * default is '_' (V12)
XAD_REQUIREDBUFFERSIZE	EQU	(TAG_USER+284) * pointer which should hold buf size (V12)


* Places 300-339 used for dates!

*************************************************************************
*									*
*    objects for xadAllocObjectA					*
*									*
*************************************************************************

XADOBJ_ARCHIVEINFO	EQU	$0001 * struct xadArchiveInfo
XADOBJ_FILEINFO 	EQU	$0002 * struct xadFileInfo
XADOBJ_DISKINFO 	EQU	$0003 * struct xadDiskInfo
XADOBJ_HOOKPARAM	EQU	$0004 * struct HookParam
XADOBJ_DEVICEINFO	EQU	$0005 * struct xadDeviceInfo
XADOBJ_PROGRESSINFO	EQU	$0006 * struct xadProgressInfo
XADOBJ_TEXTINFO 	EQU	$0007 * struct xadTextInfo
XADOBJ_SPLITFILE	EQU	$0008 * struct xadSplitFile (V2)
XADOBJ_SKIPINFO 	EQU	$0009 * struct xadSkipInfo (V3)
XADOBJ_IMAGEINFO	EQU	$000A * struct xadImageInfo (V4)
XADOBJ_SPECIAL		EQU	$000B * struct xadSpecial (V11)

* result type of xadAllocVec
XADOBJ_MEMBLOCK 	EQU	$0100 * memory of requested size and type
* private type
XADOBJ_STRING		EQU	$0101 * a typed XAD string (V12)

*************************************************************************
*									*
*    modes for xadCalcCRC126 and xadCalcCRC32				*
*									*
*************************************************************************

XADCRC16_ID1		EQU	$A001
XADCRC32_ID1		EQU	$EDB88320

*************************************************************************
*									*
*    hook related stuff 						*
*									*
*************************************************************************

XADHC_READ	EQU	1	* read data into buffer
XADHC_WRITE	EQU	2	* write buffer data to file/memory
XADHC_SEEK	EQU	3	* seek in file
XADHC_INIT	EQU	4	* initialize the hook
XADHC_FREE	EQU	5	* end up hook work, free stuff
XADHC_ABORT	EQU	6	* an error occured, delete partial stuff
XADHC_FULLSIZE	EQU	7	* complete input size is needed
XADHC_IMAGEINFO EQU	8	* return disk image info (V4)

	STRUCTURE xadHookParam,0
	ULONG	xhp_Command
	ULONG	xhp_CommandData
	APTR	xhp_BufferPtr
	LONG	xhp_BufferSize
	LONG	xhp_DataPos	* current seek position
	APTR	xhp_PrivatePtr
	APTR	xhp_TagList	* allows to transport tags to hook (V9)

* xadHookAccess commands
XADAC_READ		EQU	10	* get data
XADAC_WRITE		EQU	11	* write data
XADAC_COPY		EQU	12	* copy input to output
XADAC_INPUTSEEK 	EQU	13	* seek in input file
XADAC_OUTPUTSEEK	EQU	14	* seek in output file

*************************************************************************
*									*
*    support structures 						*
*									*
*************************************************************************

* Own date structure to cover all possible dates in a human friendly
* format. xadConvertDates may be used to convert between different date
* structures and variables.
	STRUCTURE xadDate,0
	ULONG	xd_Micros	* values 0 to 999999
	LONG	xd_Year 	* values 1 to 2147483648
	UBYTE	xd_Month	* values 1 to 12
	UBYTE	xd_WeekDay	* values 1 to 7
	UBYTE	xd_Day		* values 1 to 31
	UBYTE	xd_Hour 	* values 0 to 23
	UBYTE	xd_Minute	* values 0 to 59
	UBYTE	xd_Second	* values 0 to 59
	LABEL	xadDate_SIZE

XADDAY_MONDAY		EQU	1	* monday is the first day and
XADDAY_TUESDAY		EQU	2
XADDAY_WEDNESDAY	EQU	3
XADDAY_THURSDAY 	EQU	4
XADDAY_FRIDAY		EQU	5
XADDAY_SATURDAY 	EQU	6
XADDAY_SUNDAY		EQU	7	* sunday the last day of a week

	STRUCTURE xadDeviceInfo,0	* for XAD_OUTDEVICE tag
	APTR	xdi_DeviceName	* name of device
	ULONG	xdi_Unit	* unit of device
	APTR	xdi_DOSName	* instead of Device+Unit, dos name without ':'

	STRUCTURE xadSplitFile,0	* for XAD_INSPLITTED
	APTR	xsf_Next
	ULONG	xsf_Type	* XAD_INFILENAME, XAD_INFILEHANDLE, XAD_INMEMORY, XAD_INHOOK
	ULONG	xsf_Size	* necessary for XAD_INMEMORY, useful for others
	ULONG	xsf_Data	* FileName, Filehandle, Hookpointer or Memory

	STRUCTURE xadSkipInfo,0
	APTR	xsi_Next
	ULONG	xsi_Position	* position, where it should be skipped
	ULONG	xsi_SkipSize	* size to skip

	STRUCTURE xadImageInfo,0	* for XADHC_IMAGEINFO
	ULONG xii_SectorSize	* usually 512
	ULONG xii_FirstSector	* of the image file
	ULONG xii_NumSectors	* of the image file
	ULONG xii_TotalSectors	* of this device type
	* If the image file holds total data of disk xii_TotalSectors equals
	* xii_NumSectors and xii_FirstSector is zero. Addition of xii_FirstSector
	* and xii_NumSectors cannot exceed xii_TotalSectors value!

*************************************************************************
*                                                                       *
*    system information structure                                       *
*                                                                       *
*************************************************************************

	STRUCTURE xadSystemInfo,0
	UWORD	xsi_Version	* master library version
	UWORD	xsi_Revision	* master library revision
	ULONG	xsi_RecogSize	* size for recognition

*************************************************************************
*									*
*    information structures						*
*									*
*************************************************************************

	STRUCTURE xadArchiveInfo,0
	APTR	xai_Client	  * pointer to unarchiving client
	APTR	xai_PrivateClient * private client data
	APTR	xai_Password	  * password for crypted archives
	ULONG	xai_Flags	  * read only XADAIF_ flags
	ULONG	xai_LowCyl	  * lowest cylinder to unarchive
	ULONG	xai_HighCyl	  * highest cylinder to unarchive
	ULONG	xai_InPos	  * input position, read only
	ULONG	xai_InSize	  * input size, read only
	ULONG	xai_OutPos	  * output position, read only
	ULONG	xai_OutSize	  * output file size, read only
	APTR	xai_FileInfo	  * data pointer for file arcs
	APTR	xai_DiskInfo	  * data pointer for disk arcs
	APTR	xai_CurFile	  * data pointer for current file arc
	APTR	xai_CurDisk	  * data pointer for current disk arc
	LONG	xai_LastError	  * last error, when XADAIF_FILECORRUPT (V2)
	APTR	xai_MultiVolume   * array of start offsets from parts (V2)
	APTR	xai_SkipInfo	  * linked list of skip entries (V3)
	APTR	xai_ImageInfo	  * for filesystem clients (V5)
	APTR	xai_InName	  * Input archive name if available (V7)

* This structure is nearly complete private to either xadmaster or its
* clients. An application program may access for reading only xai_Client,
* xai_Flags, xai_FileInfo and xai_DiskInfo. For xai_Flags only XADAIF_CRYPTED
* is useful. All the other stuff is private and should not be accessed!

	BITDEF XADAI,CRYPTED,0		* archive entries are encrypted
	BITDEF XADAI,FILECORRUPT,1	* file is corrupt, but valid entries are in the list
	BITDEF XADAI,FILEARCHIVE,2	* unarchive file entry
	BITDEF XADAI,DISKARCHIVE,3	* unarchive disk entry
	BITDEF XADAI,OVERWRITE,4	* overwrite the file (PRIVATE)
	BITDEF XADAI,MAKEDIRECTORY,5	* create directory when missing (PRIVATE)
	BITDEF XADAI,IGNOREGEOMETRY,6	* ignore drive geometry (PRIVATE)
	BITDEF XADAI,VERIFY,7		* verify is turned on for disk hook (PRIVATE)
	BITDEF XADAI,NOKILLPARTIAL,8	* do not delete partial files (PRIVATE)
	BITDEF XADAI,DISKIMAGE,9	* is disk image extraction (V5)
	BITDEF XADAI,FORMAT,10		* format in disk hook (PRIVATE)
	BITDEF XADAI,NOEMPTYERROR,11	* do not create empty error (PRIVATE)
	BITDEF XADAI,ONLYIN,12		* in stuff only (PRIVATE)
	BITDEF XADAI,ONLYOUT,13 	* out stuff only (PRIVATE)
	BITDEF XADAI,USESECTORLABELS,14 * use SectorLabels (PRIVATE)

	STRUCTURE xadFileInfo,0
	APTR	xfi_Next
	ULONG	xfi_EntryNumber * number of entry
	APTR	xfi_EntryInfo	* additional archiver text
	APTR	xfi_PrivateInfo * client private, see XAD_OBJPRIVINFOSIZE
	ULONG	xfi_Flags	* see XADFIF_xxx defines
	APTR	xfi_FileName	* see XAD_OBJNAMESIZE tag
	APTR	xfi_Comment	* see XAD_OBJCOMMENTSIZE tag
	ULONG	xfi_Protection	* AmigaOS3 bits (including multiuser)
	ULONG	xfi_OwnerUID	* user ID
	ULONG	xfi_OwnerGID	* group ID
	APTR	xfi_UserName	* user name
	APTR	xfi_GroupName	* group name
	ULONG	xfi_Size	* size of this file
	ULONG	xfi_GroupCrSize * crunched size of group
	ULONG	xfi_CrunchSize	* crunched size
	APTR	xfi_LinkName	* name and path of link
	STRUCT	xfi_Date,xadDate_SIZE
	UWORD	xfi_Generation	* File Generation [0...$FFFF] (V3)
	ULONG	xfi_DataPos	* crunched data position (V3)
	APTR	xfi_MacFork	* pointer to 2nd fork for Mac (V7)
	UWORD	xfi_UnixProtect * protection bits for Unix (V11)
	UBYTE	xfi_DosProtect	* protection bits for MS-DOS (V11)
	UBYTE	xfi_FileType	* XADFILETYPE to define type of exe files (V11)
	APTR	xfi_Special	* pointer to special data (V11)

* These are used for xfi_FileType to define file type. (V11)
XADFILETYPE_DATACRUNCHER     EQU	 1 * infile was only one data file
XADFILETYPE_TEXTLINKER	     EQU	 2 * infile was text-linked

XADFILETYPE_AMIGAEXECRUNCHER EQU	11 * infile was an Amiga exe cruncher
XADFILETYPE_AMIGAEXELINKER   EQU	12 * infile was an Amiga exe linker
XADFILETYPE_AMIGATEXTLINKER  EQU	13 * infile was an Amiga text-exe linker
XADFILETYPE_AMIGAADDRESS     EQU	14 * infile was an Amiga address cruncher

XADFILETYPE_UNIXBLOCKDEVICE  EQU	21 * this file is a block device
XADFILETYPE_UNIXCHARDEVICE   EQU	22 * this file is a character device
XADFILETYPE_UNIXFIFO	     EQU	23 * this file is a named pipe
XADFILETYPE_UNIXSOCKET	     EQU	24 * this file is a socket

XADFILETYPE_MSDOSEXECRUNCHER EQU	31 * infile was an MSDOS exe cruncher

XADSPECIALTYPE_UNIXDEVICE    EQU	1 * xadSpecial entry is xadSpecialUnixDevice
XADSPECIALTYPE_AMIGAADDRESS  EQU	2 * xadSpecial entry is xadSpecialAmigaAddress

	STRUCTURE xadSpecial,0
	ULONG	xfis_Type		* XADSPECIALTYPE to define type of block (V11)
	APTR	xfis_Next		* pointer to next entry
	LABEL	xadSPECIAL_BASESIZE

	STRUCTURE xadSpecialUnixDevice,xadSPECIAL_BASESIZE
	ULONG xfis_MajorVersion 	* major device version
	ULONG xfis_MinorVersion 	* minor device version

	STRUCTURE xadSpecialAmigaAddress,xadSPECIAL_BASESIZE
	ULONG xfis_JumpAddress		* code execution start address
	ULONG xfis_DecrunchAddress	* decrunch start of code

	STRUCTURE xadSpecialCBM8bit,xadSPECIAL_BASESIZE
	UBYTE xfis_FileType		* File type XADCBM8BITTYPE_xxx
	UBYTE xfis_RecordLength 	* record length if relative file
XADCBM8BITTYPE_UNKNOWN	EQU	$00	*	 Unknown / Unused 
XADCBM8BITTYPE_BASIC	EQU	$01	* Tape - BASIC program file
XADCBM8BITTYPE_DATA	EQU	$02	* Tape - Data block (SEQ file)
XADCBM8BITTYPE_FIXED	EQU	$03	* Tape - Fixed addres program file
XADCBM8BITTYPE_SEQDATA	EQU	$04	* Tape - Sequential data file
XADCBM8BITTYPE_SEQ	EQU	$81	* Disk - Sequential file "SEQ"
XADCBM8BITTYPE_PRG	EQU	$82	* Disk - Program file "PRG"
XADCBM8BITTYPE_USR	EQU	$83	* Disk - User-defined file "USR"
XADCBM8BITTYPE_REL	EQU	$84	* Disk - Relative records file "REL"
XADCBM8BITTYPE_CBM	EQU	$85	* Disk - CBM (partition) "CBM"

* Multiuser fields (xfi_OwnerUID, xfi_OwnerUID, xfi_UserName, xfi_GroupName)
* and multiuser bits (see <dos/dos.h>) are currently not supported with normal
* Amiga filesystem. But the clients support them, if archive format holds
* such information.

* The protection bits (all 3 fields) should always be set using the
* xadConvertProtection procedure. Call it with as much protection information
* as possible. It extracts the relevant data at best (and also sets the 2 flags).
* DO NOT USE these fields directly, but always through xadConvertProtection
* call.

	BITDEF XADFI,CRYPTED,0		* entry is crypted
	BITDEF XADFI,DIRECTORY,1	* entry is a directory
	BITDEF XADFI,LINK,2		* entry is a link
	BITDEF XADFI,INFOTEXT,3 	* file is an information text
	BITDEF XADFI,GROUPED,4		* file is in a crunch group
	BITDEF XADFI,ENDOFGROUP,5	* crunch group ends here
	BITDEF XADFI,NODATE,6		* no date supported, CURRENT date is set
	BITDEF XADFI,DELETED,7		* file is marked as deleted (V3)
	BITDEF XADFI,SEEKDATAPOS,8	* before unarchiving the datapos is set (V3)
	BITDEF XADFI,NOFILENAME,9	* there was no filename, using internal one (V6)
	BITDEF XADFI,NOUNCRUNCHSIZE,10	* file size is unknown and thus set to zero (V6)
	BITDEF XADFI,PARTIALFILE,11	* file is only partial (V6)
	BITDEF XADFI,MACDATA,12 	* file is Apple data fork (V7)
	BITDEF XADFI,MACRESOURCE,13	* file is Apple resource fork (V7)
	BITDEF XADFI,EXTRACTONBUILD,14	* allows extract file during scanning (V10)
	BITDEF XADFI,UNIXPROTECTION,15	* UNIX protection bits are present (V11)
	BITDEF XADFI,DOSPROTECTION,16	* MSDOS protection bits are present (V11)
	BITDEF XADFI,ENTRYMAYCHANGE,17	* this entry may change until GetInfo is finished (V11)
	BITDEF XADFI,XADSTRFILENAME,18	* the xfi_FileName fields is an XAD string (V12)
	BITDEF XADFI,XADSTRLINKNAME,19	* the xfi_LinkName fields is an XAD string (V12)
	BITDEF XADFI,XADSTRCOMMENT,20	* the xfi_Comment fields is an XAD string (V12)

* NOTE: the texts passed with that structure must not always be printable.
* Although the clients should add an additional (not counted) zero at the text
* end, the whole file may contain other unprintable stuff (e.g. for DMS).
* So when printing this texts do it on a byte for byte base including
* printability checks.

	STRUCTURE xadTextInfo,0
	APTR	xti_Next
	ULONG	xti_Size	* maybe zero - no text - e.g. when crypted
	APTR	xti_Text	* and there is no password in xadGetInfo()
	ULONG	xti_Flags	* see XADTIF_xxx defines

	BITDEF	XADTI,CRYPTED,0 * entry is empty, as data was crypted
	BITDEF	XADTI,BANNER,1	* text is a banner
	BITDEF	XADTI,FILEDIZ,2 * text is a file description

	STRUCTURE xadDiskInfo,0
	APTR	xdi_Next
	ULONG	xdi_EntryNumber 	* number of entry
	APTR	xdi_EntryInfo		* additional archiver text
	APTR	xdi_PrivateInfo 	* client private, see XAD_OBJPRIVINFOSIZE
	ULONG	xdi_Flags		* see XADDIF_xxx defines
	ULONG	xdi_SectorSize
	ULONG	xdi_TotalSectors	* see devices/trackdisk.h
	ULONG	xdi_Cylinders		* to find out what these
	ULONG	xdi_CylSectors		* fields mean, they are equal
	ULONG	xdi_Heads		* to struct DriveGeometry
	ULONG	xdi_TrackSectors
	ULONG	xdi_LowCyl		* lowest cylinder stored
	ULONG	xdi_HighCyl		* highest cylinder stored
	ULONG	xdi_BlockInfoSize	* number of BlockInfo entries
	APTR	xdi_BlockInfo		* see XADBIF_xxx defines and XAD_OBJBLOCKENTRIES tag
	APTR	xdi_TextInfo		* linked list with info texts
	ULONG	xdi_DataPos		* crunched data position (V3)

* BlockInfo points to a UBYTE field for every track from first sector of
* lowest cylinder to last sector of highest cylinder. When not used,
* pointer must be 0. Do not use it, when there are no entries!
* This is just for information. The applications still asks the client
* to unarchive whole cylinders and not archived blocks are cleared for
* unarchiving.
	BITDEF XADDI,CRYPTED,0		* entry is crypted
	BITDEF XADDI,SEEKDATAPOS,1	* before unarchiving the datapos is set (V3)
	BITDEF XADDI,SECTORLABELS,2	* the clients delivers sector labels (V9)
	BITDEF XADDI,EXTRACTONBUILD,3	* allows extract disk during scanning (V10)
	BITDEF XADDI,ENTRYMAYCHANGE,4	* this entry may change until GetInfo is finished (V11)

* Some of the crunchers do not store all necessary information, so it
* may be needed to guess some of them. Set the following flags in that case
* and geometry check will ignore these fields.
	BITDEF XADDI,GUESSSECTORSIZE,5	  * sectorsize is guessed (V10)
	BITDEF XADDI,GUESSTOTALSECTORS,6  * totalsectors number is guessed (V10)
	BITDEF XADDI,GUESSCYLINDERS,7	  * cylinder number is guessed
	BITDEF XADDI,GUESSCYLSECTORS,8	  * cylsectors is guessed
	BITDEF XADDI,GUESSHEADS,9	  * number of heads is guessed
	BITDEF XADDI,GUESSTRACKSECTORS,10 * tracksectors is guessed
	BITDEF XADDI,GUESSLOWCYL,11	  * lowcyl is guessed
	BITDEF XADDI,GUESSHIGHCYL,12	  * highcyl is guessed

* If it is impossible to set some of the fields, you need to set some of
* these flags. NOTE: XADDIB_NOCYLINDERS is really important, as this turns
* off usage of lowcyl and highcyl keywords. When you have cylinder information,
* you should not use these and instead use guess flags and calculate
* possible values for the missing fields.
	BITDEF XADDI,NOCYLINDERS,15	* cylinder number is not set
	BITDEF XADDI,NOCYLSECTORS,16	* cylsectors is not set
	BITDEF XADDI,NOHEADS,17 	* number of heads is not set
	BITDEF XADDI,NOTRACKSECTORS,18	* tracksectors is not set
	BITDEF XADDI,NOLOWCYL,19	* lowcyl is not set
	BITDEF XADDI,NOHIGHCYL,20	* highcyl is not set

* defines for BlockInfo
	BITDEF XADBI,CLEARED,0	* this block was cleared for archiving
	BITDEF XADBI,UNUSED,1	* this block was not archived

*************************************************************************
*									*
*    progress report stuff						*
*									*
*************************************************************************

	STRUCTURE xadProgressInfo,0
	ULONG	xpi_Mode	* work modus
	APTR	xpi_Client	* the client doing the work
	APTR	xpi_DiskInfo	* current diskinfo, for disks
	APTR	xpi_FileInfo	* current info for files
	ULONG	xpi_CurrentSize * current filesize
	ULONG	xpi_LowCyl	* for disks only
	ULONG	xpi_HighCyl	* for disks only
	ULONG	xpi_Status	* see XADPIF flags
	LONG	xpi_Error	* any of the error codes
	APTR	xpi_FileName	* name of file to overwrite (V2)
	APTR	xpi_NewName	* new name buffer, passed by hook (V2)
* NOTE: For disks CurrentSize is Sector*SectorSize, where SectorSize can
* be found in xadDiskInfo structure. So you may output the sector value.

* different progress modes
XADPMODE_ASK		EQU	1
XADPMODE_PROGRESS	EQU	2
XADPMODE_END		EQU	3
XADPMODE_ERROR		EQU	4
XADPMODE_NEWENTRY	EQU	5 * (V10)
XADPMODE_GETINFOEND	EQU	6 * (V11)

* flags for progress hook and ProgressInfo status field
	BITDEF XADPI,OVERWRITE,0	* overwrite the file
	BITDEF XADPI,MAKEDIRECTORY,1	* create the directory
	BITDEF XADPI,IGNOREGEOMETRY,2	* ignore drive geometry
	BITDEF XADPI,ISDIRECTORY,3	* destination is a directory (V10)
	BITDEF XADPI,RENAME,10		* rename the file (V2)
	BITDEF XADPI,OK,16		* all ok, proceed
	BITDEF XADPI,SKIP,17		* skip file

*************************************************************************
*									*
*    errors								*
*									*
*************************************************************************

XADERR_OK		EQU	$0000 * no error
XADERR_UNKNOWN		EQU	$0001 * unknown error
XADERR_INPUT		EQU	$0002 * input data buffers border exceeded
XADERR_OUTPUT		EQU	$0003 * output data buffers border exceeded
XADERR_BADPARAMS	EQU	$0004 * function called with illegal parameters
XADERR_NOMEMORY 	EQU	$0005 * not enough memory available
XADERR_ILLEGALDATA	EQU	$0006 * data is corrupted
XADERR_NOTSUPPORTED	EQU	$0007 * command is not supported
XADERR_RESOURCE 	EQU	$0008 * required resource missing
XADERR_DECRUNCH 	EQU	$0009 * error on decrunching
XADERR_FILETYPE 	EQU	$000A * unknown file type
XADERR_OPENFILE 	EQU	$000B * opening file failed
XADERR_SKIP		EQU	$000C * file, disk has been skipped
XADERR_BREAK		EQU	$000D * user break in progress hook
XADERR_FILEEXISTS	EQU	$000E * file already exists
XADERR_PASSWORD 	EQU	$000F * missing or wrong password
XADERR_MAKEDIR		EQU	$0010 * could not create directory
XADERR_CHECKSUM 	EQU	$0011 * wrong checksum
XADERR_VERIFY		EQU	$0012 * verify failed (disk hook)
XADERR_GEOMETRY 	EQU	$0013 * wrong drive geometry
XADERR_DATAFORMAT	EQU	$0014 * unknown data format
XADERR_EMPTY		EQU	$0015 * source file contains no files
XADERR_FILESYSTEM	EQU	$0016 * unknown filesystem
XADERR_FILEDIR		EQU	$0017 * name of file exists as directory
XADERR_SHORTBUFFER	EQU	$0018 * buffer was too short
XADERR_ENCODING 	EQU	$0019 * text encoding was defective

*************************************************************************
*									*
*    characterset and filename conversion				*
*									*
*************************************************************************

CHARSET_HOST			  EQU	  0 * this is the ONLY destination setting for clients!

CHARSET_UNICODE_UCS2_HOST	  EQU	 10 * 16bit Unicode (usually no source type)
CHARSET_UNICODE_UCS2_BIGENDIAN	  EQU	 11 * 16bit Unicode big endian storage
CHARSET_UNICODE_UCS2_LITTLEENDIAN EQU	 12 * 16bit Unicode little endian storage
CHARSET_UNICODE_UTF8		  EQU	 13 * variable size unicode encoding

* all the 1xx types are generic types which also maybe a bit dynamic
CHARSET_AMIGA			  EQU	100 * the default Amiga charset
CHARSET_MSDOS 			  EQU	101 * the default MSDOS charset
CHARSET_MACOS 			  EQU	102 * the default MacOS charset
CHARSET_C64			  EQU	103 * the default C64 charset
CHARSET_ATARI_ST		  EQU	104 * the default Atari ST charset
CHARSET_WINDOWS			  EQU	105 * the default Windows charset

* all the 2xx to 9xx types are real charsets, use them whenever you know
* what the data really is
CHARSET_ASCII			  EQU	200 * the lower 7 bits of ASCII charsets
CHARSET_ISO_8859_1		  EQU	201 * the base charset
CHARSET_ISO_8859_15		  EQU	215 * Euro-sign fixed ISO variant
CHARSET_ATARI_ST_US		  EQU	300 * Atari ST (US) charset
CHARSET_PETSCII_C64_LC		  EQU	301 * C64 lower case charset
CHARSET_CODEPAGE_437		  EQU	400 * IBM Codepage 437 charset
CHARSET_CODEPAGE_1252		  EQU	401 * Windows Codepage 1252 charset

*************************************************************************
*									*
*    client related stuff						*
*									*
*************************************************************************

	STRUCTURE xadForeman,0
	ULONG	xfm_Security	* should be XADFOREMAN_SECURITY
	ULONG	xfm_ID		* must be XADFOREMAN_ID
	UWORD	xfm_Version	* set to XADFOREMAN_VERSION
	UWORD	xfm_Reserved
	APTR	xfm_VersString	* pointer to $VER: string
	APTR	xfm_FirstClient * pointer to first client
	LABEL	xadForman_SIZE

XADFOREMAN_SECURITY	EQU	$70FF4E75 * MOVEQ #-1,D0 and RTS
XADFOREMAN_ID		EQU	$58414446 * 'XADF' identification ID
XADFOREMAN_VERSION	EQU	1

	STRUCTURE xadClient,0
	APTR	xc_Next
	UWORD	xc_Version	* set to XADCLIENT_VERSION
	UWORD	xc_MasterVersion
	UWORD	xc_ClientVersion
	UWORD	xc_ClientRevision
	ULONG	xc_RecogSize	* needed size to recog the type
	ULONG	xc_Flags	* see XADCF_xxx defines
	ULONG	xc_Identifier	* ID of internal clients
	APTR	xc_ArchiverName
	APTR	xc_RecogData
	APTR	xc_GetInfo
	APTR	xc_UnArchive
	APTR	xc_Free
	LABEL	xadClient_SIZE

* function interface
* ASM(BOOL) xc_RecogData(REG(d0, ULONG size), REG(a0, STRPTR data),
*		REG(a6, struct xadMasterBase *xadMasterBase))
* ASM(LONG) xc_GetInfo(REG(a0, struct xadArchiveInfo *ai),
*		REG(a6, struct xadMasterBase *xadMasterBase))
* ASM(LONG) xc_UnArchive(REG(a0, struct xadArchiveInfo *ai),
*		REG(a6, struct xadMasterBase *xadMasterBase))
* ASM(void) xc_Free(REG(a0, struct xadArchiveInfo *ai),
*		REG(a6, struct xadMasterBase *xadMasterBase))


* xc_RecogData returns 1 when recognized and 0 when not, all the others
* return 0 when ok and XADERR values on error. xc_Free has no return
* value.

* Filesystem clients need to clear xc_RecogSize and xc_RecogData. The
* recognition is automatically done by GetInfo. XADERR_FILESYSTEM is
* returned in case of unknown format. If it is known detection should
* go on and any other code may be returned, if it fails.
* The field xc_ArchiverName means xc_FileSystemName for filesystem
* clients.

XADCLIENT_VERSION	EQU	1

	BITDEF XADC,FILEARCHIVER,0	* archiver is a file archiver
	BITDEF XADC,DISKARCHIVER,1	* archiver is a disk archiver
	BITDEF XADC,EXTERN,2		* external client, set by xadmaster
	BITDEF XADC,FILESYSTEM,3	* filesystem clients (V5)
	BITDEF XADC,NOCHECKSIZE,4	* do not check size for recog call (V6)
	BITDEF XADC,DATACRUNCHER,5	* file archiver is plain data file (V11)
	BITDEF XADC,EXECRUNCHER,6	* file archiver is executable file (V11)
	BITDEF XADC,ADDRESSCRUNCHER,7	* file archiver is address crunched file (V11)
	BITDEF XADC,LINKER,8		* file archiver is a linker file (V11)
	BITDEF XADC,FREEXADSTRINGS,25	* master frees XAD strings (V12)
	BITDEF XADC,FREESPECIALINFO,26	* master frees xadSpecial  structures (V11)
	BITDEF XADC,FREESKIPINFO,27	* master frees xadSkipInfo structures (V3)
	BITDEF XADC,FREETEXTINFO,28	* master frees xadTextInfo structures (V2)
	BITDEF XADC,FREETEXTINFOTEXT,29 * master frees xadTextInfo text block (V2)
	BITDEF XADC,FREEFILEINFO,30	* master frees xadFileInfo structures (V2)
	BITDEF XADC,FREEDISKINFO,31	* master frees xadDiskInfo structures (V2)

*************************************************************************
*									*
*    client ID's							*
*									*
*************************************************************************

* If an external client has set the xc_Identifier field, the internal
* client is replaced.

* disk archivers start with 1000
XADCID_XMASH			EQU	1000
XADCID_SUPERDUPER3		EQU	1001
XADCID_XDISK			EQU	1002
XADCID_PACKDEV			EQU	1003
XADCID_ZOOM			EQU	1004
XADCID_ZOOM5			EQU	1005
XADCID_CRUNCHDISK		EQU	1006
XADCID_PACKDISK 		EQU	1007
XADCID_MDC			EQU	1008
XADCID_COMPDISK 		EQU	1009
XADCID_LHWARP			EQU	1010
XADCID_SAVAGECOMPRESSOR 	EQU	1011
XADCID_WARP			EQU	1012
XADCID_GDC			EQU	1013
XADCID_DCS			EQU	1014
XADCID_MSA			EQU	1015
XADCID_COP			EQU	1016
XADCID_DIMP			EQU	1017
XADCID_DIMPSFX			EQU	1018

* file archivers start with 5000
XADCID_TAR			EQU	5000
XADCID_SDSSFX			EQU	5001
XADCID_LZX			EQU	5002
XADCID_MXMSIMPLEARC		EQU	5003
XADCID_LHPAK			EQU	5004
XADCID_AMIGAPLUSUNPACK		EQU	5005
XADCID_AMIPACK			EQU	5006
XADCID_LHA			EQU	5007
XADCID_LHASFX			EQU	5008
XADCID_PCOMPARC 		EQU	5009
XADCID_SOMNI			EQU	5010
XADCID_LHSFX			EQU	5011
XADCID_XPKARCHIVE		EQU	5012
XADCID_SHRINK			EQU	5013
XADCID_SPACK			EQU	5014
XADCID_SPACKSFX 		EQU	5015
XADCID_ZIP			EQU	5016
XADCID_WINZIPEXE		EQU	5017
XADCID_GZIP			EQU	5018
XADCID_ARC			EQU	5019
XADCID_ZOO			EQU	5020
XADCID_LHAEXE			EQU	5021
XADCID_ARJ			EQU	5022
XADCID_ARJEXE			EQU	5023
XADCID_ZIPEXE			EQU	5024
XADCID_LHF			EQU	5025
XADCID_COMPRESS 		EQU	5026
XADCID_ACE			EQU	5027
XADCID_ACEEXE			EQU	5028
XADCID_GZIPSFX			EQU	5029
XADCID_HA			EQU	5030
XADCID_SQ			EQU	5031
XADCID_LHAC64SFX		EQU	5032
XADCID_SIT			EQU	5033
XADCID_SIT5			EQU	5034
XADCID_SIT5EXE			EQU	5035
XADCID_MACBINARY		EQU	5036
XADCID_CPIO			EQU	5037
XADCID_PACKIT			EQU	5038
XADCID_CRUNCH			EQU	5039
XADCID_ARCCBM			EQU	5040
XADCID_ARCCBMSFX		EQU	5041
XADCID_CAB			EQU	5042
XADCID_CABMSEXE			EQU	5043
XADCID_RPM			EQU	5044
XADCID_BZIP2			EQU	5045
XADCID_BZIP2SFX			EQU	5046
XADCID_BZIP			EQU	5047
XADCID_IDPAK			EQU	5048
XADCID_IDWAD			EQU	5049
XADCID_IDWAD2			EQU	5050

* filesystem client start with 8000
XADCID_FSAMIGA			EQU	8000
XADCID_FSSANITYOS		EQU	8001
XADCID_FSFAT			EQU	8002
XADCID_FSTRDOS			EQU	8003

* mixed archivers start with 9000
XADCID_DMS			EQU	9000
XADCID_DMSSFX			EQU	9001

	ENDC	; LIBRARIES_XADMASTER_I
