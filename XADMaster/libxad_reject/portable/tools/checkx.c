/*  CheckX for UNIX
 *  Copyright (C) 2004 Stuart Caie <kyzer@4u.net>
 *
 *  XAD library system for archive handling
 *  Copyright (C) 1998 and later by Dirk Stöcker <soft@dstoecker.de>
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/* This program scans for compressed files, 'linked' files, file archives
 * and disk archives and unpacks them all. It operates recursively on all
 * unpacked data and thus really does check everything.
 *
 * The main purpose of this is to perform a virus check on all files,
 * however it can be used without virus checking. It can also save all
 * decompressed files to a chosen directory.
 *
 * Usage: checkx [--virus <virus-scanner>]
 *               [--save <savedir>]
 *               [--recursive] 
 *               [--skip <archive|diskimage|compressed|linked>]
 *               [--checksum <none|crc|sha|md5>]
 *               [--pass <passfile>]
 *               <file(s) or directory(s)>
 *
 * Use --virus to select a virus checker. The default is to use the first
 * virus checker found, or perform no virus scanning if no virus scanner
 * is found. Choose from the following scanners:
 *
 *   navs      Network Associates Virus Scan
 *   sophos    Sophos Anti Virus for UNIX
 *   avp       Kaspersky Lab AntiViral Toolkit Pro (AVP)
 *   vfind     CyberSoft VFind
 *   vscan     Trend Micro FileScanner
 *   cai       CAI InoculateIT
 *   fsav      F-Secure AV
 *   custom    Your own custom virus scanner.
 *   none      Do not perform any virus scanning.
 *
 * If "custom" is chosen as the virus scanner, the full path to your
 * chosen virus scanning command should be given in the VIRUS_SCANNER
 * environment variable. It should be the fully qualified path to an
 * executable file. It will be called with one argument, the file to scan.
 * It should not try unpacking the file as an archive (CheckX is doing
 * that), and it should exit with return code 0 to indicate no virus
 * present, or exit with return code 1 to indicate a virus is present. Any
 * other code is indication of failure of the virus checker itself. It
 * should not print to stdout or stderr except to say what the virus is.
 *
 * If --save <savedir> is used, all files unpacked will be saved in
 * <savedir> with their name, in flat order (no subdirectories). There can
 * only be one savedir. The default is no savedir.
 *
 * If --recursive is used, any directories given on the command line will
 * be recursively scanned for files. This is not related to the scanning
 * of archives, disk images, etc. which is always recursive.
 *
 * Use --skip to pick types of file to avoid recursing into:
 *
 *   --skip archive     don't will not unpack file archives with XAD
 *   --skip diskimage   don't unpack disk archives or disk images with XAD
 *   --skip compressed  don't unpack singly compressed files with XFD
 *   --skip linked      don't unlink linked files with XFD
 *
 * --skip can also be used multiple times on the command line, or you can
 * use 'A', 'D', 'C' and/or 'L' to put multiple settings in a single usage,
 * e.g. --skip ADC
 *
 * --checksum <type> can be used to display a type of checksum when
 * listing filenames. "none" shows no checksum. "crc" displays a generic
 * CRC32, "sha" shows a SHA-1 checksum, md5 shows an MD5 checksum.
 *
 * --pass <passfile> selects a file to retrieve password(s) from, used
 * when files can't be unpacked because they need a password. There should
 * be one password per line. You can also use the file "ASK" to make
 * CheckX prompt you for a password. If you need to use a password file
 * in the current directory called ASK, use "./ASK" :)
 */

#define _GNU_SOURCE 1

#if HAVE_CONFIG_H
#  include <config.h>
#endif

#include <stdio.h>

#if HAVE_SYS_TYPES_H
# include <sys/types.h>
#endif

#if HAVE_DIRENT_H
# include <dirent.h>
#endif

#if HAVE_ERRNO_H
# include <errno.h>
#endif

#if HAVE_STDARG_H
# include <stdarg.h>
#endif

#if HAVE_STDLIB_H
# include <stdlib.h>
#endif

