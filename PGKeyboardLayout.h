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
#import <Cocoa/Cocoa.h>

enum {
	PGKeyA = 0,
	PGKeyB = 11,
	PGKeyC = 8,
	PGKeyD = 2,
	PGKeyE = 14,
	PGKeyF = 3,
	PGKeyG = 5,
	PGKeyI = 34,
	PGKeyJ = 38,
	PGKeyK = 40,
	PGKeyL = 37,
	PGKeyN = 45,
	PGKeyQ = 12,
	PGKeyR = 15,
	PGKeyS = 1,
	PGKeyT = 17,
	PGKeyV = 9,
	PGKeyZ = 6,

	PGKey0 = 29,
	PGKey1 = 18,
	PGKey2 = 19,
	PGKey3 = 20,
	PGKey4 = 21,
	PGKey5 = 23,
	PGKey6 = 22,
	PGKey7 = 26,
	PGKey8 = 28,
	PGKey9 = 25,

	PGKeyPeriod = 47,
	PGKeyOpenBracket = 33,
	PGKeyCloseBracket = 30,
	PGKeySpace = 49,
	PGKeyReturn = 36,
	PGKeyEscape = 53,
	PGKeyEquals = 24,
	PGKeyMinus = 27,

	PGKeyArrowUp = 126,
	PGKeyArrowDown = 125,
	PGKeyArrowLeft = 123,
	PGKeyArrowRight = 124,

	PGKeyPad0 = 82,
	PGKeyPad1 = 83,
	PGKeyPad2 = 84,
	PGKeyPad3 = 85,
	PGKeyPad4 = 86,
	PGKeyPad5 = 87,
	PGKeyPad6 = 88,
	PGKeyPad7 = 89,
	PGKeyPad8 = 91,
	PGKeyPad9 = 92,

	PGKeyPadPeriod = 65,
	PGKeyPadEnter = 76,
	PGKeyPadPlus = 69,
	PGKeyPadMinus = 78,

	PGKeyUnknown = USHRT_MAX
};

extern unsigned short PGKeyCodeFromUnichar(unichar);
