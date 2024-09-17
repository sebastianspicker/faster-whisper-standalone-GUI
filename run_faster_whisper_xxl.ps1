Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main window (form)
$form = New-Object System.Windows.Forms.Form
$form.Text = "Faster Whisper Transcription"
$form.Size = New-Object System.Drawing.Size(600, 750)
$form.StartPosition = "CenterScreen"  # Center the window on the screen

# Create a TabControl to hold the different tabs
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Size = New-Object System.Drawing.Size(580, 700)
$tabControl.Location = New-Object System.Drawing.Point(10, 10)  # Location inside the form

# Create individual tabs for Transcription, Info, and About sections
$tabTranscription = New-Object System.Windows.Forms.TabPage
$tabTranscription.Text = "Transcription"

$tabInfo = New-Object System.Windows.Forms.TabPage
$tabInfo.Text = "Info"

$tabAbout = New-Object System.Windows.Forms.TabPage
$tabAbout.Text = "About"

### Transcription Tab Elements ###

# Input file label
$inputLabel = New-Object System.Windows.Forms.Label
$inputLabel.Location = New-Object System.Drawing.Point(10, 20)
$inputLabel.Size = New-Object System.Drawing.Size(150, 20)
$inputLabel.Text = "Input File"
$tabTranscription.Controls.Add($inputLabel)

# Input file textbox
$inputBox = New-Object System.Windows.Forms.TextBox
$inputBox.Location = New-Object System.Drawing.Point(170, 20)
$inputBox.Size = New-Object System.Drawing.Size(250, 20)
$tabTranscription.Controls.Add($inputBox)

# Browse button for input file
$inputButton = New-Object System.Windows.Forms.Button
$inputButton.Location = New-Object System.Drawing.Point(430, 20)
$inputButton.Size = New-Object System.Drawing.Size(75, 20)
$inputButton.Text = "Browse"
$tabTranscription.Controls.Add($inputButton)

# Action for Browse button to open a file dialog for selecting an input file
$inputButton.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "Audio/Video Files (*.mp3;*.wav;*.mp4)|*.mp3;*.wav;*.mp4"
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $inputBox.Text = $openFileDialog.FileName  # Set the selected file path in the inputBox
    }
})

# Device selection (cpu or cuda)
$deviceLabel = New-Object System.Windows.Forms.Label
$deviceLabel.Location = New-Object System.Drawing.Point(10, 60)
$deviceLabel.Size = New-Object System.Drawing.Size(150, 20)
$deviceLabel.Text = "Device (cpu/cuda)"
$tabTranscription.Controls.Add($deviceLabel)

$deviceBox = New-Object System.Windows.Forms.ComboBox
$deviceBox.Location = New-Object System.Drawing.Point(170, 60)
$deviceBox.Size = New-Object System.Drawing.Size(250, 20)
$deviceBox.Items.AddRange(@("cpu", "cuda"))
$deviceBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList  # Drop-down only selection
$tabTranscription.Controls.Add($deviceBox)

# Language input (ISO-639-1 format)
$languageLabel = New-Object System.Windows.Forms.Label
$languageLabel.Location = New-Object System.Drawing.Point(10, 100)
$languageLabel.Size = New-Object System.Drawing.Size(150, 20)
$languageLabel.Text = "Language (ISO-639-1)"
$tabTranscription.Controls.Add($languageLabel)

$languageBox = New-Object System.Windows.Forms.TextBox
$languageBox.Location = New-Object System.Drawing.Point(170, 100)
$languageBox.Size = New-Object System.Drawing.Size(250, 20)
$tabTranscription.Controls.Add($languageBox)

# Model selection (base, medium, large-v2, xxl)
$modelLabel = New-Object System.Windows.Forms.Label
$modelLabel.Location = New-Object System.Drawing.Point(10, 140)
$modelLabel.Size = New-Object System.Drawing.Size(150, 20)
$modelLabel.Text = "Model"
$tabTranscription.Controls.Add($modelLabel)

