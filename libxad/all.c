/* 
  LzmaDecode.h
  LZMA Decoder interface

  LZMA SDK 4.21 Copyright (c) 1999-2005 Igor Pavlov (2005-06-08)
  http://www.7-zip.org/

  LZMA SDK is licensed under two licenses:
  1) GNU Lesser General Public License (GNU LGPL)
  2) Common Public License (CPL)
  It means that you can select one of these two licenses and 
  follow rules of that license.

  SPECIAL EXCEPTION:
  Igor Pavlov, as the author of this code, expressly permits you to 
  statically or dynamically link your code (or bind by name) to the 
  interfaces of this file without subjecting your linked code to the 
  terms of the CPL or GNU LGPL. Any modifications or additions 
  to this file, however, are subject to the LGPL or CPL terms.
*/

#ifndef __LZMADECODE_H
#define __LZMADECODE_H

/* #define _LZMA_IN_CB */
/* Use callback for input data */

/* #define _LZMA_OUT_READ */
/* Use read function for output data */

/* #define _LZMA_PROB32 */
/* It can increase speed on some 32-bit CPUs, 
   but memory usage will be doubled in that case */

/* #define _LZMA_LOC_OPT */
/* Enable local speed optimizations inside code */

/* #define _LZMA_SYSTEM_SIZE_T */
/* Use system's size_t. You can use it to enable 64-bit sizes supporting*/

#ifndef UInt32
#ifdef _LZMA_UINT32_IS_ULONG
#define UInt32 unsigned long
#else
#define UInt32 unsigned int
#endif
#endif

#ifndef SizeT
#ifdef _LZMA_SYSTEM_SIZE_T
#include <stddef.h>
#define SizeT size_t
#else
#define SizeT UInt32
#endif
#endif

#ifdef _LZMA_PROB32
#define CProb UInt32
#else
#define CProb unsigned short
#endif

#define LZMA_RESULT_OK 0
#define LZMA_RESULT_DATA_ERROR 1

#ifdef _LZMA_IN_CB
typedef struct _ILzmaInCallback
{
  int (*Read)(void *object, const unsigned char **buffer, SizeT *bufferSize);
} ILzmaInCallback;
#endif

#define LZMA_BASE_SIZE 1846
#define LZMA_LIT_SIZE 768

#define LZMA_PROPERTIES_SIZE 5

typedef struct _CLzmaProperties
{
  int lc;
  int lp;
  int pb;
  #ifdef _LZMA_OUT_READ
  UInt32 DictionarySize;
  #endif
}CLzmaProperties;

int LzmaDecodeProperties(CLzmaProperties *propsRes, const unsigned char *propsData, int size);

#define LzmaGetNumProbs(Properties) (LZMA_BASE_SIZE + (LZMA_LIT_SIZE << ((Properties)->lc + (Properties)->lp)))

#define kLzmaNeedInitId (-2)

typedef struct _CLzmaDecoderState
{
  CLzmaProperties Properties;
  CProb *Probs;

  #ifdef _LZMA_IN_CB
  const unsigned char *Buffer;
  const unsigned char *BufferLim;
  #endif

  #ifdef _LZMA_OUT_READ
  unsigned char *Dictionary;
  UInt32 Range;
  UInt32 Code;
  UInt32 DictionaryPos;
  UInt32 GlobalPos;
  UInt32 DistanceLimit;
  UInt32 Reps[4];
  int State;
  int RemainLen;
  unsigned char TempDictionary[4];
  #endif
} CLzmaDecoderState;

#ifdef _LZMA_OUT_READ
#define LzmaDecoderInit(vs) { (vs)->RemainLen = kLzmaNeedInitId; }
#endif

int LzmaDecode(CLzmaDecoderState *vs,
    #ifdef _LZMA_IN_CB
    ILzmaInCallback *inCallback,
    #else
    const unsigned char *inStream, SizeT inSize, SizeT *inSizeProcessed,
    #endif
    unsigned char *outStream, SizeT outSize, SizeT *outSizeProcessed);

#endif
/* 7zAlloc.h */

#ifndef __7Z_ALLOC_H
#define __7Z_ALLOC_H

#include <stddef.h>

typedef struct _ISzAlloc
{
  void *(*Alloc)(size_t size);
  void (*Free)(void *address); /* address can be 0 */
} ISzAlloc;

void *SzAlloc(size_t size);
void SzFree(void *address);

void *SzAllocTemp(size_t size);
void SzFreeTemp(void *address);

#endif
/* 7zTypes.h */

#ifndef __COMMON_TYPES_H
#define __COMMON_TYPES_H

#ifndef UInt32
#ifdef _LZMA_UINT32_IS_ULONG
#define UInt32 unsigned long
#else
#define UInt32 unsigned int
#endif
#endif

#ifndef Byte
#define Byte unsigned char
#endif

#ifndef UInt16
#define UInt16 unsigned short
#endif

/* #define _SZ_NO_INT_64 */
/* define it your compiler doesn't support long long int */

#ifdef _SZ_NO_INT_64
#define UInt64 unsigned long
#else
#ifdef _MSC_VER
#define UInt64 unsigned __int64
#else
#define UInt64 unsigned long long int
#endif
#endif


/* #define _SZ_FILE_SIZE_64 */
/* Use _SZ_FILE_SIZE_64 if you need support for files larger than 4 GB*/

#ifndef CFileSize
#ifdef _SZ_FILE_SIZE_64
#define CFileSize UInt64
#else
#define CFileSize UInt32
#endif
#endif

#define SZ_RESULT int

#define SZ_OK (0)
#define SZE_DATA_ERROR (1)
#define SZE_OUTOFMEMORY (2)
#define SZE_CRC_ERROR (3)

#define SZE_NOTIMPL (4)
#define SZE_FAIL (5)

#define SZE_ARCHIVE_ERROR (6)

#define RINOK(x) { int __result_ = (x); if(__result_ != 0) return __result_; }

#endif
/* 7zMethodID.h */

#ifndef __7Z_METHOD_ID_H
#define __7Z_METHOD_ID_H


#define kMethodIDSize 15
  
typedef struct _CMethodID
{
  Byte ID[kMethodIDSize];
  Byte IDSize;
} CMethodID;

int AreMethodsEqual(CMethodID *a1, CMethodID *a2);

#endif
/* 7zBuffer.h */

#ifndef __7Z_BUFFER_H
#define __7Z_BUFFER_H

#include <stddef.h>

typedef struct _CSzByteBuffer
{    
	size_t Capacity;
  Byte *Items;
}CSzByteBuffer;

void SzByteBufferInit(CSzByteBuffer *buffer);
int SzByteBufferCreate(CSzByteBuffer *buffer, size_t newCapacity, void * (*allocFunc)(size_t size));
void SzByteBufferFree(CSzByteBuffer *buffer, void (*freeFunc)(void *));

#endif
/* 7zHeader.h */

#ifndef __7Z_HEADER_H
#define __7Z_HEADER_H


#define k7zSignatureSize 6
extern Byte k7zSignature[k7zSignatureSize];

#define k7zMajorVersion 0

#define k7zStartHeaderSize 0x20

enum EIdEnum
{
  k7zIdEnd,
    
  k7zIdHeader,
    
  k7zIdArchiveProperties,
    
  k7zIdAdditionalStreamsInfo,
  k7zIdMainStreamsInfo,
  k7zIdFilesInfo,
  
  k7zIdPackInfo,
  k7zIdUnPackInfo,
  k7zIdSubStreamsInfo,
  
  k7zIdSize,
  k7zIdCRC,
  
  k7zIdFolder,
  
  k7zIdCodersUnPackSize,
  k7zIdNumUnPackStream,
  
  k7zIdEmptyStream,
  k7zIdEmptyFile,
  k7zIdAnti,
  
  k7zIdName,
  k7zIdCreationTime,
  k7zIdLastAccessTime,
  k7zIdLastWriteTime,
  k7zIdWinAttributes,
  k7zIdComment,
  
  k7zIdEncodedHeader,
  
  k7zIdStartPos
};

#endif
/* 7zCrc.h */

#ifndef __7Z_CRC_H
#define __7Z_CRC_H

#include <stddef.h>


extern UInt32 g_CrcTable[256];
void InitCrcTable();

void CrcInit(UInt32 *crc);
UInt32 CrcGetDigest(UInt32 *crc);
void CrcUpdateByte(UInt32 *crc, Byte v);
void CrcUpdateUInt16(UInt32 *crc, UInt16 v);
void CrcUpdateUInt32(UInt32 *crc, UInt32 v);
void CrcUpdateUInt64(UInt32 *crc, UInt64 v);
void CrcUpdate(UInt32 *crc, const void *data, size_t size);
 
UInt32 CrcCalculateDigest(const void *data, size_t size);
int CrcVerifyDigest(UInt32 digest, const void *data, size_t size);

#endif
/* 7zItem.h */

#ifndef __7Z_ITEM_H
#define __7Z_ITEM_H


typedef struct _CCoderInfo
{
  UInt32 NumInStreams;
  UInt32 NumOutStreams;
  CMethodID MethodID;
  CSzByteBuffer Properties;
}CCoderInfo;

void SzCoderInfoInit(CCoderInfo *coder);
void SzCoderInfoFree(CCoderInfo *coder, void (*freeFunc)(void *p));

typedef struct _CBindPair
{
  UInt32 InIndex;
  UInt32 OutIndex;
}CBindPair;

typedef struct _CFolder
{
  UInt32 NumCoders;
  CCoderInfo *Coders;
  UInt32 NumBindPairs;
  CBindPair *BindPairs;
  UInt32 NumPackStreams; 
  UInt32 *PackStreams;
  CFileSize *UnPackSizes;
  int UnPackCRCDefined;
  UInt32 UnPackCRC;

  UInt32 NumUnPackStreams;
}CFolder;

void SzFolderInit(CFolder *folder);
CFileSize SzFolderGetUnPackSize(CFolder *folder);
int SzFolderFindBindPairForInStream(CFolder *folder, UInt32 inStreamIndex);
UInt32 SzFolderGetNumOutStreams(CFolder *folder);
CFileSize SzFolderGetUnPackSize(CFolder *folder);

/* #define CArchiveFileTime UInt64 */

typedef struct _CFileItem
{
  /*
  CArchiveFileTime LastWriteTime;
  CFileSize StartPos;
  UInt32 Attributes; 
  */
  CFileSize Size;
  UInt32 FileCRC;
  char *Name;

  Byte IsFileCRCDefined;
  Byte HasStream;
  Byte IsDirectory;
  Byte IsAnti;
  /*
  int AreAttributesDefined;
  int IsLastWriteTimeDefined;
  int IsStartPosDefined;
  */
}CFileItem;

void SzFileInit(CFileItem *fileItem);

typedef struct _CArchiveDatabase
{
  UInt32 NumPackStreams;
  CFileSize *PackSizes;
  Byte *PackCRCsDefined;
  UInt32 *PackCRCs;
  UInt32 NumFolders;
  CFolder *Folders;
  UInt32 NumFiles;
  CFileItem *Files;
}CArchiveDatabase;

void SzArchiveDatabaseInit(CArchiveDatabase *db);
void SzArchiveDatabaseFree(CArchiveDatabase *db, void (*freeFunc)(void *));


#endif
/* 7zIn.h */

#ifndef __7Z_IN_H
#define __7Z_IN_H

 
typedef struct _CInArchiveInfo
{
  CFileSize StartPositionAfterHeader; 
  CFileSize DataStartPosition;
}CInArchiveInfo;

typedef struct _CArchiveDatabaseEx
{
  CArchiveDatabase Database;
  CInArchiveInfo ArchiveInfo;
  UInt32 *FolderStartPackStreamIndex;
  CFileSize *PackStreamStartPositions;
  UInt32 *FolderStartFileIndex;
  UInt32 *FileIndexToFolderIndexMap;
}CArchiveDatabaseEx;

