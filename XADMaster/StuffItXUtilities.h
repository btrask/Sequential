#import "CSHandle.h"
#import "CSInputBuffer.h"

uint64_t ReadSitxP2(CSHandle *fh);
uint32_t ReadSitxUInt32(CSHandle *fh);
uint64_t ReadSitxUInt64(CSHandle *fh);
NSData *ReadSitxString(CSHandle *fh);
NSData *ReadSitxData(CSHandle *fh,int n);

uint64_t CSInputNextSitxP2(CSInputBuffer *fh);
