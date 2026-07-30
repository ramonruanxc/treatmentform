{
  TreatmentForm — VCL layer.

  Control descendants.
}
unit TreatmentForm.Vcl.Controls;

interface

uses
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  Vcl.DBGrids,
  Data.DB;

type
  { Alternating row colours for a data grid.

    The original declared this as

        TDBGrid = class(Vcl.DBGrids.TDBGrid)

    which shadows the VCL type. Any unit that pulled the library in silently
    got a different TDBGrid than the one it thought it was using, with no
    compiler error to say so — including forms whose .dfm had been streamed
    against the real class. The name is distinct here for that reason. }
  TZebraDBGrid = class(TDBGrid)
  strict private
    FEvenRowColor: TColor;
    procedure SetEvenRowColor(const AValue: TColor);
  protected
    procedure DrawDataCell(const Rect: TRect; Field: TField;
      State: TGridDrawState); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property EvenRowColor: TColor read FEvenRowColor write SetEvenRowColor
      default $00F4F4F4;
  end;

  { Form that fades in on open and out on close, and closes on Escape.

    The original owned two TTimer instances and drove opacity from their
    OnTimer handlers, creating them in the constructor and freeing them in the
    destructor. The behaviour is kept; the timers are now created only if the
    fade is actually enabled, and the Escape handling is a published property
    rather than an unconditional override, because a modal form that discards
    input on Escape is not always what the caller wants. }
  TFadeForm = class(TForm)
  strict private
    FFadeTimer: TTimer;
    FFadeDuration: Integer;
    FFadeEnabled: Boolean;
    FCloseOnEscape: Boolean;
    FFadingOut: Boolean;
    FStep: Integer;
    procedure FadeTick(Sender: TObject);
    procedure StartFade(AFadingOut: Boolean);
  protected
    procedure DoShow; override;
    procedure DoClose(var Action: TCloseAction); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    property FadeEnabled: Boolean read FFadeEnabled write FFadeEnabled;
    { Total fade time in milliseconds. }
    property FadeDuration: Integer read FFadeDuration write FFadeDuration;
    property CloseOnEscape: Boolean read FCloseOnEscape write FCloseOnEscape;
  end;

implementation

uses
  Winapi.Windows;

const
  FadeIntervalMs = 15;

{ TZebraDBGrid }

constructor TZebraDBGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEvenRowColor := $00F4F4F4;
end;

procedure TZebraDBGrid.SetEvenRowColor(const AValue: TColor);
begin
  if FEvenRowColor = AValue then
    Exit;
  FEvenRowColor := AValue;
  Invalidate;
end;

procedure TZebraDBGrid.DrawDataCell(const Rect: TRect; Field: TField;
  State: TGridDrawState);
begin
  { Guard the whole chain. The original tested DataSource.DataSet without
    checking DataSource first, which raises while a grid sits on a form at
    design time with no data source assigned yet. }
  if (DataSource <> nil) and (DataSource.DataSet <> nil) and
     DataSource.DataSet.Active and (DataSource.DataSet.RecordCount > 0) and
     not (gdSelected in State) and not Odd(DataSource.DataSet.RecNo) then
  begin
    Canvas.Brush.Color := FEvenRowColor;
    Canvas.FillRect(Rect);
    Canvas.TextRect(Rect, Rect.Left + 2, Rect.Top + 2, Field.DisplayText);
  end;

  inherited DrawDataCell(Rect, Field, State);
end;

{ TFadeForm }

constructor TFadeForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFadeEnabled := True;
  FFadeDuration := 220;
  FCloseOnEscape := True;
end;

procedure TFadeForm.StartFade(AFadingOut: Boolean);
begin
  FFadingOut := AFadingOut;
  FStep := Round(255 / (FFadeDuration / FadeIntervalMs));
  if FStep < 1 then
    FStep := 1;

  { Created on demand rather than in the constructor, so a form with the fade
    switched off costs nothing. Owned by Self, so no explicit destructor. }
  if FFadeTimer = nil then
  begin
    FFadeTimer := TTimer.Create(Self);
    FFadeTimer.Interval := FadeIntervalMs;
    FFadeTimer.OnTimer := FadeTick;
  end;

  AlphaBlend := True;
  if AFadingOut then
    AlphaBlendValue := 255
  else
    AlphaBlendValue := 0;

  FFadeTimer.Enabled := True;
end;

procedure TFadeForm.FadeTick(Sender: TObject);
var
  Next: Integer;
begin
  if FFadingOut then
  begin
    Next := AlphaBlendValue - FStep;
    if Next <= 0 then
    begin
      FFadeTimer.Enabled := False;
      AlphaBlendValue := 0;
      Exit;
    end;
  end
  else
  begin
    Next := AlphaBlendValue + FStep;
    if Next >= 255 then
    begin
      FFadeTimer.Enabled := False;
      AlphaBlendValue := 255;
      { Alpha blending costs a compositing pass on every repaint, so it is
        switched off once the form is fully opaque. }
      AlphaBlend := False;
      Exit;
    end;
  end;
  AlphaBlendValue := Next;
end;

procedure TFadeForm.DoShow;
begin
  inherited DoShow;
  if FFadeEnabled then
    StartFade(False);
end;

procedure TFadeForm.DoClose(var Action: TCloseAction);
begin
  if FFadeEnabled and (FFadeTimer <> nil) then
    FFadeTimer.Enabled := False;
  inherited DoClose(Action);
end;

procedure TFadeForm.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if FCloseOnEscape and (Key = VK_ESCAPE) and (Shift = []) then
  begin
    Key := 0;
    Close;
    Exit;
  end;
  inherited KeyDown(Key, Shift);
end;

end.
