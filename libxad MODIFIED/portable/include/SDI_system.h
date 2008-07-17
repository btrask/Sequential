#ifndef SDI_SYSTEM_H
#define SDI_SYSTEM_H

/* Includeheader

        Name:           SDI_system.h
        Versionstring:  $VER: SDI_system.h 1.1 (01.02.2004)
        Author:         SDI
        Distribution:   PD
        Description:    defines to system dependencies

 1.0   19.01.04 : first version
 1.1   01.02.04 : correct three typos

*/

/*
** This is PD (Public Domain). This means you can do with it whatever you want
** without any restrictions. I only ask you to tell me improvements, so I may
** fix the main line of this files as well.
**
** To keep confusion level low: When changing this file, please note it in
** above history list and indicate that the change was not made by myself
** (e.g. add your name or nick name).
**
** Dirk Stöcker <soft@dstoecker.de>
*/

/* first some exceptions */
#if defined(__amigaos4__) /* The OS4 system definitions */

  #define SDI_LIBBASE(type, name, iface, iname) \
          type  * name = 0; iface * iname = 0;
  #define SDI_SETSYSBASE \
          SysBase = (*((struct ExecBase **) 4)); \
          IExec   = (struct ExecIFace *)SysBase->MainInterface;
  #define SDI_OPENLIB(type, name, iface, iname, libname, version) \
          { type  * _##name; iface * _##iname = 0; \
            if((_##name = (type *) OpenLibrary(libname, version))) \
            { \
              if((_##iname = (itype *) GetInterface((struct Library *) \
              _##name, "main", 1, NULL))) \
              { name = _##name; iname = _##iname; } \
            }
  #define SDI_CLOSELIB(name, iname) \
            if(_##iname) DropInterface((struct Interface *)_##iname); \
            if(_##name) CloseLibrary((struct Library *) _##name); \
          }
  #define SDI_CHECKOPEN(name, iname) (_##name && _##iname)

/* now global variant */

  #define SDI_GLOBALLIBBASE(type, name, iface, iname) \
          SDI_LIBBASE(type, name, iface, iname)
  #define SDI_GLOBALOPENLIB(type, name, iface, iname, libname, version) \
          SDI_OPENLIB(type, name, iface, iname, libname, version)
  #define SDI_GLOBALCLOSELIB(name, iname) \
          SDI_CLOSELIB(name, iname)
  #define SDI_GLOBALCHECKOPEN(name, iname) \
          SDI_CHECKOPEN(name, iname)

#elif defined(__SASC) /* The SAS-C definitions */

  #define SDI_LIBBASE(type, name, iface, iname) /* nothing */
  #define SDI_SETSYSBASE \
          SysBase = (*((struct ExecBase **) 4));
  #define SDI_OPENLIB(type, name, iface, iname, libname, version) \
          { type *name; name = (type *) OpenLibrary(libname, version);
  #define SDI_CLOSELIB(name, iname) \
          if(name) CloseLibrary((struct Library *) name); }
  #define SDI_CHECKOPEN(name, iname) (name)

/* now global variant */

  #define SDI_GLOBALLIBBASE(type, name, iface, iname) \
          type * name = 0;
  #define SDI_GLOBALOPENLIB(type, name, iface, iname, libname, version) \
          { type * _##name; \
            if((_##name = (type *) OpenLibrary(libname, version))) \
            { name = _##name; }
  #define SDI_GLOBALCLOSELIB(name, iname) \
          if(_##name) CloseLibrary((struct Library *) _##name); }
  #define SDI_GLOBALCHECKOPEN(name, iname) (_##name)

#else /* the normal definitions */

  #define SDI_LIBBASE(type, name, iface, iname) \
          type * name = 0;
  #define SDI_SETSYSBASE \
          SysBase = (*((struct ExecBase **) 4));
  #define SDI_OPENLIB(type, name, iface, iname, libname, version) \
          { type * _##name; \
            if((_##name = (type *) OpenLibrary(libname, version))) \
            { name = _##name; }
  #define SDI_CLOSELIB(name, iname) \
          if(_##name) CloseLibrary((struct Library *) _##name); }
  #define SDI_CHECKOPEN(name, iname) (_##name)

/* now global variant */

  #define SDI_GLOBALLIBBASE(type, name, iface, iname) \
          SDI_LIBBASE(type, name, iface, iname)
  #define SDI_GLOBALOPENLIB(type, name, iface, iname, libname, version) \
          SDI_OPENLIB(type, name, iface, iname, libname, version)
  #define SDI_GLOBALCLOSELIB(name, iname) \
          SDI_CLOSELIB(name, iname)
  #define SDI_GLOBALCHECKOPEN(name, iname) \
          SDI_CHECKOPEN(name, iname)

#endif

#endif /* SDI_SYSTEM_H */
