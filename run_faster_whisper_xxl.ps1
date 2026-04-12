<#
.SYNOPSIS
    Starts a Windows GUI to run a Faster Whisper transcription/translation job and returns a structured run summary object.

.DESCRIPTION
    This script provides a WinForms user interface to configure and start a single run of an external transcription tool (the configured executable).
    The GUI collects input file, device, language, model, output directory, output format, task, and decoding parameters (best_of, beam_size, patience, temperature).
    When the process finishes (or fails validation), the script writes exactly one summary object to the pipeline that can be piped to Export-Csv, ConvertTo-Json, Where-Object, etc.
    All human-friendly interaction (dialogs, message boxes) is handled via the GUI; the pipeline output remains machine-friendly.

.PARAMETER None
    This script does not accept command-line parameters. Configuration is done via the GUI and (optionally) a JSON configuration file.

.INPUTS
    None. You cannot pipe input into this script.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Emits a single run summary object per attempted run. The object contains these properties:

    - InputFile: Full path to the selected audio/video file.
    - OutputDirectory: Folder where the tool writes output files.
    - Device: "cpu" or "cuda".
    - Language: ISO-639-1 language code (empty string if not specified).
    - Model: Selected model name (e.g., base, medium, large-v2, xxl).
    - OutputFormat: Output file format (txt, srt, vtt).
    - Task: "transcribe" or "translate".
    - BestOf: Integer best_of value.
    - BeamSize: Integer beam_size value.
    - Patience: Decimal patience value.
    - Temperature: Decimal temperature value.
    - PlaySound: Boolean indicating whether the completion sound was enabled.
    - ShowCliProgress: Boolean indicating whether the tool progress output was requested.
    - Executable: Executable name/path that was invoked.
    - StartTime: Timestamp when the run started (local time).
    - EndTime: Timestamp when the run ended (local time).
    - DurationSeconds: Total runtime in seconds (rounded).
    - ExitCode: Process exit code (null if the process did not start).
    - Succeeded: Boolean indicating success (ExitCode = 0).
    - ErrorMessage: Error text if validation failed or ExitCode was non-zero; otherwise null.

.DESCRIPTION (CONFIGURATION)
    The script supports optional JSON-based configuration.
    The JSON file path is defined inside the script (placeholder: PATH\TO\JSON\run_faster_whisper_xxl.config.json).
    If the file is missing, empty, unreadable, or contains invalid JSON, the script silently falls back to built-in defaults.
    Supported JSON keys (all optional) match the GUI settings and are used only to pre-populate the GUI:
    ExecutablePath, Device, Language, Model, OutputFormat, Task, BestOf, BeamSize, Patience, Temperature,
    PlayConfirmationSound, ShowCliProgress, UseInputDirectoryAsOutput.

.DESCRIPTION (WORKFLOW)
    1) Start the script to open the GUI.
    2) Select an input audio/video file.
    3) Choose device/model/language/task/output options and adjust decoding parameters.
    4) Click Start to launch the external process.
    5) Wait until completion; the GUI unlocks and a run summary object is emitted to the pipeline.

.EXAMPLE
    PS> .\run_faster_whisper_xxl.ps1

    Opens the GUI. After the run completes, a summary object is written to the pipeline.

.EXAMPLE
    PS> $result = .\run_faster_whisper_xxl.ps1
    PS> $result | ConvertTo-Json -Depth 4

    Runs the GUI, captures the summary object into $result, and converts it to JSON.

.EXAMPLE
    PS> .\run_faster_whisper_xxl.ps1 | Export-Csv -NoTypeInformation -Path .\transcription-runs.csv

    Runs the GUI and appends/creates a CSV log of each run summary object.

.EXAMPLE
    PS> .\run_faster_whisper_xxl.ps1 | Where-Object { -not $_.Succeeded } | Format-List *

    Runs the GUI and displays detailed information only if the run failed.

.NOTES
    - The GUI validates the executable and the input file before launching the process and shows a message box on validation errors.
    - Output directory handling: if "Use input directory as output" is enabled, the output directory is derived from the input file location and the output directory controls are disabled.
    - Numeric parameters are formatted culture-invariant when passed to the executable to ensure a dot decimal separator.
    - The pipeline output is intentionally kept free of decorative strings to support clean automation and logging.
#>