void SzArDbExInit(CArchiveDatabaseEx *db);
void SzArDbExFree(CArchiveDatabaseEx *db, void (*freeFunc)(void *));
CFileSize SzArDbGetFolderStreamPos(CArchiveDatabaseEx *db, UInt32 folderIndex, UInt32 indexInFolder);
CFileSize SzArDbGetFolderFullPackSize(CArchiveDatabaseEx *db, UInt32 folderIndex);

typedef struct _ISzInStream
{
  #ifdef _LZMA_IN_CB
  SZ_RESULT (*Read)(
      void *object,           /* pointer to ISzInStream itself */
      void **buffer,          /* out: pointer to buffer with data */
      size_t maxRequiredSize, /* max required size to read */
      size_t *processedSize); /* real processed size. 
                                 processedSize can be less than maxRequiredSize.
                                 If processedSize == 0, then there are no more 
                                 bytes in stream. */
  #else
  SZ_RESULT (*Read)(void *object, void *buffer, size_t size, size_t *processedSize);
  #endif
  SZ_RESULT (*Seek)(void *object, CFileSize pos);
} ISzInStream;

 
int SzArchiveOpen(
    ISzInStream *inStream, 
    CArchiveDatabaseEx *db,
    ISzAlloc *allocMain, 
    ISzAlloc *allocTemp);
 
#endif
/* 7zExtract.h */

#ifndef __7Z_EXTRACT_H
#define __7Z_EXTRACT_H


/*
  SzExtract extracts file from archive

  *outBuffer must be 0 before first call for each new archive. 

  Extracting cache:
    If you need to decompress more than one file, you can send 
    these values from previous call:
      *blockIndex, 
      *outBuffer, 
      *outBufferSize
    You can consider "*outBuffer" as cache of solid block. If your archive is solid, 
    it will increase decompression speed.
  
    If you use external function, you can declare these 3 cache variables 
    (blockIndex, outBuffer, outBufferSize) as static in that external function.
    
    Free *outBuffer and set *outBuffer to 0, if you want to flush cache.
*/

SZ_RESULT SzExtract(
    ISzInStream *inStream, 
    CArchiveDatabaseEx *db,
    UInt32 fileIndex,         /* index of file */
    UInt32 *blockIndex,       /* index of solid block */
    Byte **outBuffer,         /* pointer to pointer to output buffer (allocated with allocMain) */
    size_t *outBufferSize,    /* buffer size for output buffer */
    size_t *offset,           /* offset of stream for required file in *outBuffer */
    size_t *outSizeProcessed, /* size of file in *outBuffer */
    ISzAlloc *allocMain,
    ISzAlloc *allocTemp);

#endif
/* 7zDecode.h */

#ifndef __7Z_DECODE_H
#define __7Z_DECODE_H

#ifdef _LZMA_IN_CB
#endif

SZ_RESULT SzDecode(const CFileSize *packSizes, const CFolder *folder,
    #ifdef _LZMA_IN_CB
    ISzInStream *stream,
    #else
    const Byte *inBuffer,
    #endif
    Byte *outBuffer, size_t outSize, 
    size_t *outSizeProcessed, ISzAlloc *allocMain);

#endif
/*
  LzmaDecode.c
  LZMA Decoder (optimized for Speed version)
  
  LZMA SDK 4.22 Copyright (c) 1999-2005 Igor Pavlov (2005-06-10)
  http://www.7-zip.org/

  LZMA SDK is licensed under two licenses:
  1) GNU Lesser General Public License (GNU LGPL)
  2) Common Public License (CPL)
  It means that you can select one of these two licenses and 
  follow rules of that license.

  SPECIAL EXCEPTION:
  Igor Pavlov, as the author of this Code, expressly permits you to 
  statically or dynamically link your Code (or bind by name) to the 
  interfaces of this file without subjecting your linked Code to the 
  terms of the CPL or GNU LGPL. Any modifications or additions 
  to this file, however, are subject to the LGPL or CPL terms.
*/


#ifndef Byte
#define Byte unsigned char
#endif

#define kNumTopBits 24
#define kTopValue ((UInt32)1 << kNumTopBits)

#define kNumBitModelTotalBits 11
#define kBitModelTotal (1 << kNumBitModelTotalBits)
#define kNumMoveBits 5

#define RC_READ_BYTE (*Buffer++)

#define RC_INIT2 Code = 0; Range = 0xFFFFFFFF; \
  { int i; for(i = 0; i < 5; i++) { RC_TEST; Code = (Code << 8) | RC_READ_BYTE; }}

#ifdef _LZMA_IN_CB

#define RC_TEST { if (Buffer == BufferLim) \
  { SizeT size; int result = InCallback->Read(InCallback, &Buffer, &size); if (result != LZMA_RESULT_OK) return result; \
  BufferLim = Buffer + size; if (size == 0) return LZMA_RESULT_DATA_ERROR; }}

#define RC_INIT Buffer = BufferLim = 0; RC_INIT2

#else

#define RC_TEST { if (Buffer == BufferLim) return LZMA_RESULT_DATA_ERROR; }

#define RC_INIT(buffer, bufferSize) Buffer = buffer; BufferLim = buffer + bufferSize; RC_INIT2
 
#endif

#define RC_NORMALIZE if (Range < kTopValue) { RC_TEST; Range <<= 8; Code = (Code << 8) | RC_READ_BYTE; }

#define IfBit0(p) RC_NORMALIZE; bound = (Range >> kNumBitModelTotalBits) * *(p); if (Code < bound)
#define UpdateBit0(p) Range = bound; *(p) += (kBitModelTotal - *(p)) >> kNumMoveBits;
#define UpdateBit1(p) Range -= bound; Code -= bound; *(p) -= (*(p)) >> kNumMoveBits;

#define RC_GET_BIT2(p, mi, A0, A1) IfBit0(p) \
  { UpdateBit0(p); mi <<= 1; A0; } else \
  { UpdateBit1(p); mi = (mi + mi) + 1; A1; } 
  
#define RC_GET_BIT(p, mi) RC_GET_BIT2(p, mi, ; , ;)               

#define RangeDecoderBitTreeDecode(probs, numLevels, res) \
  { int i = numLevels; res = 1; \
  do { CProb *p = probs + res; RC_GET_BIT(p, res) } while(--i != 0); \
  res -= (1 << numLevels); }


#define kNumPosBitsMax 4
#define kNumPosStatesMax (1 << kNumPosBitsMax)

#define kLenNumLowBits 3
#define kLenNumLowSymbols (1 << kLenNumLowBits)
#define kLenNumMidBits 3
#define kLenNumMidSymbols (1 << kLenNumMidBits)
#define kLenNumHighBits 8
#define kLenNumHighSymbols (1 << kLenNumHighBits)

#define LenChoice 0
#define LenChoice2 (LenChoice + 1)
#define LenLow (LenChoice2 + 1)
#define LenMid (LenLow + (kNumPosStatesMax << kLenNumLowBits))
#define LenHigh (LenMid + (kNumPosStatesMax << kLenNumMidBits))
#define kNumLenProbs (LenHigh + kLenNumHighSymbols) 


#define kNumStates 12
#define kNumLitStates 7

#define kStartPosModelIndex 4
#define kEndPosModelIndex 14
#define kNumFullDistances (1 << (kEndPosModelIndex >> 1))

#define kNumPosSlotBits 6
#define kNumLenToPosStates 4

#define kNumAlignBits 4
#define kAlignTableSize (1 << kNumAlignBits)

#define kMatchMinLen 2

#define IsMatch 0
#define IsRep (IsMatch + (kNumStates << kNumPosBitsMax))
#define IsRepG0 (IsRep + kNumStates)
#define IsRepG1 (IsRepG0 + kNumStates)
#define IsRepG2 (IsRepG1 + kNumStates)
#define IsRep0Long (IsRepG2 + kNumStates)
#define PosSlot (IsRep0Long + (kNumStates << kNumPosBitsMax))
#define SpecPos (PosSlot + (kNumLenToPosStates << kNumPosSlotBits))
#define Align (SpecPos + kNumFullDistances - kEndPosModelIndex)
#define LenCoder (Align + kAlignTableSize)
#define RepLenCoder (LenCoder + kNumLenProbs)
#define Literal (RepLenCoder + kNumLenProbs)

#if Literal != LZMA_BASE_SIZE
StopCompilingDueBUG
#endif

int LzmaDecodeProperties(CLzmaProperties *propsRes, const unsigned char *propsData, int size)
{
  unsigned char prop0;
  if (size < LZMA_PROPERTIES_SIZE)
    return LZMA_RESULT_DATA_ERROR;
  prop0 = propsData[0];
  if (prop0 >= (9 * 5 * 5))
    return LZMA_RESULT_DATA_ERROR;
  {
    for (propsRes->pb = 0; prop0 >= (9 * 5); propsRes->pb++, prop0 -= (9 * 5));
    for (propsRes->lp = 0; prop0 >= 9; propsRes->lp++, prop0 -= 9);
    propsRes->lc = prop0;
    /*
    unsigned char remainder = (unsigned char)(prop0 / 9);
    propsRes->lc = prop0 % 9;
    propsRes->pb = remainder / 5;
    propsRes->lp = remainder % 5;
    */
  }

  #ifdef _LZMA_OUT_READ
  {
    int i;
    propsRes->DictionarySize = 0;
    for (i = 0; i < 4; i++)
      propsRes->DictionarySize += (UInt32)(propsData[1 + i]) << (i * 8);
    if (propsRes->DictionarySize == 0)
      propsRes->DictionarySize = 1;
  }
  #endif
  return LZMA_RESULT_OK;
}

#define kLzmaStreamWasFinishedId (-1)

