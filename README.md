# TreatmentForm

[![CI](https://github.com/ramonruanxc/treatmentform/actions/workflows/ci.yml/badge.svg)](https://github.com/ramonruanxc/treatmentform/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Validation and form treatment for Delphi, with a portable core.

The validation rules are plain Object Pascal with no UI dependency, so they
compile under both Delphi and Free Pascal and can be used from a form, a
service, or a console application. The VCL layer sits on top and decides how a
failure is shown to the user.

---

## Install

With [Boss](https://github.com/HashLoad/boss):

```
boss install github.com/ramonruanxc/treatmentform
```

Or add `src/core` and `src/vcl` to your project's search path. The core needs
nothing beyond the RTL; the VCL layer needs the VCL.

Requires Delphi 10.1 Berlin or later. The core also builds on Free Pascal 3.2
with `-Mdelphi`.

---

## Validating a value

```pascal
uses
  TreatmentForm.Types, TreatmentForm.Validation;

var
  Validator: IValidator;
  Res: TValidationResult;
begin
  Validator := TCpfValidator.Create;
  Res := Validator.Validate('529.982.247-25');

  if not Res.IsValid then
    ShowMessage(Res.Message);
end;
```

`TValidationResult` carries a reason, not just a flag:

```pascal
Res := Validator.Validate('11111111111');
// Res.IsValid  = False
// Res.Reason   = vfRepeatedSequence
// Res.Message  = 'CPF is a repeated sequence of the same digit.'
```

That distinction is the point. "Invalid CPF" gives a user nothing to act on;
"check digit does not match" and "10 digits, expected 11" do.

Available validators: `TCpfValidator`, `TCnpjValidator`, `TCepValidator`,
`TEmailValidator`, `TDateValidator`, and `TCompositeValidator` to run several
over one value.

`TCepValidator` optionally checks the code against a state's allocated ranges:

```pascal
Validator := TCepValidator.Create('CE');
Validator.Validate('01310930');   // vfOutOfRange — that is a Sao Paulo code
```

## Formatting a value

Formatters never reject input, because a field is formatted while the user is
still typing into it:

```pascal
uses TreatmentForm.Formatting;

Formatter := TCpfCnpjFormatter.Create;
Formatter.Format('52998224725');     // '529.982.247-25'
Formatter.Format('11222333000181');  // '11.222.333/0001-81'
Formatter.Format('529');             // '529' — nothing to format yet
```

## Validating a form

```pascal
uses
  TreatmentForm.Validation,
  TreatmentForm.Vcl.Treatments,
  TreatmentForm.Vcl.FormTreatment;

FTreatment := TFormTreatment.Create;

// How failures are shown. Attach as many as you want; they all run.
FTreatment
  .Treat(THighlightTreatment.Create)
  .Treat(TBalloonTipTreatment.Create)
  .Treat(TFocusTreatment.Create);

// What is checked. The control is named, not guessed at.
FTreatment
  .Require(edName, 'Name')
  .Rule(edCpf, TCpfValidator.Create, 'CPF')
  .Rule(edEmail, TEmailValidator.Create, 'E-mail');

if FTreatment.Validate then
  Save
else
  ShowMessage(FTreatment.Failures[0].Message);
```

`StopOnFirstFailure` is `True` by default. Set it to `False` to signal every
failing field in one pass; `Failures` then holds all of them and
`FirstInvalidControl` points at the first.

`ArrangeTabOrder(Self)` assigns tab order following the visual layout — top to
bottom, then left to right — skipping labels and controls that cannot take
focus. It recurses into nested containers.

## One thing to know about lifetimes

The validators descend from `TInterfacedObject`, so they are reference counted.
Store them in interface variables:

```pascal
var
  Validator: IValidator;        // correct
begin
  Validator := TCpfValidator.Create;
```

Holding only a concrete reference and passing it to an `IValidator` parameter
gives the object a reference count that drops to zero when that call returns,
freeing it underneath you. If you need the concrete type — to set
`TDateValidator.TwoDigitYearPivot`, say — keep an interface reference alongside
it for as long as you use the object.

## Class helpers

`TreatmentForm.Vcl.Helpers` offers a terser form:

```pascal
if not edCpf.ValidateAsCpf.IsValid then ...
edCpf.FormatAsCpfCnpj;
```

**Read the header of that unit before using it.** Delphi resolves at most one
class helper per type in scope, silently. If your project already has a
`TCustomEdit` helper, one of the two disappears with no compiler diagnostic.
The helpers are one-line forwards to the validators, which have no such
constraint — prefer those in anything large.

---

## Running the tests

Free Pascal, which is what CI uses:

```
mkdir build
fpc -Mdelphi -Fusrc/core -Futests/core -FUbuild -obuild/CoreTests tests/core/CoreTests.dpr
./build/CoreTests
```

The runner exits non-zero if any assertion fails. 122 assertions currently
cover the core.

The suite uses a small assertion runner in `TreatmentForm.Testing` rather than
DUnitX, because it has to run under both compilers and DUnitX does not run
under Free Pascal. Maintaining two parallel suites is how test suites rot; a
hundred lines of runner is the cheaper trade. The assertions hold no framework
state, so they can be wrapped in DUnitX for IDE integration without changes.

The VCL layer has no automated coverage. It is UI code whose observable
behaviour is "a red tint appears" — the `demo/` project exercises it, by hand.

---

## Why it was rewritten

The 2017 version was one 1,100 line unit holding six unrelated types. Bringing
it up to date meant fixing design problems, and some outright defects, that are
worth naming.

**Validation was bound to the VCL.** `IsCPF`, `IsEmail` and the rest lived on a
`TCustomEdit` class helper, so the rules could not be tested without
instantiating a form, and could not be reused from a service, a console tool,
or FMX. The rules are now objects in a core that does not know a UI exists —
which is also what makes the CI badge above possible.

**Rules were matched by control name.**

```pascal
if UpperCase(Edit.Name).Contains('EMAIL') then
  if not Edit.IsEmail then ...
```

Rename `edEmail` to `edContact` and the validation silently stops running. No
error, no warning, no failing test — the form just starts accepting anything.
Rules now name the control they apply to, so the compiler is involved.

**The result was computed wrongly.** The original assigned `Result` inside its
loop, so in the `ttBalloonTipInAll` and `ttPaintControlInAll` modes the last
control examined decided the answer. An invalid field followed by a valid one
returned `True` and the form submitted. `Validate` now cannot let a later
success overwrite an earlier failure.

**`TDBGrid` shadowed the VCL type.** The original declared
`TDBGrid = class(Vcl.DBGrids.TDBGrid)`, so any unit that pulled the library in
got a different `TDBGrid` than it thought — including forms whose `.dfm` had
been streamed against the real class. It is `TZebraDBGrid` now. Its
`DrawDataCell` also guards `DataSource` before dereferencing it, which the
original did not, and which raised on a grid sitting on a form at design time
with no data source assigned.

**The balloon tip leaked and could overflow.** The hand-rolled Win32 tooltip
allocated 512 bytes and told `StringToWideChar` it had 712; never destroyed the
tooltip window it created, leaking a handle per call; used an uninitialised
`TToolInfo`; and cast a pointer through `Integer`, which truncates on 64-bit.
It is `TBalloonHint` now — a VCL component that has shipped since Delphi 2009
and does the same job without any of that.

**Highlighting did not survive a repaint.** `SetBorder` drew a rectangle
straight onto the window DC, so the red border vanished the moment anything
invalidated the control. `THighlightTreatment` sets the control's own colour and
restores it, which the control repaints for you.

**Five enum values encoded two decisions.** `TTreatFormType` multiplied "how to
signal" by "stop at the first failure or not", so every new way of signalling
meant another enum value and another branch, and combinations like *highlight
and show a balloon* were unreachable. Signalling is an object now; combining
means putting two in a list. Stopping is a property on the object that runs the
loop.

**There were no tests, no packaging and no CI.** There are now.

The 2017 code is preserved at the `v1.0` tag, and
[MIGRATION.md](MIGRATION.md) maps the old API onto the new one.

---

## Licence

MIT. See [LICENSE](LICENSE).