# --- Ensure STA mode for WinForms/FileDialogs ---
if ($host.Runspace.ApartmentState -ne 'STA') {
    if ($env:OS -ne 'Windows_NT') {
        throw 'This script requires Windows (WinForms) and an STA runspace.'
    }

    $psExe = (Get-Process -Id $PID).Path

    if (-not (Test-Path -LiteralPath $psExe)) {
        Write-Error "Could not locate PowerShell executable for STA relaunch."
        return
    }

    if (-not $PSCommandPath) {
        Write-Error 'Could not determine script path for STA relaunch.'
        return
    }

    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$PSCommandPath`"")

    # Relaunch and exit current non-STA process
    Start-Process -FilePath $psExe -ArgumentList $argList -WindowStyle Normal | Out-Null
    exit
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'PowerShell 7+ (pwsh) is required.'
}

# --- Load WinForms assemblies ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# --- Load configuration helpers ---
$moduleManifestPath = Join-Path -Path $PSScriptRoot -ChildPath 'Module/FasterWhisperStandaloneGui.psd1'
Import-Module -Name $moduleManifestPath -Force -ErrorAction Stop

# --- Load configuration ---
$defaultConfig = Get-FasterWhisperGuiDefaultConfig
$configJsonPath = Join-Path -Path $PSScriptRoot -ChildPath 'run_faster_whisper_xxl.config.json'
$config = Get-FasterWhisperGuiConfig -ConfigPath $configJsonPath -DefaultConfig $defaultConfig

# Collect run summaries here; emitted to pipeline when form closes (event output cannot reach main pipeline)
$script:RunSummaries = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
# Track current process so we can wait for it after form closes (P0: no lost summary when user closes while running)
$script:CurrentProcess = $null

# Script-level helper: record a failed run summary and add to pipeline collection (deduplicates 9 failure paths)
function script:Add-FailedRunSummary {
    param(
        [Parameter(Mandatory)] $Summary,
        [Parameter(Mandatory)] [string] $ErrorMessage
    )
    if ($null -eq $Summary) { return }
    $Summary.ErrorMessage = $ErrorMessage
    $Summary | Add-Member -MemberType NoteProperty -Name Succeeded -Value $false -Force
    $Summary | Add-Member -MemberType NoteProperty -Name EndTime -Value (Get-Date) -Force
    $Summary.DurationSeconds = [Math]::Round( ($Summary.EndTime - $Summary.StartTime).TotalSeconds, 1 )
    $Summary.ExitCode = $null
    [void]$script:RunSummaries.Add($Summary)
}

# --- Main Form ---
# Layout constants for Transcription tab (single place to adjust horizontal layout)
$script:GuiLabelLeft   = 10
$script:GuiInputLeft   = 170
$script:GuiLabelWidth  = 150
$script:GuiInputWidth  = 250
$script:GuiValueLeft   = 480
$script:GuiButtonLeft  = 430
$script:GuiButtonWidth = 80
$script:GuiSliderWidth = 300
$script:GuiSliderHeight = 45

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Faster Whisper Transcription'
$form.ClientSize = [System.Drawing.Size]::new(600,750)
$form.StartPosition = 'CenterScreen'
$form.AutoScaleMode = 'Dpi'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.TopMost      = $false

# --- Handle Form Closing While Running ---
$form.Add_FormClosing({
    param($eventSender, $formClosingArgs)
    $null = $eventSender  # Required by WinForms event delegate signature

    if ($script:CurrentProcess -and -not $script:CurrentProcess.HasExited) {
        $msg = "A transcription is still in progress.`n`nYes = Stop transcription and close`nNo = Let it finish in the background, then close`nCancel = Return to the application"
        $result = [System.Windows.Forms.MessageBox]::Show(
            $msg,
            'Process Running',
            [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            try {
                $script:CurrentProcess.Kill()
            } catch {
                Write-Warning "Failed to terminate process: $($_.Exception.Message)"
            }
        }
        elseif ($result -eq [System.Windows.Forms.DialogResult]::No) {
            # Let it run in background, but the script will wait after ShowDialog()
        }
        else {
            $formClosingArgs.Cancel = $true
        }
    }
})

# --- TabControl and Pages ---
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = 'Fill'
$form.Controls.Add($tabControl)

$tabTranscription = New-Object System.Windows.Forms.TabPage
$tabTranscription.Text = 'Transcription'

$tabInfo = New-Object System.Windows.Forms.TabPage
$tabInfo.Text = 'Info'

$tabAbout = New-Object System.Windows.Forms.TabPage
$tabAbout.Text = 'About'

$tabControl.TabPages.AddRange(@($tabTranscription, $tabInfo, $tabAbout))

# --- Input File Selection ---
$inputLabel = New-Object System.Windows.Forms.Label
$inputLabel.Location = [Drawing.Point]::new($script:GuiLabelLeft,20)
$inputLabel.Size     = [Drawing.Size]::new($script:GuiLabelWidth,20)
$inputLabel.Text     = 'Audio/Video File'
$tabTranscription.Controls.Add($inputLabel)

$inputBox = New-Object System.Windows.Forms.TextBox
$inputBox.Location = [Drawing.Point]::new($script:GuiInputLeft,20)
$inputBox.Size     = [Drawing.Size]::new($script:GuiInputWidth,20)
$inputBox.Anchor   = 'Top,Left,Right'
$tabTranscription.Controls.Add($inputBox)

$inputButton = New-Object System.Windows.Forms.Button
$inputButton.Location = [Drawing.Point]::new($script:GuiButtonLeft,20)
$inputButton.Size     = [Drawing.Size]::new($script:GuiButtonWidth,22)
$inputButton.Text     = 'Browse...'
$inputButton.Anchor   = 'Top,Right'
$tabTranscription.Controls.Add($inputButton)

# --- Device Selection (ComboBox) ---
$deviceLabel = New-Object System.Windows.Forms.Label
$deviceLabel.Location = [Drawing.Point]::new($script:GuiLabelLeft,60)
$deviceLabel.Size     = [Drawing.Size]::new($script:GuiLabelWidth,20)
$deviceLabel.Text     = 'Processing Device'
$tabTranscription.Controls.Add($deviceLabel)

$deviceBox = New-Object System.Windows.Forms.ComboBox
$deviceBox.Location = [Drawing.Point]::new($script:GuiInputLeft,60)
$deviceBox.Size     = [Drawing.Size]::new($script:GuiInputWidth,20)
$deviceBox.DropDownStyle = 'DropDownList'
$allowedValues = Get-FasterWhisperAllowedValueMap
[void]$deviceBox.Items.AddRange($allowedValues.Devices)
if ($deviceBox.Items.Contains($config.Device)) { $deviceBox.SelectedItem = $config.Device } else { $deviceBox.SelectedIndex = 0 }
$tabTranscription.Controls.Add($deviceBox)

# --- Language ---
$languageLabel = New-Object System.Windows.Forms.Label
$languageLabel.Location = [Drawing.Point]::new($script:GuiLabelLeft,100)
$languageLabel.Size     = [Drawing.Size]::new($script:GuiLabelWidth,20)
$languageLabel.Text     = 'Language (e.g. en, de, fr)'
$tabTranscription.Controls.Add($languageLabel)

$languageBox = New-Object System.Windows.Forms.TextBox
$languageBox.Location = [Drawing.Point]::new($script:GuiInputLeft,100)
$languageBox.Size     = [Drawing.Size]::new($script:GuiInputWidth,20)
$languageBox.Text     = $config.Language
$tabTranscription.Controls.Add($languageBox)

# --- Model Selection ---
$modelLabel = New-Object System.Windows.Forms.Label
$modelLabel.Location = [Drawing.Point]::new($script:GuiLabelLeft,140)
$modelLabel.Size     = [Drawing.Size]::new($script:GuiLabelWidth,20)
$modelLabel.Text     = 'Model Size'
$tabTranscription.Controls.Add($modelLabel)

$modelBox = New-Object System.Windows.Forms.ComboBox
$modelBox.Location    = [Drawing.Point]::new($script:GuiInputLeft,140)
$modelBox.Size        = [Drawing.Size]::new($script:GuiInputWidth,20)
$modelBox.DropDownStyle = 'DropDownList'
[void]$modelBox.Items.AddRange($allowedValues.Models)
if ($modelBox.Items.Contains($config.Model)) { $modelBox.SelectedItem = $config.Model } else { $modelBox.SelectedIndex = 0 }
$tabTranscription.Controls.Add($modelBox)

# --- Output Directory Selection ---
$outputLabel = New-Object System.Windows.Forms.Label
$outputLabel.Location = [Drawing.Point]::new($script:GuiLabelLeft,180)
$outputLabel.Size     = [Drawing.Size]::new($script:GuiLabelWidth,20)
$outputLabel.Text     = 'Output Directory'
$tabTranscription.Controls.Add($outputLabel)

$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Location = [Drawing.Point]::new($script:GuiInputLeft,180)
$outputBox.Size     = [Drawing.Size]::new($script:GuiInputWidth,20)
$outputBox.Anchor   = 'Top,Left,Right'
$tabTranscription.Controls.Add($outputBox)

$outputButton = New-Object System.Windows.Forms.Button
$outputButton.Location = [Drawing.Point]::new($script:GuiButtonLeft,180)
$outputButton.Size     = [Drawing.Size]::new($script:GuiButtonWidth,22)
$outputButton.Text     = 'Browse...'
$outputButton.Anchor   = 'Top,Right'
$tabTranscription.Controls.Add($outputButton)

# --- Use Input Directory As Output ---
$useInputAsOutput = New-Object System.Windows.Forms.CheckBox
$useInputAsOutput.Location = [Drawing.Point]::new($script:GuiInputLeft,210)
$useInputAsOutput.Size = [Drawing.Size]::new(360,20)
$useInputAsOutput.Text = 'Use input directory as output'
$useInputAsOutput.Checked = $config.UseInputDirectoryAsOutput
$tabTranscription.Controls.Add($useInputAsOutput)

# Disable output controls on form load when UseInputDirectoryAsOutput is pre-configured
if ($useInputAsOutput.Checked) {
    $outputBox.Enabled = $false
    $outputButton.Enabled = $false
}

# --- Output Format Selection ---
$formatLabel = New-Object System.Windows.Forms.Label
$formatLabel.Location = [Drawing.Point]::new($script:GuiLabelLeft,240)
$formatLabel.Size     = [Drawing.Size]::new($script:GuiLabelWidth,20)
$formatLabel.Text     = 'Output Format'
$tabTranscription.Controls.Add($formatLabel)

$formatBox = New-Object System.Windows.Forms.ComboBox
$formatBox.Location = [Drawing.Point]::new($script:GuiInputLeft,240)
$formatBox.Size     = [Drawing.Size]::new($script:GuiInputWidth,20)
$formatBox.DropDownStyle = 'DropDownList'
[void]$formatBox.Items.AddRange($allowedValues.Formats)
if ($formatBox.Items.Contains($config.OutputFormat)) { $formatBox.SelectedItem = $config.OutputFormat } else { $formatBox.SelectedIndex = 0 }
$tabTranscription.Controls.Add($formatBox)

# --- Task Selection (transcribe/translate) ---
$taskLabel = New-Object System.Windows.Forms.Label
$taskLabel.Location = [Drawing.Point]::new($script:GuiLabelLeft,280)
$taskLabel.Size     = [Drawing.Size]::new($script:GuiLabelWidth,20)
$taskLabel.Text     = 'Task'
$tabTranscription.Controls.Add($taskLabel)

$taskBox = New-Object System.Windows.Forms.ComboBox
$taskBox.Location = [Drawing.Point]::new($script:GuiInputLeft,280)
$taskBox.Size     = [Drawing.Size]::new($script:GuiInputWidth,20)
$taskBox.DropDownStyle = 'DropDownList'
[void]$taskBox.Items.AddRange($allowedValues.Tasks)
if ($taskBox.Items.Contains($config.Task)) { $taskBox.SelectedItem = $config.Task } else { $taskBox.SelectedIndex = 0 }
$tabTranscription.Controls.Add($taskBox)

# --- Sliders for Best Of/Beam Size/Patience/Temperature ---
$bestOfLabel = New-Object System.Windows.Forms.Label
$bestOfLabel.Location = [Drawing.Point]::new($script:GuiLabelLeft,320)
$bestOfLabel.Size     = [Drawing.Size]::new($script:GuiLabelWidth,20)
$bestOfLabel.Text     = 'Best Of (candidates)'
$tabTranscription.Controls.Add($bestOfLabel)

$bestOfSlider = New-Object System.Windows.Forms.TrackBar
$bestOfSlider.Location = [Drawing.Point]::new($script:GuiInputLeft,320)
$bestOfSlider.Size     = [Drawing.Size]::new($script:GuiSliderWidth,$script:GuiSliderHeight)
$bestOfSlider.Minimum  = 1
$bestOfSlider.Maximum  = 10
$bestOfSlider.Value    = [Math]::Min([Math]::Max($config.BestOf,1),10)
$tabTranscription.Controls.Add($bestOfSlider)

$bestOfValue = New-Object System.Windows.Forms.Label
$bestOfValue.Location  = [Drawing.Point]::new($script:GuiValueLeft,320)
$bestOfValue.Size      = [Drawing.Size]::new(50,20)
$bestOfValue.Text      = $bestOfSlider.Value
$tabTranscription.Controls.Add($bestOfValue)
$bestOfSlider.add_ValueChanged({ $bestOfValue.Text = $bestOfSlider.Value })

$beamSizeLabel = New-Object System.Windows.Forms.Label
$beamSizeLabel.Location = [Drawing.Point]::new($script:GuiLabelLeft,370)
$beamSizeLabel.Size     = [Drawing.Size]::new($script:GuiLabelWidth,20)
$beamSizeLabel.Text     = 'Beam Size (search width)'
$tabTranscription.Controls.Add($beamSizeLabel)

$beamSizeSlider = New-Object System.Windows.Forms.TrackBar
$beamSizeSlider.Location = [Drawing.Point]::new($script:GuiInputLeft,370)
$beamSizeSlider.Size     = [Drawing.Size]::new($script:GuiSliderWidth,$script:GuiSliderHeight)
$beamSizeSlider.Minimum  = 1
$beamSizeSlider.Maximum  = 10
$beamSizeSlider.Value    = [Math]::Min([Math]::Max($config.BeamSize,1),10)
$tabTranscription.Controls.Add($beamSizeSlider)

$beamSizeValue = New-Object System.Windows.Forms.Label
$beamSizeValue.Location  = [Drawing.Point]::new($script:GuiValueLeft,370)
$beamSizeValue.Size      = [Drawing.Size]::new(50,20)
$beamSizeValue.Text      = $beamSizeSlider.Value
$tabTranscription.Controls.Add($beamSizeValue)
$beamSizeSlider.add_ValueChanged({ $beamSizeValue.Text = $beamSizeSlider.Value })

$patienceLabel = New-Object System.Windows.Forms.Label
$patienceLabel.Location = [Drawing.Point]::new($script:GuiLabelLeft,420)
$patienceLabel.Size     = [Drawing.Size]::new($script:GuiLabelWidth,20)
$patienceLabel.Text     = 'Patience (1.0 = default)'
$tabTranscription.Controls.Add($patienceLabel)

$patienceSlider = New-Object System.Windows.Forms.TrackBar
$patienceSlider.Location = [Drawing.Point]::new($script:GuiInputLeft,420)
$patienceSlider.Size     = [Drawing.Size]::new($script:GuiSliderWidth,$script:GuiSliderHeight)
$patienceSlider.Minimum  = 0      # 0.0
$patienceSlider.Maximum  = 20     # 2.0
$patienceSlider.TickFrequency = 1
$patienceSlider.Value    = [int]([Math]::Min([Math]::Max($config.Patience,0.0),2.0) * 10)
$tabTranscription.Controls.Add($patienceSlider)

$patienceValueLabel = New-Object System.Windows.Forms.Label
$patienceValueLabel.Location  = [Drawing.Point]::new($script:GuiValueLeft,420)
$patienceValueLabel.Size      = [Drawing.Size]::new(50,20)
$patienceValueLabel.Text      = ($patienceSlider.Value / 10.0).ToString([System.Globalization.CultureInfo]::InvariantCulture)
$tabTranscription.Controls.Add($patienceValueLabel)
$patienceSlider.add_ValueChanged({ $patienceValueLabel.Text = ($patienceSlider.Value / 10.0).ToString([System.Globalization.CultureInfo]::InvariantCulture) })

$temperatureLabel = New-Object System.Windows.Forms.Label
$temperatureLabel.Location = [Drawing.Point]::new($script:GuiLabelLeft,470)
$temperatureLabel.Size     = [Drawing.Size]::new($script:GuiLabelWidth,20)
$temperatureLabel.Text     = 'Temperature (0 = precise)'
$tabTranscription.Controls.Add($temperatureLabel)

$temperatureSlider = New-Object System.Windows.Forms.TrackBar
$temperatureSlider.Location = [Drawing.Point]::new($script:GuiInputLeft,470)
$temperatureSlider.Size     = [Drawing.Size]::new($script:GuiSliderWidth,$script:GuiSliderHeight)
$temperatureSlider.Minimum  = 0      # 0.0
$temperatureSlider.Maximum  = 20     # 2.0
$temperatureSlider.TickFrequency = 1
$temperatureSlider.Value    = [int]([Math]::Min([Math]::Max($config.Temperature,0.0),2.0) * 10)
$tabTranscription.Controls.Add($temperatureSlider)

$temperatureValueLabel = New-Object System.Windows.Forms.Label
$temperatureValueLabel.Location  = [Drawing.Point]::new($script:GuiValueLeft,470)
$temperatureValueLabel.Size      = [Drawing.Size]::new(50,20)
$temperatureValueLabel.Text      = ($temperatureSlider.Value / 10.0).ToString([System.Globalization.CultureInfo]::InvariantCulture)
$tabTranscription.Controls.Add($temperatureValueLabel)
$temperatureSlider.add_ValueChanged({ $temperatureValueLabel.Text = ($temperatureSlider.Value / 10.0).ToString([System.Globalization.CultureInfo]::InvariantCulture) })

# --- Checkboxes (Sound/Progress) ---
$confirmationSoundCheckbox = New-Object System.Windows.Forms.CheckBox
$confirmationSoundCheckbox.Location = [Drawing.Point]::new($script:GuiInputLeft,520)
$confirmationSoundCheckbox.Size     = [Drawing.Size]::new($script:GuiInputWidth,20)
$confirmationSoundCheckbox.Text     = 'Play sound when finished'
$confirmationSoundCheckbox.Checked  = $config.PlayConfirmationSound
$tabTranscription.Controls.Add($confirmationSoundCheckbox)

$progressCheckbox = New-Object System.Windows.Forms.CheckBox
$progressCheckbox.Location = [Drawing.Point]::new($script:GuiInputLeft,550)
$progressCheckbox.Size     = [Drawing.Size]::new(350,20)
$progressCheckbox.Text     = 'Show progress in console window'
$progressCheckbox.Checked  = $config.ShowCliProgress
$tabTranscription.Controls.Add($progressCheckbox)

# --- Start/Close Buttons ---
$startButton = New-Object System.Windows.Forms.Button
$startButton.Location = [Drawing.Point]::new($script:GuiInputLeft,580)
$startButton.Size     = [Drawing.Size]::new(130,30)
$startButton.Text     = 'Start Transcription'
$tabTranscription.Controls.Add($startButton)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Location = [Drawing.Point]::new(310,580)
$closeButton.Size     = [Drawing.Size]::new(100,30)
$closeButton.Text     = 'Close'
$closeButton.Add_Click({ $form.Close() })
$tabTranscription.Controls.Add($closeButton)

$form.AcceptButton = $startButton
$form.CancelButton = $closeButton

# --- Event handlers that depend on existing controls ---

$inputButton.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    try {
        $ofd.Filter = 'Audio/Video Files (*.mp3;*.wav;*.mp4)|*.mp3;*.wav;*.mp4|All Files (*.*)|*.*'
        $ofd.Multiselect = $false
        if ($ofd.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            $inputBox.Text = $ofd.FileName
            if ($useInputAsOutput.Checked) {
                $outputBox.Text = [System.IO.Path]::GetDirectoryName($ofd.FileName)
            }
        }
    }
    finally {
        $ofd.Dispose()
    }
})

$outputButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    try {
        if ($folderBrowser.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            $outputBox.Text = $folderBrowser.SelectedPath
        }
    }
    finally {
        $folderBrowser.Dispose()
    }
})

$useInputAsOutput.Add_CheckedChanged({
    if ($useInputAsOutput.Checked) {
        if ([System.IO.File]::Exists($inputBox.Text)) {
            $dir = [System.IO.Path]::GetDirectoryName($inputBox.Text)
            $outputBox.Text       = $dir
            $outputBox.Enabled    = $false
            $outputButton.Enabled = $false
        }
        else {
            [System.Windows.Forms.MessageBox]::Show(
                "Please select an audio or video file first before enabling this option.`n`nClick Browse to choose a file.",
                'Input File Required',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            $useInputAsOutput.Checked = $false
        }
    }
    else {
        $outputBox.Enabled    = $true
        $outputButton.Enabled = $true
    }
})

# --- Start Operation Handler ---
$startButton.Add_Click({

    # Disable buttons immediately to prevent double-click launching two processes
    $startButton.Enabled = $false
    $closeButton.Enabled = $false

  $processLaunched = $false
  try {

    # Build an object to capture the run summary (used when process exits)
    $summary = [pscustomobject]@{
        InputFile        = $null
        OutputDirectory  = $null
        Device           = $null
        Language         = $null
        Model            = $null
        OutputFormat     = $null
        Task             = $null
        BestOf           = $null
        BeamSize         = $null
        Patience         = $null
        Temperature      = $null
        PlaySound        = $null
        ShowCliProgress  = $null
        Executable       = $null
        StartTime        = Get-Date
        EndTime          = $null
        DurationSeconds  = $null
        ExitCode         = $null
        Succeeded        = $false
        ErrorMessage     = $null
    }

    $summary.InputFile   = $inputBox.Text
    $summary.Device      = $deviceBox.SelectedItem
    $summary.Language    = $languageBox.Text
    $summary.Model       = $modelBox.SelectedItem
    $summary.OutputFormat = $formatBox.SelectedItem
    $summary.Task        = $taskBox.SelectedItem
    $summary.BestOf      = $bestOfSlider.Value
    $summary.BeamSize    = $beamSizeSlider.Value
    $summary.PlaySound   = $confirmationSoundCheckbox.Checked
    $summary.ShowCliProgress = $progressCheckbox.Checked

    # Determine patience and temperature as invariant strings
    $invCulture = [System.Globalization.CultureInfo]::InvariantCulture
    $patienceValue = [string]::Format($invCulture, '{0:0.0}', ($patienceSlider.Value / 10.0))
    $temperatureValue = [string]::Format($invCulture, '{0:0.0}', ($temperatureSlider.Value / 10.0))

    $summary.Patience    = [double]$patienceValue
    $summary.Temperature = [double]$temperatureValue

    # Validate Language (optional, but if provided should be ISO-639-1)
    if (-not [string]::IsNullOrWhiteSpace($languageBox.Text)) {
        if ($languageBox.Text -notmatch '(?i)^[a-z]{2}$') {
            $summary.ErrorMessage = "Invalid language code: '$($languageBox.Text)'. Please enter a 2-letter language code (e.g. 'en' for English, 'de' for German, 'fr' for French) or leave it empty for auto-detection."
            [System.Windows.Forms.MessageBox]::Show(
                $summary.ErrorMessage,
                'Validation Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            Add-FailedRunSummary -Summary $summary -ErrorMessage $summary.ErrorMessage
            return
        }
        # Normalize language to lowercase for the executable
        $languageBox.Text = $languageBox.Text.ToLowerInvariant()
    }

    # Resolve executable path (configurable) with security validation
    $exe = if (-not [string]::IsNullOrWhiteSpace($config.ExecutablePath)) {
        $config.ExecutablePath
    }
    else {
        'faster-whisper-xxl.exe'
    }
    
    # Security validation for executable path
    $exeValidationResult = Test-SafeExecutablePath -ExecutablePath $exe
    if (-not $exeValidationResult.IsValid) {
        $summary.ErrorMessage = "The configured executable path is not allowed for security reasons: $($exeValidationResult.Message)`n`nPlease check the 'ExecutablePath' setting in your config JSON file."
        [System.Windows.Forms.MessageBox]::Show(
            $summary.ErrorMessage,
            'Security Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        Add-FailedRunSummary -Summary $summary -ErrorMessage $summary.ErrorMessage
        return
    }
    if ($exeValidationResult.Warning) {
        $warningResult = [System.Windows.Forms.MessageBox]::Show(
            "Security Warning: $($exeValidationResult.Warning)`n`nDo you want to continue?",
            'Security Warning',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($warningResult -ne [System.Windows.Forms.DialogResult]::Yes) {
            $summary.ErrorMessage = "User cancelled due to security warning."
            Add-FailedRunSummary -Summary $summary -ErrorMessage $summary.ErrorMessage
            return
        }
    }

    $summary.Executable = $exe

    # Validate executable: use Test-Path for absolute paths, Get-Command for names in PATH
    $exeExists = if ($exe -match '[/\\]') {
        Test-Path -LiteralPath $exe -PathType Leaf
    } else {
        $null -ne (Get-Command -Name $exe -ErrorAction SilentlyContinue)
    }
    if (-not $exeExists) {
        $summary.ErrorMessage = "Transcription engine not found: $exe`n`nTo fix this:`n1. Download faster-whisper-xxl.exe and place it in the same folder as this script.`n2. Or add its location to your system PATH.`n3. Or set 'ExecutablePath' in the config JSON file."
        [System.Windows.Forms.MessageBox]::Show(
            $summary.ErrorMessage,
            'Transcription Engine Not Found',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null

        Add-FailedRunSummary -Summary $summary -ErrorMessage $summary.ErrorMessage
        return
    }

    # Validate input file
    if ([string]::IsNullOrWhiteSpace($inputBox.Text) -or
        -not [System.IO.File]::Exists($inputBox.Text)) {

        $summary.ErrorMessage = "No input file selected or file not found.`n`nPlease click Browse to select an audio or video file (MP3, WAV, MP4)."
        [System.Windows.Forms.MessageBox]::Show(
            $summary.ErrorMessage,
            'Input File Required',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null

        Add-FailedRunSummary -Summary $summary -ErrorMessage $summary.ErrorMessage
        return
    }

    if (-not (Test-PathTraversalSafe -Path $inputBox.Text)) {
        $summary.ErrorMessage = "The input file path appears unsafe.`nPlease select a file using the Browse button instead of typing the path manually."
        [System.Windows.Forms.MessageBox]::Show(
            $summary.ErrorMessage,
            'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        Add-FailedRunSummary -Summary $summary -ErrorMessage $summary.ErrorMessage
        return
    }

    # Determine output directory
    $outputDir = Get-FasterWhisperOutputDirectory `
        -InputFile $inputBox.Text `
        -OutputDirectory $outputBox.Text `
        -UseInputDirectoryAsOutput $useInputAsOutput.Checked

    $summary.OutputDirectory = $outputDir

    if (-not (Test-PathTraversalSafe -Path $outputDir)) {
        $summary.ErrorMessage = "The output directory path appears unsafe.`nPlease select a folder using the Browse button instead of typing the path manually."
        [System.Windows.Forms.MessageBox]::Show(
            $summary.ErrorMessage,
            'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        Add-FailedRunSummary -Summary $summary -ErrorMessage $summary.ErrorMessage
        return
    }

    try {
        if (-not [System.IO.Directory]::Exists($outputDir)) {
            [System.IO.Directory]::CreateDirectory($outputDir) | Out-Null
        }
    }
    catch {
        $summary.ErrorMessage = "Could not create or access the output folder:`n$outputDir`n`nPlease check that you have write permissions to this location, or choose a different output folder.`n`nDetails: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show(
            $summary.ErrorMessage,
            'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null

        Add-FailedRunSummary -Summary $summary -ErrorMessage $summary.ErrorMessage
        return
    }

    # Build arguments (passed as array to Start-Process/ProcessStartInfo to handle quoting automatically)
    $argList = Get-FasterWhisperArgumentList `
        -InputFile $inputBox.Text `
        -Device $deviceBox.SelectedItem `
        -Language $languageBox.Text `
        -Model $modelBox.SelectedItem `
        -OutputDirectory $outputDir `
        -OutputFormat $formatBox.SelectedItem `
        -Task $taskBox.SelectedItem `
        -BestOf $bestOfSlider.Value `
        -BeamSize $beamSizeSlider.Value `
        -Patience $patienceValue `
        -Temperature $temperatureValue `
        -PlayConfirmationSound $confirmationSoundCheckbox.Checked `
        -ShowCliProgress $progressCheckbox.Checked

    # Create process object
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $p.StartInfo.FileName         = $exe
    # Use ArgumentList (PS 7+) for robust argument passing without manual quoting/escaping
    foreach ($arg in $argList) { [void]$p.StartInfo.ArgumentList.Add([string]$arg) }
    $p.StartInfo.UseShellExecute  = $false
    $p.StartInfo.CreateNoWindow   = $false
    $workingDir = Split-Path -Path $inputBox.Text -Parent
    if ([string]::IsNullOrWhiteSpace($workingDir)) {
        $workingDir = [System.Environment]::CurrentDirectory
    }
    $p.StartInfo.WorkingDirectory = $workingDir
    $p.EnableRaisingEvents        = $true

    # Register Exited event BEFORE starting to ensure we don't miss quick-finishing processes.
    # Pass summary and UI refs via MessageData so the Action block has reliable access (event scope does not share closure).
    $eventId = "FasterWhisperExited_$([Guid]::NewGuid().ToString('N'))"
    $messageData = [pscustomobject]@{
        Summary           = $summary
        Form              = $form
        StartButton        = $startButton
        CloseButton        = $closeButton
        PlaySoundCheckbox  = $confirmationSoundCheckbox
    }
    $null = Register-ObjectEvent -InputObject $p -EventName Exited -SourceIdentifier $eventId -MessageData $messageData -Action {
        try {
            $proc = $Event.Sender
            $msg = $Event.MessageData
            if ($null -eq $msg -or $null -eq $msg.Summary) { return }
            $summary = $msg.Summary

            $summary.EndTime = Get-Date
            $summary.DurationSeconds = [Math]::Round( ($summary.EndTime - $summary.StartTime).TotalSeconds, 1 )
            $summary.ExitCode = $proc.ExitCode
            $summary.Succeeded = ($proc.ExitCode -eq 0)
            if (-not $summary.Succeeded -and -not $summary.ErrorMessage) {
                $summary.ErrorMessage = "Transcription failed (exit code $($proc.ExitCode)).`nCheck the console window for details, or try a different model size or device setting."
            }

            if ($msg.PlaySoundCheckbox.Checked) {
                [System.Media.SystemSounds]::Asterisk.Play()
            }

            if ($msg.Form.IsHandleCreated -and -not $msg.Form.IsDisposed) {
                try {
                    $msg.Form.Invoke([System.Action]{
                        $msg.StartButton.Enabled = $true
                        $msg.CloseButton.Enabled = $true

                        if ($summary.Succeeded) {
                            $durationText = if ($summary.DurationSeconds -ge 60) {
                                $mins = [Math]::Floor($summary.DurationSeconds / 60)
                                $secs = [Math]::Round($summary.DurationSeconds % 60)
                                "${mins} min ${secs} sec"
                            } else {
                                "$($summary.DurationSeconds) seconds"
                            }
                            [System.Windows.Forms.MessageBox]::Show(
                                "Transcription completed successfully!`n`nOutput saved to:`n$($summary.OutputDirectory)`n`nDuration: $durationText",
                                'Transcription Complete',
                                [System.Windows.Forms.MessageBoxButtons]::OK,
                                [System.Windows.Forms.MessageBoxIcon]::Information
                            ) | Out-Null
                        } else {
                            [System.Windows.Forms.MessageBox]::Show(
                                $summary.ErrorMessage,
                                'Transcription Failed',
                                [System.Windows.Forms.MessageBoxButtons]::OK,
                                [System.Windows.Forms.MessageBoxIcon]::Error
                            ) | Out-Null
                        }
                    }) | Out-Null
                }
                catch {
                    # Form may already be disposed when event fires late.
                    Write-Verbose "UI update after process exit was skipped: $($_.Exception.Message)"
                }
            }

            [void]$script:RunSummaries.Add($summary)
        }
        finally {
            $script:CurrentProcess = $null
            Unregister-Event -SourceIdentifier $EventSubscriber.SourceIdentifier
            if ($proc -is [System.IDisposable]) {
                $proc.Dispose()
            }
        }
    }

    try {
        $null = $p.Start()
        $script:CurrentProcess = $p
        $processLaunched = $true
    }
    catch {
        # If start fails, cleanup event and update UI
        Unregister-Event -SourceIdentifier $eventId
        $script:CurrentProcess = $null

        $summary.ErrorMessage = "Failed to start the transcription engine.`n`nPlease verify that '$exe' is a valid executable and try again.`n`nDetails: $($_.Exception.Message)"
        Add-FailedRunSummary -Summary $summary -ErrorMessage $summary.ErrorMessage

        [System.Windows.Forms.MessageBox]::Show(
            $summary.ErrorMessage,
            'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        
        $startButton.Enabled = $true
        $closeButton.Enabled = $true
    }
  }
  finally {
    # Re-enable buttons if the process was not successfully launched (validation failures, errors)
    if (-not $processLaunched) {
        $startButton.Enabled = $true
        $closeButton.Enabled = $true
    }
  }
})

