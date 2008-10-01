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
