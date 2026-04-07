unit VGStackTrace;

interface

uses
  Classes, DateUtils, Generics.Collections, SyncObjs, SysUtils;

type
  TVGStackTrace = class
  private const
    FRAMES_COUNT = 10; // Defines number of frames in the stack trace

  private type
    TFramesBuffer = class
    public
      Frames: array[0..FRAMES_COUNT - 1] of string;
      HeadIndex: Integer;
      LastUpdateTime: TDateTime;
    end;

  private class var
    CVGStackTrace: TVGStackTrace;

  private
    // Stack provider for Exception
    class function GetExceptionStackInfo(P: PExceptionRecord): Pointer; static;
    class procedure CleanUpStackInfo(Info: Pointer); static;
    class function GetStackInfoString(Info: Pointer): string; static;

  private
    FStackTraceBuffers: TObjectDictionary<TThreadID, TFramesBuffer>;
    FLock: TCriticalSection;

    // Thread safe methods
    procedure EnterMethodInternal(AThreadID: TThreadID; AMethodName: string);
    function GetStackTraceInternal(AThreadID: TThreadID): string;

  public
    constructor Create;
    destructor Destroy; override;

  public
    class procedure Initialize;
    class procedure Finalize;

    // Thread safe API
    class procedure EnterMethod(AThreadID: TThreadID; AMethodName: string); overload; static;
    class procedure EnterMethod(AMethodName: string); overload; static;

    class function GetStackTrace(AThreadID: TThreadID): string; overload; inline; static;
    class function GetStackTrace: string; overload; static;
  end;

implementation

{ TVGStackTrace }

constructor TVGStackTrace.Create;
begin
  inherited;

  FLock := TCriticalSection.Create;
  FStackTraceBuffers := TObjectDictionary<TThreadID, TFramesBuffer>.Create(
    [doOwnsValues]);
end;

destructor TVGStackTrace.Destroy;
begin
  FreeAndNil(FStackTraceBuffers);
  FreeAndNil(FLock);

  inherited;
end;

class procedure TVGStackTrace.EnterMethod(AMethodName: string);
begin
  EnterMethod(TThread.Current.ThreadID, AMethodName);
end;

class procedure TVGStackTrace.EnterMethod(AThreadID: TThreadID; AMethodName: string);
begin
  CVGStackTrace.EnterMethodInternal(AThreadID, AMethodName);
end;

procedure TVGStackTrace.EnterMethodInternal(AThreadID: TThreadID; AMethodName: string);
var
  LFramesBuffer: TFramesBuffer;
  LKey: TThreadID;
begin
  FLock.Enter;
  try
    if not FStackTraceBuffers.TryGetValue(AThreadID, LFramesBuffer) then
    begin
      LFramesBuffer := TFramesBuffer.Create;
      FStackTraceBuffers.Add(AThreadID, LFramesBuffer);
    end;

    LFramesBuffer.HeadIndex :=
      (LFramesBuffer.HeadIndex + 1) mod FRAMES_COUNT;

    LFramesBuffer.Frames[LFramesBuffer.HeadIndex] := AMethodName;
    LFramesBuffer.LastUpdateTime := Now;

    // Cleanup
    if FStackTraceBuffers.Count > 100 then
      for LKey in FStackTraceBuffers.Keys.ToArray do
      begin
        LFramesBuffer := FStackTraceBuffers[LKey];
        if MinutesBetween(LFramesBuffer.LastUpdateTime, Now) > 15 then
          FStackTraceBuffers.Remove(LKey);
      end;
  finally
    FLock.Leave;
  end;
end;

class function TVGStackTrace.GetStackTrace: string;
begin
  Result := GetStackTrace(TThread.Current.ThreadID);
end;

class function TVGStackTrace.GetStackTrace(AThreadID: TThreadID): string;
begin
  Result := CVGStackTrace.GetStackTraceInternal(AThreadID);
end;

function TVGStackTrace.GetStackTraceInternal(AThreadID: TThreadID): string;
var
  LMethodName: string;
  LFramesBuffer: TFramesBuffer;
  LStringList: TStringList;
  i: Integer;
begin
  FLock.Enter;
  try
    if not FStackTraceBuffers.TryGetValue(AThreadID, LFramesBuffer) then
    begin
      Result := '';
      Exit;
    end;

    LStringList := TStringList.Create();
    try
      LStringList.Capacity := FRAMES_COUNT;
      for i := 0 to FRAMES_COUNT - 1 do
      begin
        LMethodName := LFramesBuffer.Frames[
          (LFramesBuffer.HeadIndex - i + FRAMES_COUNT) mod FRAMES_COUNT];

        if (not LMethodName.IsEmpty) then
          LStringList.Add(LMethodName);
      end;

      Result := LStringList.Text;
    finally
      FreeAndNil(LStringList);
    end;
  finally
    FLock.Leave;
  end;
end;

class function TVGStackTrace.GetExceptionStackInfo(P: PExceptionRecord): Pointer;
var
  S: string;
begin
  S := GetStackTrace;
  Result := Pointer(S);
  Pointer(S) := nil; // keep this string allocated in memory
end;

class procedure TVGStackTrace.CleanUpStackInfo(Info: Pointer);
begin
  string(Info) := ''; // deallocate string
end;

class function TVGStackTrace.GetStackInfoString(Info: Pointer): string;
begin
  Result := string(Info);
end;

class procedure TVGStackTrace.Initialize;
begin
  CVGStackTrace := TVGStackTrace.Create;

  Exception.GetExceptionStackInfoProc := GetExceptionStackInfo;
  Exception.GetStackInfoStringProc := GetStackInfoString;
  Exception.CleanupStackInfoProc := CleanUpStackInfo;
end;

class procedure TVGStackTrace.Finalize;
begin
  Exception.GetExceptionStackInfoProc := nil;
  Exception.GetStackInfoStringProc := nil;
  Exception.CleanupStackInfoProc := nil;

  FreeAndNil(CVGStackTrace);
end;


initialization
  TVGStackTrace.Initialize;

finalization
  TVGStackTrace.Finalize;

end.
