# Deep Inspection Findings

**Date:** 2026-03-02

## Scope

- `run_faster_whisper_xxl.ps1`
- `Module/Public/*.ps1`
- module manifest/export wiring

## Findings

| ID | Severity | Probability | Location | Issue | Why suspicious |
|----|----------|-------------|----------|-------|----------------|
| FW-1 | P3 | Medium | `run_faster_whisper_xxl.ps1` form-closing handler | Parameter name collided with PowerShell automatic variable (`eventArgs`) | Can cause confusing behavior and static-analysis failures in event handlers. |
| FW-2 | P3 | Medium | `run_faster_whisper_xxl.ps1` process-exit event action | Empty catch block | Swallows UI/disposal errors and reduces diagnosability. |
| FW-3 | P3 | High | `Module/Public/Get-FasterWhisperAllowedValues.ps1` | Plural cmdlet noun warning (`PSUseSingularNouns`) | Repeated analyzer noise; weakens signal-to-noise for real issues. |

## Fixes Applied

- **FW-1:** renamed form-closing scriptblock parameter to `formClosingArgs` and updated use site.
- **FW-2:** replaced empty catch with explicit `Write-Verbose` diagnostic message.
- **FW-3:** introduced canonical singular cmdlet `Get-FasterWhisperAllowedValueMap`, kept backward-compatible alias `Get-FasterWhisperAllowedValues`, and updated module exports + call sites.

## Verification

- `Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1 -Severity Error,Warning` → **0 findings**
- `Invoke-Pester -Path tests -CI` → **16 passed**

## Current Status

- **P0:** none
- **P1:** none
- **P2:** none
- **P3:** resolved

---

## Second pass (append, 2026-03-02)

### Findings

- Re-scanned module/script with ScriptAnalyzer and reviewed event/process-handling paths.
- No new P0/P1/P2/P3 findings.

### Verification

- `Invoke-ScriptAnalyzer ... -Severity Error,Warning` → 0
- `Invoke-Pester -Path tests -CI` → 16 passed

---

## Third pass (append, 2026-03-02)

- Re-ran ScriptAnalyzer and Pester after latest cross-repo fixes.
- No new P0/P1/P2/P3 findings.

---

## Fourth pass (append, 2026-03-02)

### Findings

- Re-ran ScriptAnalyzer and Pester after release-prep updates.
- Added minimum GitHub Actions CI workflow on `windows-latest` to run:
  - `Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1 -Severity Error,Warning`
  - `Invoke-Pester -Path tests -CI`
- Standardized README section naming to exact `## How it works` and `## Lifecycle` with explicit failure branches.
- No new P0/P1/P2/P3 findings.

### Verification

- `Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1 -Severity Error,Warning` -> 0 findings
- `Invoke-Pester -Path tests -CI` -> 16 passed

### Closure

- Final iteration result: **no new P3 findings**.