int LzmaDecode(CLzmaDecoderState *vs,
    #ifdef _LZMA_IN_CB
    ILzmaInCallback *InCallback,
    #else
    const unsigned char *inStream, SizeT inSize, SizeT *inSizeProcessed,
    #endif
    unsigned char *outStream, SizeT outSize, SizeT *outSizeProcessed)
{
  CProb *p = vs->Probs;
  SizeT nowPos = 0;
  Byte previousByte = 0;
  UInt32 posStateMask = (1 << (vs->Properties.pb)) - 1;
  UInt32 literalPosMask = (1 << (vs->Properties.lp)) - 1;
  int lc = vs->Properties.lc;

  #ifdef _LZMA_OUT_READ
  
  UInt32 Range = vs->Range;
  UInt32 Code = vs->Code;
  #ifdef _LZMA_IN_CB
  const Byte *Buffer = vs->Buffer;
  const Byte *BufferLim = vs->BufferLim;
  #else
  const Byte *Buffer = inStream;
  const Byte *BufferLim = inStream + inSize;
  #endif
  int state = vs->State;
  UInt32 rep0 = vs->Reps[0], rep1 = vs->Reps[1], rep2 = vs->Reps[2], rep3 = vs->Reps[3];
  int len = vs->RemainLen;
  UInt32 globalPos = vs->GlobalPos;
  UInt32 distanceLimit = vs->DistanceLimit;

  Byte *dictionary = vs->Dictionary;
  UInt32 dictionarySize = vs->Properties.DictionarySize;
  UInt32 dictionaryPos = vs->DictionaryPos;

  Byte tempDictionary[4];

  #ifndef _LZMA_IN_CB
  *inSizeProcessed = 0;
  #endif
  *outSizeProcessed = 0;
  if (len == kLzmaStreamWasFinishedId)
    return LZMA_RESULT_OK;

  if (dictionarySize == 0)
  {
    dictionary = tempDictionary;
    dictionarySize = 1;
    tempDictionary[0] = vs->TempDictionary[0];
  }

  if (len == kLzmaNeedInitId)
  {
    {
      UInt32 numProbs = Literal + ((UInt32)LZMA_LIT_SIZE << (lc + vs->Properties.lp));
      UInt32 i;
      for (i = 0; i < numProbs; i++)
        p[i] = kBitModelTotal >> 1; 
      rep0 = rep1 = rep2 = rep3 = 1;
      state = 0;
      globalPos = 0;
      distanceLimit = 0;
      dictionaryPos = 0;
      dictionary[dictionarySize - 1] = 0;
      #ifdef _LZMA_IN_CB
      RC_INIT;
      #else
      RC_INIT(inStream, inSize);
      #endif
    }
    len = 0;
  }
  while(len != 0 && nowPos < outSize)
  {
    UInt32 pos = dictionaryPos - rep0;
    if (pos >= dictionarySize)
      pos += dictionarySize;
    outStream[nowPos++] = dictionary[dictionaryPos] = dictionary[pos];
    if (++dictionaryPos == dictionarySize)
      dictionaryPos = 0;
    len--;
  }
  if (dictionaryPos == 0)
    previousByte = dictionary[dictionarySize - 1];
  else
    previousByte = dictionary[dictionaryPos - 1];

  #else /* if !_LZMA_OUT_READ */

  int state = 0;
  UInt32 rep0 = 1, rep1 = 1, rep2 = 1, rep3 = 1;
  int len = 0;
  const Byte *Buffer;
  const Byte *BufferLim;
  UInt32 Range;
  UInt32 Code;

  #ifndef _LZMA_IN_CB
  *inSizeProcessed = 0;
  #endif
  *outSizeProcessed = 0;

  {
    UInt32 i;
    UInt32 numProbs = Literal + ((UInt32)LZMA_LIT_SIZE << (lc + vs->Properties.lp));
    for (i = 0; i < numProbs; i++)
      p[i] = kBitModelTotal >> 1;
  }
  
  #ifdef _LZMA_IN_CB
  RC_INIT;
  #else
  RC_INIT(inStream, inSize);
  #endif

  #endif /* _LZMA_OUT_READ */

  while(nowPos < outSize)
  {
    CProb *prob;
    UInt32 bound;
    int posState = (int)(
        (nowPos 
        #ifdef _LZMA_OUT_READ
        + globalPos
        #endif
        )
        & posStateMask);

    prob = p + IsMatch + (state << kNumPosBitsMax) + posState;
    IfBit0(prob)
    {
      int symbol = 1;
      UpdateBit0(prob)
      prob = p + Literal + (LZMA_LIT_SIZE * 
        (((
        (nowPos 
        #ifdef _LZMA_OUT_READ
        + globalPos
        #endif
        )
        & literalPosMask) << lc) + (previousByte >> (8 - lc))));

      if (state >= kNumLitStates)
      {
        int matchByte;
        #ifdef _LZMA_OUT_READ
        UInt32 pos = dictionaryPos - rep0;
        if (pos >= dictionarySize)
          pos += dictionarySize;
        matchByte = dictionary[pos];
        #else
        matchByte = outStream[nowPos - rep0];
        #endif
        do
        {
          int bit;
          CProb *probLit;
          matchByte <<= 1;
          bit = (matchByte & 0x100);
          probLit = prob + 0x100 + bit + symbol;
          RC_GET_BIT2(probLit, symbol, if (bit != 0) break, if (bit == 0) break)
        }
        while (symbol < 0x100);
      }
      while (symbol < 0x100)
      {
        CProb *probLit = prob + symbol;
        RC_GET_BIT(probLit, symbol)
      }
      previousByte = (Byte)symbol;

      outStream[nowPos++] = previousByte;
      #ifdef _LZMA_OUT_READ
      if (distanceLimit < dictionarySize)
        distanceLimit++;

      dictionary[dictionaryPos] = previousByte;
      if (++dictionaryPos == dictionarySize)
        dictionaryPos = 0;
      #endif
      if (state < 4) state = 0;
      else if (state < 10) state -= 3;
      else state -= 6;
    }
    else             
    {
      UpdateBit1(prob);
      prob = p + IsRep + state;
      IfBit0(prob)
      {
        UpdateBit0(prob);
        rep3 = rep2;
        rep2 = rep1;
        rep1 = rep0;
        state = state < kNumLitStates ? 0 : 3;
        prob = p + LenCoder;
      }
      else
      {
        UpdateBit1(prob);
        prob = p + IsRepG0 + state;
        IfBit0(prob)
        {
          UpdateBit0(prob);
          prob = p + IsRep0Long + (state << kNumPosBitsMax) + posState;
          IfBit0(prob)
          {
            #ifdef _LZMA_OUT_READ
            UInt32 pos;
            #endif
            UpdateBit0(prob);
            
            #ifdef _LZMA_OUT_READ
            if (distanceLimit == 0)
            #else
            if (nowPos == 0)
            #endif
              return LZMA_RESULT_DATA_ERROR;
            
            state = state < kNumLitStates ? 9 : 11;
            #ifdef _LZMA_OUT_READ
            pos = dictionaryPos - rep0;
            if (pos >= dictionarySize)
              pos += dictionarySize;
            previousByte = dictionary[pos];
            dictionary[dictionaryPos] = previousByte;
            if (++dictionaryPos == dictionarySize)
              dictionaryPos = 0;
            #else
            previousByte = outStream[nowPos - rep0];
            #endif
            outStream[nowPos++] = previousByte;
            #ifdef _LZMA_OUT_READ
            if (distanceLimit < dictionarySize)
              distanceLimit++;
            #endif

            continue;
          }
          else
          {
            UpdateBit1(prob);
          }
        }
        else
        {
          UInt32 distance;
          UpdateBit1(prob);
          prob = p + IsRepG1 + state;
          IfBit0(prob)
          {
            UpdateBit0(prob);
            distance = rep1;
          }
          else 
          {
            UpdateBit1(prob);
            prob = p + IsRepG2 + state;
            IfBit0(prob)
            {
              UpdateBit0(prob);
              distance = rep2;
            }
            else
            {
              UpdateBit1(prob);
              distance = rep3;
              rep3 = rep2;
            }
            rep2 = rep1;
          }
          rep1 = rep0;
          rep0 = distance;
        }
        state = state < kNumLitStates ? 8 : 11;
        prob = p + RepLenCoder;
      }
      {
        int numBits, offset;
        CProb *probLen = prob + LenChoice;
        IfBit0(probLen)
        {
          UpdateBit0(probLen);
          probLen = prob + LenLow + (posState << kLenNumLowBits);
          offset = 0;
          numBits = kLenNumLowBits;
        }
        else
        {
          UpdateBit1(probLen);
          probLen = prob + LenChoice2;
          IfBit0(probLen)
          {
            UpdateBit0(probLen);
            probLen = prob + LenMid + (posState << kLenNumMidBits);
            offset = kLenNumLowSymbols;
            numBits = kLenNumMidBits;
          }
          else
          {
            UpdateBit1(probLen);
            probLen = prob + LenHigh;
            offset = kLenNumLowSymbols + kLenNumMidSymbols;
            numBits = kLenNumHighBits;
          }
        }
        RangeDecoderBitTreeDecode(probLen, numBits, len);
        len += offset;
      }

      if (state < 4)
      {
        int posSlot;
        state += kNumLitStates;
        prob = p + PosSlot +
            ((len < kNumLenToPosStates ? len : kNumLenToPosStates - 1) << 
            kNumPosSlotBits);
        RangeDecoderBitTreeDecode(prob, kNumPosSlotBits, posSlot);
        if (posSlot >= kStartPosModelIndex)
        {
          int numDirectBits = ((posSlot >> 1) - 1);
          rep0 = (2 | ((UInt32)posSlot & 1));
          if (posSlot < kEndPosModelIndex)
          {
            rep0 <<= numDirectBits;
            prob = p + SpecPos + rep0 - posSlot - 1;
          }
          else
          {
            numDirectBits -= kNumAlignBits;
            do
            {
              RC_NORMALIZE
              Range >>= 1;
              rep0 <<= 1;
              if (Code >= Range)
              {
                Code -= Range;
                rep0 |= 1;
              }
            }
            while (--numDirectBits != 0);
            prob = p + Align;
            rep0 <<= kNumAlignBits;
            numDirectBits = kNumAlignBits;
          }
          {
            int i = 1;
            int mi = 1;
            do
            {
              CProb *prob3 = prob + mi;
              RC_GET_BIT2(prob3, mi, ; , rep0 |= i);
              i <<= 1;
            }
            while(--numDirectBits != 0);
          }
        }
        else
          rep0 = posSlot;
        if (++rep0 == (UInt32)(0))
        {
          /* it's for stream version */
          len = kLzmaStreamWasFinishedId;
          break;
        }
      }

      len += kMatchMinLen;
      #ifdef _LZMA_OUT_READ
      if (rep0 > distanceLimit) 
      #else
      if (rep0 > nowPos)
      #endif
        return LZMA_RESULT_DATA_ERROR;

      #ifdef _LZMA_OUT_READ
      if (dictionarySize - distanceLimit > (UInt32)len)
        distanceLimit += len;
      else
        distanceLimit = dictionarySize;
      #endif

      do
      {
        #ifdef _LZMA_OUT_READ
        UInt32 pos = dictionaryPos - rep0;
        if (pos >= dictionarySize)
          pos += dictionarySize;
        previousByte = dictionary[pos];
        dictionary[dictionaryPos] = previousByte;
        if (++dictionaryPos == dictionarySize)
          dictionaryPos = 0;
        #else
        previousByte = outStream[nowPos - rep0];
        #endif
        len--;
        outStream[nowPos++] = previousByte;
      }
      while(len != 0 && nowPos < outSize);
    }
  }
  RC_NORMALIZE;

  #ifdef _LZMA_OUT_READ
  vs->Range = Range;
  vs->Code = Code;
  vs->DictionaryPos = dictionaryPos;
  vs->GlobalPos = globalPos + (UInt32)nowPos;
  vs->DistanceLimit = distanceLimit;
  vs->Reps[0] = rep0;
  vs->Reps[1] = rep1;
  vs->Reps[2] = rep2;
  vs->Reps[3] = rep3;
  vs->State = state;
  vs->RemainLen = len;
  vs->TempDictionary[0] = tempDictionary[0];
  #endif

  #ifdef _LZMA_IN_CB
  vs->Buffer = Buffer;
  vs->BufferLim = BufferLim;
  #else
  *inSizeProcessed = (SizeT)(Buffer - inStream);
  #endif
  *outSizeProcessed = nowPos;
  return LZMA_RESULT_OK;
}
/* 7zAlloc.c */

#include <stdlib.h>

/* #define _SZ_ALLOC_DEBUG */
/* use _SZ_ALLOC_DEBUG to debug alloc/free operations */

#ifdef _SZ_ALLOC_DEBUG

#ifdef _WIN32
#include <windows.h>
#endif
#include <stdio.h>
int g_allocCount = 0;
int g_allocCountTemp = 0;
#endif

void *SzAlloc(size_t size)
{
  if (size == 0)
    return 0;
  #ifdef _SZ_ALLOC_DEBUG
  fprintf(stderr, "\nAlloc %10d bytes; count = %10d", size, g_allocCount);
  g_allocCount++;
  #endif
  return malloc(size);
}

void SzFree(void *address)
{
  #ifdef _SZ_ALLOC_DEBUG
  if (address != 0)
  {
    g_allocCount--;
    fprintf(stderr, "\nFree; count = %10d", g_allocCount);
  }
  #endif
  free(address);
}

void *SzAllocTemp(size_t size)
{
  if (size == 0)
    return 0;
  #ifdef _SZ_ALLOC_DEBUG
  fprintf(stderr, "\nAlloc_temp %10d bytes;  count = %10d", size, g_allocCountTemp);
  g_allocCountTemp++;
  #ifdef _WIN32
  return HeapAlloc(GetProcessHeap(), 0, size);
  #endif
  #endif
  return malloc(size);
}