#if HAVE_STRING_H
# include <string.h>
#endif

#if HAVE_STRINGS_H
# include <strings.h>
#endif

#if HAVE_SYS_STAT_H
# include <sys/stat.h>
#endif

#if HAVE_SYS_WAIT_H
# include <sys/wait.h>
#endif

#if HAVE_UNISTD_H
# include <unistd.h>
#endif

#if !STDC_HEADERS
# if !HAVE_STRCHR
#  define strchr index
#  define strrchr rindex
# endif
# if !HAVE_STRCASECMP
#  define strcasecmp strcmpi
# endif
# if !HAVE_MEMCPY
#  define memcpy(d,s,n) bcopy((s),(d),(n))
# endif
#endif
#include "getopt.h"

#include <xadmaster.h>

static const struct option optList[] = {
  { "virus",         1, NULL, 'V' },
  { "save",          1, NULL, 'd' },
  { "recursive",     0, NULL, 'R' },
  { "skip",          1, NULL, 's' },
  { "checksum",      1, NULL, 'c' },
  { "pass",          0, NULL, 'p' },
  { "help",          0, NULL, 'h' },
  { "version",       0, NULL, 'v' },
  { NULL,            0, NULL, 0   }
};

/* options for --virus */
#define VIRUS_ANY     (0)
#define VIRUS_NAVS    (1)
#define VIRUS_SOPHOS  (2)
#define VIRUS_AVP     (3)
#define VIRUS_VFIND   (4)
#define VIRUS_VSCAN   (5)
#define VIRUS_CAI     (6)
#define VIRUS_FSAV    (7)
#define VIRUS_CUSTOM  (8)
#define VIRUS_NONE    (9)

/* options for --skip */
#define SKIP_ARCHIVE (1 << 0)
#define SKIP_DISK    (1 << 1)
#define SKIP_PACKED  (1 << 2)
#define SKIP_LINKED  (1 << 3)

/* options for --checksum */
#define CKSUM_NONE    (0)
#define CKSUM_CRC_ZIP (1)
#define CKSUM_SHA1    (2)
#define CKSUM_MD5     (3)

struct recallStack {
  struct recallStack *pred;
  char *fileName;
  char *fileType;
};

/* global data */
struct globalData {
  struct xadMasterBase *xadMasterBase;

  /* arguments */
  char                 *saveDir;
  char                 *passwdFile;
  unsigned char         virusChecker;
  unsigned char         askPasswd;
  unsigned char         recurse;
  unsigned char         skip;
  unsigned char         cksum;

  /* state */
  char                 *virusCheckerExe;
  unsigned int          recursionDepth;
  unsigned int          fileErrorCount;
  unsigned int          xadErrorCount;
  unsigned int          virusCount;
  struct recallStack   *recall;
};

/* prototypes */
static int processArg(struct globalData *gd, const char *arg);
static int processFile(struct globalData *gd, const char *file);
static int processFileArchive(struct globalData *gd, const char *file);
static int processDiskArchive(struct globalData *gd, const char *file);
static int processDiskImage(struct globalData *gd, const char *file);

static int initVirusChecker(struct globalData *gd);
static void freeVirusChecker(struct globalData *gd);
static int findVirusChecker(struct globalData *gd, unsigned int virusChecker);
static int runVirusChecker(struct globalData *gd, const char *file);

static int saveFile(struct globalData *gd, const char *file);

static void cksumInit(struct globalData *gd);
static void cksumPrint(struct globalData *gd, const char *file);

static char *findInPath(const char *path, const char *exe);
static int runCommand(const char *command, ...);
static char *makeTempDir();
static int deleteDir(const char *dir);


/**
 * Parses arguments, initialises the system and calls processArg() on all
 * file or directory parmeters.
 */