$modelBox = New-Object System.Windows.Forms.ComboBox
$modelBox.Location = New-Object System.Drawing.Point(170, 140)
$modelBox.Size = New-Object System.Drawing.Size(250, 20)
$modelBox.Items.AddRange(@("base", "medium", "large-v2", "xxl"))
$modelBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$tabTranscription.Controls.Add($modelBox)

# Output directory label and textbox
$outputLabel = New-Object System.Windows.Forms.Label
$outputLabel.Location = New-Object System.Drawing.Point(10, 180)
$outputLabel.Size = New-Object System.Drawing.Size(150, 20)
$outputLabel.Text = "Output Directory"
$tabTranscription.Controls.Add($outputLabel)

$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Location = New-Object System.Drawing.Point(170, 180)
$outputBox.Size = New-Object System.Drawing.Size(250, 20)
$tabTranscription.Controls.Add($outputBox)

# Browse button for output directory
$outputButton = New-Object System.Windows.Forms.Button
$outputButton.Location = New-Object System.Drawing.Point(430, 180)
$outputButton.Size = New-Object System.Drawing.Size(75, 20)
$outputButton.Text = "Browse"
$tabTranscription.Controls.Add($outputButton)

# Action for Browse button to open a folder dialog for selecting output directory
$outputButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $outputBox.Text = $folderBrowser.SelectedPath  # Set the selected folder path in the outputBox
    }
})

# Checkbox for using input directory as output directory
$useInputAsOutput = New-Object System.Windows.Forms.CheckBox
$useInputAsOutput.Location = New-Object System.Drawing.Point(170, 210)
$useInputAsOutput.Size = New-Object System.Drawing.Size(250, 20)
$useInputAsOutput.Text = "Use input directory as output"
$tabTranscription.Controls.Add($useInputAsOutput)

# Action for using input directory as output
$useInputAsOutput.Add_CheckedChanged({
    if ($useInputAsOutput.Checked -eq $true) {
        if ([System.IO.File]::Exists($inputBox.Text)) {
            $outputBox.Text = [System.IO.Path]::GetDirectoryName($inputBox.Text)
            $outputBox.Enabled = $false
            $outputButton.Enabled = $false
        } else {
            [System.Windows.Forms.MessageBox]::Show("Invalid input file. Please select a valid file.", "Error")
            $useInputAsOutput.Checked = $false
        }
    } else {
        $outputBox.Enabled = $true
        $outputButton.Enabled = $true
    }
})

# Output format label and drop-down
$formatLabel = New-Object System.Windows.Forms.Label
$formatLabel.Location = New-Object System.Drawing.Point(10, 240)
$formatLabel.Size = New-Object System.Drawing.Size(150, 20)
$formatLabel.Text = "Output Format"
$tabTranscription.Controls.Add($formatLabel)

$formatBox = New-Object System.Windows.Forms.ComboBox
$formatBox.Location = New-Object System.Drawing.Point(170, 240)
$formatBox.Size = New-Object System.Drawing.Size(250, 20)
$formatBox.Items.AddRange(@("txt", "srt", "vtt"))
$formatBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$tabTranscription.Controls.Add($formatBox)

# Task selection (transcribe or translate)
$taskLabel = New-Object System.Windows.Forms.Label
$taskLabel.Location = New-Object System.Drawing.Point(10, 280)
$taskLabel.Size = New-Object System.Drawing.Size(150, 20)
$taskLabel.Text = "Task (transcribe/translate)"
$tabTranscription.Controls.Add($taskLabel)

$taskBox = New-Object System.Windows.Forms.ComboBox
$taskBox.Location = New-Object System.Drawing.Point(170, 280)
$taskBox.Size = New-Object System.Drawing.Size(250, 20)
$taskBox.Items.AddRange(@("transcribe", "translate"))
$taskBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$tabTranscription.Controls.Add($taskBox)

### Sliders for Parameters ###

# Slider for Best Of value (range: 1-10)
$bestOfLabel = New-Object System.Windows.Forms.Label
$bestOfLabel.Location = New-Object System.Drawing.Point(10, 320)
$bestOfLabel.Size = New-Object System.Drawing.Size(150, 20)
$bestOfLabel.Text = "Best of"
$tabTranscription.Controls.Add($bestOfLabel)

