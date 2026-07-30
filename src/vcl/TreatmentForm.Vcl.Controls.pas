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
  Vcl.Grids,
  Vcl.DBGrids,
  Data.DB;

type
  { Alternating row colours for a data grid.

    Three things the 2017 version got wrong, all verified against the shipped
    Vcl.DBGrids source:

    1. It was declared `TDBGrid = class(Vcl.DBGrids.TDBGrid)`, shadowing the VCL
       type. Any unit that pulled the library in silently resolved TDBGrid to
       this class instead of the VCL's — including forms whose .dfm had been
       streamed against the real one. Hence the distinct name.

    2. It hooked DrawDataCell. TCustomDBGrid.DrawCell writes the cell text
       first and only then calls DrawDataCell, so filling the rect there erased
       text the grid had already painted; repainting it by hand lost the
       column's Alignment and BiDi. Worse, that call is gated on
       `Columns.State = csDefault`, so touching the Columns collection made the
       striping silently vanish — and the VCL itself marks the method obsolete.
       DrawColumnCell is called unconditionally and is the supported hook.

    3. It took row parity from DataSet.RecNo. TDataSet.GetRecNo returns -1
       unless a descendant overrides it, so on a unidirectional cursor or a
       hand-written dataset the striping never happened, with no diagnostic.
       Parity now comes from the grid's own DataLink.ActiveRecord — the row
       being painted.

    Stripes follow screen rows rather than records, which is what
    ActiveRecord reports and what keeps the feature working on every dataset. }
  TZebraDBGrid = class(TDBGrid)
  strict private
    FEvenRowColor: TColor;
    procedure SetEvenRowColor(const AValue: TColor);
  protected
    procedure DrawColumnCell(const Rect: TRect; DataCol: Integer;
      Column: TColumn; State: TGridDrawState); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property EvenRowColor: TColor read FEvenRowColor write SetEvenRowColor
      default $00F4F4F4;
  end;

  { Form that fades in when it opens, and optionally closes on Escape.

    Fade-in only, and that is deliberate. The 2017 version's class comment
    promised "fades in on open and out on close", but StartFade was only ever
    called with False: the whole fade-out branch was dead code and DoClose just
    switched the timer off, so the window vanished instantly. Rather than ship a
    half-implemented fade-out that cannot be verified here, the feature is
    fade-in, and the documentation says so.

    Construct with CreateNew, not Create. TCustomForm.Create raises
    EResNotFound for any class other than TForm itself that has no .dfm
    resource, and this class ships none. Descendants that do have a .dfm use
    Create normally.

    Defaults live in InitializeNewForm rather than in a constructor, because
    Vcl.Forms declares it `dynamic` and BOTH Create and CreateNew call it.
    Putting them in an overridden Create — as the 2017 version did — meant they
    were skipped entirely by CreateNew, which is the only constructor this class
    can actually be built with. }
  TFadeForm = class(TForm)
  strict private
    FFadeTimer: TTimer;
    FFadeDuration: Integer;
    FFadeEnabled: Boolean;
    FCloseOnEscape: Boolean;
    FStep: Integer;
    procedure FadeTick(Sender: TObject);
    procedure StartFadeIn;
  protected
    procedure InitializeNewForm; override;
    procedure DoShow; override;
    procedure DoClose(var Action: TCloseAction); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    property FadeEnabled: Boolean read FFadeEnabled write FFadeEnabled;
    { Total fade-in time in milliseconds. A value of zero or less means "no
      fade": the form simply appears. }
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

procedure TZebraDBGrid.DrawColumnCell(const Rect: TRect; DataCol: Integer;
  Column: TColumn; State: TGridDrawState);
begin
  { A selected row keeps the highlight colour the grid chose for it. }
  if not (gdSelected in State) and Assigned(DataLink) and DataLink.Active and
     Odd(DataLink.ActiveRecord) then
    Canvas.Brush.Color := FEvenRowColor;

  { DefaultDrawColumnCell fills the cell with the current brush and then writes
    the text with the column's own Alignment and BiDi handling. Never paint the
    text by hand — that is what lost both in the 2017 version. }
  DefaultDrawColumnCell(Rect, DataCol, Column, State);
end;

{ TFadeForm }

procedure TFadeForm.InitializeNewForm;
begin
  inherited InitializeNewForm;
  FFadeEnabled := True;
  FFadeDuration := 220;
  FCloseOnEscape := True;

  { Without KeyPreview, TWinControl.DoKeyDown does not forward the key to the
    form, so the KeyDown override below never runs whenever any child control
    has focus — which made CloseOnEscape silently inert on every realistic
    form. }
  KeyPreview := True;
end;

procedure TFadeForm.StartFadeIn;
begin
  { A non-positive duration means "no fade". Guarded because FFadeDuration is a
    public read/write property and the division below would raise EZeroDivide
    from inside DoShow. }
  if FFadeDuration <= 0 then
  begin
    AlphaBlend := False;
    Exit;
  end;

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
  AlphaBlendValue := 0;
  FFadeTimer.Enabled := True;
end;

procedure TFadeForm.FadeTick(Sender: TObject);
var
  Next: Integer;
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
  AlphaBlendValue := Next;
end;

procedure TFadeForm.DoShow;
begin
  inherited DoShow;
  if FFadeEnabled then
    StartFadeIn;
end;

procedure TFadeForm.DoClose(var Action: TCloseAction);
begin
  { Stop the timer before the window goes away so no tick fires against a
    closing form. }
  if FFadeTimer <> nil then
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