int main(int argc, char *argv[]) {
  int i, error = EXIT_SUCCESS, help = 0, version = 0;
  struct globalData gd;

  /* set all fields to 0 or NULL */
  memset(&gd, 0, sizeof(gd));

  /* parse options */
  while ((i = getopt_long(argc, argv, "V:d:Rs:c:phv", optList, NULL)) != -1) {
    switch (i) {
    case 'V':
      if      (!strcmp(optarg, "navs"))    gd.virusChecker = VIRUS_NAVS;
      else if (!strcmp(optarg, "sophos"))  gd.virusChecker = VIRUS_SOPHOS;
      else if (!strcmp(optarg, "avp"))     gd.virusChecker = VIRUS_AVP;
      else if (!strcmp(optarg, "vfind"))   gd.virusChecker = VIRUS_VFIND;
      else if (!strcmp(optarg, "vscan"))   gd.virusChecker = VIRUS_VSCAN;
      else if (!strcmp(optarg, "cai"))     gd.virusChecker = VIRUS_CAI;
      else if (!strcmp(optarg, "fsav"))    gd.virusChecker = VIRUS_FSAV;
      else if (!strcmp(optarg, "custom"))  gd.virusChecker = VIRUS_CUSTOM;
      else if (!strcmp(optarg, "none"))    gd.virusChecker = VIRUS_NONE;
      else if (!strcmp(optarg, "help")) {
	fprintf(stderr,
	  "Valid arguments for --virus option:\n"
          "   navs                Network Associates Virus Scan\n"
          "   sophos              Sophos Anti Virus for UNIX\n"
          "   avp                 Kaspersky Lab AntiViral Toolkit Pro (AVP)\n"
          "   vfind               CyberSoft VFind\n"
          "   vscan               Trend Micro FileScanner\n"
          "   cai                 CAI InoculateIT\n"
          "   fsav                F-Secure AV\n"
          "   custom              Use VIRUSCHECKER environment variable\n"
	  "   none                Do not perform any virus scanning\n");
	return EXIT_SUCCESS;
      }
      else {
	fprintf(stderr, "%s: bad argument to --virus: %s\n"
		"Use '--virus help' to get a list of valid arguments\n",
		argv[0], optarg);
	return EXIT_FAILURE;
      }
      break;

    case 'd':
      gd.saveDir = optarg;
      break;

    case 'R':
      gd.recurse = 1;
      break;

    case 's':
      if      (!strcmp(optarg, "archive"))    gd.skip |= SKIP_ARCHIVE;
      else if (!strcmp(optarg, "diskimage"))  gd.skip |= SKIP_DISK;
      else if (!strcmp(optarg, "compressed")) gd.skip |= SKIP_PACKED;
      else if (!strcmp(optarg, "linked"))     gd.skip |= SKIP_LINKED;
      else if (!strcmp(optarg, "help")) {
	fprintf(stderr,
	  "Valid arguments for --skip option:\n"
	  "  archive              skip file archives (ZIP, RAR, etc.)\n"
	  "  diskimage            skip disk images (ADF, ISO, etc.)\n"
	  "  compressed           skip packed files (LZO, UPX, etc.)\n"
	  "  linked               skip linked files\n"
	  "The letters A, D, C and L can also be used, e.g. --skip ADCL\n");
	return EXIT_SUCCESS;
      }
      else {
	char *p;
	for (p = optarg; *p; p++) {
	  if      (*p == 'A') gd.skip |= SKIP_ARCHIVE;
	  else if (*p == 'D') gd.skip |= SKIP_DISK;
	  else if (*p == 'C') gd.skip |= SKIP_PACKED;
	  else if (*p == 'L') gd.skip |= SKIP_LINKED;
	  else {
	    fprintf(stderr, "%s: bad argument to --skip: %s\n"
		    "Use '--skip help' to get a list of valid arguments\n",
		    argv[0], optarg);
	    return EXIT_FAILURE;
	  }
	}
      }
      break;

    case 'c':
      if      (!strcmp(optarg, "none"))  gd.cksum = CKSUM_NONE;
      else if (!strcmp(optarg, "crc"))   gd.cksum = CKSUM_CRC_ZIP;
      else if (!strcmp(optarg, "sha"))   gd.cksum = CKSUM_SHA1;
      else if (!strcmp(optarg, "md5"))   gd.cksum = CKSUM_MD5;
      else if (!strcmp(optarg, "help")) {
	fprintf(stderr,
	  "Valid arguments for --checksum option:\n"
          "  none                 Do not print a checksum\n"
          "  crc                  CRC32 as used by PKZIP\n"
          "  sha                  FIPS 180-1 Secure Hash Algorithm 1\n"
          "  md5                  RSA MD5 Message-Digest\n");
	return EXIT_SUCCESS;
      }
      else {
	fprintf(stderr, "%s: bad argument to --crc: %s\n"
		"Use '--checksum help' to get a list of valid arguments\n",
		argv[0], optarg);
	return EXIT_FAILURE;
      }
      break;

    case 'p':
      if (!strcmp(optarg, "ASK")) {
	gd.passwdFile = NULL;
	gd.askPasswd = 1;
      }
      else {
	gd.passwdFile = optarg;
	gd.askPasswd = 0;
      }
      break;

    case 'h': 
      help = 1;
      break;

    case 'v':
      version = 1;
      break;
    }
  }

  if (help) {
    fprintf(stderr,
      "Usage: %s [options] <file(s)>\n\n"
      "This will check all files for viruses. All files which are file\n"
      "archives, disk archives, disk images, compressed files or linked\n"
      "files will be unpacked and recursively checked.\n\n", argv[0]);
    fprintf(stderr,
      "Options:\n"
      "  -v   --version       print version and exit\n"
      "  -h   --help          show this help page\n"
      "  -V   --virus <X>     use the given virus-checker\n"
      "  -d   --save <X>      save unpacked files to given directory\n"
      "  -R   --recursive     recurse into directories on cmd line\n"
      "  -s   --skip <X>      skip the given type of file\n"
      "  -c   --checksum <X>  print a checksum for every file\n"
      "  -p   --password <X>  use passwords in the given file\n\n");
    fprintf(stderr,
      "Pass 'help' to --virus, --skip or --checksum for a list of options.\n"
      "Pass 'ASK' to --password to prompt for passwords as needed.\n\n"
      "CheckX is copyright (C) 1996-2004 Dirk Stoecker <soft@dstoecker.de>\n"
      "CheckX UNIX %s is copyright (C) 2004 Stuart Caie <kyzer@4u.net>\n"
      "This is free software with ABSOLUTELY NO WARRANTY.\n",
      VERSION);
    return EXIT_SUCCESS;
  }

  if (version) {
    printf("CheckX version %s\n", VERSION);
    return EXIT_SUCCESS;
  }

  if (optind == argc) {
    /* no arguments other than the options */
    fprintf(stderr, "%s: No files specified.\nTry '%s --help' "
	    "for more information.\n", argv[0], argv[0]);
    return EXIT_FAILURE;
  }

  /* verify that virus checker is available, or find default */
  if (!initVirusChecker(&gd)) {
    fprintf(stderr, "%s: Can't find chosen virus-checker.\n", argv[0]);
    return EXIT_FAILURE;
  }

  /* initialise checksumming state, if necessary */
  cksumInit(&gd);

  /* ensure the required libraries are available */
  if (!(gd.skip & (SKIP_DISK | SKIP_ARCHIVE))) {
    if (!(gd.xadMasterBase = xadOpenLibrary(12))) {
      fprintf(stderr, "%s: Can't open XAD library.\n", argv[0]);
      error = EXIT_FAILURE;
    }
  }

  /* process each argument */
  for (i = optind; i < argc; i++) {
    if (! processArg(&gd, argv[i])) error = EXIT_FAILURE;
  }

  if (!(gd.skip & (SKIP_DISK | SKIP_ARCHIVE))) {
    xadCloseLibrary(gd.xadMasterBase);
  }
  freeVirusChecker(&gd);

  printf("Summary: %u file errors, %u unpack errors, %u viruses found.\n",
	 gd.fileErrorCount, gd.xadErrorCount, gd.virusCount);

  return error;
}

