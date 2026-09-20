#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <time.h>

typedef int qboolean;
typedef long long fs_offset_t;
typedef struct { int kind; } file_t;
#define true 1
#define false 0
#define MAX_QPATH 64
#define MAX_SYSPATH 1024
#define Q_min(a,b) ((a) < (b) ? (a) : (b))

typedef enum { F_NONE = 0, F_LABEL_OPEN = 1, F_LABEL_WRITE = 2, F_LABEL_CLOSE = 4, F_SAVE_RENAME = 8,
	F_FINAL_WRITE = 16, F_FINAL_CLOSE = 32, F_COPY_WRITE = 64, F_LABEL_BACKUP_RENAME = 128,
	F_LABEL_COMMIT_RENAME = 256, F_ROLLBACK_SAVE_RENAME = 512, F_COPY_READ = 1024,
	F_TRACK_OPEN = 2048 } fault_t;
static fault_t fault;
static int rootCompat = 1, menuEnabled = 1, gameMenu = 0, validSave = 1;
static int successMarkers, saveRenameCalls, inCopy, finalWrites;
static int haveSave, haveSaveBackup, haveLabel, haveLabelTemp, haveLabelBackup;
/* Content identity tokens travel with fake rename/delete operations. */
static unsigned saveBytes, saveBackupBytes, labelBytes, labelTempBytes, labelBackupBytes;
static file_t labelFile = { 1 }, finalFile = { 2 }, inputFile = { 3 };
static qboolean cofMenuSaveTracking, cofMenuSaveIOFailed;
struct { const char *name; } gameInfo = { "cryoffear" }, *GI = &gameInfo;
struct { char name[65]; } sv = { "c1a0" };

static int is_save(const char *p) { return strstr(p, "cofsave") != NULL; }
static int is_backup(const char *p) { return strstr(p, ".coffix-backup") != NULL; }
static int is_temp(const char *p) { return strstr(p, ".coffix-temp") != NULL; }
static int is_label(const char *p) { return strstr(p, "saveinfo") != NULL; }
static void Q_snprintf(char *b, size_t n, const char *f, ...) { va_list a; va_start(a,f); vsnprintf(b,n,f,a); va_end(a); }
static void Q_strncpy(char *d, const char *s, size_t n) { if (!n) return; strncpy(d,s,n-1); d[n-1]=0; }
static int Q_strlen(const char *s) { return (int)strlen(s); }
static int Q_stricmp(const char *a, const char *b) { return _stricmp(a,b); }
static void Con_Printf(const char *f, ...) { if (strstr(f, "committed")) successMarkers++; }
static int Cvar_VariableInteger(const char *n) { return !strcmp(n,"cof_pause_menu_saves") ? menuEnabled : !strcmp(n,"game_menu") ? gameMenu : 1; }
static qboolean IsValidSave(void) { return validSave; }
static void SaveBuildComment(char *b, size_t n) { Q_strncpy(b, "checkpoint", n); }