$bestOfSlider = New-Object System.Windows.Forms.TrackBar
$bestOfSlider.Location = New-Object System.Drawing.Point(170, 320)
$bestOfSlider.Size = New-Object System.Drawing.Size(300, 45)
$bestOfSlider.Minimum = 1
$bestOfSlider.Maximum = 10
$bestOfSlider.Value = 3
$tabTranscription.Controls.Add($bestOfSlider)

$bestOfValue = New-Object System.Windows.Forms.Label
$bestOfValue.Location = New-Object System.Drawing.Point(480, 320)
$bestOfValue.Size = New-Object System.Drawing.Size(50, 20)
$bestOfValue.Text = $bestOfSlider.Value
$tabTranscription.Controls.Add($bestOfValue)

$bestOfSlider.add_ValueChanged({
    $bestOfValue.Text = $bestOfSlider.Value  # Update label with slider value
})

# Slider for Beam Size value (range: 1-10)
$beamSizeLabel = New-Object System.Windows.Forms.Label
$beamSizeLabel.Location = New-Object System.Drawing.Point(10, 370)
$beamSizeLabel.Size = New-Object System.Drawing.Size(150, 20)
$beamSizeLabel.Text = "Beam Size"
$tabTranscription.Controls.Add($beamSizeLabel)

$beamSizeSlider = New-Object System.Windows.Forms.TrackBar
$beamSizeSlider.Location = New-Object System.Drawing.Point(170, 370)
$beamSizeSlider.Size = New-Object System.Drawing.Size(300, 45)
$beamSizeSlider.Minimum = 1
$beamSizeSlider.Maximum = 10
$beamSizeSlider.Value = 5
$tabTranscription.Controls.Add($beamSizeSlider)

$beamSizeValue = New-Object System.Windows.Forms.Label
$beamSizeValue.Location = New-Object System.Drawing.Point(480, 370)
$beamSizeValue.Size = New-Object System.Drawing.Size(50, 20)
$beamSizeValue.Text = $beamSizeSlider.Value
$tabTranscription.Controls.Add($beamSizeValue)

$beamSizeSlider.add_ValueChanged({
    $beamSizeValue.Text = $beamSizeSlider.Value
})

# Slider for Patience value (range: 1.0-2.0)
$patienceLabel = New-Object System.Windows.Forms.Label
$patienceLabel.Location = New-Object System.Drawing.Point(10, 420)
$patienceLabel.Size = New-Object System.Drawing.Size(150, 20)
$patienceLabel.Text = "Patience"
$tabTranscription.Controls.Add($patienceLabel)

$patienceSlider = New-Object System.Windows.Forms.TrackBar
$patienceSlider.Location = New-Object System.Drawing.Point(170, 420)
$patienceSlider.Size = New-Object System.Drawing.Size(300, 45)
$patienceSlider.Minimum = 10
$patienceSlider.Maximum = 20
$patienceSlider.TickFrequency = 1
$patienceSlider.Value = 20  # Start value = 2.0 (20/10)
$tabTranscription.Controls.Add($patienceSlider)

$patienceValue = New-Object System.Windows.Forms.Label
$patienceValue.Location = New-Object System.Drawing.Point(480, 420)
$patienceValue.Size = New-Object System.Drawing.Size(50, 20)
$patienceValue.Text = ($patienceSlider.Value / 10.0)
$tabTranscription.Controls.Add($patienceValue)

$patienceSlider.add_ValueChanged({
    $patienceValue.Text = ($patienceSlider.Value / 10.0)  # Display slider value as decimal
})

# Slider for Temperature value (range: 0-2.0)
$temperatureLabel = New-Object System.Windows.Forms.Label
$temperatureLabel.Location = New-Object System.Drawing.Point(10, 470)
$temperatureLabel.Size = New-Object System.Drawing.Size(150, 20)
$temperatureLabel.Text = "Temperature"
$tabTranscription.Controls.Add($temperatureLabel)

