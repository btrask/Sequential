#include <openssl/sha.h>

void SHA1_Update_WithRARBug(SHA_CTX *ctx,void *bytes,unsigned long length,int bug);