static file_t *RawOpen(const char *p, const char *m, qboolean g) {
	(void)m; (void)g;
	if (is_label(p) && is_temp(p)) { if (fault & F_LABEL_OPEN) return NULL; haveLabelTemp=1; labelTempBytes=0; return &labelFile; }
	if (is_save(p) && !is_backup(p)) { if (fault & F_TRACK_OPEN) return NULL; haveSave=1; saveBytes=0; }
	return &finalFile;
}
static fs_offset_t RawWrite(file_t *f, const void *p, size_t n) {
	(void)p;
	if (f->kind == 1 && (fault & F_LABEL_WRITE)) { labelTempBytes=0xBAD1; return n ? (fs_offset_t)n - 1 : 0; }
	if (f->kind == 1) labelTempBytes=0x4E45574C;
	if (f->kind == 2 && (((inCopy || finalWrites > 0) && (fault & F_COPY_WRITE)) || (!(inCopy || finalWrites > 0) && (fault & F_FINAL_WRITE)))) { saveBytes=0xBAD5; return n ? (fs_offset_t)n - 1 : 0; }
	if (f->kind == 2) { saveBytes=0x4E455753; finalWrites++; }
	return (fs_offset_t)n;
}
static int RawClose(file_t *f) {
	if (f->kind == 1 && (fault & F_LABEL_CLOSE)) return -1;
	if (f->kind == 2 && (fault & F_FINAL_CLOSE)) return -1;
	return 0;
}
static fs_offset_t RawRead(file_t *f, void *p, size_t n) { (void)f; if (fault & F_COPY_READ) return 0; memset(p, 'x', n); return (fs_offset_t)n; }
static int RawExists(const char *p, int g) {
	(void)g;
	if (is_label(p)) return is_temp(p) ? haveLabelTemp : is_backup(p) ? haveLabelBackup : haveLabel;
	return is_backup(p) ? haveSaveBackup : haveSave;
}
static qboolean RawDelete(const char *p) {
	if (is_label(p)) { if (is_temp(p)) { haveLabelTemp=0; labelTempBytes=0; } else if (is_backup(p)) { haveLabelBackup=0; labelBackupBytes=0; } else { haveLabel=0; labelBytes=0; } }
	else { if (is_backup(p)) { haveSaveBackup=0; saveBackupBytes=0; } else { haveSave=0; saveBytes=0; } }
	return true;
}
static qboolean RawRename(const char *o, const char *n) {
	if (!is_label(o)) {
		saveRenameCalls++;
		if ((fault & F_SAVE_RENAME) && saveRenameCalls == 1) return false;
		if ((fault & F_ROLLBACK_SAVE_RENAME) && saveRenameCalls == 2) return false;
		if (is_backup(n)) { haveSaveBackup=haveSave; saveBackupBytes=saveBytes; haveSave=0; saveBytes=0; } else { haveSave=haveSaveBackup; saveBytes=saveBackupBytes; haveSaveBackup=0; saveBackupBytes=0; }
		return true;
	}
	if ((fault & F_LABEL_BACKUP_RENAME) && !is_backup(o)) return false;
	if ((fault & F_LABEL_COMMIT_RENAME) && is_temp(o)) return false;
	if (is_temp(n)) { haveLabelTemp=haveLabel; labelTempBytes=labelBytes; haveLabel=0; labelBytes=0; }
	else if (is_backup(n)) { haveLabelBackup=haveLabel; labelBackupBytes=labelBytes; haveLabel=0; labelBytes=0; }
	else if (is_temp(o)) { haveLabel=haveLabelTemp; labelBytes=labelTempBytes; haveLabelTemp=0; labelTempBytes=0; }
	else { haveLabel=haveLabelBackup; labelBytes=labelBackupBytes; haveLabelBackup=0; labelBackupBytes=0; }
	return true;
}

struct fs_api { file_t *(*Open)(const char*,const char*,qboolean); fs_offset_t (*Write)(file_t*,const void*,size_t); int (*Close)(file_t*); fs_offset_t (*Read)(file_t*,void*,size_t); qboolean (*FileCopy)(file_t*,file_t*,int); int (*FileExists)(const char*,int); qboolean (*Rename)(const char*,const char*); qboolean (*Delete)(const char*); };
static qboolean RawFileCopy(file_t *o,file_t *i,int n) { (void)o;(void)i;(void)n; return true; }
static struct fs_api g_fsapi = { RawOpen, RawWrite, RawClose, RawRead, RawFileCopy, RawExists, RawRename, RawDelete };
static file_t *FS_Open(const char *p,const char*m,qboolean g) { return RawOpen(p,m,g); }
static int FS_FileExists(const char *p,int g) { return RawExists(p,g); }
static qboolean FS_Rename(const char *o,const char*n) { return RawRename(o,n); }
static qboolean FS_Delete(const char *p) { return RawDelete(p); }
static void FS_AllowDirectPaths(qboolean x) { (void)x; }

/* Extracted from the current production sv_save.c; only filesystem and engine dependencies above are stubbed. */
static qboolean SV_CoFRootSaveCompat( void ) { return rootCompat && GI && !strcmp( GI->name, "cryoffear" ); }
static qboolean SV_SaveWriteMode( const char *mode ) { return mode && ( mode[0] == 'w' || mode[0] == 'a' || mode[0] == 'e' || strchr( mode, '+' )); }
static file_t *SV_SaveFSOpen( const char *path, const char *mode, qboolean gamedironly ) { file_t *file = FS_Open(path,mode,gamedironly); if (cofMenuSaveTracking && SV_SaveWriteMode(mode) && !file) cofMenuSaveIOFailed=true; return file; }
static int SV_SaveFSFileExists( const char *path, int gamedironly ) { return FS_FileExists(path,gamedironly); }
static qboolean SV_SaveFSDelete( const char *path ) { return FS_Delete(path); }
static qboolean SV_SaveFSRename( const char *oldpath, const char *newpath ) { return FS_Rename(oldpath,newpath); }
static fs_offset_t Actual_SV_SaveFSWrite(file_t*,const void*,size_t);
static int Actual_SV_SaveFSClose(file_t*);
static qboolean Actual_SV_SaveFSFileCopy(file_t*,file_t*,int);
static qboolean SV_SaveGame(const char *name) {
	file_t *out = SV_SaveFSOpen("save/cofsaveN.sav", "wb", true);
	if (!out) return false;
	Actual_SV_SaveFSWrite(out, "header", 6); /* final SAV header/body path */
	Actual_SV_SaveFSFileCopy(out, &inputFile, 12); /* DirectoryCopy HL component path */
	Actual_SV_SaveFSClose(out);
	(void)name;
	return true; /* deliberately native-style false-success so tracker is exercised */
}

