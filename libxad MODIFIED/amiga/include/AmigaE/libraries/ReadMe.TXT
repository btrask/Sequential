Differences between C includes and E includes


Because E does not support unsigned numbers and void pointers the following
datatypes are used:

LONG instead of ULONG
INT instead of UWORD
CHAR instead if UBYTE
PTR TO CHAR instead of APTR
PTR TO LONG instead of a pointer to a function


Because E does not support unions the following object definitions are
different in E than in C:

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

OBJECT xadSpecial
    xfis_Type:LONG              /* XADSPECIALTYPE to define type of block (V11) */
    xfis_Next:PTR TO xadSpecial /* pointer to next entry */
ENDOBJECT

Ronald van Dijk <ronaldvd@xs4all.nl>
