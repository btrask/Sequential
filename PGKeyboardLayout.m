/* Copyright © 2007-2009, The Sequential Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the Sequential Project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE SEQUENTIAL PROJECT ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE SEQUENTIAL PROJECT BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGKeyboardLayout.h"

unsigned short PGKeyCodeFromUnichar(unichar c)
{
	switch(c) {
		case 'a': return PGKeyA;
		case 'b': return PGKeyB;
		case 'c': return PGKeyC;
		case 'd': return PGKeyD;
		case 'e': return PGKeyE;
		case 'f': return PGKeyF;
		case 'g': return PGKeyG;
		case 'i': return PGKeyI;
		case 'j': return PGKeyJ;
		case 'k': return PGKeyK;
		case 'l': return PGKeyL;
		case 'm': return PGKeyM;
		case 'n': return PGKeyN;
		case 'q': return PGKeyQ;
		case 'r': return PGKeyR;
		case 's': return PGKeyS;
		case 't': return PGKeyT;
		case 'v': return PGKeyV;
		case 'z': return PGKeyZ;

		case '[': return PGKeyOpenBracket;
		case ']': return PGKeyCloseBracket;

		default: return PGKeyUnknown;
	}
}