/**
 * Processes a file or directory argument from the command line. If the
 * argument is a file, perform processFile() on it. If the argument is
 * a directory, and the --recursive flag was set, perform processArg() on
 * all members of that directory. Otherwise, do nothing.
 *
 * @param gd global data, fileErrorCount may be modified by this function.
 * @param arg the file or directory argument
 * @return zero for failure or non-zero for success
 */
static int processArg(struct globalData *gd, const char *arg) {
  struct stat st;

  if (stat(arg, &st) == 0) {
    if (! S_ISDIR(st.st_mode)) {
      return processFile(gd, arg);
    }
    else {
      /* directory -- handle recursively if required */
      DIR *dir;
      int ok = 1;

      if (! gd->recurse) return 1;

      if ((dir = opendir(arg))) {
	struct dirent *dirEnt;
	while ((dirEnt = readdir(dir))) {
	  char *newarg;
	  if ((strcmp(dirEnt->d_name, ".") == 0) ||
	      (strcmp(dirEnt->d_name, "..") == 0)) continue;

	  if ((newarg = malloc(strlen(arg) + strlen (dirEnt->d_name) + 2))) {
	    sprintf(newarg, "%s/%s", arg, dirEnt->d_name);
	    if (!processArg(gd, newarg)) ok = 0;
	    free(newarg);
	  }
	}
	closedir(dir);
	return ok;
      }
    }
  }
  perror(arg);
  gd->fileErrorCount++;
  return 0;
}