void SzFreeTemp(void *address)
{
  #ifdef _SZ_ALLOC_DEBUG
  if (address != 0)
  {
    g_allocCountTemp--;
    fprintf(stderr, "\nFree_temp; count = %10d", g_allocCountTemp);
  }
  #ifdef _WIN32
  HeapFree(GetProcessHeap(), 0, address);
  return;
  #endif
  #endif
  free(address);
}
/* 7zBuffer.c */


void SzByteBufferInit(CSzByteBuffer *buffer)
{
  buffer->Capacity = 0;
  buffer->Items = 0;
}

int SzByteBufferCreate(CSzByteBuffer *buffer, size_t newCapacity, void * (*allocFunc)(size_t size))
{
  buffer->Capacity = newCapacity;
  if (newCapacity == 0)
  {
    buffer->Items = 0;
    return 1;
  }
  buffer->Items = (Byte *)allocFunc(newCapacity);
  return (buffer->Items != 0);
}

void SzByteBufferFree(CSzByteBuffer *buffer, void (*freeFunc)(void *))
{
  freeFunc(buffer->Items);
  buffer->Items = 0;
  buffer->Capacity = 0;
}
/* 7zCrc.c */


#define kCrcPoly 0xEDB88320

UInt32 g_CrcTable[256];

void InitCrcTable()
{
  UInt32 i;
  for (i = 0; i < 256; i++)
  {
    UInt32 r = i;
    int j;
    for (j = 0; j < 8; j++)
      if (r & 1) 
        r = (r >> 1) ^ kCrcPoly;
      else     
        r >>= 1;
    g_CrcTable[i] = r;
  }
}

void CrcInit(UInt32 *crc) { *crc = 0xFFFFFFFF; }
UInt32 CrcGetDigest(UInt32 *crc) { return *crc ^ 0xFFFFFFFF; } 

void CrcUpdateByte(UInt32 *crc, Byte b)
{
  *crc = g_CrcTable[((Byte)(*crc)) ^ b] ^ (*crc >> 8);
}

void CrcUpdateUInt16(UInt32 *crc, UInt16 v)
{
  CrcUpdateByte(crc, (Byte)v);
  CrcUpdateByte(crc, (Byte)(v >> 8));
}

void CrcUpdateUInt32(UInt32 *crc, UInt32 v)
{
  int i;
  for (i = 0; i < 4; i++)
    CrcUpdateByte(crc, (Byte)(v >> (8 * i)));
}

void CrcUpdateUInt64(UInt32 *crc, UInt64 v)
{
  int i;
  for (i = 0; i < 8; i++)
  {
    CrcUpdateByte(crc, (Byte)(v));
    v >>= 8;
  }
}

void CrcUpdate(UInt32 *crc, const void *data, size_t size)
{
  UInt32 v = *crc;
  const Byte *p = (const Byte *)data;
  for (; size > 0 ; size--, p++)
    v = g_CrcTable[((Byte)(v)) ^ *p] ^ (v >> 8);
  *crc = v;
}

UInt32 CrcCalculateDigest(const void *data, size_t size)
{
  UInt32 crc;
  CrcInit(&crc);
  CrcUpdate(&crc, data, size);
  return CrcGetDigest(&crc);
}

int CrcVerifyDigest(UInt32 digest, const void *data, size_t size)
{
  return (CrcCalculateDigest(data, size) == digest);
}
/* 7zDecode.c */

#ifdef _SZ_ONE_DIRECTORY
#else
#endif

CMethodID k_Copy = { { 0x0 }, 1 };
CMethodID k_LZMA = { { 0x3, 0x1, 0x1 }, 3 };

#ifdef _LZMA_IN_CB

typedef struct _CLzmaInCallbackImp
{
  ILzmaInCallback InCallback;
  ISzInStream *InStream;
  size_t Size;
} CLzmaInCallbackImp;

int LzmaReadImp(void *object, const unsigned char **buffer, SizeT *size)
{
  CLzmaInCallbackImp *cb = (CLzmaInCallbackImp *)object;
  size_t processedSize;
  SZ_RESULT res;
  *size = 0;
  res = cb->InStream->Read((void *)cb->InStream, (void **)buffer, cb->Size, &processedSize);
  *size = (SizeT)processedSize;
  if (processedSize > cb->Size)
    return (int)SZE_FAIL;
  cb->Size -= processedSize;
  if (res == SZ_OK)
    return 0;
  return (int)res;
}

#endif

SZ_RESULT SzDecode(const CFileSize *packSizes, const CFolder *folder,
    #ifdef _LZMA_IN_CB
    ISzInStream *inStream,
    #else
    const Byte *inBuffer,
    #endif
    Byte *outBuffer, size_t outSize, 
    size_t *outSizeProcessed, ISzAlloc *allocMain)
{
  UInt32 si;
  size_t inSize = 0;
  CCoderInfo *coder;
  if (folder->NumPackStreams != 1)
    return SZE_NOTIMPL;
  if (folder->NumCoders != 1)
    return SZE_NOTIMPL;
  coder = folder->Coders;
  *outSizeProcessed = 0;

  for (si = 0; si < folder->NumPackStreams; si++)
    inSize += (size_t)packSizes[si];

  if (AreMethodsEqual(&coder->MethodID, &k_Copy))
  {
    size_t i;
    if (inSize != outSize)
      return SZE_DATA_ERROR;
    #ifdef _LZMA_IN_CB
    for (i = 0; i < inSize;)
    {
      size_t j;
      Byte *inBuffer;
      size_t bufferSize;
      RINOK(inStream->Read((void *)inStream,  (void **)&inBuffer, inSize - i, &bufferSize));
      if (bufferSize == 0)
        return SZE_DATA_ERROR;
      if (bufferSize > inSize - i)
        return SZE_FAIL;
      *outSizeProcessed += bufferSize;
      for (j = 0; j < bufferSize && i < inSize; j++, i++)
        outBuffer[i] = inBuffer[j];
    }
    #else
    for (i = 0; i < inSize; i++)
      outBuffer[i] = inBuffer[i];
    *outSizeProcessed = inSize;
    #endif
    return SZ_OK;
  }

  if (AreMethodsEqual(&coder->MethodID, &k_LZMA))
  {
    #ifdef _LZMA_IN_CB
    CLzmaInCallbackImp lzmaCallback;
    #else
    SizeT inProcessed;
    #endif

    CLzmaDecoderState state;  /* it's about 24-80 bytes structure, if int is 32-bit */
    int result;
    SizeT outSizeProcessedLoc;

    #ifdef _LZMA_IN_CB
    lzmaCallback.Size = inSize;
    lzmaCallback.InStream = inStream;
    lzmaCallback.InCallback.Read = LzmaReadImp;
    #endif

    if (LzmaDecodeProperties(&state.Properties, coder->Properties.Items, 
        coder->Properties.Capacity) != LZMA_RESULT_OK)
      return SZE_FAIL;

    state.Probs = (CProb *)allocMain->Alloc(LzmaGetNumProbs(&state.Properties) * sizeof(CProb));
    if (state.Probs == 0)
      return SZE_OUTOFMEMORY;

    #ifdef _LZMA_OUT_READ
    if (state.Properties.DictionarySize == 0)
      state.Dictionary = 0;
    else
    {
      state.Dictionary = (unsigned char *)allocMain->Alloc(state.Properties.DictionarySize);
      if (state.Dictionary == 0)
      {
        allocMain->Free(state.Probs);
        return SZE_OUTOFMEMORY;
      }
    }
    LzmaDecoderInit(&state);
    #endif

    result = LzmaDecode(&state,
        #ifdef _LZMA_IN_CB
        &lzmaCallback.InCallback,
        #else
        inBuffer, (SizeT)inSize, &inProcessed,
        #endif
        outBuffer, (SizeT)outSize, &outSizeProcessedLoc);
    *outSizeProcessed = (size_t)outSizeProcessedLoc;
    allocMain->Free(state.Probs);
    #ifdef _LZMA_OUT_READ
    allocMain->Free(state.Dictionary);
    #endif
    if (result == LZMA_RESULT_DATA_ERROR)
      return SZE_DATA_ERROR;
    if (result != LZMA_RESULT_OK)
      return SZE_FAIL;
    return SZ_OK;
  }
  return SZE_NOTIMPL;
}
/* 7zExtract.c */


SZ_RESULT SzExtract(
    ISzInStream *inStream, 
    CArchiveDatabaseEx *db,
    UInt32 fileIndex,
    UInt32 *blockIndex,
    Byte **outBuffer, 
    size_t *outBufferSize,
    size_t *offset, 
    size_t *outSizeProcessed, 
    ISzAlloc *allocMain,
    ISzAlloc *allocTemp)
{
  UInt32 folderIndex = db->FileIndexToFolderIndexMap[fileIndex];
  SZ_RESULT res = SZ_OK;
  *offset = 0;
  *outSizeProcessed = 0;
  if (folderIndex == (UInt32)-1)
  {
    allocMain->Free(*outBuffer);
    *blockIndex = folderIndex;
    *outBuffer = 0;
    *outBufferSize = 0;
    return SZ_OK;
  }

  if (*outBuffer == 0 || *blockIndex != folderIndex)
  {
    CFolder *folder = db->Database.Folders + folderIndex;
    CFileSize unPackSize = SzFolderGetUnPackSize(folder);
    #ifndef _LZMA_IN_CB
    CFileSize packSize = SzArDbGetFolderFullPackSize(db, folderIndex);
    Byte *inBuffer = 0;
    size_t processedSize;
    #endif
    *blockIndex = folderIndex;
    allocMain->Free(*outBuffer);
    *outBuffer = 0;
    
    RINOK(inStream->Seek(inStream, SzArDbGetFolderStreamPos(db, folderIndex, 0)));
    
    #ifndef _LZMA_IN_CB
    if (packSize != 0)
    {
      inBuffer = (Byte *)allocTemp->Alloc((size_t)packSize);
      if (inBuffer == 0)
        return SZE_OUTOFMEMORY;
    }
    res = inStream->Read(inStream, inBuffer, (size_t)packSize, &processedSize);
    if (res == SZ_OK && processedSize != (size_t)packSize)
      res = SZE_FAIL;
    #endif
    if (res == SZ_OK)
    {
      *outBufferSize = (size_t)unPackSize;
      if (unPackSize != 0)
      {
        *outBuffer = (Byte *)allocMain->Alloc((size_t)unPackSize);
        if (*outBuffer == 0)
          res = SZE_OUTOFMEMORY;
      }
      if (res == SZ_OK)
      {
        size_t outRealSize;
        res = SzDecode(db->Database.PackSizes + 
          db->FolderStartPackStreamIndex[folderIndex], folder, 
          #ifdef _LZMA_IN_CB
          inStream,
          #else
          inBuffer, 
          #endif
          *outBuffer, (size_t)unPackSize, &outRealSize, allocTemp);
        if (res == SZ_OK)
        {
          if (outRealSize == (size_t)unPackSize)
          {
            if (folder->UnPackCRCDefined)
            {
              if (!CrcVerifyDigest(folder->UnPackCRC, *outBuffer, (size_t)unPackSize))
                res = SZE_FAIL;
            }
          }
          else
            res = SZE_FAIL;
        }
      }
    }
    #ifndef _LZMA_IN_CB
    allocTemp->Free(inBuffer);
    #endif
  }
  if (res == SZ_OK)
  {
    UInt32 i; 
    CFileItem *fileItem = db->Database.Files + fileIndex;
    *offset = 0;
    for(i = db->FolderStartFileIndex[folderIndex]; i < fileIndex; i++)
      *offset += (UInt32)db->Database.Files[i].Size;
    *outSizeProcessed = (size_t)fileItem->Size;
    if (*offset + *outSizeProcessed > *outBufferSize)
      return SZE_FAIL;
    {
      if (fileItem->IsFileCRCDefined)
      {
        if (!CrcVerifyDigest(fileItem->FileCRC, *outBuffer + *offset, *outSizeProcessed))
          res = SZE_FAIL;
      }
    }
  }
  return res;
}
/*  7zHeader.c */