static int failures, tests;
/* Generated from the current production source before compilation. */
#define S_ERROR ""
#define S_WARN ""
#include "actual_extracted.inc"

static void reset(fault_t f) { fault=f; rootCompat=menuEnabled=validSave=1; gameMenu=0; Q_strncpy(sv.name,"c1a0",sizeof(sv.name)); successMarkers=saveRenameCalls=inCopy=finalWrites=0; haveSave=haveLabel=1; haveSaveBackup=haveLabelTemp=haveLabelBackup=0; saveBytes=0x4F4C4453; labelBytes=0x4F4C444C; saveBackupBytes=labelTempBytes=labelBackupBytes=0; cofMenuSaveTracking=cofMenuSaveIOFailed=0; }
static void expect(int ok, const char *name) { tests++; if(!ok) { failures++; printf("FAIL %s\n",name); } }
static void run_fault(fault_t f, const char *name, int rollbackRename) { reset(f); expect(!Actual_SV_CoFMenuSave(1),name); expect(successMarkers==0,"no success marker"); expect(!haveLabelTemp && !labelTempBytes,"no temp label"); if(rollbackRename) { expect(haveSaveBackup && !haveSave && saveBackupBytes==0x4F4C4453,"old save bytes retained as recovery backup"); } else { expect(haveSave && !haveSaveBackup && saveBytes==0x4F4C4453,"old save bytes restored"); } expect(haveLabel && !haveLabelBackup && labelBytes==0x4F4C444C,"old label bytes restored"); }
int main(void) {
	for(int s=1;s<=5;s++) { reset(F_NONE); expect(Actual_SV_CoFMenuSave(s),"five slot success"); expect(haveSave && haveLabel && saveBytes==0x4E455753 && labelBytes==0x4E45574C && !haveSaveBackup && !haveLabelBackup,"success committed new bytes cleanly"); }
	reset(F_NONE); menuEnabled=0; expect(!Actual_SV_CoFMenuSave(1) && saveBytes==0x4F4C4453 && labelBytes==0x4F4C444C,"disabled no mutation"); reset(F_NONE); expect(!Actual_SV_CoFMenuSave(0) && saveBytes==0x4F4C4453 && labelBytes==0x4F4C444C,"invalid no mutation"); reset(F_NONE); gameMenu=1; expect(!Actual_SV_CoFMenuSave(1) && saveBytes==0x4F4C4453 && labelBytes==0x4F4C444C,"menu cvar no mutation"); reset(F_NONE); Q_strncpy(sv.name,"C_GAME_MENU1",sizeof(sv.name)); expect(!Actual_SV_CoFMenuSave(1) && saveBytes==0x4F4C4453 && labelBytes==0x4F4C444C,"menu map name no mutation"); reset(F_NONE); validSave=0; expect(!Actual_SV_CoFMenuSave(1) && saveBytes==0x4F4C4453 && labelBytes==0x4F4C444C,"invalid save state no mutation");
	run_fault(F_LABEL_OPEN,"metadata open",0); run_fault(F_LABEL_WRITE,"metadata write",0); run_fault(F_LABEL_CLOSE,"metadata close",0); run_fault(F_SAVE_RENAME,"old save backup rename",0); run_fault(F_TRACK_OPEN,"tracked final SAV open",0); run_fault(F_FINAL_WRITE,"final SAV short write",0); run_fault(F_FINAL_CLOSE,"final SAV close",0); run_fault(F_COPY_READ,"HL FileCopy read",0); run_fault(F_COPY_WRITE,"HL FileCopy short write",0); run_fault(F_LABEL_BACKUP_RENAME,"metadata backup rename",0); run_fault(F_LABEL_COMMIT_RENAME,"metadata commit rename",0); run_fault((fault_t)(F_LABEL_COMMIT_RENAME | F_ROLLBACK_SAVE_RENAME),"rollback rename retains backup",1);
	printf("%d assertions, %d failures\n",tests,failures); return failures ? 1 : 0;
}