/**
 * Processes a single file by scanning it for viruses and then trying to
 * decompress it in any way and recursively perform on any further data
 * found by decompression.
 *
 * @param gd global data
 * @param file the file to act on
 * @return zero for failure or non-zero for success
 */
static int processFile(struct globalData *gd, const char *file) {
  int i, ok = 1;

  /* Checksum file if --checksum <type> is set. Print filename either with
   * checksum or not, as determined. */
  cksumPrint(gd, file);
  i = gd->recursionDepth; while (i--) putchar('*');
  puts(file);

  /* Check file for viruses with chosen virus-scanner */
  if (runVirusChecker(gd, file)) {
    struct recallStack *recall;
    printf("VIRUS FOUND in file %s\n", file);
    for (recall = gd->recall; recall; recall = recall->pred) {
      printf("  in file %s [%s]\n", recall->fileName, recall->fileType);
    }
    gd->virusCount++;
  }

  /* Save file to savedir if --save <savedir> is set. */
  if (! saveFile(gd, file)) ok = 0;

  /* Test if file is an archive (unless --skip archive is set).  If so,
   * extract every file in the archive and recursively processFile() every
   * file. After recursive completion, delete all extracted files. */
  if (! processFileArchive(gd, file)) ok = 0;

  /* Test if file is a disk archive (unless --skip diskimage is set).  If
   * so, extract disk image and recursively processFile() the unpacked
   * diskimage. After recursive completion, delete diskimage. */
  if (! processDiskArchive(gd, file)) ok = 0;

  /* Test if file is a disk image (unless --skip diskimage is set). If so,
   * extract all files from disk image and recursively processFile() every
   * file. */
  if (! processDiskImage(gd, file)) ok = 0;

  return ok;
}

/* Tests if a file is a file archives and extracts the contents if so. Then
 * processFile() is run on each archive member.
 * 
 * @param gd global data
 * @param file file to extract
 * @return zero for failure or non-zero for success
 */
static int processFileArchive(struct globalData *gd, const char *file) {
  struct xadArchiveInfo *ai;
  struct xadFileInfo *fi;
  xadERROR xadErr;
  int ok = 1;

  if (gd->skip & SKIP_ARCHIVE) return 1; 

  if ((ai = xadAllocObjectA(gd->xadMasterBase, XADOBJ_ARCHIVEINFO, NULL))) {
    xadErr = xadGetInfo(gd->xadMasterBase, ai, XAD_INFILENAME, file,
					       TAG_DONE);
    if (xadErr == 0) {
      char *tempdir = makeTempDir();
      if (tempdir) {
        for (fi = ai->xai_FileInfo; fi; fi = fi->xfi_Next) {
	}	
	deleteDir(tempdir);
	free(tempdir);
      }
      else {
	fprintf(stderr, "%s: can't make temporary directory\n", file);
	ok = 0;
      }
    }
    else {
      fprintf(stderr, "%s: XAD error: %s\n", file,
	      xadGetErrorText(gd->xadMasterBase, xadErr));
      ok = 0;
    }
    xadFreeObjectA(gd->xadMasterBase, ai, NULL);
  }
  else {
    fprintf(stderr, "%s: XAD allocation error\n", file);
    ok = 0;
  }
  return ok; 
}

