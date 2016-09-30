/*
Copyright 2011 Martin T. Sandsmark <sandsmark@samfundet.no>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.*/

#include "win_defs.h"
#include "window_utsname.h"

int w_uname(struct utsname *name) {
    struct utsname *ret;
    OSVERSIONINFO versionInfo;
    SYSTEM_INFO sysInfo;
    
    // Get Windows version info
    ZeroMemory(&versionInfo, sizeof(OSVERSIONINFO));
    versionInfo.dwOSVersionInfoSize = sizeof(OSVERSIONINFO); // wtf
    GetVersionEx(&versionInfo);
    
    // Get hardware info
    ZeroMemory(&sysInfo, sizeof(SYSTEM_INFO));
    GetSystemInfo(&sysInfo);

    strcpy(name->sysname, "Windows");
    itoa(versionInfo.dwBuildNumber, name->release, 10);
    sprintf(name->version, "%i.%i", versionInfo.dwMajorVersion, versionInfo.dwMinorVersion);

    if (gethostname(name->nodename, WINDOW_UTSNAME_LENGTH) != 0) {
        if (WSAGetLastError() == WSANOTINITIALISED) { // WinSock not initialized
            WSADATA WSAData;
            WSAStartup(MAKEWORD(1, 0), &WSAData);
            gethostname(name->nodename, WINDOW_UTSNAME_LENGTH);
            WSACleanup();
        } else
            return WSAGetLastError();
    }

    switch(sysInfo.wProcessorArchitecture) {
    case PROCESSOR_ARCHITECTURE_AMD64:
        strcpy(name->machine, "x86_64");
        break;
    case PROCESSOR_ARCHITECTURE_IA64:
        strcpy(name->machine, "ia64");
        break;
    case PROCESSOR_ARCHITECTURE_INTEL:
        strcpy(name->machine, "x86");
        break;
    case PROCESSOR_ARCHITECTURE_UNKNOWN:
    default:
        strcpy(name->machine, "unknown");
    }

    return 0;
}
