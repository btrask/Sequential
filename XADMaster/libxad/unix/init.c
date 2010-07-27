/*  $Id: init.c,v 1.20 2005/06/23 14:54:43 stoecker Exp $
    Unix startup and shutdown code.

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk Stöcker <soft@dstoecker.de>

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include "../config.h"
#undef VERSION

#include "../include/functions.h"
#include "../include/version.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
//#include <dlfcn.h>
#include <sys/types.h>
#include <dirent.h>
#include <stdlib.h>
//#include <pthread.h>

/* Lock this when you need to access globals! */
//static pthread_mutex_t GlobalMutex = PTHREAD_MUTEX_INITIALIZER;

static struct xadMasterBaseP *xadMasterBase = NULL;

/******************************************************************************
 *
 * Load external clients to memory. You must have a lock on GlobalMutex!
 * Returns XADFALSE if it can't lock the directory, XADTRUE otherwise
 *
 ******************************************************************************
 */
typedef const xadSTRING * (*XC_VERSION)();
typedef const struct xadClient * (*XC_CLIENT)();

#if 0
static xadBOOL LoadExtClients(struct xadMasterBaseP *xmb, xadSTRPTR directory)
{
  DIR *dir;
  struct dirent *dirEnt;
  char fname[512];
  unsigned int handles = xmb->xmb_NumExtClients;

  if (!(dir = opendir(directory))) return XADFALSE;

  while ((dirEnt = readdir(dir))) {
    void *handle;
    int keep = 0;

    /* attempt to load directory entry as shared object */
    snprintf(&fname[0], sizeof(fname), "%s/%s", directory, dirEnt->d_name);
    /* only load files with the SO_EXT extension */
    if (strcmp(&fname[strlen(&fname[0]) - strlen(SO_EXT)], SO_EXT) != 0)
      continue;

    if ((handle = dlopen((char *) &fname[0], RTLD_LAZY))) {
      XC_VERSION gcv = (XC_VERSION) dlsym(handle, "xad_GetClientVersion");
      XC_CLIENT  gc  = (XC_CLIENT)  dlsym(handle, "xad_GetClient");

      /* if directory has appropriate symbols */
      if (gcv && gc) {
#ifdef DEBUG
        DebugRunTime("Loaded external client: %s\n", gcv());
#endif
        if (xadAddClients(xmb, gc(), XADCF_EXTERN)) keep = 1;
      }
    }

    /* if we load a shared object and get clients from it, keep it */
    if (keep) {
      /* ensure space to store handle */
      if (!xmb->xmb_ExtClients) {
        handles = 16;
        xmb->xmb_ExtClients = malloc(sizeof(void *) * handles);
      }
      else if (xmb->xmb_NumExtClients >= handles) {
        handles *= 2; /* FIXME: memory is lost if realloc fails */
        xmb->xmb_ExtClients = realloc(xmb->xmb_ExtClients,
                                      sizeof(void *) * handles);
      }

      /* store shared object handle for later closure, don't free it */
      if (xmb->xmb_ExtClients) {
        xmb->xmb_ExtClients[xmb->xmb_NumExtClients++] = handle;
        handle = NULL;
      }
    }
    if (handle) dlclose(handle);
  }
  closedir(dir);
  return XADTRUE;
}

/******************************************************************************
 *
 * Free clients in memory.  You must have a lock on GlobalMutex!
 * WARNING: The external clients are not removed from the central client list!
 * Remove them before calling this function.
 *
 ******************************************************************************
 */

static void UnloadExtClients( struct xadMasterBaseP *xmb )
{
  unsigned int i;

  if (xmb == NULL)
    return;

  /* close the loaded libraries */
  for (i = 0; i < xmb->xmb_NumExtClients; i++) {
    dlclose(xmb->xmb_ExtClients[i]);
  }

  /* free the list of loaded clients */
  free(xmb->xmb_ExtClients);
  xmb->xmb_ExtClients = NULL;
  xmb->xmb_NumExtClients = 0;
}
#endif

/******************************************************************************
 *
 * Init the private xadMasterBase structure.
 *
 ******************************************************************************
 */

static struct xadMasterBaseP *InitXADMasterBaseP( struct xadMasterBaseP *xmb )
{
  const struct xadClient *client;
  unsigned long minsize = 0;

  if (xmb == NULL)
    return NULL;

  xmb->xmb_DefaultName            = "unnamed.dat";
  xmb->xmb_FirstClient            = NULL;
  xmb->xmb_ExtClients             = NULL;
  xmb->xmb_NumExtClients          = 0;

  xmb->xmb_InHookFH.h_Entry       = (xadUINT32 (*)()) InHookFH;
  xmb->xmb_OutHookFH.h_Entry      = (xadUINT32 (*)()) OutHookFH;
  xmb->xmb_InHookMem.h_Entry      = (xadUINT32 (*)()) InHookMem;
  xmb->xmb_OutHookMem.h_Entry     = (xadUINT32 (*)()) OutHookMem;
  xmb->xmb_InHookStream.h_Entry   = (xadUINT32 (*)()) InHookStream;
  xmb->xmb_OutHookStream.h_Entry  = (xadUINT32 (*)()) OutHookStream;
  xmb->xmb_InHookSplitted.h_Entry = (xadUINT32 (*)()) InHookSplitted;
  xmb->xmb_InHookDiskArc.h_Entry  = (xadUINT32 (*)()) InHookDiskArc;

  /* add internal clients */
  xadAddClients(xmb, RealFirstClient, 0);
  /* load and add external clients */
  //LoadExtClients(xmb, CLIENTDIR);

  for (client = xmb->xmb_FirstClient; client; client = client->xc_Next)
    if (client->xc_RecogSize > minsize)
      minsize = client->xc_RecogSize;

  xmb->xmb_RecogSize = minsize;
  MakeCRC16(xmb->xmb_CRCTable1, XADCRC16_ID1);
  MakeCRC32(xmb->xmb_CRCTable2, XADCRC32_ID1);

  return xmb;
}


/******************************************************************************
 *
 * This is the Unix version of LibInit() found in libinit.c
 *
 ******************************************************************************
 */

struct xadMasterBase *xadOpenLibrary( xadINT32 version )
{
  struct xadMasterBase *xmb;

  if (XADMASTERVERSION < version)
    return NULL;

//  pthread_mutex_lock(&GlobalMutex);

  /* Allocate and init the private xadMasterBase. I've kept allocation and
   * initialisation separate, so that InitXADMasterBaseP() can eventually be
   * reused in the Amiga build (and other builds) too, to reduce redundant code.
   */
  if (xadMasterBase == NULL)
    xadMasterBase = InitXADMasterBaseP(calloc(1, sizeof(struct xadMasterBaseP)));

  if ((xmb = (struct xadMasterBase *) xadMasterBase))
    xadMasterBase->xmb_Unix_AccessCount++;

//  pthread_mutex_unlock(&GlobalMutex);

  return xmb;
}

/******************************************************************************
 *
 * Shutdown
 *
 ******************************************************************************
 */

void xadCloseLibrary( struct xadMasterBase *xmb )
{
  if (xmb == NULL)
    return;

//  pthread_mutex_lock(&GlobalMutex);

  if (--xadMasterBase->xmb_Unix_AccessCount <= 0)
  {
    xadFreeClients(xadMasterBase);
    //UnloadExtClients(xadMasterBase);
    free(xadMasterBase);
    xadMasterBase = NULL;
  }

//  pthread_mutex_unlock(&GlobalMutex);
}