static int processDiskArchive(struct globalData *gd, const char *file) {
  return 0;
}

static int processDiskImage(struct globalData *gd, const char *file) {
  return 0;
}



/**
 * Initialises the chosen virus checker, or initialises the first one that
 * can be found, if any virus checker is acceptable.
 *
 * @param gd global data
 * @return zero for failure, non-zero for success
 */
static int initVirusChecker(struct globalData *gd) {
  if (gd->virusChecker == VIRUS_ANY) {
    if      (findVirusChecker(gd,VIRUS_NAVS))   gd->virusChecker=VIRUS_NAVS;
    else if (findVirusChecker(gd,VIRUS_SOPHOS)) gd->virusChecker=VIRUS_SOPHOS;
    else if (findVirusChecker(gd,VIRUS_AVP))    gd->virusChecker=VIRUS_AVP;
    else if (findVirusChecker(gd,VIRUS_VFIND))  gd->virusChecker=VIRUS_VFIND;
    else if (findVirusChecker(gd,VIRUS_VSCAN))  gd->virusChecker=VIRUS_VSCAN;
    else if (findVirusChecker(gd,VIRUS_CAI))    gd->virusChecker=VIRUS_CAI;
    else if (findVirusChecker(gd,VIRUS_FSAV))   gd->virusChecker=VIRUS_FSAV;
    else if (findVirusChecker(gd,VIRUS_CUSTOM)) gd->virusChecker=VIRUS_CUSTOM;
    else                                        gd->virusChecker=VIRUS_NONE;
  }
  else {
    return findVirusChecker(gd, gd->virusChecker);
  }
  return 1;
}

/**
 * Frees any resources associated with the virus checker.
 *
 * @param gd global data
 */
static void freeVirusChecker(struct globalData *gd) {
  free(gd->virusCheckerExe);
}

static const char *default_path = "/bin:/usr/bin:/usr/local/bin";
static const char *avp_path     = "/usr/local/AvpLinux:/opt/AVP:"
                                  "/usr/local/share/AVP";
static const char *vfind_path   = "/usr/local/vstk:/usr/local/vstkp";
static const char *vscan_path   = "/etc/iscan";
static const char *cai_path     = "/usr/local/inoculateit";
static const char *fsav_path    = "/usr/local/fsav";

/**
 * Searches for the given virus checker.
 *
 * @param gd global data, virusCheckerExe may be set by this function.
 * @param virusChecker one of the VIRUS_* defines
 * @return zero if virus checker not found, non-zero if found.
 */