# --- Info Tab: TextBox with Scrollbars ---
$infoText = @"
Getting Started with Faster Whisper Transcription

This tool converts speech in audio and video files into text.
All processing happens on your computer -- no files are uploaded anywhere.

QUICK START
-----------
1. Click "Browse..." to select your audio or video file (MP3, WAV, MP4).
2. Click "Start Transcription" to begin.
3. When finished, a message will show you where the output file was saved.

SETTINGS EXPLAINED
------------------
Audio/Video File:
   The file you want to transcribe. Supported: MP3, WAV, MP4.

Processing Device:
   - 'cpu': Uses your processor. Works on any computer, but slower.
   - 'cuda': Uses your NVIDIA graphics card. Much faster, but requires
     a compatible NVIDIA GPU with CUDA drivers installed.

Language (e.g. en, de, fr):
   Enter the 2-letter code for the spoken language in your file.
   Examples: 'en' = English, 'de' = German, 'fr' = French, 'es' = Spanish.
   Leave empty to let the tool detect the language automatically.

Model Size:
   Controls accuracy vs. speed:
   - 'base': Fastest, least accurate. Good for quick drafts.
   - 'medium': Balanced accuracy and speed. Recommended for most uses.
   - 'large-v2': High accuracy, slower processing.
   - 'xxl': Best accuracy, requires the most time and memory.

