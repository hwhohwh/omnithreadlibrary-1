///<summary>Stuff common for the OmniThreadLibrary project.</summary>
///<author>Primoz Gabrijelcic</author>
///<license>
///This software is distributed under the BSD license.
///
///Copyright (c) 2008, Primoz Gabrijelcic
///All rights reserved.
///
///Redistribution and use in source and binary forms, with or without modification,
///are permitted provided that the following conditions are met:
///- Redistributions of source code must retain the above copyright notice, this
///  list of conditions and the following disclaimer.
///- Redistributions in binary form must reproduce the above copyright notice,
///  this list of conditions and the following disclaimer in the documentation
///  and/or other materials provided with the distribution.
///- The name of the Primoz Gabrijelcic may not be used to endorse or promote
///  products derived from this software without specific prior written permission.
///
///THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
///ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
///WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
///DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
///ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
///(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
///LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
///ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
///(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
///SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
///</license>
///<remarks><para>
///   Author            : Primoz Gabrijelcic
///   Creation date     : 2008-06-12
///   Last modification : 2008-07-15
///   Version           : 0.1
///</para><para>
///   History:
///     0.1: 2008-07-15
///       - Moved in TOmniValueContainer from OtlTask. 
///</para></remarks>

unit OtlCommon;

interface

uses
  Classes,
  Variants,
  GpStuff;

const
  // reserved exit statuses
  EXIT_OK                        = 0;
  EXIT_EXCEPTION                 = integer($80000000);
  EXIT_THREADPOOL_QUEUE_TOO_LONG = EXIT_EXCEPTION + 1;
  EXIT_THREADPOOL_STALE_TASK     = EXIT_EXCEPTION + 2;
  EXIT_THREADPOOL_CANCELLED      = EXIT_EXCEPTION + 3;
  EXIT_THREADPOOL_INTERNAL_ERROR = EXIT_EXCEPTION + 4;

type
  TOmniValue = type Variant; // maybe we should use own record type with implicit overloaded for parameters instead of TOmniValue

  TOmniValueContainer = class
  strict private
    ovcCanModify: boolean;
    ovcNames    : TStringList;
    ovcValues   : array of TOmniValue;
  strict protected
    procedure Clear;
    procedure Grow;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Add(paramValue: TOmniValue; paramName: string = '');
    procedure Assign(parameters: array of TOmniValue);
    function  IsLocked: boolean; inline;
    procedure Lock; inline;
    function ParamByIdx(paramIdx: integer): TOmniValue;
    function ParamByName(const paramName: string): TOmniValue;
  end; { TOmniValueContainer }

  IOmniMonitorParams = interface
    function  GetLParam: integer;
    function  GetMessage: cardinal;
    function  GetWindow: THandle;
    function  GetWParam: integer;
  //
    property Window: THandle read GetWindow;
    property Msg: cardinal read GetMessage;
    property WParam: integer read GetWParam;
    property LParam: integer read GetLParam;
  end; { IOmniMonitorParams }

  IOmniMonitorSupport = interface ['{6D5F1191-9E4A-4DD5-99D8-694C95B0DE90}']
    function  GetMonitor: IOmniMonitorParams;
  //
    procedure Notify; overload;
    procedure Notify(obj: TObject); overload; 
    procedure RemoveMonitor;
    procedure SetMonitor(monitor: IOmniMonitorParams);
    property Monitor: IOmniMonitorParams read GetMonitor;
  end; { IOmniMonitorSupport }

  IOmniCounter = interface ['{3A73CCF3-EDC5-484F-8459-532B8C715E3C}']
    function  GetValue: integer;
    procedure SetValue(const value: integer);
  //
    function  Increment: integer;
    function  Decrement: integer;
    property Value: integer read GetValue write SetValue;
  end; { IOmniCounter }

  function CreateCounter(initialValue: integer = 0): IOmniCounter;

  function CreateOmniMonitorParams(window: THandle; msg: cardinal;
    wParam, lParam: integer): IOmniMonitorParams;
  function CreateOmniMonitorSupport: IOmniMonitorSupport;

  procedure SetThreadName(const name: string);

var
  OtlUID: TGp8AlignedInt;

implementation

uses
  Windows,
  SysUtils;