Byte k7zSignature[k7zSignatureSize] = {'7', 'z', 0xBC, 0xAF, 0x27, 0x1C};
/* 7zIn.c */


#define RINOM(x) { if((x) == 0) return SZE_OUTOFMEMORY; }

void SzArDbExInit(CArchiveDatabaseEx *db)
{
  SzArchiveDatabaseInit(&db->Database);
  db->FolderStartPackStreamIndex = 0;
  db->PackStreamStartPositions = 0;
  db->FolderStartFileIndex = 0;
  db->FileIndexToFolderIndexMap = 0;
}

void SzArDbExFree(CArchiveDatabaseEx *db, void (*freeFunc)(void *))
{
  freeFunc(db->FolderStartPackStreamIndex);
  freeFunc(db->PackStreamStartPositions);
  freeFunc(db->FolderStartFileIndex);
  freeFunc(db->FileIndexToFolderIndexMap);
  SzArchiveDatabaseFree(&db->Database, freeFunc);
  SzArDbExInit(db);
}

/*
CFileSize GetFolderPackStreamSize(int folderIndex, int streamIndex) const 
{
  return PackSizes[FolderStartPackStreamIndex[folderIndex] + streamIndex];
}

CFileSize GetFilePackSize(int fileIndex) const
{
  int folderIndex = FileIndexToFolderIndexMap[fileIndex];
  if (folderIndex >= 0)
  {
    const CFolder &folderInfo = Folders[folderIndex];
    if (FolderStartFileIndex[folderIndex] == fileIndex)
    return GetFolderFullPackSize(folderIndex);
  }
  return 0;
}
*/


SZ_RESULT MySzInAlloc(void **p, size_t size, void * (*allocFunc)(size_t size))
{
  if (size == 0)
    *p = 0;
  else
  {
    *p = allocFunc(size);
    RINOM(*p);
  }
  return SZ_OK;
}

SZ_RESULT SzArDbExFill(CArchiveDatabaseEx *db, void * (*allocFunc)(size_t size))
{
  UInt32 startPos = 0;
  CFileSize startPosSize = 0;
  UInt32 i;
  UInt32 folderIndex = 0;
  UInt32 indexInFolder = 0;
  RINOK(MySzInAlloc((void **)&db->FolderStartPackStreamIndex, db->Database.NumFolders * sizeof(UInt32), allocFunc));
  for(i = 0; i < db->Database.NumFolders; i++)
  {
    db->FolderStartPackStreamIndex[i] = startPos;
    startPos += db->Database.Folders[i].NumPackStreams;
  }

  RINOK(MySzInAlloc((void **)&db->PackStreamStartPositions, db->Database.NumPackStreams * sizeof(CFileSize), allocFunc));

  for(i = 0; i < db->Database.NumPackStreams; i++)
  {
    db->PackStreamStartPositions[i] = startPosSize;
    startPosSize += db->Database.PackSizes[i];
  }

  RINOK(MySzInAlloc((void **)&db->FolderStartFileIndex, db->Database.NumFolders * sizeof(UInt32), allocFunc));
  RINOK(MySzInAlloc((void **)&db->FileIndexToFolderIndexMap, db->Database.NumFiles * sizeof(UInt32), allocFunc));

  for (i = 0; i < db->Database.NumFiles; i++)
  {
    CFileItem *file = db->Database.Files + i;
    int emptyStream = !file->HasStream;
    if (emptyStream && indexInFolder == 0)
    {
      db->FileIndexToFolderIndexMap[i] = (UInt32)-1;
      continue;
    }
    if (indexInFolder == 0)
    {
      /*
      v3.13 incorrectly worked with empty folders
      v4.07: Loop for skipping empty folders
      */
      while(1)
      {
        if (folderIndex >= db->Database.NumFolders)
          return SZE_ARCHIVE_ERROR;
        db->FolderStartFileIndex[folderIndex] = i;
        if (db->Database.Folders[folderIndex].NumUnPackStreams != 0)
          break;
        folderIndex++;
      }
    }
    db->FileIndexToFolderIndexMap[i] = folderIndex;
    if (emptyStream)
      continue;
    indexInFolder++;
    if (indexInFolder >= db->Database.Folders[folderIndex].NumUnPackStreams)
    {
      folderIndex++;
      indexInFolder = 0;
    }
  }
  return SZ_OK;
}


CFileSize SzArDbGetFolderStreamPos(CArchiveDatabaseEx *db, UInt32 folderIndex, UInt32 indexInFolder)
{
  return db->ArchiveInfo.DataStartPosition + 
    db->PackStreamStartPositions[db->FolderStartPackStreamIndex[folderIndex] + indexInFolder];
}

CFileSize SzArDbGetFolderFullPackSize(CArchiveDatabaseEx *db, UInt32 folderIndex)
{
  UInt32 packStreamIndex = db->FolderStartPackStreamIndex[folderIndex];
  CFolder *folder = db->Database.Folders + folderIndex;
  CFileSize size = 0;
  UInt32 i;
  for (i = 0; i < folder->NumPackStreams; i++)
    size += db->Database.PackSizes[packStreamIndex + i];
  return size;
}


/*
SZ_RESULT SzReadTime(const CObjectVector<CSzByteBuffer> &dataVector,
    CObjectVector<CFileItem> &files, UInt64 type)
{
  CBoolVector boolVector;
  RINOK(ReadBoolVector2(files.Size(), boolVector))

  CStreamSwitch streamSwitch;
  RINOK(streamSwitch.Set(this, &dataVector));

  for(int i = 0; i < files.Size(); i++)
  {
    CFileItem &file = files[i];
    CArchiveFileTime fileTime;
    bool defined = boolVector[i];
    if (defined)
    {
      UInt32 low, high;
      RINOK(SzReadUInt32(low));
      RINOK(SzReadUInt32(high));
      fileTime.dwLowDateTime = low;
      fileTime.dwHighDateTime = high;
    }
    switch(type)
    {
      case k7zIdCreationTime:
        file.IsCreationTimeDefined = defined;
        if (defined)
          file.CreationTime = fileTime;
        break;
      case k7zIdLastWriteTime:
        file.IsLastWriteTimeDefined = defined;
        if (defined)
          file.LastWriteTime = fileTime;
        break;
      case k7zIdLastAccessTime:
        file.IsLastAccessTimeDefined = defined;
        if (defined)
          file.LastAccessTime = fileTime;
        break;
    }
  }
  return SZ_OK;
}
*/

SZ_RESULT SafeReadDirect(ISzInStream *inStream, Byte *data, size_t size)
{
  #ifdef _LZMA_IN_CB
  while (size > 0)
  {
    Byte *inBuffer;
    size_t processedSize;
    RINOK(inStream->Read(inStream, (void **)&inBuffer, size, &processedSize));
    if (processedSize == 0 || processedSize > size)
      return SZE_FAIL;
    size -= processedSize;
    do
    {
      *data++ = *inBuffer++;
    }
    while (--processedSize != 0);
  }
  #else
  size_t processedSize;
  RINOK(inStream->Read(inStream, data, size, &processedSize));
  if (processedSize != size)
    return SZE_FAIL;
  #endif
  return SZ_OK;
}

SZ_RESULT SafeReadDirectByte(ISzInStream *inStream, Byte *data)
{
  return SafeReadDirect(inStream, data, 1);
}

SZ_RESULT SafeReadDirectUInt32(ISzInStream *inStream, UInt32 *value)
{
  int i;
  *value = 0;
  for (i = 0; i < 4; i++)
  {
    Byte b;
    RINOK(SafeReadDirectByte(inStream, &b));
    *value |= ((UInt32)b << (8 * i));
  }
  return SZ_OK;
}

SZ_RESULT SafeReadDirectUInt64(ISzInStream *inStream, UInt64 *value)
{
  int i;
  *value = 0;
  for (i = 0; i < 8; i++)
  {
    Byte b;
    RINOK(SafeReadDirectByte(inStream, &b));
    *value |= ((UInt32)b << (8 * i));
  }
  return SZ_OK;
}

int TestSignatureCandidate(Byte *testBytes)
{
  size_t i;
  for (i = 0; i < k7zSignatureSize; i++)
    if (testBytes[i] != k7zSignature[i])
      return 0;
  return 1;
}

typedef struct _CSzState
{
  Byte *Data;
  size_t Size;
}CSzData;

SZ_RESULT SzReadByte(CSzData *sd, Byte *b)
{
  if (sd->Size == 0)
    return SZE_ARCHIVE_ERROR;
  sd->Size--;
  *b = *sd->Data++;
  return SZ_OK;
}

SZ_RESULT SzReadBytes(CSzData *sd, Byte *data, size_t size)
{
  size_t i;
  for (i = 0; i < size; i++)
  {
    RINOK(SzReadByte(sd, data + i));
  }
  return SZ_OK;
}

SZ_RESULT SzReadUInt32(CSzData *sd, UInt32 *value)
{
  int i;
  *value = 0;
  for (i = 0; i < 4; i++)
  {
    Byte b;
    RINOK(SzReadByte(sd, &b));
    *value |= ((UInt32)(b) << (8 * i));
  }
  return SZ_OK;
}

SZ_RESULT SzReadNumber(CSzData *sd, UInt64 *value)
{
  Byte firstByte;
  Byte mask = 0x80;
  int i;
  RINOK(SzReadByte(sd, &firstByte));
  *value = 0;
  for (i = 0; i < 8; i++)
  {
    Byte b;
    if ((firstByte & mask) == 0)
    {
      UInt64 highPart = firstByte & (mask - 1);
      *value += (highPart << (8 * i));
      return SZ_OK;
    }
    RINOK(SzReadByte(sd, &b));
    *value |= ((UInt64)b << (8 * i));
    mask >>= 1;
  }
  return SZ_OK;
}

SZ_RESULT SzReadSize(CSzData *sd, CFileSize *value)
{
  UInt64 value64;
  RINOK(SzReadNumber(sd, &value64));
  *value = (CFileSize)value64;
  return SZ_OK;
}

SZ_RESULT SzReadNumber32(CSzData *sd, UInt32 *value)
{
  UInt64 value64;
  RINOK(SzReadNumber(sd, &value64));
  if (value64 >= 0x80000000)
    return SZE_NOTIMPL;
  if (value64 >= ((UInt64)(1) << ((sizeof(size_t) - 1) * 8 + 2)))
    return SZE_NOTIMPL;
  *value = (UInt32)value64;
  return SZ_OK;
}

SZ_RESULT SzReadID(CSzData *sd, UInt64 *value) 
{ 
  return SzReadNumber(sd, value); 
}

SZ_RESULT SzSkeepDataSize(CSzData *sd, UInt64 size)
{
  if (size > sd->Size)
    return SZE_ARCHIVE_ERROR;
  sd->Size -= (size_t)size;
  sd->Data += (size_t)size;
  return SZ_OK;
}

SZ_RESULT SzSkeepData(CSzData *sd)
{
  UInt64 size;
  RINOK(SzReadNumber(sd, &size));
  return SzSkeepDataSize(sd, size);
}

SZ_RESULT SzReadArchiveProperties(CSzData *sd)
{
  while(1)
  {
    UInt64 type;
    RINOK(SzReadID(sd, &type));
    if (type == k7zIdEnd)
      break;
    SzSkeepData(sd);
  }
  return SZ_OK;
}

