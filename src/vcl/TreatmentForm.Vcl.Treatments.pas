{
  TreatmentForm — VCL layer.

  How a validation failure is shown to the user.

  The original library encoded this as an enumeration:

    TTreatFormType = (ttDefault, ttPaintControlInOne, ttPaintControlInAll,
                      ttBalloonTipInOne, ttBalloonTipInAll);

  Five values covering two independent decisions — how to signal a failure,
  and whether to stop at the first one — multiplied together. Every new way of
  signalling meant another enumeration value and another branch in an already
  branching routine, and combinations like "highlight AND show a balloon" were
  simply unreachable.

  Here each way of signalling is an object. Combining them is putting two of
  them in a list, and "stop at the first failure" moves to where it belongs,
  on the object that runs the loop.
}
unit TreatmentForm.Vcl.Treatments;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  TreatmentForm.Types;

type
  IControlTreatment = interface
    ['{A6D3E4B2-7C81-4F95-B0A7-3D82E15C9F44}']
    { Applied to a control that failed validation. }
    procedure Apply(AControl: TWinControl; const AResult: TValidationResult);
    { Returns the control to its untouched state. Called on every control
      before a validation pass, so a failure signalled on a previous pass does
      not linger after the user fixes the field. }
    procedure Clear(AControl: TWinControl);
  end;

  { Tints the background of the offending control.

    The original drew a red rectangle straight onto the window DC, which the
    next repaint erased — the highlight disappeared as soon as the user
    scrolled or another window overlapped. Setting the control's own colour
    survives repainting because the control draws it. }
  { What has to be put back when the highlight is cleared. Restoring the colour
    alone is not enough: TControl.SetColor also clears ParentColor, so a control
    that was tracking its parent's colour would stay permanently detached from
    it after the first failed validation. }
  TSavedColor = record
    Color: TColor;
    ParentColor: Boolean;
  end;

  THighlightTreatment = class(TInterfacedObject, IControlTreatment)
  strict private
    FColor: TColor;
    FOriginalColors: TDictionary<TWinControl, TSavedColor>;
  public
    constructor Create(AColor: TColor = $00CFCFFF);
    destructor Destroy; override;
    procedure Apply(AControl: TWinControl; const AResult: TValidationResult);
    procedure Clear(AControl: TWinControl);
    property Color: TColor read FColor write FColor;
  end;

  { Shows the failure message in a balloon anchored to the FIRST offending
    control of a pass.

    Replaces a hand-rolled Win32 tooltip that leaked a window handle on every
    call, under-allocated its text buffer, and truncated pointers on 64-bit.
    TBalloonHint has shipped with the VCL since Delphi 2009 and does the same
    job without any of that.

    First failure only, and that is a real constraint rather than a choice: a
    TCustomHint can display exactly one balloon. Every ShowHint queues a hint
    window onto the object's single animation thread, which frees all but the
    last before painting. Showing a balloon per field would therefore display
    one arbitrary balloon and silently discard the rest, so the treatment claims
    only what it can deliver — like TFocusTreatment, which is bounded the same
    way for the same kind of reason. Pair it with THighlightTreatment when
    StopOnFirstFailure is False and you want every bad field marked. }
  TBalloonTipTreatment = class(TInterfacedObject, IControlTreatment)
  strict private
    FHint: TBalloonHint;
    FTitle: string;
    FClaimed: Boolean;
  public
    constructor Create(const ATitle: string = 'Check this field');
    destructor Destroy; override;
    procedure Apply(AControl: TWinControl; const AResult: TValidationResult);
    procedure Clear(AControl: TWinControl);
    property Title: string read FTitle write FTitle;
  end;

  { Moves the caret to the offending control. Only the first failure of a pass
    takes focus; later ones would fight over it. }
  TFocusTreatment = class(TInterfacedObject, IControlTreatment)
  strict private
    FClaimed: Boolean;
  public
    procedure Apply(AControl: TWinControl; const AResult: TValidationResult);
    procedure Clear(AControl: TWinControl);
  end;

implementation

uses
  Vcl.Forms;

{ THighlightTreatment }

constructor THighlightTreatment.Create(AColor: TColor);
begin
  inherited Create;
  FColor := AColor;
  FOriginalColors := TDictionary<TWinControl, TSavedColor>.Create;
end;

destructor THighlightTreatment.Destroy;
begin
  FOriginalColors.Free;
  inherited Destroy;
end;

type
  { Color and ParentColor are declared protected on TControl and only made
    public or published by concrete classes like TEdit, so a TWinControl
    reference cannot reach them. A local descendant exposes the inherited
    protected members, which lets the treatment tint any control uniformly
    without casting to each concrete published type — the standard VCL
    "cracker" idiom. }
  TControlColorAccess = class(TControl);

procedure THighlightTreatment.Apply(AControl: TWinControl;
  const AResult: TValidationResult);
var
  Saved: TSavedColor;
begin
  if not FOriginalColors.ContainsKey(AControl) then
  begin
    Saved.Color := TControlColorAccess(AControl).Color;
    Saved.ParentColor := TControlColorAccess(AControl).ParentColor;
    FOriginalColors.Add(AControl, Saved);
  end;
  TControlColorAccess(AControl).Color := FColor;
end;

procedure THighlightTreatment.Clear(AControl: TWinControl);
var
  Saved: TSavedColor;
begin
  if FOriginalColors.TryGetValue(AControl, Saved) then
  begin
    { Order matters: assigning Color clears ParentColor, so ParentColor has to
      go back last. }
    TControlColorAccess(AControl).Color := Saved.Color;
    TControlColorAccess(AControl).ParentColor := Saved.ParentColor;
    FOriginalColors.Remove(AControl);
  end;
end;

{ TBalloonTipTreatment }

constructor TBalloonTipTreatment.Create(const ATitle: string);
begin
  inherited Create;
  FTitle := ATitle;
  FHint := TBalloonHint.Create(nil);
  FHint.HideAfter := 5000;
end;

destructor TBalloonTipTreatment.Destroy;
begin
  FHint.Free;
  inherited Destroy;
end;

procedure TBalloonTipTreatment.Apply(AControl: TWinControl;
  const AResult: TValidationResult);
begin
  if FClaimed then
    Exit;

  FHint.Title := FTitle;
  { The message comes from the validator that rejected the value, so the text
    lives with the rule instead of being duplicated at every call site. }
  FHint.Description := AResult.Message;
  FHint.ShowHint(AControl);
  FClaimed := True;
end;

procedure TBalloonTipTreatment.Clear(AControl: TWinControl);
begin
  { Clear runs over every control before a pass begins, which is when the claim
    has to be released. }
  FClaimed := False;
  FHint.HideHint;
end;

{ TFocusTreatment }

procedure TFocusTreatment.Apply(AControl: TWinControl;
  const AResult: TValidationResult);
begin
  if FClaimed then
    Exit;
  if AControl.CanFocus then
  begin
    AControl.SetFocus;
    FClaimed := True;
  end;
end;

procedure TFocusTreatment.Clear(AControl: TWinControl);
begin
  { Clear runs over every control before a pass begins, which is exactly when
    the claim has to be released. }
  FClaimed := False;
end;

end.