static int findVirusChecker(struct globalData *gd, unsigned int virusChecker) {
  char *virusExe = NULL, *path = getenv("PATH");
  int result = 0;

  switch (virusChecker) {
  case VIRUS_NAVS:
    virusExe                = findInPath(path,         "uvscan");
    if (!virusExe) virusExe = findInPath(default_path, "uvscan");
    if (virusExe) result = 1;
    break;

  case VIRUS_SOPHOS:
    virusExe =                findInPath(path,         "sweep");
    if (!virusExe) virusExe = findInPath(default_path, "sweep");
    if (virusExe) result = 1;
    break;

  case VIRUS_AVP:
    virusExe =                findInPath(path,         "AvpDaemonClient");
    if (!virusExe) virusExe = findInPath(avp_path,     "AvpDaemonClient");
    if (!virusExe) virusExe = findInPath(default_path, "AvpDaemonClient");
    if (!virusExe) virusExe = findInPath(path,         "AvpDaemonTst");
    if (!virusExe) virusExe = findInPath(avp_path,     "AvpDaemonTst");
    if (!virusExe) virusExe = findInPath(default_path, "AvpDaemonTst");
    if (!virusExe) virusExe = findInPath(path,         "AvpLinux");
    if (!virusExe) virusExe = findInPath(avp_path,     "AvpLinux");
    if (!virusExe) virusExe = findInPath(default_path, "AvpLinux");
    if (!virusExe) virusExe = findInPath(path,         "kavscanner");
    if (!virusExe) virusExe = findInPath(avp_path,     "kavscanner");
    if (!virusExe) virusExe = findInPath(default_path, "kavscanner");
    if (virusExe) result = 1;
    break;

  case VIRUS_VFIND:
    virusExe =                findInPath(path,         "vfind");
    if (!virusExe) virusExe = findInPath(vfind_path,   "vfind");
    if (!virusExe) virusExe = findInPath(default_path, "vfind");
    if (virusExe) result = 1;
    break;

  case VIRUS_VSCAN:
    virusExe =                findInPath(path,         "vscan");
    if (!virusExe) virusExe = findInPath(vscan_path,   "vscan");
    if (!virusExe) virusExe = findInPath(default_path, "vscan");
    if (virusExe) result = 1;
    break;

  case VIRUS_CAI:
    virusExe =                findInPath(path,         "inocucmd");
    if (!virusExe) virusExe = findInPath(cai_path,     "inocucmd");
    if (!virusExe) virusExe = findInPath(default_path, "inocucmd");
    if (virusExe) result = 1;
    break;

  case VIRUS_FSAV:
    virusExe =                findInPath(path,         "fsav");
    if (!virusExe) virusExe = findInPath(fsav_path,    "fsav");
    if (!virusExe) virusExe = findInPath(default_path, "fsav");
    if (virusExe) result = 1;
    break;

  case VIRUS_CUSTOM:
    virusExe = getenv("VIRUS_CHECKER");
    if (virusExe) virusExe = strdup(virusExe);
    break;
  }
  
  if (virusExe) {
    if (gd->virusCheckerExe) free(gd->virusCheckerExe);
    gd->virusCheckerExe = virusExe;
  }
  return result;
}

/**
 * Checks a file for viruses.
 *
 * @param gd global data
 * @param file file to check for viruses
 * @return zero if no viruses found, non-zero if viruses found.
 */
static int runVirusChecker(struct globalData *gd, const char *file) {
  int result;
  switch (gd->virusChecker) {
  case VIRUS_NAVS:
    result = runCommand(gd->virusCheckerExe,
			"--secure", "-rv", "--noboot", file);
    if (result == 0) return 0;
    if (result == 13) return 1;
    break;

  case VIRUS_SOPHOS:
    result = runCommand(gd->virusCheckerExe,
			"-nb", "-f", "-all", "-rec", "-ss", "-sc", file);
    if (result == 0) return 0;
    if (result == 3) return 1;
    break;

  case VIRUS_AVP:
    result = runCommand(gd->virusCheckerExe,
			"-*", "-P", "-B", "-Y", file);
    if (result == 0) return 0;
    if ((result == 3) || (result == 4)) return 1;
    break;

  case VIRUS_VFIND:
    result = runCommand(gd->virusCheckerExe, file);
    if (result == 0) return 0;
    break;

  case VIRUS_VSCAN:
    result = runCommand(gd->virusCheckerExe, file);
    if (result == 0) return 0;
    break;

  case VIRUS_CAI:
    result = runCommand(gd->virusCheckerExe, file);
    if (result == 0) return 0;
    break;

  case VIRUS_FSAV:
    result = runCommand(gd->virusCheckerExe, file);
    if (result == 0) return 0;
    break;

  case VIRUS_CUSTOM:
    result = runCommand(gd->virusCheckerExe, file);
    if (result == 1) return 1;
    if (result == 0) return 0;
    break;
  }
  /* error running virus checker */
  return 0;
}

