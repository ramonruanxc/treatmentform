# TreatmentForm 2.0 — design

Date: 2026-07-29
Status: approved, implemented

## Goal

Modernize the 2017 library in place rather than replacing it, keeping the same
feature set but with module boundaries, a UI-free core, automated tests, and
continuous integration.

Scope is deliberately closed to what 1.0 already did: validation, form
treatment, and UI helpers. No new feature areas. A utility library that keeps
growing sideways never reaches a releasable state.

## Constraints discovered during design

**Delphi cannot compile in CI, and cannot compile from the command line at
all on this machine.** The Community Edition refuses:

```
This version of the product does not support command line compiling.
```

Embarcadero's licence also does not permit the Community Edition on a hosted
runner. Any automated test story therefore has to run on a compiler that is
free to redistribute, which means Free Pascal.

This single constraint drives the architecture below. It is not a preference.

## Architecture

Three layers with one rule between them: **the core does not know a UI exists.**

```
src/core/   Object Pascal, RTL only. Delphi and FPC.
            Types, text helpers, validators, formatters, test runner.

src/vcl/    Delphi + VCL. Treatments, form treatment, controls, helpers.

tests/core/ Portable. Runs in CI on every push.
```

Consequences of the rule, in order of value:

1. The core test suite runs on GitHub Actions for free, so the badge means
   something.
2. The rules can be unit tested without instantiating a form.
3. The same rules work from a console app, a service, or FMX.

Cost: no inline variables or custom managed records in the core, since FPC 3.2
does not support them. Accepted.

## Key decisions

### Validators are objects, not class helpers

1.0 put validation on `TCustomEdit` class helpers. Delphi resolves at most one
class helper per type in scope, silently, so any consuming project with its own
`TCustomEdit` helper lost the entire feature set with no diagnostic. Helpers
cannot be the foundation of a library.

They remain available as opt-in sugar in `TreatmentForm.Vcl.Helpers`, forwarding
to the validators, with the collision hazard documented in the unit header.

### Validators return a reason, not a boolean

`TValidationResult` carries `IsValid`, `Reason` (`TValidationFailure`) and
`Message`. "Invalid CPF" is not actionable; "check digit does not match" and
"10 digits, expected 11" are. The message lives with the rule, so it is not
duplicated at every call site.

### Invalid input never raises

Invalid input is an expected outcome. Exceptions are reserved for programmer
error — a nil validator, a nil target control.

### Treatments replace the behaviour enum

`TTreatFormType` had five values encoding two independent decisions: how to
signal a failure, and whether to stop at the first one. Every new signal meant
another value and another branch, and combinations were unreachable.

`IControlTreatment` has `Apply` and `Clear`. `Clear` exists so a failure
signalled on a previous pass does not linger after the user fixes the field.
`StopOnFirstFailure` moves to the object that runs the loop, where it belongs.

### Rules are bound explicitly

1.0 inferred rules from the control's name (`if Name.Contains('EMAIL')`).
Renaming a control silently disabled its validation — no error, no warning, no
failing test. `Rule(AControl, AValidator)` puts the compiler back in the loop.

This also removes the need for `IgnoreList`: only registered controls are
checked, so there is nothing to exclude.

### A purpose-built test runner instead of DUnitX

DUnitX does not run on Free Pascal, and the suite must run on both compilers.
The alternatives were two parallel suites, which is how suites rot, or roughly a
hundred lines of assertion runner. The runner holds no framework state, so
Delphi users can wrap the suites in DUnitX for IDE integration without changing
them.

This is the most arguable decision in the design and should be defended on the
CI constraint, not on taste.

### Repository name and history

The name stays `treatmentform`: the URL is already published in a CV and on
LinkedIn, and the cost of breaking that link exceeds the benefit of a more
descriptive name.

The 2017 commit is tagged `v1.0` before any change, so anything depending on the
old API can pin it, and `MIGRATION.md` maps the old surface onto the new one.

## Defects found in 1.0 while rewriting

Recorded because fixing them, not restructuring, is most of the value:

1. `StartTreatment` assigned `Result` inside its loop, so in the "InAll" modes
   the last control examined decided the answer. Invalid field followed by valid
   field returned `True`.
2. `TDBGrid = class(Vcl.DBGrids.TDBGrid)` shadowed the VCL type.
3. `TDBGrid.DrawDataCell` dereferenced `DataSource.DataSet` without checking
   `DataSource`.
4. `ShowBalloonTip` never destroyed the tooltip window it created — one leaked
   handle per call.
5. `ShowBalloonTip` allocated `2 * 256` bytes and declared `2 * 356` to
   `StringToWideChar`.
6. `ShowBalloonTip` cast `@ToolInfo` through `Integer`, truncating on 64-bit.
7. `ShowBalloonTip` used an uninitialised `TToolInfo`.
8. `SetBorder` drew on the window DC, so the highlight died on the next repaint.
9. `GetIndex` returned 0 for "not found", indistinguishable from a match at
   index 0.
10. `TreatTabOrder` ignored nested containers.

## Testing

Core: 122 assertions, verified passing under FPC 3.2.2. Coverage targets the
cases implementations usually miss — repeated-digit CPF and CNPJ (all twenty),
CEP blocks split across states (AM, DF, GO), leap year century rules, the
two-digit year pivot, and the reference-counting lifetime contract.

VCL layer: no automated coverage. Its observable behaviour is "a tint appears".
`demo/` exercises it manually. Stated plainly in the README rather than implied
away.

## Verification status

- Core compiles under FPC 3.2.2 and all 122 assertions pass.
- VCL layer and demo are **not compile-verified**: the Community Edition blocks
  command-line compilation, so they need one build inside the IDE.

## Out of scope

- FMX adapters. The core permits them; nothing here provides them.
- Additional Brazilian document types (IE, PIS, Renavam). The core makes them
  easy to add, which is not a reason to add them now.
- `ProximoDiaUtil` and `VersaoExe` from 1.0's `TFunctions`. Not form treatment.
