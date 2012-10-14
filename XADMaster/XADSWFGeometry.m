#import "XADSWFGeometry.h"
#import <math.h>


SWFPoint SWFPointOnLine(SWFPoint a,SWFPoint b,float t)
{
	return SWFMakePoint(
		(float)a.x*(1-t)+(float)b.x*t,
		(float)a.y*(1-t)+(float)b.y*t
	);
}

SWFRect SWFParseRect(CSHandle *fh)
{
	int bits=[fh readBits:5];
	int xmin=[fh readSignedBits:bits];
	int xmax=[fh readSignedBits:bits];
	int ymin=[fh readSignedBits:bits];
	int ymax=[fh readSignedBits:bits];

	[fh flushReadBits];

	return SWFMakeRect(xmin,ymin,xmax-xmin,ymax-ymin);
}

void SWFWriteRect(SWFRect rect,CSHandle *fh)
{
	int xmin=rect.x;
	int xmax=rect.x+rect.width;
	int ymin=rect.y;
	int ymax=rect.y+rect.height;
	int bits=SWFCountSignedBits4(xmin,xmax,ymin,ymax);

	[fh writeSignedBits:5 value:bits];
	[fh writeSignedBits:bits value:xmin];
	[fh writeSignedBits:bits value:xmax];
	[fh writeSignedBits:bits value:ymin];
	[fh writeSignedBits:bits value:ymax];
	[fh flushWriteBits];
}

SWFMatrix SWFParseMatrix(CSHandle *fh)
{
	int a00=1<<16,a01=0,a02=0;
	int a10=0,a11=1<<16,a12=0;

	if([fh readBits:1])
	{
		int bits=[fh readBits:5];
		a00=[fh readSignedBits:bits];
		a11=[fh readSignedBits:bits];
	}

	if([fh readBits:1])
	{
		int bits=[fh readBits:5];
		a10=[fh readSignedBits:bits];
		a01=[fh readSignedBits:bits];
	}

	int bits=[fh readBits:5];
	a02=[fh readSignedBits:bits];
	a12=[fh readSignedBits:bits];

	[fh flushReadBits];

	return SWFMakeMatrix(a00,a01,a02,a10,a11,a12);
}

void SWFWriteMatrix(SWFMatrix mtx,CSHandle *fh)
{
	if(mtx.a00!=1<<16||mtx.a11!=1<<16)
	{
		int bits=SWFCountSignedBits2(mtx.a00,mtx.a11);
		[fh writeBits:1 value:1];
		[fh writeBits:5 value:bits];
		[fh writeBits:bits value:mtx.a00];
		[fh writeBits:bits value:mtx.a11];
	}
	else [fh writeBits:1 value:0];

	if(mtx.a01!=0||mtx.a10!=0)
	{
		int bits=SWFCountSignedBits2(mtx.a01,mtx.a10);
		[fh writeBits:1 value:1];
		[fh writeBits:5 value:bits];
		[fh writeBits:bits value:mtx.a10];
		[fh writeBits:bits value:mtx.a01];
	}
	else [fh writeBits:1 value:0];

	int bits=SWFCountSignedBits2(mtx.a02,mtx.a12);
	[fh writeBits:5 value:bits];
	[fh writeBits:bits value:mtx.a02];
	[fh writeBits:bits value:mtx.a12];

	[fh flushWriteBits];
}

static inline int fixmult(int a,int b) { return (((int64_t)a)*((int64_t)b))/65536; }

SWFMatrix SWFMultiplyMatrices(SWFMatrix a,SWFMatrix b)
{
	return SWFMakeMatrix(
		fixmult(a.a00,b.a00)+fixmult(a.a01,b.a10),
		fixmult(a.a00,b.a01)+fixmult(a.a01,b.a11),
		fixmult(a.a00,b.a02)+fixmult(a.a01,b.a12)+a.a02,
		fixmult(a.a10,b.a00)+fixmult(a.a11,b.a10),
		fixmult(a.a10,b.a01)+fixmult(a.a11,b.a11),
		fixmult(a.a10,b.a02)+fixmult(a.a11,b.a12)+a.a12
	);
}

SWFMatrix SWFScalingMatrix(float x_scale,float y_scale)
{
	return SWFMakeMatrix(
		65536*x_scale,0,0,
		0,65536*y_scale,0
	);
}

SWFMatrix SWFRotationMatrix(float degrees)
{
	double rad=degrees*M_PI/180;
	return SWFMakeMatrix(
		65536*cos(rad),-65536*sin(rad),0,
		65536*sin(rad),65536*cos(rad),0
	);
}



/*SWFMatrix SWFMatrixFromAffineTransform(NSAffineTransform *t)
{
	NSAffineTransformStruct a=[t transformStruct];
	SWFMatrix res={
		a.m11*65536.0,a.m21*65536.0,a.tX*20.0,
		a.m12*65536.0,a.m22*65536.0,a.tY*20.0
	};
	return res;
}

NSAffineTransform *SWFAffineTransformFromMatrix(SWFMatrix m)
{
	NSAffineTransformStruct a={
		(float)m.a00/65536.0,(float)m.a10/65536.0,
		(float)m.a01/65536.0,(float)m.a11/65536.0,
		(float)m.a02/20.0,(float)m.a12/20.0
	}
	NSAffineTransform *t=[NSAffineTransform transform];
	[transform setTransformStruct:a];
	return t;
}*/




static inline int imax(int a,int b) { return a>b?a:b; }

int SWFCountBits(uint32_t val)
{
	int res=0;
	if(val==0) return 0;
	if(val&0xFFFF0000) { res|=16; val>>=16; }
	if(val&0x0000FF00) { res|=8; val>>=8; }
	if(val&0x000000F0) { res|=4; val>>=4; }
	if(val&0x0000000C) { res|=2; val>>=2; }
	if(val&0x00000002) { res|=1; }
	return res+1;
}


int SWFCountBits2(uint32_t val1,uint32_t val2)
{
	return imax(SWFCountBits(val1),SWFCountBits(val2));
}

int SWFCountBits4(uint32_t val1,uint32_t val2,uint32_t val3,uint32_t val4)
{
	return imax(SWFCountBits2(val1,val2),SWFCountBits2(val3,val4));
}


int SWFCountSignedBits(int32_t val)
{
	if(val==0) return 0;
	else if(val<0) return SWFCountBits(~val)+1;
	else return SWFCountBits(val)+1;
}

int SWFCountSignedBits2(int32_t val1,int32_t val2)
{
	return imax(SWFCountSignedBits(val1),SWFCountSignedBits(val2));
}

int SWFCountSignedBits4(int32_t val1,int32_t val2,int32_t val3,int32_t val4)
{
	return imax(SWFCountSignedBits2(val1,val2),SWFCountSignedBits2(val3,val4));
}
