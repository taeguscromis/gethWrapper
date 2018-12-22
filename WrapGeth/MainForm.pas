unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { TfKillForm }

  TfKillForm = class(TForm)
    procedure FormCreate(Sender: TObject);
  public

  end;

var
  fKillForm: TfKillForm;

implementation

{$R *.frm}

{ TfKillForm }

function InjectDll2(const ProcessID: DWORD; const LibraryName: string): Integer;
const
  MAX_LIBRARYNAME   =  MAX_PATH;
type
  PLibRemote        =  ^TLibRemote;
  TLibRemote        =  packed record
    ProcessID:     DWORD;
    LibraryName:   Array [0..MAX_LIBRARYNAME] of Char;
    LibraryHandle: HMODULE;
  end;

var
   hKernel:     HMODULE;
   hProcess:    THandle;
   hThread:     THandle;
   dwNull:      DWORD;
   dwNull2:     PtrUint;
   lpRemote:    PLibRemote;
   lpLibRemote: PChar;

begin
  // Set default result of (-1), which means the injection failed
  Result := (-1);

  // Check library name and version of OS we are running on
  if (Length(LibraryName) > 0) and ((GetVersion and $80000000) = 0)then
  begin
    Result := 2;
    // Attempt to open the process
    hProcess:=OpenProcess(PROCESS_ALL_ACCESS, False, ProcessID);
    // Check process handle
    if (hProcess <> 0) then
    begin
      // Resource protection
      try
        Result:= 3;
        // Get module handle for kernel32
        hKernel:=GetModuleHandle('kernel32.dll');
        // Check handle
        if (hKernel <> 0) then
        begin
          Result := 4;
          // Allocate memory in other process
          lpLibRemote:=VirtualAllocEx(hProcess, nil, Succ(Length(LibraryName)), MEM_COMMIT, PAGE_READWRITE);
          // Check memory pointer
          if Assigned(lpLibRemote) then
          begin
            // Resource protection
            try
              Result := 5;
              // Write the library name to the memory in other process
              WriteProcessMemory(hProcess, lpLibRemote, PChar(LibraryName), Length(LibraryName), dwNull2);
              // Create the remote thread
              hThread:=CreateRemoteThread(hProcess, nil, 0, GetProcAddress(hKernel, 'LoadLibraryA'), lpLibRemote, 0, dwNull);
              // Check the thread handle
              if (hThread <> 0) then
              begin
                // Resource protection
                try
                  // Allocate a new remote injection record
                  lpRemote:=AllocMem(SizeOf(TLibRemote));
                  // Set process id
                  lpRemote^.ProcessID:=ProcessID;
                  // Copy library name
                  StrPLCopy(lpRemote^.LibraryName, LibraryName, MAX_LIBRARYNAME);
                  // Wait for the thread to complete
                  WaitForSingleObject(hThread, INFINITE);
                  // Fill in the library handle
                  GetExitCodeThread(hThread, PDWORD(lpRemote^.LibraryHandle));
                  Result := 1;
                finally
                  // Close the thread handle
                  CloseHandle(hThread);
                end;
              end;
            finally
              // Free allocated memory
              VirtualFree(lpLibRemote, 0, MEM_RELEASE);
            end;
          end;
        end;
      finally
        // Close the process handle
        CloseHandle(hProcess);
      end;
    end;
  end;
end;

procedure TfKillForm.FormCreate(Sender: TObject);
var
  FilePath: string;
begin
  FilePath := ExtractFilePath(ParamStr(0)) + 'StopGeth.dll';
  InjectDLL2(StrToInt(ParamStr(1)), FilePath);
  // wait for DLL code to execute then halt
  Sleep(2000);
  Halt;
end;

end.