Output Directory:
   Where the result file will be saved. You can choose any folder,
   or check "Use input directory as output" to save next to the original file.

Output Format:
   - 'txt': Plain text (just the words, no timestamps).
   - 'srt': Subtitle file for video players (with timestamps).
   - 'vtt': Web subtitle file (with timestamps, for web video).

Task:
   - 'transcribe': Write out what is said, in the original language.
   - 'translate': Translate the speech into English.

ADVANCED SETTINGS (optional)
-----------------------------
These are fine at their defaults. Only adjust if needed:

   Best Of (candidates): How many alternatives to consider per segment.
      Higher = potentially better results, but slower. Default: 3.

   Beam Size (search width): How many paths to explore at each step.
      Higher = more thorough, but slower. Default: 5.

   Patience (1.0 = default): How much extra searching to allow.
      Values above 1.0 explore more options. Useful for difficult audio.

   Temperature (0 = precise): Controls randomness.
      0.0 = most precise/deterministic. Higher = more varied output.

ADDITIONAL OPTIONS
------------------
   Play sound when finished: Plays a notification sound when done.
   Show progress in console window: Displays a progress indicator
      in the PowerShell console while transcription is running.

TIPS
----
- Start with the 'medium' model for a good balance of speed and accuracy.
- Use 'cuda' if you have an NVIDIA GPU -- it can be 5-10x faster.
- For long recordings, larger models (large-v2, xxl) give better results.
- Your files stay on your computer. Nothing is sent to the internet.

