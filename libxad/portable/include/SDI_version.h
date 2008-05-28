#ifndef SDI_VERSION_H
#define SDI_VERSION_H

/* Includeheader

        Name:           SDI_version
        Versionstring:  $VER: SDI_version.h 1.1 (15.04.2001)
        Author:         SDI
        Distribution:   PD
        Description:    standard version string

 1.0   30.04.00 : excluded SDI_version.h
 1.1   15.04.01 : changed email address
*/

/*
  AUTHOR        program author - default is "by Dirk ..."
  DATE          programm creation date - default is automatically created
  DISTRIBUTION  distribution form - default is "(PD) "
  REVISION      revision number - default is "0"
  VERSION       version number - default is "1"
*/

#ifndef AUTHOR
  #define AUTHOR "by Dirk Stöcker <soft@dstoecker.de>"
#endif
#ifndef VERSION
  #define VERSION "1"
#endif
#ifndef REVISION
  #define REVISION "0"
#endif
#ifndef DATE
  #if defined(__MAXON__) || defined(__STORM__)
    #define SDI_DATE "(" __DATE2__ ")"
  #elif defined(__SASC)
    #define SDI_DATE __AMIGADATE__
  #elif defined(__GNUC__) || defined(__VBCC__)
    #define SDI_DATE "(" __DATE__ ")"
  #else
    #define SDI_DATE "(" __DATE__ ")"
  #endif
#else
  #define SDI_DATE "(" DATE ")"
#endif

#ifndef DISTRIBUTION
  #define DISTRIBUTION "(PD) "
#endif
const char * version = "$VER: " NAME " " VERSION "." REVISION " "
SDI_DATE " " DISTRIBUTION AUTHOR;

#endif /* SDI_VERSION_H */