/**
 * Copies a file to the save directory, if required.
 *
 * @param gd global data
 * @param file file to copy
 * @return zero for failure, non-zero for success
 */
static int saveFile(struct globalData *gd, const char *file) {
  return 0;
}

/**
 * Initialises any state required for checksumming.
 *
 * @param gd global data
 */
static void cksumInit(struct globalData *gd) {
}

/**
 * Prints the checksum of a file to stdout.
 *
 * @param gd global data
 * @param file file to print the checksum of
 */
static void cksumPrint(struct globalData *gd, const char *file) {
}


/**
 * Searches for an executable in a list of directories. The directories
 * are given in a single string, seperated by colon (':') symbols. If an
 * executable is found and is accessable, its fully qualified filepath is
 * returned. This should be free()d once finished with.
 *
 * @param path a list of directories seperated by the ':' character
 * @param exe the name of the executable
 * @return the fully qualified executable name
 */
static char *findInPath(const char *path, const char *exe) {
  char *buf, *p, *np, *cmd;
  struct stat st;
  if (path && exe && (buf = strdup(path))) {
    for (p = buf; p; p = np) {
      if ((np = strchr(p, ':'))) *np++ = '\0';

      if ((cmd = malloc(strlen(p) + strlen(exe) + 2))) {
	sprintf(cmd, "%s/%s", p, exe);
	if ((access(cmd, X_OK) == 0) &&
	    (stat(cmd, &st) == 0) && S_ISREG(st.st_mode))
	{
	  free(buf);
	  return cmd;
	}
	free(cmd);
      }
    }
    free(buf);
  }
  return NULL;
}


/**
 * Runs a UNIX executable with optional arguments. The executable must
 * include its full path, the system path will not be searched.
 *
 * @param command the command to run
 * @return the return-code from the command, or -1 to indicate failure
 */
static int runCommand(const char *command, ...) {
  char *argv[64];
  int argc = 1, status;
  va_list ap;
  pid_t pid;

  argv[0] = (char *) command;
  va_start(ap, command);
  while ((argv[argc++] = va_arg(ap, char *))) if (argc >= 64) return -1;
  va_end(ap);

  if ((pid = fork()) == 0) {
    execv(argv[0], argv); /* child */
    exit(EXIT_FAILURE);
  }
  else if (pid > 0) {
    wait(&status); /* parent */
    if (WIFEXITED(status)) return WEXITSTATUS(status);
  }
  return -1; /* error */
}

/**
 * Creates a temporary directory in a secure manner.
 *
 * @return a fully qualified path to the temporary directory
 */
static char *makeTempDir() {
  char dir[L_tmpnam];
  int i;
  for (i = 0; i < 5; i++) {
    if (tmpnam(dir)) {
      if (mkdir(dir, 0700) == 0) break;
      if (errno != EEXIST) perror(dir);
      rmdir(dir);
    }
  }
  if (i == 5) return NULL;
  return strdup(dir);
}

/**
 * Recursively deletes a directory and all its contents.
 *
 * @param directory to delete
 * @return zero for failure or non-zero for success
 */
static int deleteDir(const char *dir) {
  struct dirent *dirEnt;
  DIR *dirPtr;
  char *file = NULL;
  struct stat st;
  int ok = 1;

  if (!(dirPtr = opendir(dir))) return 0; 

  chmod(dir, 0700);
  while ((dirEnt = readdir(dirPtr))) {
    if ((strcmp(dirEnt->d_name, ".") == 0) ||
        (strcmp(dirEnt->d_name, "..") == 0)) continue;

    file = malloc(strlen(dir) + strlen (dirEnt->d_name) + 2);
    if (!file) goto failure;
    sprintf(file, "%s/%s", dir, dirEnt->d_name);
    if (stat(file, &st) != 0) goto failure;
    if (S_ISDIR(st.st_mode) && !deleteDir(file)) goto failure;
    if (unlink(file) != 0) goto failure;
    free(file);
  }
  closedir(dirPtr);
  return (rmdir(dir) == 0) ? 1 : 0;

failure:
  free(file);
  closedir(dir);
  return 0;
}
