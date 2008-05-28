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
 * $Id: jpeg.h,v 1.4 2002/10/15 02:57:09 ejohnst Exp $
 */

/*
 * Functions for parsing a JPEG file, specific to EXIF use.
 *
 * Portions of this code were developed while referencing the public domain
 * 'Jhead' program (version 1.2) by Matthias Wandel <mwandel@rim.net>.
 *
 */

#ifndef _JPEG_H
#define _JPEG_H

/* The JPEG marker codes we're interested in. */

#define JPEG_M_BEG	0xff	/* Start of marker. */
#define JPEG_M_SOF0	0xc0	/* Start of frame n... */
#define JPEG_M_SOF1	0xc1
#define JPEG_M_SOF2	0xc2
#define JPEG_M_SOF3	0xc3
#define JPEG_M_SOF5	0xc5
#define JPEG_M_SOF6	0xc6
#define JPEG_M_SOF7	0xc7
#define JPEG_M_SOF9	0xc9
#define JPEG_M_SOF10	0xca
#define JPEG_M_SOF11	0xcb
#define JPEG_M_SOF13	0xcd
#define JPEG_M_SOF14	0xce
#define JPEG_M_SOF15	0xcf
#define JPEG_M_SOI	0xd8	/* Start of image. */
#define JPEG_M_EOI	0xd9	/* End of image. */
#define JPEG_M_SOS	0xda	/* Start of scan. */
#define JPEG_M_APP1	0xe1	/* APP1 marker. */
#define JPEG_M_APP2	0xe2	/* APP2 marker. */
#define JPEG_M_ERR	0x100


/* Our JPEG utility functions. */

extern int jpegscan(FILE *fp, int *mark, unsigned int *len, int first);
extern int jpeginfo(int *prcsn, int *cmpnts, unsigned int *height,
    unsigned int *width, const char *prcss);

#endif
