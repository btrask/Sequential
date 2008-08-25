/* Copyright © 2007-2008 The Sequential Project. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal with the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:
1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimers.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimers in the
   documentation and/or other materials provided with the distribution.
3. Neither the name of The Sequential Project nor the names of its
   contributors may be used to endorse or promote products derived from
   this Software without specific prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
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