HELP
----
Visit https://github.com/Purfview/whisper-standalone-win
or https://github.com/sebastianspicker/ for updates and support.

"@

$infoBox = New-Object System.Windows.Forms.TextBox
$infoBox.Multiline   = $true
$infoBox.ReadOnly    = $true
$infoBox.ScrollBars  = 'Vertical'
$infoBox.Location    = [Drawing.Point]::new($script:GuiLabelLeft,10)
$infoBox.Size        = [Drawing.Size]::new(560,660)
$infoBox.Text        = $infoText
$tabInfo.Controls.Add($infoBox)

# --- About Tab ---
$aboutLabel = New-Object System.Windows.Forms.Label
$aboutLabel.Location = [Drawing.Point]::new($script:GuiLabelLeft,10)
$aboutLabel.Text     = 'Based on: https://github.com/Purfview/whisper-standalone-win'
$tabAbout.Controls.Add($aboutLabel)

$whisperLink = New-Object System.Windows.Forms.LinkLabel
$whisperLink.Text     = 'https://github.com/openai/whisper'
$whisperLink.Location = [Drawing.Point]::new($script:GuiLabelLeft,30)
$whisperLink.AutoSize = $true
$null = $whisperLink.Links.Add(0, $whisperLink.Text.Length, $whisperLink.Text)
$whisperLink.add_LinkClicked({
    param($linkLabel, $linkClickedEventArgs)

    if ($null -eq $linkLabel -or $null -eq $linkClickedEventArgs -or $null -eq $linkClickedEventArgs.Link) { return }
    $linkData = $linkClickedEventArgs.Link.LinkData
    if ($null -eq $linkData) { return }
    $url = $linkData.ToString()
    if ($url -match '^https?://') {
        Start-Process -FilePath $url
    } else {
        Write-Warning "Blocked non-HTTP link: $url"
    }
})
$tabAbout.Controls.Add($whisperLink)

