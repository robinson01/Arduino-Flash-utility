# PowerShell Flash Memory Utility Script with GUI

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$global:IsGUI = $true

# Import the function definitions from the util script
. "$PSScriptRoot\util.ps1"

# Reset the flag after the GUI script runs
$global:IsGUI = $false

$form = New-Object Windows.Forms.Form
$form.Text = "SPI Flash Utility"
$form.Size = New-Object Drawing.Size(550, 400)
$form.StartPosition = "CenterScreen"

$portLabel = New-Object Windows.Forms.Label
$portLabel.Text = "COM Port:"
$portLabel.Location = New-Object Drawing.Point(20, 20)
$form.Controls.Add($portLabel)

$portBox = New-Object Windows.Forms.TextBox
$portBox.Text = "COM2"
$portBox.Location = New-Object Drawing.Point(150, 18)
$form.Controls.Add($portBox)

$baudLabel = New-Object Windows.Forms.Label
$baudLabel.Text = "Baud Rate:"
$baudLabel.Location = New-Object Drawing.Point(20, 60)
$form.Controls.Add($baudLabel)

$baudBox = New-Object Windows.Forms.TextBox
$baudBox.Text = "57600"
$baudBox.Location = New-Object Drawing.Point(150, 58)
$form.Controls.Add($baudBox)

$modeLabel = New-Object Windows.Forms.Label
$modeLabel.Text = "Mode:"
$modeLabel.Location = New-Object Drawing.Point(20, 100)
$form.Controls.Add($modeLabel)

$readRadio = New-Object Windows.Forms.RadioButton
$readRadio.Text = "Read"
$readRadio.Location = New-Object Drawing.Point(150, 100)
$readRadio.Checked = $true
$form.Controls.Add($readRadio)

$writeRadio = New-Object Windows.Forms.RadioButton
$writeRadio.Text = "Write"
$writeRadio.Location = New-Object Drawing.Point(300, 100)
$form.Controls.Add($writeRadio)

$outputLabel = New-Object Windows.Forms.Label
$outputLabel.Text = "Output File:"
$outputLabel.Location = New-Object Drawing.Point(20, 140)
$form.Controls.Add($outputLabel)

$outputBox = New-Object Windows.Forms.TextBox
$outputBox.Location = New-Object Drawing.Point(150, 138)
$outputBox.Size = New-Object Drawing.Size(350, 20)
$form.Controls.Add($outputBox)

$bytesLabel = New-Object Windows.Forms.Label
$bytesLabel.Text = "Bytes to Read:"
$bytesLabel.Location = New-Object Drawing.Point(20, 180)
$form.Controls.Add($bytesLabel)

$bytesBox = New-Object Windows.Forms.TextBox
$bytesBox.Location = New-Object Drawing.Point(150, 178)
$bytesBox.Size = New-Object Drawing.Size(350, 20)
$form.Controls.Add($bytesBox)

$inputLabel = New-Object Windows.Forms.Label
$inputLabel.Text = "Input File:"
$inputLabel.Location = New-Object Drawing.Point(20, 220)
$form.Controls.Add($inputLabel)

$inputBox = New-Object Windows.Forms.TextBox
$inputBox.Location = New-Object Drawing.Point(150, 218)
$inputBox.Size = New-Object Drawing.Size(350, 20)
$form.Controls.Add($inputBox)

$startButton = New-Object Windows.Forms.Button
$startButton.Text = "Start"
$startButton.Location = New-Object Drawing.Point(100, 260)
$startButton.Add_Click({
    if ($readRadio.Checked) {
        $bytesToRead = [int]::Parse($bytesBox.Text)
        Read-Flash -PortName $portBox.Text -outputFile $outputBox.Text -BaudRate ([int]::Parse($baudBox.Text)) -totalBytesToRead $bytesToRead
    }
    elseif ($writeRadio.Checked) {
        Write-Flash -PortName $portBox.Text -BaudRate ([int]::Parse($baudBox.Text)) -inputFile $inputBox.Text
    }
})
$form.Controls.Add($startButton)

$quitButton = New-Object Windows.Forms.Button
$quitButton.Text = "Quit"
$quitButton.Location = New-Object Drawing.Point(200, 260)
$quitButton.Add_Click({ $form.Close() })
$form.Controls.Add($quitButton)

$progressBar = New-Object Windows.Forms.ProgressBar
$progressBar.Location = New-Object Drawing.Point(20, 300)
$progressBar.Size = New-Object Drawing.Size(490, 20)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$form.Controls.Add($progressBar)

$readRadio.Add_CheckedChanged({
    $outputBox.Enabled = $readRadio.Checked
    $inputBox.Enabled = !$readRadio.Checked
    $bytesBox.Enabled = $readRadio.Checked
})
$writeRadio.Add_CheckedChanged({
    $outputBox.Enabled = !$writeRadio.Checked
    $inputBox.Enabled = $writeRadio.Checked
    $bytesBox.Enabled = !$writeRadio.Checked
})

# Initialize fields
$outputBox.Enabled = $true
$inputBox.Enabled = $false
$bytesBox.Enabled = $true

$form.ShowDialog()


# Set default values (if not set dynamically)
$COM_PORT = "COM2"
$BAUD_RATE = 57600
$chunkSize = 64