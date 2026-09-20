/*
 * CoFLaunchApp -- isolated Xash3D launcher for the Cry of Fear profile.
 *
 * This launcher is intentionally small.  It resolves all runtime paths from
 * its own directory, sets XASH3D_BASEDIR for the engine, and supplies the
 * compatibility profile required by the verified client/server pair.  It
 * does not copy, patch, or modify game assets.
 */

#include <windows.h>

#include <shellapi.h>
#include <string>
#include <vector>

typedef void (*pfnChangeGame)( const char *progname );
typedef int (*pfnInit)( int argc, char **argv, const char *progname,
	int bChangeGame, pfnChangeGame func );
typedef void (*pfnShutdown)( void );

static std::wstring ModuleDirectory()
{
	wchar_t path[MAX_PATH];
	DWORD length = GetModuleFileNameW( NULL, path, ARRAYSIZE( path ));
	if( !length || length >= ARRAYSIZE( path ))
		return std::wstring();

	std::wstring result( path, length );
	std::wstring::size_type slash = result.find_last_of( L"\\/" );
	return slash == std::wstring::npos ? std::wstring() : result.substr( 0, slash );
}

static std::string Narrow( const std::wstring &value )
{
	if( value.empty( ))
		return std::string();

	int length = WideCharToMultiByte( CP_ACP, 0, value.data(), (int)value.size(),
		NULL, 0, NULL, NULL );
	if( !length )
		return std::string();

	std::string result( length, '\0' );
	WideCharToMultiByte( CP_ACP, 0, value.data(), (int)value.size(),
		&result[0], length, NULL, NULL );
	return result;
}

static bool IsSwitch( const std::wstring &value, const wchar_t *name )
{
	return _wcsicmp( value.c_str(), name ) == 0;
}

static void ShowError( const wchar_t *message )
{
	MessageBoxW( NULL, message, L"Cry of Fear launcher", MB_OK | MB_ICONERROR );
}

int wmain( int argc, wchar_t **argv )
{
	const std::wstring root = ModuleDirectory();
	if( root.empty( ))
	{
		ShowError( L"Unable to determine the launcher directory." );
		return 1;
	}

	// Xash3D resolves its root from this variable before falling back to SDL's
	// process directory.  The explicit current directory also covers DLLs and
	// the stdio filesystem module on Windows.
	if( !SetEnvironmentVariableW( L"XASH3D_BASEDIR", root.c_str( )) ||
		!SetCurrentDirectoryW( root.c_str( )))
	{
		ShowError( L"Unable to establish the isolated runtime directory." );
		return 1;
	}
	SetDllDirectoryW( root.c_str( ));

	const std::wstring enginePath = root + L"\\xash.dll";
	HMODULE engine = LoadLibraryW( enginePath.c_str( ));
	if( !engine )
	{
		ShowError( L"xash.dll is missing or could not be loaded from the launcher directory." );
		return 1;
	}

	pfnInit hostMain = (pfnInit)GetProcAddress( engine, "Host_Main" );
	pfnShutdown hostShutdown = (pfnShutdown)GetProcAddress( engine, "Host_Shutdown" );
	if( !hostMain )
	{
		ShowError( L"xash.dll does not export Host_Main." );
		FreeLibrary( engine );
		return 1;
	}

	std::vector<std::string> arguments;
	arguments.push_back( "CoFLaunchApp.exe" );
	for( int i = 1; i < argc; ++i )
	{
		const std::wstring current = argv[i];
		// Steam may provide a game argument.  The launcher owns the fixed profile,
		// so discard caller supplied values and add the fixed profile below.
		if( IsSwitch( current, L"-game" ))
		{
			if( i + 1 < argc )
				++i;
			continue;
		}
		if( IsSwitch( current, L"-cof-pmove-legacy" ))
			continue;
		arguments.push_back( Narrow( current ));
	}

	arguments.push_back( "-game" );
	arguments.push_back( "cryoffear" );
	arguments.push_back( "-cof-pmove-legacy" );
	std::vector<char *> argumentPointers;
	for( std::vector<std::string>::iterator it = arguments.begin(); it != arguments.end(); ++it )
		argumentPointers.push_back( &(*it)[0] );

	// "valve" is the engine's fallback/base directory.  The explicit -game
	// argument selects the fixed Cry of Fear directory below root.
	int result = hostMain( (int)argumentPointers.size(), argumentPointers.data(),
		"valve", 0, NULL );
	if( hostShutdown )
		hostShutdown();
	FreeLibrary( engine );
	return result;
}
