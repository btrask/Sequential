/*
 * Copyright (c) 2001, 2002, Eric M. Johnston <emj@postal.net>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by Eric M. Johnston.
 * 4. Neither the name of the author nor the names of any co-contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $Id: jpeg.c,v 1.5 2002/10/15 02:57:09 ejohnst Exp $
 */

/*
 * This module contains a minimal set of functions for parsing a JPEG
 * file, specific for use in extracting EXIF information.  Primarily, it
 * reads the input file and looks for the markers which indicate the start
 * of APP1 and APP2 sections.
 *
 * Portions of this code were developed while referencing the public domain
 * 'Jhead' program (version 1.2) by Matthias Wandel <mwandel@rim.net>.
 */

#include <stdio.h>

#include "jpeg.h"
#include "exif.h"


static FILE *infile;

/* Some data we collect from a start of frame. */

static int jpg_prcsn;			/* Precision. */
static int jpg_cmpnts;			/* Number of components. */
static unsigned int jpg_height;		/* Image height. */
static unsigned int jpg_width;		/* Image width. */
static const char *jpg_prcss;		/* Process. */

static int seensof;


/* Process string lookup table. */

static struct jpgprocess {
	int sof;
	const char *str;
} process[] = {
	{ JPEG_M_SOF0,	"Baseline" },
	{ JPEG_M_SOF1,	"Extended sequential" },
	{ JPEG_M_SOF2,	"Progressive" },
	{ JPEG_M_SOF3,	"Lossless" },
	{ JPEG_M_SOF5,	"Differential sequential" },
	{ JPEG_M_SOF6,	"Differential progressive" },
	{ JPEG_M_SOF7,	"Differential lossless" },
	{ JPEG_M_SOF9,	"Extended sequential, arithmetic coding" },
	{ JPEG_M_SOF10,	"Progressive, arithmetic coding" },
	{ JPEG_M_SOF11,	"Lossless, arithmetic coding" },
	{ JPEG_M_SOF13,	"Differential sequential, arithmetic coding" },
	{ JPEG_M_SOF14,	"Differential progressive, arithmetic coding" },
	{ JPEG_M_SOF15,	"Differential lossless, arithmetic coding" },
	{ JPEG_M_ERR,	"Unknown" },
};


/*
 * Fetch one byte of the JPEG file.
 */
static int
jpg1byte(void)
{
	int b;

	b = fgetc(infile);
	if (b == EOF)
		exifdie("invalid JPEG format");
	return (b);
}


/*
 * Fetch two bytes of the JPEG file.
 */
static unsigned int
jpg2byte(void)
{
	int b1, b2;

	b1 = fgetc(infile);
	b2 = fgetc(infile);
	if (b1 == EOF || b2 == EOF)
		exifdie("invalid JPEG format");

	return ((b1 << 8) | b2);
}


/*
 * Fetch the length of a marker.
 */
static unsigned int
mkrlen(void)
{
	unsigned int l;

	/* Length includes itself. */

	if ((l = jpg2byte()) < 2)
		exifdie("invalid JPEG marker (length mismatch)");
	return (l - 2);
}


/*
 * Skip over an uninteresting marker.
 */
static void
skipmkr(void)
{
	unsigned int l;

	l = mkrlen();
	while (l) {
		jpg1byte();
		l--;
	}
}


/*
 * Check the first bytes of the file for a marker.
 */
static int
topmkr(void)
{

	if (jpg1byte() != JPEG_M_BEG)
		return (JPEG_M_ERR);
	return (jpg1byte());
}


/*
 * Find the next JPEG marker in the file.
 */
static int
nxtmkr(void)
{
	int b;
	int bad = 0;

	/* Read until we see JPEG_MARKER. */

	while ((b = jpg1byte()) != JPEG_M_BEG)
		bad++;

	/* Read all JPEG_M_BEGs (which may be used for padding). */

	while ((b = jpg1byte()) == JPEG_M_BEG);

	if (bad)
		exifwarn("skipped spurious bytes in JPEG");

	return (b);
}


/*
 * Collect image data from the start of frame.
 * XXX Note that we clobber any previously collected info...
 */
static void
sofmrk(int mark)
{
	int i;
	unsigned int l;

	l = mkrlen();
	jpg_prcsn = jpg1byte();
	jpg_height = jpg2byte();
	jpg_width = jpg2byte();
	jpg_cmpnts = jpg1byte();

	for (i = 0; process[i].sof < JPEG_M_ERR; i++)
		if (process[i].sof == mark)
			break;
	jpg_prcss = process[i].str;

	/* Verify length. */

	if (l != (unsigned int)(6 + jpg_cmpnts * 3))
		exifdie("invalid JPEG SOF marker (length mismatch)");

	/* Skip over component info we don't care about. */

	for (i = 0; i < jpg_cmpnts; i++) {
		jpg1byte(); jpg1byte(); jpg1byte();
	}

	seensof = TRUE;
}


/*
 * Scan through a JPEG file for markers, returning interesting ones.
 * Returns false when it's done with the file.
 */
int
jpegscan(FILE *fp, int *mark, unsigned int *len, int first)
{
	infile = fp;

	/* First time through. */

	if (first && topmkr() != JPEG_M_SOI) {
		exifwarn("doesn't appear to be a JPEG file; "
		    "searching for start of image");
		if (nxtmkr() != JPEG_M_SOI)
			exifdie("start of image not found");
	}

	/* Look for interesting markers. */

	for (;;) {
		switch ((*mark = nxtmkr())) {
		case JPEG_M_EOI:
		case JPEG_M_SOS:
			return (FALSE);

		case JPEG_M_APP1:
		case JPEG_M_APP2:
			*len = mkrlen();
			return (TRUE);

		/* We might as well collect some useful info from SOFs. */

		case JPEG_M_SOF0:
		case JPEG_M_SOF1:
		case JPEG_M_SOF3:
		case JPEG_M_SOF5:
		case JPEG_M_SOF6:
		case JPEG_M_SOF7:
		case JPEG_M_SOF9:
		case JPEG_M_SOF10:
		case JPEG_M_SOF11:
		case JPEG_M_SOF13:
		case JPEG_M_SOF14:
		case JPEG_M_SOF15:
			sofmrk(*mark);
			break;

		/* Just skip past markers we don't care about. */

		default:
			skipmkr();
		}
	}

	return (FALSE);
}


/*
 * Returns some basic image info about the JPEG, gleaned from start of
 * frame sections.
 */
int
jpeginfo(int *prcsn, int *cmpnts, unsigned int *height, unsigned int *width,
    const char *prcss)
{

	*prcsn = jpg_prcsn;
	*cmpnts = jpg_cmpnts;
	*height = jpg_height;
	*width = jpg_width;
	prcss = jpg_prcss;

	return (seensof);
}