SZ_RESULT SzWaitAttribute(CSzData *sd, UInt64 attribute)
{
  while(1)
  {
    UInt64 type;
    RINOK(SzReadID(sd, &type));
    if (type == attribute)
      return SZ_OK;
    if (type == k7zIdEnd)
      return SZE_ARCHIVE_ERROR;
    RINOK(SzSkeepData(sd));
  }
}

SZ_RESULT SzReadBoolVector(CSzData *sd, size_t numItems, Byte **v, void * (*allocFunc)(size_t size))
{
  Byte b = 0;
  Byte mask = 0;
  size_t i;
  RINOK(MySzInAlloc((void **)v, numItems * sizeof(Byte), allocFunc));
  for(i = 0; i < numItems; i++)
  {
    if (mask == 0)
    {
      RINOK(SzReadByte(sd, &b));
      mask = 0x80;
    }
    (*v)[i] = (Byte)(((b & mask) != 0) ? 1 : 0);
    mask >>= 1;
  }
  return SZ_OK;
}

SZ_RESULT SzReadBoolVector2(CSzData *sd, size_t numItems, Byte **v, void * (*allocFunc)(size_t size))
{
  Byte allAreDefined;
  size_t i;
  RINOK(SzReadByte(sd, &allAreDefined));
  if (allAreDefined == 0)
    return SzReadBoolVector(sd, numItems, v, allocFunc);
  RINOK(MySzInAlloc((void **)v, numItems * sizeof(Byte), allocFunc));
  for(i = 0; i < numItems; i++)
    (*v)[i] = 1;
  return SZ_OK;
}

SZ_RESULT SzReadHashDigests(
    CSzData *sd, 
    size_t numItems,
    Byte **digestsDefined, 
    UInt32 **digests, 
    void * (*allocFunc)(size_t size))
{
  size_t i;
  RINOK(SzReadBoolVector2(sd, numItems, digestsDefined, allocFunc));
  RINOK(MySzInAlloc((void **)digests, numItems * sizeof(UInt32), allocFunc));
  for(i = 0; i < numItems; i++)
    if ((*digestsDefined)[i])
    {
      RINOK(SzReadUInt32(sd, (*digests) + i));
    }
  return SZ_OK;
}

SZ_RESULT SzReadPackInfo(
    CSzData *sd, 
    CFileSize *dataOffset,
    UInt32 *numPackStreams,
    CFileSize **packSizes,
    Byte **packCRCsDefined,
    UInt32 **packCRCs,
    void * (*allocFunc)(size_t size))
{
  UInt32 i;
  RINOK(SzReadSize(sd, dataOffset));
  RINOK(SzReadNumber32(sd, numPackStreams));

  RINOK(SzWaitAttribute(sd, k7zIdSize));

  RINOK(MySzInAlloc((void **)packSizes, (size_t)*numPackStreams * sizeof(CFileSize), allocFunc));

  for(i = 0; i < *numPackStreams; i++)
  {
    RINOK(SzReadSize(sd, (*packSizes) + i));
  }

  while(1)
  {
    UInt64 type;
    RINOK(SzReadID(sd, &type));
    if (type == k7zIdEnd)
      break;
    if (type == k7zIdCRC)
    {
      RINOK(SzReadHashDigests(sd, (size_t)*numPackStreams, packCRCsDefined, packCRCs, allocFunc)); 
      continue;
    }
    RINOK(SzSkeepData(sd));
  }
  if (*packCRCsDefined == 0)
  {
    RINOK(MySzInAlloc((void **)packCRCsDefined, (size_t)*numPackStreams * sizeof(Byte), allocFunc));
    RINOK(MySzInAlloc((void **)packCRCs, (size_t)*numPackStreams * sizeof(UInt32), allocFunc));
    for(i = 0; i < *numPackStreams; i++)
    {
      (*packCRCsDefined)[i] = 0;
      (*packCRCs)[i] = 0;
    }
  }
  return SZ_OK;
}

SZ_RESULT SzReadSwitch(CSzData *sd)
{
  Byte external;
  RINOK(SzReadByte(sd, &external));
  return (external == 0) ? SZ_OK: SZE_ARCHIVE_ERROR;
}

SZ_RESULT SzGetNextFolderItem(CSzData *sd, CFolder *folder, void * (*allocFunc)(size_t size))
{
  UInt32 numCoders;
  UInt32 numBindPairs;
  UInt32 numPackedStreams;
  UInt32 i;
  UInt32 numInStreams = 0;
  UInt32 numOutStreams = 0;
  RINOK(SzReadNumber32(sd, &numCoders));
  folder->NumCoders = numCoders;

  RINOK(MySzInAlloc((void **)&folder->Coders, (size_t)numCoders * sizeof(CCoderInfo), allocFunc));

  for (i = 0; i < numCoders; i++)
    SzCoderInfoInit(folder->Coders + i);

  for (i = 0; i < numCoders; i++)
  {
    Byte mainByte;
    CCoderInfo *coder = folder->Coders + i;
    {
      RINOK(SzReadByte(sd, &mainByte));
      coder->MethodID.IDSize = (Byte)(mainByte & 0xF);
      RINOK(SzReadBytes(sd, coder->MethodID.ID, coder->MethodID.IDSize));
      if ((mainByte & 0x10) != 0)
      {
        RINOK(SzReadNumber32(sd, &coder->NumInStreams));
        RINOK(SzReadNumber32(sd, &coder->NumOutStreams));
      }
      else
      {
        coder->NumInStreams = 1;
        coder->NumOutStreams = 1;
      }
      if ((mainByte & 0x20) != 0)
      {
        UInt64 propertiesSize = 0;
        RINOK(SzReadNumber(sd, &propertiesSize));
        if (!SzByteBufferCreate(&coder->Properties, (size_t)propertiesSize, allocFunc))
          return SZE_OUTOFMEMORY;
        RINOK(SzReadBytes(sd, coder->Properties.Items, (size_t)propertiesSize));
      }
    }
    while ((mainByte & 0x80) != 0)
    {
      RINOK(SzReadByte(sd, &mainByte));
      RINOK(SzSkeepDataSize(sd, (mainByte & 0xF)));
      if ((mainByte & 0x10) != 0)
      {
        UInt32 n;
        RINOK(SzReadNumber32(sd, &n));
        RINOK(SzReadNumber32(sd, &n));
      }
      if ((mainByte & 0x20) != 0)
      {
        UInt64 propertiesSize = 0;
        RINOK(SzReadNumber(sd, &propertiesSize));
        RINOK(SzSkeepDataSize(sd, propertiesSize));
      }
    }
    numInStreams += (UInt32)coder->NumInStreams;
    numOutStreams += (UInt32)coder->NumOutStreams;
  }

  numBindPairs = numOutStreams - 1;
  folder->NumBindPairs = numBindPairs;


  RINOK(MySzInAlloc((void **)&folder->BindPairs, (size_t)numBindPairs * sizeof(CBindPair), allocFunc));

  for (i = 0; i < numBindPairs; i++)
  {
    CBindPair *bindPair = folder->BindPairs + i;;
    RINOK(SzReadNumber32(sd, &bindPair->InIndex));
    RINOK(SzReadNumber32(sd, &bindPair->OutIndex)); 
  }

  numPackedStreams = numInStreams - (UInt32)numBindPairs;

  folder->NumPackStreams = numPackedStreams;
  RINOK(MySzInAlloc((void **)&folder->PackStreams, (size_t)numPackedStreams * sizeof(UInt32), allocFunc));

  if (numPackedStreams == 1)
  {
    UInt32 j;
    UInt32 pi = 0;
    for (j = 0; j < numInStreams; j++)
      if (SzFolderFindBindPairForInStream(folder, j) < 0)
      {
        folder->PackStreams[pi++] = j;
        break;
      }
  }
  else
    for(i = 0; i < numPackedStreams; i++)
    {
      RINOK(SzReadNumber32(sd, folder->PackStreams + i));
    }
  return SZ_OK;
}

SZ_RESULT SzReadUnPackInfo(
    CSzData *sd, 
    UInt32 *numFolders,
    CFolder **folders,  /* for allocFunc */
    void * (*allocFunc)(size_t size),
    ISzAlloc *allocTemp)
{
  UInt32 i;
  RINOK(SzWaitAttribute(sd, k7zIdFolder));
  RINOK(SzReadNumber32(sd, numFolders));
  {
    RINOK(SzReadSwitch(sd));


    RINOK(MySzInAlloc((void **)folders, (size_t)*numFolders * sizeof(CFolder), allocFunc));

    for(i = 0; i < *numFolders; i++)
      SzFolderInit((*folders) + i);

    for(i = 0; i < *numFolders; i++)
    {
      RINOK(SzGetNextFolderItem(sd, (*folders) + i, allocFunc));
    }
  }

  RINOK(SzWaitAttribute(sd, k7zIdCodersUnPackSize));

  for(i = 0; i < *numFolders; i++)
  {
    UInt32 j;
    CFolder *folder = (*folders) + i;
    UInt32 numOutStreams = SzFolderGetNumOutStreams(folder);

    RINOK(MySzInAlloc((void **)&folder->UnPackSizes, (size_t)numOutStreams * sizeof(CFileSize), allocFunc));

    for(j = 0; j < numOutStreams; j++)
    {
      RINOK(SzReadSize(sd, folder->UnPackSizes + j));
    }
  }

  while(1)
  {
    UInt64 type;
    RINOK(SzReadID(sd, &type));
    if (type == k7zIdEnd)
      return SZ_OK;
    if (type == k7zIdCRC)
    {
      SZ_RESULT res;
      Byte *crcsDefined = 0;
      UInt32 *crcs = 0;
      res = SzReadHashDigests(sd, *numFolders, &crcsDefined, &crcs, allocTemp->Alloc); 
      if (res == SZ_OK)
      {
        for(i = 0; i < *numFolders; i++)
        {
          CFolder *folder = (*folders) + i;
          folder->UnPackCRCDefined = crcsDefined[i];
          folder->UnPackCRC = crcs[i];
        }
      }
      allocTemp->Free(crcs);
      allocTemp->Free(crcsDefined);
      RINOK(res);
      continue;
    }
    RINOK(SzSkeepData(sd));
  }
}