$temperatureSlider = New-Object System.Windows.Forms.TrackBar
$temperatureSlider.Location = New-Object System.Drawing.Point(170, 470)
$temperatureSlider.Size = New-Object System.Drawing.Size(300, 45)
$temperatureSlider.Minimum = 0
$temperatureSlider.Maximum = 20
$temperatureSlider.TickFrequency = 1
$temperatureSlider.Value = 0  # Default value = 0
$tabTranscription.Controls.Add($temperatureSlider)

$temperatureValue = New-Object System.Windows.Forms.Label
$temperatureValue.Location = New-Object System.Drawing.Point(480, 470)
$temperatureValue.Size = New-Object System.Drawing.Size(50, 20)
$temperatureValue.Text = ($temperatureSlider.Value / 10.0)
$tabTranscription.Controls.Add($temperatureValue)

$temperatureSlider.add_ValueChanged({
    $temperatureValue.Text = ($temperatureSlider.Value / 10.0)  # Display slider value as decimal
})

### Checkboxes ###

# Checkbox for sound confirmation after operation
$confirmationSoundCheckbox = New-Object System.Windows.Forms.CheckBox
$confirmationSoundCheckbox.Location = New-Object System.Drawing.Point(170, 520)
$confirmationSoundCheckbox.Size = New-Object System.Drawing.Size(250, 20)
$confirmationSoundCheckbox.Text = "Play confirmation sound"
$confirmationSoundCheckbox.Checked = $false  # Default checked
$tabTranscription.Controls.Add($confirmationSoundCheckbox)

# Checkbox for showing progress bar
$progressCheckbox = New-Object System.Windows.Forms.CheckBox
$progressCheckbox.Location = New-Object System.Drawing.Point(170, 550)
$progressCheckbox.Size = New-Object System.Drawing.Size(250, 20)
$progressCheckbox.Text = "Show progress bar"
$progressCheckbox.Checked = $false  # Default unchecked
$tabTranscription.Controls.Add($progressCheckbox)

### Buttons ###

# Start button to run Faster Whisper with selected parameters
$startButton = New-Object System.Windows.Forms.Button
$startButton.Location = New-Object System.Drawing.Point(170, 580)
$startButton.Size = New-Object System.Drawing.Size(100, 30)
$startButton.Text = "Start"
$tabTranscription.Controls.Add($startButton)

# Close button to exit the GUI
$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Location = New-Object System.Drawing.Point(280, 580)
$closeButton.Size = New-Object System.Drawing.Size(100, 30)
$closeButton.Text = "Close"
$tabTranscription.Controls.Add($closeButton)

# Close button event handler to close the form
$closeButton.Add_Click({
    $form.Close()
})

# Start button event handler to run Faster Whisper with parameters from the GUI
$startButton.Add_Click({
    # Collect parameters from the GUI elements
    $task = $taskBox.SelectedItem
    $device = $deviceBox.SelectedItem
    $language = $languageBox.Text
    $model = $modelBox.SelectedItem
    $inputFile = $inputBox.Text
    $outputDir = $outputBox.Text
    $outputFormat = $formatBox.SelectedItem
    $bestOf = $bestOfSlider.Value
    $beamSize = $beamSizeSlider.Value
    $patience = $patienceSlider.Value / 10.0
    $temperature = $temperatureSlider.Value / 10.0

    # Use input directory as output if the checkbox is checked
    if ($useInputAsOutput.Checked) {
        $outputDir = [System.IO.Path]::GetDirectoryName($inputFile)
    }

    # Create the command to execute Faster Whisper with the selected options
    $cmd = "faster-whisper-xxl.exe `"$inputFile`" --device $device --language $language --model $model --output_dir `"$outputDir`" --output_format $outputFormat --task $task --best_of $bestOf --beam_size $beamSize --patience $patience --temperature $temperature"

    # Disable confirmation sound if the checkbox is unchecked
    if (-not $confirmationSoundCheckbox.Checked) {
        $cmd += " --beep_off"
    }

    # Enable progress bar display if the checkbox is checked
    if ($progressCheckbox.Checked) {
        $cmd += " --print_progress"
    }

    # Execute the command in a cmd shell
    Start-Process "cmd.exe" -ArgumentList "/c", $cmd -NoNewWindow -Wait

    # Play a beep sound if confirmation sound checkbox is checked
    if ($confirmationSoundCheckbox.Checked) {
        [console]::beep(1000, 300)
    }
})

