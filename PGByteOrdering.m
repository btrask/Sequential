#import "PGByteOrdering.h"

uint16_t PGSwapInt16ToHost(CFByteOrder byteOrder, uint16_t arg)
{
	switch(byteOrder) {
		case CFByteOrderLittleEndian: return CFSwapInt16LittleToHost(arg);
		case CFByteOrderBigEndian:    return CFSwapInt16BigToHost(arg);
		default:                      return arg;
	}
}
uint32_t PGSwapInt32ToHost(CFByteOrder byteOrder, uint32_t arg)
{
	switch(byteOrder) {
		case CFByteOrderLittleEndian: return CFSwapInt32LittleToHost(arg);
		case CFByteOrderBigEndian:    return CFSwapInt32BigToHost(arg);
		default:                      return arg;
	}
}