SZ_RESULT SzReadSubStreamsInfo(
    CSzData *sd, 
    UInt32 numFolders,
    CFolder *folders,
    UInt32 *numUnPackStreams,
    CFileSize **unPackSizes,
    Byte **digestsDefined,
    UInt32 **digests,
    ISzAlloc *allocTemp)
{
  UInt64 type = 0;
  UInt32 i;
  UInt32 si = 0;
  UInt32 numDigests = 0;

  for(i = 0; i < numFolders; i++)
    folders[i].NumUnPackStreams = 1;
  *numUnPackStreams = numFolders;

  while(1)
  {
    RINOK(SzReadID(sd, &type));
    if (type == k7zIdNumUnPackStream)
    {
      *numUnPackStreams = 0;
      for(i = 0; i < numFolders; i++)
      {
        UInt32 numStreams;
        RINOK(SzReadNumber32(sd, &numStreams));
        folders[i].NumUnPackStreams = numStreams;
        *numUnPackStreams += numStreams;
      }
      continue;
    }
    if (type == k7zIdCRC || type == k7zIdSize)
      break;
    if (type == k7zIdEnd)
      break;
    RINOK(SzSkeepData(sd));
  }

  if (*numUnPackStreams == 0)
  {
    *unPackSizes = 0;
    *digestsDefined = 0;
    *digests = 0;
  }
  else
  {
    *unPackSizes = (CFileSize *)allocTemp->Alloc((size_t)*numUnPackStreams * sizeof(CFileSize));
    RINOM(*unPackSizes);
    *digestsDefined = (Byte *)allocTemp->Alloc((size_t)*numUnPackStreams * sizeof(Byte));
    RINOM(*digestsDefined);
    *digests = (UInt32 *)allocTemp->Alloc((size_t)*numUnPackStreams * sizeof(UInt32));
    RINOM(*digests);
  }

  for(i = 0; i < numFolders; i++)
  {
    /*
    v3.13 incorrectly worked with empty folders
    v4.07: we check that folder is empty
    */
    CFileSize sum = 0;
    UInt32 j;
    UInt32 numSubstreams = folders[i].NumUnPackStreams;
    if (numSubstreams == 0)
      continue;
    if (type == k7zIdSize)
    for (j = 1; j < numSubstreams; j++)
    {
      CFileSize size;
      RINOK(SzReadSize(sd, &size));
      (*unPackSizes)[si++] = size;
      sum += size;
    }
    (*unPackSizes)[si++] = SzFolderGetUnPackSize(folders + i) - sum;
  }
  if (type == k7zIdSize)
  {
    RINOK(SzReadID(sd, &type));
  }

  for(i = 0; i < *numUnPackStreams; i++)
  {
    (*digestsDefined)[i] = 0;
    (*digests)[i] = 0;
  }


  for(i = 0; i < numFolders; i++)
  {
    UInt32 numSubstreams = folders[i].NumUnPackStreams;
    if (numSubstreams != 1 || !folders[i].UnPackCRCDefined)
      numDigests += numSubstreams;
  }

 
  si = 0;
  while(1)
  {
    if (type == k7zIdCRC)
    {
      int digestIndex = 0;
      Byte *digestsDefined2 = 0; 
      UInt32 *digests2 = 0;
      SZ_RESULT res = SzReadHashDigests(sd, numDigests, &digestsDefined2, &digests2, allocTemp->Alloc);
      if (res == SZ_OK)
      {
        for (i = 0; i < numFolders; i++)
        {
          CFolder *folder = folders + i;
          UInt32 numSubstreams = folder->NumUnPackStreams;
          if (numSubstreams == 1 && folder->UnPackCRCDefined)
          {
            (*digestsDefined)[si] = 1;
            (*digests)[si] = folder->UnPackCRC;
            si++;
          }
          else
          {
            UInt32 j;
            for (j = 0; j < numSubstreams; j++, digestIndex++)
            {
              (*digestsDefined)[si] = digestsDefined2[digestIndex];
              (*digests)[si] = digests2[digestIndex];
              si++;
            }
          }
        }
      }
      allocTemp->Free(digestsDefined2);
      allocTemp->Free(digests2);
      RINOK(res);
    }
    else if (type == k7zIdEnd)
      return SZ_OK;
    else
    {
      RINOK(SzSkeepData(sd));
    }
    RINOK(SzReadID(sd, &type));
  }
}


SZ_RESULT SzReadStreamsInfo(
    CSzData *sd, 
    CFileSize *dataOffset,
    CArchiveDatabase *db,
    UInt32 *numUnPackStreams,
    CFileSize **unPackSizes, /* allocTemp */
    Byte **digestsDefined,   /* allocTemp */
    UInt32 **digests,        /* allocTemp */
    void * (*allocFunc)(size_t size),
    ISzAlloc *allocTemp)
{
  while(1)
  {
    UInt64 type;
    RINOK(SzReadID(sd, &type));
    if ((UInt64)(int)type != type)
      return SZE_FAIL;
    switch((int)type)
    {
      case k7zIdEnd:
        return SZ_OK;
      case k7zIdPackInfo:
      {
        RINOK(SzReadPackInfo(sd, dataOffset, &db->NumPackStreams, 
            &db->PackSizes, &db->PackCRCsDefined, &db->PackCRCs, allocFunc));
        break;
      }
      case k7zIdUnPackInfo:
      {
        RINOK(SzReadUnPackInfo(sd, &db->NumFolders, &db->Folders, allocFunc, allocTemp));
        break;
      }
      case k7zIdSubStreamsInfo:
      {
        RINOK(SzReadSubStreamsInfo(sd, db->NumFolders, db->Folders, 
            numUnPackStreams, unPackSizes, digestsDefined, digests, allocTemp));
        break;
      }
      default:
        return SZE_FAIL;
    }
  }
}

Byte kUtf8Limits[5] = { 0xC0, 0xE0, 0xF0, 0xF8, 0xFC };

SZ_RESULT SzReadFileNames(CSzData *sd, UInt32 numFiles, CFileItem *files, 
    void * (*allocFunc)(size_t size))
{
  UInt32 i;
  for(i = 0; i < numFiles; i++)
  {
    UInt32 len = 0;
    UInt32 pos = 0;
    CFileItem *file = files + i;
    while(pos + 2 <= sd->Size)
    {
      int numAdds;
      UInt32 value = (UInt32)(sd->Data[pos] | (((UInt32)sd->Data[pos + 1]) << 8));
      pos += 2;
      len++;
      if (value == 0)
        break;
      if (value < 0x80)
        continue;
      if (value >= 0xD800 && value < 0xE000)
      {
        UInt32 c2;
        if (value >= 0xDC00)
          return SZE_ARCHIVE_ERROR;
        if (pos + 2 > sd->Size)
          return SZE_ARCHIVE_ERROR;
        c2 = (UInt32)(sd->Data[pos] | (((UInt32)sd->Data[pos + 1]) << 8));
        pos += 2;
        if (c2 < 0xDC00 || c2 >= 0xE000)
          return SZE_ARCHIVE_ERROR;
        value = ((value - 0xD800) << 10) | (c2 - 0xDC00);
      }
      for (numAdds = 1; numAdds < 5; numAdds++)
        if (value < (((UInt32)1) << (numAdds * 5 + 6)))
          break;
      len += numAdds;
    }

    RINOK(MySzInAlloc((void **)&file->Name, (size_t)len * sizeof(char), allocFunc));

    len = 0;
    while(2 <= sd->Size)
    {
      int numAdds;
      UInt32 value = (UInt32)(sd->Data[0] | (((UInt32)sd->Data[1]) << 8));
      SzSkeepDataSize(sd, 2);
      if (value < 0x80)
      {
        file->Name[len++] = (char)value;
        if (value == 0)
          break;
        continue;
      }
      if (value >= 0xD800 && value < 0xE000)
      {
        UInt32 c2 = (UInt32)(sd->Data[0] | (((UInt32)sd->Data[1]) << 8));
        SzSkeepDataSize(sd, 2);
        value = ((value - 0xD800) << 10) | (c2 - 0xDC00);
      }
      for (numAdds = 1; numAdds < 5; numAdds++)
        if (value < (((UInt32)1) << (numAdds * 5 + 6)))
          break;
      file->Name[len++] = (char)(kUtf8Limits[numAdds - 1] + (value >> (6 * numAdds)));
      do
      {
        numAdds--;
        file->Name[len++] = (char)(0x80 + ((value >> (6 * numAdds)) & 0x3F));
      }
      while(numAdds > 0);

      len += numAdds;
    }
  }
  return SZ_OK;
}

SZ_RESULT SzReadHeader2(
    CSzData *sd, 
    CArchiveDatabaseEx *db,   /* allocMain */
    CFileSize **unPackSizes,  /* allocTemp */
    Byte **digestsDefined,    /* allocTemp */
    UInt32 **digests,         /* allocTemp */
    Byte **emptyStreamVector, /* allocTemp */
    Byte **emptyFileVector,   /* allocTemp */
    ISzAlloc *allocMain, 
    ISzAlloc *allocTemp)
{
  UInt64 type;
  UInt32 numUnPackStreams = 0;
  UInt32 numFiles = 0;
  CFileItem *files = 0;
  UInt32 numEmptyStreams = 0;
  UInt32 i;

  RINOK(SzReadID(sd, &type));

  if (type == k7zIdArchiveProperties)
  {
    RINOK(SzReadArchiveProperties(sd));
    RINOK(SzReadID(sd, &type));
  }
 
 
  if (type == k7zIdMainStreamsInfo)
  {
    RINOK(SzReadStreamsInfo(sd,
        &db->ArchiveInfo.DataStartPosition,
        &db->Database, 
        &numUnPackStreams,
        unPackSizes,
        digestsDefined,
        digests, allocMain->Alloc, allocTemp));
    db->ArchiveInfo.DataStartPosition += db->ArchiveInfo.StartPositionAfterHeader;
    RINOK(SzReadID(sd, &type));
  }

  if (type == k7zIdEnd)
    return SZ_OK;
  if (type != k7zIdFilesInfo)
    return SZE_ARCHIVE_ERROR;
  
  RINOK(SzReadNumber32(sd, &numFiles));
  db->Database.NumFiles = numFiles;

  RINOK(MySzInAlloc((void **)&files, (size_t)numFiles * sizeof(CFileItem), allocMain->Alloc));

  db->Database.Files = files;
  for(i = 0; i < numFiles; i++)
    SzFileInit(files + i);

  while(1)
  {
    UInt64 type;
    UInt64 size;
    RINOK(SzReadID(sd, &type));
    if (type == k7zIdEnd)
      break;
    RINOK(SzReadNumber(sd, &size));

    if ((UInt64)(int)type != type)
    {
      RINOK(SzSkeepDataSize(sd, size));
    }
    else
    switch((int)type)
    {
      case k7zIdName:
      {
        RINOK(SzReadSwitch(sd));
        RINOK(SzReadFileNames(sd, numFiles, files, allocMain->Alloc))
        break;
      }
      case k7zIdEmptyStream:
      {
        RINOK(SzReadBoolVector(sd, numFiles, emptyStreamVector, allocTemp->Alloc));
        numEmptyStreams = 0;
        for (i = 0; i < numFiles; i++)
          if ((*emptyStreamVector)[i])
            numEmptyStreams++;
        break;
      }
      case k7zIdEmptyFile:
      {
        RINOK(SzReadBoolVector(sd, numEmptyStreams, emptyFileVector, allocTemp->Alloc));
        break;
      }
      default:
      {
        RINOK(SzSkeepDataSize(sd, size));
      }
    }
  }

  {
    UInt32 emptyFileIndex = 0;
    UInt32 sizeIndex = 0;
    for(i = 0; i < numFiles; i++)
    {
      CFileItem *file = files + i;
      file->IsAnti = 0;
      if (*emptyStreamVector == 0)
        file->HasStream = 1;
      else
        file->HasStream = (Byte)((*emptyStreamVector)[i] ? 0 : 1);
      if(file->HasStream)
      {
        file->IsDirectory = 0;
        file->Size = (*unPackSizes)[sizeIndex];
        file->FileCRC = (*digests)[sizeIndex];
        file->IsFileCRCDefined = (Byte)(*digestsDefined)[sizeIndex];
        sizeIndex++;
      }
      else
      {
        if (*emptyFileVector == 0)
          file->IsDirectory = 1;
        else
          file->IsDirectory = (Byte)((*emptyFileVector)[emptyFileIndex] ? 0 : 1);
        emptyFileIndex++;
        file->Size = 0;
        file->IsFileCRCDefined = 0;
      }
    }
  }
  return SzArDbExFill(db, allocMain->Alloc);
}

SZ_RESULT SzReadHeader(
    CSzData *sd, 
    CArchiveDatabaseEx *db, 
    ISzAlloc *allocMain, 
    ISzAlloc *allocTemp)
{
  CFileSize *unPackSizes = 0;
  Byte *digestsDefined = 0;
  UInt32 *digests = 0;
  Byte *emptyStreamVector = 0;
  Byte *emptyFileVector = 0;
  SZ_RESULT res = SzReadHeader2(sd, db, 
      &unPackSizes, &digestsDefined, &digests,
      &emptyStreamVector, &emptyFileVector,
      allocMain, allocTemp);
  allocTemp->Free(unPackSizes);
  allocTemp->Free(digestsDefined);
  allocTemp->Free(digests);
  allocTemp->Free(emptyStreamVector);
  allocTemp->Free(emptyFileVector);
  return res;
} 