type
  TOmniCounter = class(TInterfacedObject, IOmniCounter)
  strict private
    ocValue: TGp4AlignedInt;
  protected
    function  GetValue: integer;
    procedure SetValue(const value: integer);
  public
    constructor Create(initialValue: integer);
    function Decrement: integer;
    function Increment: integer;
    property Value: integer read GetValue write SetValue;
  end; { TOmniCounter }

  TOmniMonitorParams = class(TInterfacedObject, IOmniMonitorParams)
  strict private
    ompLParam : integer;
    ompMessage: cardinal;
    ompWindow : THandle;
    ompWParam : integer;
  protected
    function  GetLParam: integer;
    function  GetMessage: cardinal;
    function  GetWindow: THandle;
    function  GetWParam: integer;
  public
    constructor Create(window: THandle; msg: cardinal; wParam, lParam: integer);
    destructor Destroy; override;
    property LParam: integer read GetLParam;
    property Msg: cardinal read GetMessage;
    property Window: THandle read GetWindow;
    property WParam: integer read GetWParam;
  end; { TOmniMonitorParams }

  TOmniMonitorSupport = class(TInterfacedObject, IOmniMonitorSupport)
  strict private
    omsMonitor: IOmniMonitorParams;
  protected
    function  GetMonitor: IOmniMonitorParams;
  public
    procedure Notify; overload;
    procedure Notify(obj: TObject); overload;
    procedure RemoveMonitor;
    procedure SetMonitor(monitor: IOmniMonitorParams);
    property Monitor: IOmniMonitorParams read GetMonitor;
  end; { TOmniMonitorSupport }

{ exports }

function CreateCounter(initialValue: integer): IOmniCounter;
begin
  Result := TOmniCounter.Create(initialValue);
end; { CreateCounter }

function CreateOmniMonitorParams(window: THandle; msg: cardinal;
  wParam, lParam: integer): IOmniMonitorParams;
begin
  Result := TOmniMonitorParams.Create(window, msg, wParam, lParam);
end; { CreateOmniMonitorParams }

function CreateOmniMonitorSupport: IOmniMonitorSupport;
begin
  Result := TOmniMonitorSupport.Create;
end; { CreateOmniMonitorSupport }

procedure SetThreadName(const name: string);
type
  TThreadNameInfo = record
    FType    : LongWord; // must be 0x1000
    FName    : PChar;    // pointer to name (in user address space)
    FThreadID: LongWord; // thread ID (-1 indicates caller thread)
    FFlags   : LongWord; // reserved for future use, must be zero
  end; { TThreadNameInfo }
var
  ThreadNameInfo: TThreadNameInfo;
begin
  ThreadNameInfo.FType := $1000;
  ThreadNameInfo.FName := PChar(name);
  ThreadNameInfo.FThreadID := $FFFFFFFF;
  ThreadNameInfo.FFlags := 0;
  try
    RaiseException($406D1388, 0, SizeOf(ThreadNameInfo) div SizeOf(LongWord), @ThreadNameInfo);
  except {ignore} end;
end; { SetThreadName }

{ TOmniValueContainer }

constructor TOmniValueContainer.Create;
begin
  inherited Create;
  ovcNames := TStringList.Create;
  ovcCanModify := true;
end; { TOmniValueContainer.Create }

destructor TOmniValueContainer.Destroy;
begin
  FreeAndNil(ovcNames);
  inherited Destroy;
end; { TOmniValueContainer.Destroy }

procedure TOmniValueContainer.Add(paramValue: TOmniValue; paramName: string);
var
  idxParam: integer;
begin
  if not ovcCanModify then
    raise Exception.Create('TOmniValueContainer: Already locked');
  if paramName = '' then
    paramName := IntToStr(ovcNames.Count);
  idxParam := ovcNames.IndexOf(paramName); 
  if idxParam < 0 then begin
    idxParam := ovcNames.Add(paramName);
    if ovcNames.Count > Length(ovcValues) then
      Grow;
  end;
  ovcValues[idxParam] := paramValue;
end; { TOmniValueContainer.Add }

procedure TOmniValueContainer.Assign(parameters: array of TOmniValue);
var
  value: TOmniValue;
begin
  if not ovcCanModify then
    raise Exception.Create('TOmniValueContainer: Already locked');
  Clear;
  SetLength(ovcValues, Length(parameters));
  for value in parameters do
    Add(value);
