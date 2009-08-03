#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <xadmaster.h>

int main(int argc, char *argv[]) {
  struct xadArchiveInfo *ai;
  struct xadMasterBase *xmb;
  xadINT32 err;

  if (argc != 2) {
    printf("%s <archive>\n", argv[0]);
    return 0;
  }

  if (!(xmb = xadOpenLibrary(10))) return 0;

  if ((ai = xadAllocObjectA(xmb, XADOBJ_ARCHIVEINFO, 0))) {
    err = xadGetInfo(xmb, ai, XAD_INFILENAME, argv[1], TAG_DONE);
    if (err == XADERR_OK) xadFreeInfo(xmb, ai);
    else {
      printf("xadGetInfo: %s\n", xadGetErrorText(xmb, err));
      if (err == XADERR_FILETYPE) {
        printf("trying again as image...\n");
        err = xadGetDiskInfo(xmb, ai, XAD_INFILENAME, argv[1], TAG_DONE);
        if (err == XADERR_OK) xadFreeInfo(xmb, ai);
        else printf("xadGetDiskInfo: %s\n", xadGetErrorText(xmb, err));
      }
    }
    xadFreeObjectA(xmb, ai, 0);
  }
  xadCloseLibrary(xmb);
  return 0;
}