SZ_RESULT SzReadAndDecodePackedStreams2(
    ISzInStream *inStream, 
    CSzData *sd,
    CSzByteBuffer *outBuffer,
    CFileSize baseOffset, 
    CArchiveDatabase *db,
    CFileSize **unPackSizes,
    Byte **digestsDefined,
    UInt32 **digests,
    #ifndef _LZMA_IN_CB
    Byte **inBuffer,
    #endif
    ISzAlloc *allocTemp)
{

  UInt32 numUnPackStreams = 0;
  CFileSize dataStartPos;
  CFolder *folder;
  #ifndef _LZMA_IN_CB
  CFileSize packSize = 0;
  UInt32 i = 0;
  #endif
  CFileSize unPackSize;
  size_t outRealSize;
  SZ_RESULT res;

  RINOK(SzReadStreamsInfo(sd, &dataStartPos, db,
      &numUnPackStreams,  unPackSizes, digestsDefined, digests, 
      allocTemp->Alloc, allocTemp));
  
  dataStartPos += baseOffset;
  if (db->NumFolders != 1)
    return SZE_ARCHIVE_ERROR;

  folder = db->Folders;
  unPackSize = SzFolderGetUnPackSize(folder);
  
  RINOK(inStream->Seek(inStream, dataStartPos));

  #ifndef _LZMA_IN_CB
  for (i = 0; i < db->NumPackStreams; i++)
    packSize += db->PackSizes[i];

  RINOK(MySzInAlloc((void **)inBuffer, (size_t)packSize, allocTemp->Alloc));

  RINOK(SafeReadDirect(inStream, *inBuffer, (size_t)packSize));
  #endif

  if (!SzByteBufferCreate(outBuffer, (size_t)unPackSize, allocTemp->Alloc))
    return SZE_OUTOFMEMORY;
  
  res = SzDecode(db->PackSizes, folder, 
          #ifdef _LZMA_IN_CB
          inStream,
          #else
          *inBuffer, 
          #endif
          outBuffer->Items, (size_t)unPackSize,
          &outRealSize, allocTemp);
  RINOK(res)
  if (outRealSize != (UInt32)unPackSize)
    return SZE_FAIL;
  if (folder->UnPackCRCDefined)
    if (!CrcVerifyDigest(folder->UnPackCRC, outBuffer->Items, (size_t)unPackSize))
      return SZE_FAIL;
  return SZ_OK;
}

SZ_RESULT SzReadAndDecodePackedStreams(
    ISzInStream *inStream, 
    CSzData *sd,
    CSzByteBuffer *outBuffer,
    CFileSize baseOffset, 
    ISzAlloc *allocTemp)
{
  CArchiveDatabase db;
  CFileSize *unPackSizes = 0;
  Byte *digestsDefined = 0;
  UInt32 *digests = 0;
  #ifndef _LZMA_IN_CB
  Byte *inBuffer = 0;
  #endif
  SZ_RESULT res;
  SzArchiveDatabaseInit(&db);
  res = SzReadAndDecodePackedStreams2(inStream, sd, outBuffer, baseOffset, 
    &db, &unPackSizes, &digestsDefined, &digests, 
    #ifndef _LZMA_IN_CB
    &inBuffer,
    #endif
    allocTemp);
  SzArchiveDatabaseFree(&db, allocTemp->Free);
  allocTemp->Free(unPackSizes);
  allocTemp->Free(digestsDefined);
  allocTemp->Free(digests);
  #ifndef _LZMA_IN_CB
  allocTemp->Free(inBuffer);
  #endif
  return res;
}

SZ_RESULT SzArchiveOpen2(
    ISzInStream *inStream, 
    CArchiveDatabaseEx *db,
    ISzAlloc *allocMain, 
    ISzAlloc *allocTemp)
{
  Byte signature[k7zSignatureSize];
  Byte version;
  UInt32 crcFromArchive;
  UInt64 nextHeaderOffset;
  UInt64 nextHeaderSize;
  UInt32 nextHeaderCRC;
  UInt32 crc;
  CFileSize pos = 0;
  CSzByteBuffer buffer;
  CSzData sd;
  SZ_RESULT res;

  RINOK(SafeReadDirect(inStream, signature, k7zSignatureSize));

  if (!TestSignatureCandidate(signature))
    return SZE_ARCHIVE_ERROR;

  /*
  db.Clear();
  db.ArchiveInfo.StartPosition = _arhiveBeginStreamPosition;
  */
  RINOK(SafeReadDirectByte(inStream, &version));
  if (version != k7zMajorVersion)
    return SZE_ARCHIVE_ERROR;
  RINOK(SafeReadDirectByte(inStream, &version));

  RINOK(SafeReadDirectUInt32(inStream, &crcFromArchive));

  CrcInit(&crc);
  RINOK(SafeReadDirectUInt64(inStream, &nextHeaderOffset));
  CrcUpdateUInt64(&crc, nextHeaderOffset);
  RINOK(SafeReadDirectUInt64(inStream, &nextHeaderSize));
  CrcUpdateUInt64(&crc, nextHeaderSize);
  RINOK(SafeReadDirectUInt32(inStream, &nextHeaderCRC));
  CrcUpdateUInt32(&crc, nextHeaderCRC);

  pos = k7zStartHeaderSize;
  db->ArchiveInfo.StartPositionAfterHeader = pos;
  
  if (CrcGetDigest(&crc) != crcFromArchive)
    return SZE_ARCHIVE_ERROR;

  if (nextHeaderSize == 0)
    return SZ_OK;

  RINOK(inStream->Seek(inStream, (CFileSize)(pos + nextHeaderOffset)));

  if (!SzByteBufferCreate(&buffer, (size_t)nextHeaderSize, allocTemp->Alloc))
    return SZE_OUTOFMEMORY;

  res = SafeReadDirect(inStream, buffer.Items, (size_t)nextHeaderSize);
  if (res == SZ_OK)
  {
    if (CrcVerifyDigest(nextHeaderCRC, buffer.Items, (UInt32)nextHeaderSize))
    {
      while (1)
      {
        UInt64 type;
        sd.Data = buffer.Items;
        sd.Size = buffer.Capacity;
        res = SzReadID(&sd, &type);
        if (res != SZ_OK)
          break;
        if (type == k7zIdHeader)
        {
          res = SzReadHeader(&sd, db, allocMain, allocTemp);
          break;
        }
        if (type != k7zIdEncodedHeader)
        {
          res = SZE_ARCHIVE_ERROR;
          break;
        }
        {
          CSzByteBuffer outBuffer;
          res = SzReadAndDecodePackedStreams(inStream, &sd, &outBuffer, 
              db->ArchiveInfo.StartPositionAfterHeader, 
              allocTemp);
          if (res != SZ_OK)
          {
            SzByteBufferFree(&outBuffer, allocTemp->Free);
            break;
          }
          SzByteBufferFree(&buffer, allocTemp->Free);
          buffer.Items = outBuffer.Items;
          buffer.Capacity = outBuffer.Capacity;
        }
      }
    }
  }
  SzByteBufferFree(&buffer, allocTemp->Free);
  return res;
}

SZ_RESULT SzArchiveOpen(
    ISzInStream *inStream, 
    CArchiveDatabaseEx *db,
    ISzAlloc *allocMain, 
    ISzAlloc *allocTemp)
{
  SZ_RESULT res = SzArchiveOpen2(inStream, db, allocMain, allocTemp);
  if (res != SZ_OK)
    SzArDbExFree(db, allocMain->Free);
  return res;
}
/* 7zItem.c */


void SzCoderInfoInit(CCoderInfo *coder)
{
  SzByteBufferInit(&coder->Properties);
}

void SzCoderInfoFree(CCoderInfo *coder, void (*freeFunc)(void *p))
{
  SzByteBufferFree(&coder->Properties, freeFunc);
  SzCoderInfoInit(coder);
}

void SzFolderInit(CFolder *folder)
{
  folder->NumCoders = 0;
  folder->Coders = 0;
  folder->NumBindPairs = 0;
  folder->BindPairs = 0;
  folder->NumPackStreams = 0;
  folder->PackStreams = 0;
  folder->UnPackSizes = 0;
  folder->UnPackCRCDefined = 0;
  folder->UnPackCRC = 0;
  folder->NumUnPackStreams = 0;
}

void SzFolderFree(CFolder *folder, void (*freeFunc)(void *p))
{
  UInt32 i;
  for (i = 0; i < folder->NumCoders; i++)
    SzCoderInfoFree(&folder->Coders[i], freeFunc);
  freeFunc(folder->Coders);
  freeFunc(folder->BindPairs);
  freeFunc(folder->PackStreams);
  freeFunc(folder->UnPackSizes);
  SzFolderInit(folder);
}

UInt32 SzFolderGetNumOutStreams(CFolder *folder)
{
  UInt32 result = 0;
  UInt32 i;
  for (i = 0; i < folder->NumCoders; i++)
    result += folder->Coders[i].NumOutStreams;
  return result;
}

int SzFolderFindBindPairForInStream(CFolder *folder, UInt32 inStreamIndex)
{
  UInt32 i;
  for(i = 0; i < folder->NumBindPairs; i++)
    if (folder->BindPairs[i].InIndex == inStreamIndex)
      return i;
  return -1;
}


int SzFolderFindBindPairForOutStream(CFolder *folder, UInt32 outStreamIndex)
{
  UInt32 i;
  for(i = 0; i < folder->NumBindPairs; i++)
    if (folder->BindPairs[i].OutIndex == outStreamIndex)
      return i;
  return -1;
}

CFileSize SzFolderGetUnPackSize(CFolder *folder)
{ 
  int i = (int)SzFolderGetNumOutStreams(folder);
  if (i == 0)
    return 0;
  for (i--; i >= 0; i--)
    if (SzFolderFindBindPairForOutStream(folder, i) < 0)
      return folder->UnPackSizes[i];
  /* throw 1; */
  return 0;
}

/*
int FindPackStreamArrayIndex(int inStreamIndex) const
{
  for(int i = 0; i < PackStreams.Size(); i++)
  if (PackStreams[i] == inStreamIndex)
    return i;
  return -1;
}
*/

void SzFileInit(CFileItem *fileItem)
{
  fileItem->IsFileCRCDefined = 0;
  fileItem->HasStream = 1;
  fileItem->IsDirectory = 0;
  fileItem->IsAnti = 0;
  fileItem->Name = 0;
}

void SzFileFree(CFileItem *fileItem, void (*freeFunc)(void *p))
{
  freeFunc(fileItem->Name);
  SzFileInit(fileItem);
}

void SzArchiveDatabaseInit(CArchiveDatabase *db)
{
  db->NumPackStreams = 0;
  db->PackSizes = 0;
  db->PackCRCsDefined = 0;
  db->PackCRCs = 0;
  db->NumFolders = 0;
  db->Folders = 0;
  db->NumFiles = 0;
  db->Files = 0;
}

void SzArchiveDatabaseFree(CArchiveDatabase *db, void (*freeFunc)(void *))
{
  UInt32 i;
  for (i = 0; i < db->NumFolders; i++)
    SzFolderFree(&db->Folders[i], freeFunc);
  for (i = 0; i < db->NumFiles; i++)
    SzFileFree(&db->Files[i], freeFunc);
  freeFunc(db->PackSizes);
  freeFunc(db->PackCRCsDefined);
  freeFunc(db->PackCRCs);
  freeFunc(db->Folders);
  freeFunc(db->Files);
  SzArchiveDatabaseInit(db);
}
/* 7zMethodID.c */


int AreMethodsEqual(CMethodID *a1, CMethodID *a2)
{
  int i;
  if (a1->IDSize != a2->IDSize)
    return 0;
  for (i = 0; i < a1->IDSize; i++)
    if (a1->ID[i] != a2->ID[i])
      return 0;
  return 1;
}