$creatorLink = New-Object System.Windows.Forms.LinkLabel
$creatorLink.Text     = 'Created by: https://github.com/sebastianspicker'
$creatorLink.Location = [Drawing.Point]::new($script:GuiLabelLeft,60)
$creatorLink.AutoSize = $true
$null = $creatorLink.Links.Add(12, $creatorLink.Text.Length - 12, 'https://github.com/sebastianspicker')
$creatorLink.add_LinkClicked({
    param($linkLabel, $linkClickedEventArgs)

    if ($null -eq $linkLabel -or $null -eq $linkClickedEventArgs -or $null -eq $linkClickedEventArgs.Link) { return }
    $linkData = $linkClickedEventArgs.Link.LinkData
    if ($null -eq $linkData) { return }
    $url = $linkData.ToString()
    if ($url -match '^https?://') {
        Start-Process -FilePath $url
    } else {
        Write-Warning "Blocked non-HTTP link: $url"
    }
})
$tabAbout.Controls.Add($creatorLink)

$creditsLabel = New-Object System.Windows.Forms.Label
$creditsLabel.Location = [Drawing.Point]::new($script:GuiLabelLeft,90)
$creditsLabel.AutoSize = $true
$creditsLabel.Text     = 'Cologne University of Music, 2025'
$tabAbout.Controls.Add($creditsLabel)

# --- Show Form (Modal) ---
$form.Add_Shown({ $form.Activate() })
try {
    [void]$form.ShowDialog()
}
finally {
    $form.Dispose()
}

# P0: Wait for any still-running process so its summary is added before we output (no lost summary when user closed while running)
while ($script:CurrentProcess -and -not $script:CurrentProcess.HasExited) {
    Start-Sleep -Milliseconds 200
}

# Emit all run summaries to pipeline (event-handler output cannot reach main pipeline)
foreach ($s in $script:RunSummaries) { $s }
