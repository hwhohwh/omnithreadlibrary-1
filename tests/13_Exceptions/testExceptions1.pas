unit testExceptions1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,
  OtlTask,
  OtlTaskControl,
  OtlContainers,
  OtlComm,
  OtlEventMonitor;

type
  TfrmTestLock = class(TForm)
    btnAV             : TButton;
    btnCustomException: TButton;
    btnRC             : TButton;
    lbLog             : TListBox;
    OmniTED           : TOmniTaskEventDispatch;
    btnInitException: TButton;
    btnCleanupException: TButton;
    procedure OmniTEDTaskMessage(task: IOmniTaskControl);
    procedure RunObjectTest(Sender: TObject);
    procedure RunTest(Sender: TObject);
  private
    procedure Log(const msg: string);
  public
    procedure TestException(task: IOmniTask);
  end;

var
  frmTestLock: TfrmTestLock;

implementation

uses
  SyncObjs,
  DSiWin32,
  SpinLock;

{$R *.dfm}

const
  EXC_AV     = 1;
  EXC_RC     = 2;
  EXC_CUSTOM = 3;

type
  ECustomException = class(Exception);

  TExceptionTest = class(TOmniWorker)
  strict private
    etExceptInInit: boolean;
  protected
    procedure Cleanup; override;
    function  Initialize: boolean; override;
  public
    constructor Create(exceptionInInit: boolean);
  end;

{ TExceptionTest }

constructor TExceptionTest.Create(exceptionInInit: boolean);
begin
  etExceptInInit := exceptionInInit;
end;

procedure TExceptionTest.Cleanup;
begin
  if not etExceptInInit then
    raise Exception.Create('Exception in Cleanup');
end;

function TExceptionTest.Initialize: boolean;
begin
  if etExceptInInit then
    raise Exception.Create('Exception in Initialize')
  else
    Result := true;
end;

{ TfrmTestOtlComm }

procedure TfrmTestLock.Log(const msg: string);
begin
  lbLog.ItemIndex := lbLog.Items.Add(msg);
end;

procedure TfrmTestLock.OmniTEDTaskMessage(task: IOmniTaskControl);
var
  msg: TOmniMessage;
begin
  task.Comm.Receive(msg);
  Log(msg.MsgData);
end;

procedure TfrmTestLock.RunObjectTest(Sender: TObject);
var
  task: IOmniTaskControl;
begin
  task := CreateTask(TExceptionTest.Create(Sender = btnInitException)).FreeOnTerminate.Run;
  task.Terminate;
  Log(Format('%d %s', [task.ExitCode, task.ExitMessage]));
end;

procedure TfrmTestLock.RunTest(Sender: TObject);
var
  task: IOmniTaskControl;
begin
  task := CreateTask(TestException).Run;
  if Sender = btnAV then
    task.Comm.Send(EXC_AV)
  else if Sender = btnRC then
    task.Comm.Send(EXC_RC)
  else
    task.Comm.Send(EXC_CUSTOM);
  task.Terminate;
  Log(Format('%d %s', [task.ExitCode, task.ExitMessage]));
end;

procedure TfrmTestLock.TestException(task: IOmniTask);
var
  i  : array [1..1] of integer;
  msg: TOmniMessage;
begin
  WaitForSingleObject(task.Comm.NewMessageEvent, INFINITE);
  task.Comm.Receive(msg);
  if msg.MsgID = EXC_AV then
    PChar(nil)^ := #0
  else if msg.MsgID = EXC_RC then begin
    i[1] := 42;
    i[i[1]] := 0;
  end
  else
    raise ECustomException.Create('Exception test');
end;

end.