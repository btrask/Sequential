/* simple open/close test of libxad */

#include <xadmaster.h>

int main(int argc, char *argv[]) {
  struct xadMasterBase *xadMasterBase;
  if ((xadMasterBase = xadOpenLibrary(12))) {
    xadCloseLibrary(xadMasterBase);
  }
  return 0;
}