### Info Tab Content ###

# Info tab label content
$infoLabel = New-Object System.Windows.Forms.Label
$infoLabel.AutoSize = $true
$infoLabel.Location = New-Object System.Drawing.Point(10, 10)
$infoLabel.Size = New-Object System.Drawing.Size(560, 600)
$infoLabel.Text = "Usage Guide for Faster Whisper Transcription Tool:" + `
    [System.Environment]::NewLine + [System.Environment]::NewLine + `
    "1. Input File: Select the audio or video file you wish to transcribe or translate." + `
    [System.Environment]::NewLine + `
    "   Supported formats: MP3, WAV, MP4." + `
    [System.Environment]::NewLine + [System.Environment]::NewLine + `
    "2. Device (cpu/cuda): Choose the hardware for processing:" + `
    [System.Environment]::NewLine + `
    "   - 'cpu' for processing on the central processing unit." + `
    [System.Environment]::NewLine + `
    "   - 'cuda' for processing on a CUDA-enabled GPU." + `
    [System.Environment]::NewLine + [System.Environment]::NewLine + `
    "3. Language: Enter the ISO-639-1 language code for the audio." + `
    [System.Environment]::NewLine + `
    "   Example: 'en' for English, 'de' for German." + `
    [System.Environment]::NewLine + [System.Environment]::NewLine + `
    "4. Model: Select the transcription model to use:" + `
    [System.Environment]::NewLine + `
    "   - 'base', 'medium', 'large-v2', or 'xxl' depending on your performance needs." + `
    [System.Environment]::NewLine + [System.Environment]::NewLine + `
    "5. Output Directory: Choose the folder where the transcription or translation output will be saved." + `
    [System.Environment]::NewLine + `
    "   - You can select a custom directory or use the input file's directory by enabling the checkbox." + `
    [System.Environment]::NewLine + [System.Environment]::NewLine + `
    "6. Output Format: Select the desired output format:" + `
    [System.Environment]::NewLine + `
    "   - 'txt': Plain text transcription." + `
    [System.Environment]::NewLine + `
    "   - 'srt': Subtitle format for videos." + `
    [System.Environment]::NewLine + `
    "   - 'vtt': WebVTT subtitle format." + `
    [System.Environment]::NewLine + [System.Environment]::NewLine + `
    "7. Task: Choose whether to transcribe or translate the input file." + `
    [System.Environment]::NewLine + `
    "   - 'transcribe' generates a transcription in the input language." + `
    [System.Environment]::NewLine + `
    "   - 'translate' translates the transcription to English." + `
    [System.Environment]::NewLine + [System.Environment]::NewLine + `
    "8. Parameters:" + `
    [System.Environment]::NewLine + `
    "   - Best Of: Sets the number of candidates when sampling with non-zero temperature." + `
    [System.Environment]::NewLine + `
    "     A higher value improves accuracy but increases processing time." + `
    [System.Environment]::NewLine + `
    "   - Beam Size: Number of beams used during beam search (only relevant if Temperature is 0)." + `
    [System.Environment]::NewLine + `
    "     Higher values improve accuracy but increase resource usage." + `
    [System.Environment]::NewLine + `
    "   - Patience: Optional value to improve beam decoding accuracy (1.0 is default for standard beam search)." + `
    [System.Environment]::NewLine + `
    "   - Temperature: Sampling temperature (higher values generate more creative results)." + `
    [System.Environment]::NewLine + `
    "     Values closer to 0 make results more deterministic." + `
    [System.Environment]::NewLine + [System.Environment]::NewLine + `
    "9. Optional Settings:" + `
    [System.Environment]::NewLine + `
    "   - Play Confirmation Sound: Plays a beep when transcription is complete (enabled by default)." + `
    [System.Environment]::NewLine + `
    "   - Show Progress Bar: Displays a progress bar during transcription instead of showing transcription text." + `
    [System.Environment]::NewLine + [System.Environment]::NewLine + `
    "How to Use:" + `
    [System.Environment]::NewLine + `
    "1. Select the input file you wish to transcribe." + `
    [System.Environment]::NewLine + `
    "2. Configure the settings for device, language, model, output, and format." + `
    [System.Environment]::NewLine + `
    "3. Adjust the advanced parameters (Best Of, Beam Size, Patience, Temperature) as necessary." + `
    [System.Environment]::NewLine + `
    "4. Click 'Start' to begin the transcription or translation process." + `
    [System.Environment]::NewLine + `
    "5. The output will be saved in the specified directory." + `
    [System.Environment]::NewLine + [System.Environment]::NewLine + `
    "Tips:" + `
    [System.Environment]::NewLine + `
    "   - For fast processing, use 'cpu' on systems without a GPU or 'cuda' on systems with CUDA-enabled GPUs." + `
    [System.Environment]::NewLine + `
    "   - Lower beam size and best of values reduce processing time but may decrease accuracy." + `
    [System.Environment]::NewLine + `
    "   - Use a larger model for longer or more complex files." + `
    [System.Environment]::NewLine
$tabInfo.Controls.Add($infoLabel)


### About Tab Content ###

# About Tab with Links and additional text
$aboutLabel = New-Object System.Windows.Forms.Label
$aboutLabel.AutoSize = $true
$aboutLabel.Location = New-Object System.Drawing.Point(10, 10)
$aboutLabel.Text = "Based on:"
$tabAbout.Controls.Add($aboutLabel) | Out-Null  # Suppress the output

$whisperLink = New-Object System.Windows.Forms.LinkLabel
$whisperLink.Text = "https://github.com/Purfview/whisper-standalone-win"
$whisperLink.Location = New-Object System.Drawing.Point(10, 30)
$whisperLink.Size = New-Object System.Drawing.Size(500, 20)
$whisperLink.Links.Add(0, $whisperLink.Text.Length, "https://github.com/Purfview/whisper-standalone-win") | Out-Null  # Suppress output
$whisperLink.add_LinkClicked({
    param($sender, $e)
    Start-Process -FilePath $e.Link.LinkData.ToString()
})
$tabAbout.Controls.Add($whisperLink) | Out-Null  # Suppress the output

$creatorLink = New-Object System.Windows.Forms.LinkLabel
$creatorLink.Text = "Created by: https://github.com/sebastianspicker/"
$creatorLink.Location = New-Object System.Drawing.Point(10, 60)
$creatorLink.Size = New-Object System.Drawing.Size(500, 20)
$creatorLink.Links.Add(12, $creatorLink.Text.Length - 12, "https://github.com/sebastianspicker/") | Out-Null  # Suppress output
$creatorLink.add_LinkClicked({
    param($sender, $e)
    Start-Process -FilePath $e.Link.LinkData.ToString()
})
$tabAbout.Controls.Add($creatorLink) | Out-Null  # Suppress the output

# Additional text for credits
$creditsLabel = New-Object System.Windows.Forms.Label
$creditsLabel.AutoSize = $true
$creditsLabel.Location = New-Object System.Drawing.Point(10, 90)
$creditsLabel.Text = "Sebastian Spicker, HfMT Koeln, 2024"
$tabAbout.Controls.Add($creditsLabel) | Out-Null  # Suppress the output



### Finalizing Tabs ###

# Add the tabs to the TabControl
$tabControl.Controls.Add($tabTranscription)
$tabControl.Controls.Add($tabInfo)
$tabControl.Controls.Add($tabAbout)

# Add the TabControl to the form
$form.Controls.Add($tabControl)

# Show the form and keep it open
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
