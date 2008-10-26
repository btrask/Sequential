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
