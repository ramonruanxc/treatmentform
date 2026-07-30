# Migrating from 1.0

Version 2.0 is a breaking rewrite. The 2017 code is preserved at the `v1.0`
tag, so nothing that depends on it has to move:

```
boss install github.com/ramonruanxc/treatmentform@v1.0
```

Everything below maps the old API onto the new one.

---

## Validation

`RRClass.pas` put validation on a `TCustomEdit` class helper. The rules are now
objects in `TreatmentForm.Validation`.

| 1.0 | 2.0 |
| --- | --- |
| `Edit.IsCPF` | `TCpfValidator.Create.Validate(Edit.Text)` |
| `Edit.IsCNPJ` | `TCnpjValidator.Create.Validate(Edit.Text)` |
| `Edit.IsCEP` | `TCepValidator.Create.Validate(Edit.Text)` |
| `Edit.IsCEP(cEstado)` | `TCepValidator.Create(AState).Validate(Edit.Text)` |
| `Edit.IsEmail` | `TEmailValidator.Create.Validate(Edit.Text)` |
| `Edit.IsDate` | `TDateValidator.Create.Validate(Edit.Text)` |

The return type changed from `Boolean` to `TValidationResult`. Where you had:

```pascal
if not edCpf.IsCPF then
  ShowMessage('Invalid CPF');
```

you now have the reason available:

```pascal
var
  Validator: IValidator;
  Res: TValidationResult;
begin
  Validator := TCpfValidator.Create;
  Res := Validator.Validate(edCpf.Text);
  if not Res.IsValid then
    ShowMessage(Res.Message);
```

If you only want the boolean, `Res.IsValid` is it.

`TreatmentForm.Vcl.Helpers` keeps a helper-shaped API for callers who want the
short form — `edCpf.ValidateAsCpf.IsValid` — but read that unit's header first.
Delphi resolves one class helper per type and does so silently.

## Formatting

Masks moved out of the validation helper into `TreatmentForm.Formatting`.

| 1.0 | 2.0 |
| --- | --- |
| `Edit.SetMaskCpfCnpj` | `TCpfCnpjFormatter.Create.Format(Edit.Text)` |
| `Edit.SetMaskPhone` | `TPhoneFormatter.Create.Format(Edit.Text)` |
| `Edit.SetMaskDate2D` | `TDateFormatter.Create(dsTwoDigitYear).Format(...)` |
| `Edit.SetMaskDate4D` | `TDateFormatter.Create(dsFourDigitYear).Format(...)` |
| — | `TCepFormatter` (new) |

The 1.0 methods mutated `Edit.Text` and returned a string. Formatters are pure:
they take a string and return one. The helper unit keeps the mutating form as
`FormatAsCpfCnpj`, `FormatAsCep` and `FormatAsPhone`.

## Form treatment

`TFormHelper.StartTreatment` is replaced by `TFormTreatment`.

1.0 inferred rules from control names and selected behaviour from an enum:

```pascal
if not Self.StartTreatment(IgnoreList, ttBalloonTipInAll) then
  Exit;
```

2.0 states both explicitly, normally once in the form's constructor:

```pascal
FTreatment := TFormTreatment.Create;
FTreatment.StopOnFirstFailure := False;

FTreatment
  .Treat(TBalloonTipTreatment.Create);

FTreatment
  .Require(edName, 'Name')
  .Rule(edCpf, TCpfValidator.Create, 'CPF')
  .Rule(edEmail, TEmailValidator.Create, 'E-mail');
```

and then, where `StartTreatment` used to be called:

```pascal
if not FTreatment.Validate then
  Exit;
```

`TFormTreatment` is a plain object — free it in the form's destructor.

### The enum

| 1.0 `TTreatFormType` | 2.0 |
| --- | --- |
| `ttDefault` | `.Treat(TBalloonTipTreatment.Create)`, `StopOnFirstFailure := True` |
| `ttBalloonTipInOne` | same as above |
| `ttBalloonTipInAll` | `.Treat(TBalloonTipTreatment.Create)`, `StopOnFirstFailure := False` |
| `ttPaintControlInOne` | `.Treat(THighlightTreatment.Create)`, `StopOnFirstFailure := True` |
| `ttPaintControlInAll` | `.Treat(THighlightTreatment.Create)`, `StopOnFirstFailure := False` |

Combinations the enum could not express now work, because the treatments are a
list:

```pascal
FTreatment
  .Treat(THighlightTreatment.Create)
  .Treat(TBalloonTipTreatment.Create)
  .Treat(TFocusTreatment.Create);
```

### IgnoreList

Gone, and it does not need a replacement. 1.0 validated every control on the
form and took a `TStringList` of control names to skip. 2.0 validates only the
controls you registered a rule for, so there is nothing to exclude.

Controls that are disabled or invisible are still skipped automatically, as
they were in 1.0.

### Tab order

| 1.0 | 2.0 |
| --- | --- |
| `Self.TreatTabOrder` | `FTreatment.ArrangeTabOrder(Self)` |

Same behaviour: visual order, top to bottom then left to right, skipping labels
and anything that cannot take focus. It now recurses into nested containers,
which 1.0 did not.

## Controls

| 1.0 | 2.0 |
| --- | --- |
| `TDBGrid` (in `RRClass`) | `TZebraDBGrid` (in `TreatmentForm.Vcl.Controls`) |
| `TDBGrid.ColorDataCell` | `TZebraDBGrid.EvenRowColor` |
| `TfObject` | `TFadeForm` |

**`TDBGrid` had to be renamed.** In 1.0 it shadowed `Vcl.DBGrids.TDBGrid`, so
adding `RRClass` to a uses clause silently changed which class your `TDBGrid`
references resolved to — including in forms whose `.dfm` had been streamed
against the real VCL class. If you relied on that shadowing to skin grids
without touching them, you now have to change the declarations. That is the
intent: the change is visible instead of silent.

`TFadeForm` keeps the fade and the close-on-Escape behaviour, both now
switchable:

```pascal
FadeEnabled := True;      // default
FadeDuration := 220;      // ms, default
CloseOnEscape := True;    // default
```

1.0 closed on Escape unconditionally, which is wrong for a modal dialog that
should not discard input.

## Removed

| 1.0 | Why |
| --- | --- |
| `UTips.pas` (`TTip` helper) | The Win32 tooltip it wrapped leaked a window handle per call and under-allocated its text buffer. Replaced internally by `TBalloonHint`. Use `TBalloonTipTreatment`. |
| `TTip.SetBorder` | Drew onto the window DC, so the border vanished on the next repaint. Use `THighlightTreatment`. |
| `TFunctions` and the global `fFunctions` | Two unrelated routines behind a global mutable instance. `ProximoDiaUtil` and `VersaoExe` were not form treatment and are out of scope; copy them into your own project if you need them. |
| `TComboBoxHelper.GetIndex` | Returned 0 when nothing matched, which cannot be told apart from a match on the first item. Replaced by `TTreatmentComboHelper.IndexOfText`, which returns -1. |

## Language

Identifiers, comments and documentation are in English throughout. The only
renames that affect callers are in the tables above.