end; { TOmniValueContainer.Assign }

procedure TOmniValueContainer.Clear;
begin
  SetLength(ovcValues, 0);
  ovcNames.Clear;
end; { TOmniValueContainer.Clear }

procedure TOmniValueContainer.Grow;
var
  iValue   : integer;
  tmpValues: array of TOmniValue;
begin
  SetLength(tmpValues, Length(ovcValues));
  for iValue := 0 to High(ovcValues) - 1 do
    tmpValues[iValue] := ovcValues[iValue];
  SetLength(ovcValues, 2*Length(ovcValues)+1);
  for iValue := 0 to High(tmpValues) - 1 do
    ovcValues[iValue] := tmpValues[iValue];
end; { TOmniValueContainer.Grow }

function TOmniValueContainer.IsLocked: boolean;
begin
  Result := not ovcCanModify;
end; { TOmniValueContainer.IsLocked }

procedure TOmniValueContainer.Lock;
begin
  ovcCanModify := false;
end; { TOmniValueContainer.Lock }

function TOmniValueContainer.ParamByIdx(paramIdx: integer): TOmniValue;
begin
  Result := ovcValues[paramIdx];
end; { TOmniValueContainer.ParamByIdx }

function TOmniValueContainer.ParamByName(const paramName: string): TOmniValue;
begin
  Result := ovcValues[ovcNames.IndexOf(paramName)];
end; { TOmniValueContainer.ParamByName }

{ TOmniCounter }

constructor TOmniCounter.Create(initialValue: integer);
begin
  Value := initialValue;
end; { TOmniCounter.Create }

function TOmniCounter.Decrement: integer;
begin
  Result := ocValue.Decrement;
end; { TOmniCounter.Decrement }

function TOmniCounter.GetValue: integer;
begin
  Result := ocValue;
end; { TOmniCounter.GetValue }

function TOmniCounter.Increment: integer;
begin
  Result := ocValue.Increment;
end; { TOmniCounter.Increment }

procedure TOmniCounter.SetValue(const value: integer);
begin
  ocValue.Value := value;
end; { TOmniCounter.SetValue }

{ TOmniMonitorSupport }

function TOmniMonitorSupport.GetMonitor: IOmniMonitorParams;
begin
  Result := omsMonitor;
end; { TOmniMonitorSupport.GetMonitor }

procedure TOmniMonitorSupport.Notify;
var
  params: IOmniMonitorParams;
begin
  params := GetMonitor;
  if assigned(params) then
    PostMessage(params.Window, params.Msg, params.WParam, params.LParam);
end; { TOmniMonitorSupport.Notify }

procedure TOmniMonitorSupport.Notify(obj: TObject);
var
  params: IOmniMonitorParams;
begin
  params := GetMonitor;
  if assigned(params) then
    PostMessage(params.Window, params.Msg, params.WParam, LParam(obj));
end; { TOmniMonitorSupport.Notify }

procedure TOmniMonitorSupport.RemoveMonitor;
begin
  omsMonitor := nil;
end; { TOmniMonitorSupport.RemoveMonitor }

procedure TOmniMonitorSupport.SetMonitor(monitor: IOmniMonitorParams);
begin
  omsMonitor := monitor;
end; { TOmniMonitorSupport.SetMonitor }

constructor TOmniMonitorParams.Create(window: THandle; msg: cardinal; wParam, lParam:
  integer);
begin
  ompMessage := msg;
  ompLParam := lParam;
  ompWParam := wParam;
  ompWindow := window;
end; { TOmniMonitorParams.Create }

destructor TOmniMonitorParams.Destroy;
begin
  inherited Destroy;
end;

function TOmniMonitorParams.GetLParam: integer;
begin
  Result := ompLParam;
end; { TOmniMonitorParams.GetLParam }

function TOmniMonitorParams.GetMessage: cardinal;
begin
  Result := ompMessage;
end; { TOmniMonitorParams.GetMessage }

function TOmniMonitorParams.GetWindow: THandle;
begin
  Result := ompWindow;
end; { TOmniMonitorParams.GetWindow }

function TOmniMonitorParams.GetWParam: integer;
begin
  Result := ompWParam;
end; { TOmniMonitorParams.GetWParam }

end.
