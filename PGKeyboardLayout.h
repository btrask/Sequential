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
	PGKeyM = 46,
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

	PGKeyUnknown = USHRT_MAX,
};

extern unsigned short PGKeyCodeFromUnichar(unichar);
