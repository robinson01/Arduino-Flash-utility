# PowerShell Flash Memory Utility Script

function Show-ProgressBar {
    param (
        [int]$Progress
    )
    $done = [int]($Progress / 2)
    $pending = 50 - $done
    $bar = ';' * $done + '.' * $pending
    Write-Host ("`r[$bar] $Progress%") -NoNewline
}

function Log-Serial {
    param (
        [string]$Text
    )
    Add-Content -Path "log.txt" -Value $Text
}

function Read-Flash {
    param (
        [string]$PortName,
		[string]$outputFile,
        [int]$BaudRate,
		[int]$totalBytesToRead
    )
    $readSize = [int]$totalBytesToRead
	$outputFile =[string]$outputFile

    $port = New-Object System.IO.Ports.SerialPort $PortName, $BaudRate, None, 8, one
    $port.Open()
    
	# Send command
    $command = "d$totalBytesToRead`n"
    $bytesToSend = [System.Text.Encoding]::ASCII.GetBytes($command)
    $port.Write($bytesToSend, 0, $bytesToSend.Length)

    Start-Sleep -Milliseconds 100

    # Setup for receiving data
    $responseStream = New-Object System.IO.MemoryStream
    $buffer = New-Object byte[] $chunkSize
    $bytesReadTotal = 0

    # Setup progress bar
    $progressLength = 50
    $lastDisplayed = -1

    Write-Host "`nReading data:"
    while ($bytesReadTotal -lt $totalBytesToRead) {
        $remaining = $totalBytesToRead - $bytesReadTotal
        $readSize = [Math]::Min($chunkSize, $remaining)
        $tempBuffer = New-Object byte[] $readSize
        $readNow = $port.Read($tempBuffer, 0, $readSize)
        if ($readNow -gt 0) {
            $responseStream.Write($tempBuffer, 0, $readNow)
            $bytesReadTotal += $readNow

            # Update progress
            $progress = [Math]::Floor(($bytesReadTotal / $totalBytesToRead) * $progressLength)
            if ($progress -ne $lastDisplayed) {
                $bar = ";" * $progress + "." * ($progressLength - $progress)
                $percent = [Math]::Round(($bytesReadTotal / $totalBytesToRead) * 100)
                Write-Host -NoNewline "`r[$bar] $percent%"
                $lastDisplayed = $progress
            }
        }
    }
    Write-Host "`nDone reading."

    $port.Close()

    # Write data to file
    $responseStream.Seek(0, 'Begin') | Out-Null
    [System.IO.File]::WriteAllBytes($outputFile, $responseStream.ToArray())

    # Display file info
    $fileSize = (Get-Item $outputFile).Length
    Write-Host "Saved to $outputFile ($fileSize bytes)"
}

function Write-Flash {
    param (
        [string]$PortName,
        [int]$BaudRate
    )

    while ($true) {
        $fileName = Read-Host "Enter the filename to write"
        if (Test-Path $fileName) {
            break
        } else {
            Write-Host "File not found. Please enter a valid filename."
        }
    }

    $fileBytes = [System.IO.File]::ReadAllBytes($fileName)
    $serialPort = New-Object System.IO.Ports.SerialPort $PortName, $BaudRate, None, 8, one
    $serialPort.Open()
    
    $responseBuffer = ""
    Write-Host "Disabling write protection..."
    $serialPort.Write("pN`n")
    Log-Serial "TX: pN"
    Start-Sleep -Milliseconds 500
    while ($serialPort.BytesToRead -gt 0) {
        $char = [char]$serialPort.ReadByte()
        $responseBuffer += $char
    }
    
    Write-Host $responseBuffer
    Log-Serial -Text ("RX: " + $responseBuffer)
    
    Write-Host "Erasing chip..."
    $serialPort.Write("e255`n")
    Log-Serial "TX: e255"

    $responseBuffer = ""
    $eraseStart = Get-Date
    $chipErased = $false

    while (-not $chipErased) {
        Start-Sleep -Milliseconds 200
        while ($serialPort.BytesToRead -gt 0) {
            $char = [char]$serialPort.ReadByte()
            $responseBuffer += $char

            if ($responseBuffer -match "chip erased") {
                Write-Host $responseBuffer
                Log-Serial -Text ("RX: " + $responseBuffer)
                $chipErased = $true
                break
            }
        }

        if (((Get-Date) - $eraseStart).TotalSeconds -gt 60) {
            Write-Host "Timeout waiting for 'chip erased' confirmation."
            $serialPort.Close()
            return
        }
    }
    Write-Host "Erase complete. Starting upload..."

    $chunkSize = 32
    $writeCommandPrefix = [System.Text.Encoding]::ASCII.GetBytes("w")[0]
    $totalChunks = [math]::Ceiling($fileBytes.Length / $chunkSize)

    for ($i = 0; $i -lt $totalChunks; $i++) {
        $offset = $i * $chunkSize
        $length = [math]::Min($chunkSize, $fileBytes.Length - $offset)

        $buffer = New-Object byte[] (1 + $length)
        $buffer[0] = $writeCommandPrefix
        [Array]::Copy($fileBytes, $offset, $buffer, 1, $length)

        try {
            $serialPort.Write($buffer, 0, $buffer.Length)
            $txData = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $buffer.Length)
            #Log-Serial "TX: $txData"
        } catch {
            Write-Host "Write failed at chunk $i"
        }

    $ackd = 0
    while ($ackd -eq 0) {
        while ($serialPort.BytesToRead -gt 0) {
            $char = [char]$serialPort.ReadByte()
            Log-Serial -Text "RX: $char"
            if ($char -eq 'k') { $ackd = 1 }
        }
        Start-Sleep -Milliseconds 10
    }


        $progress = [int](($i + 1) / $totalChunks * 100)
        Show-ProgressBar -Progress $progress
    }
	
	$serialPort.Close()
	
    Write-Host "`nUpload complete. Verifying..."

	Read-Flash -PortName $COM_PORT -outputFile "temp.bin" -BaudRate $BAUD_RATE -totalBytesToRead $fileBytes.Length
	
    $readBack = [System.IO.File]::ReadAllBytes("temp.bin")

    if ($readBack.Length -ne $fileBytes.Length) {
        Write-Host "Verification failed: Length mismatch."
    } elseif (-not ([System.Linq.Enumerable]::SequenceEqual([byte[]]$fileBytes, [byte[]]$readBack))) {
        Write-Host "Verification failed: Data mismatch."
    } else {
        Write-Host "Write verified successfully."
    }
}

# Main Menu

Write-Host "`n################################################################"
Write-Host "################   Arduino SPIFlash util v0.1   ################"
Write-Host "################################################################`n"

$COM_PORT = "COM2"
$BAUD_RATE = 57600
$chunkSize = 64

do {
	do {
		Write-Host "`ncurrently selected port $COM_PORT and baud $BAUD_RATE"
		$portOk = Read-Host "Is this ok? (Y/N)"
		switch ($portOk.ToUpper()){
			"Y"{}
			"N"{
				$COM_PORT = Read-Host "`nport"
				$BAUD_RATE = Read-Host "baud"
			}
			default{
			}
		}
	} while ($portOk.ToUpper() -ne "Y")
	
    $action = Read-Host "`nEnter operation: (R)ead or (W)rite or (C)hange port or (Q)uit"
	$continue = 'Y'
    switch ($action.ToUpper()) {
        "R" {
			# Ask for data size and file name
			[int]$totalBytesToRead = Read-Host "Enter number of bytes to read from flash"
			[string]$outputFile = Read-Host "Enter the name of the output file"
			
			# Perform the read and save
			Read-Flash -PortName $COM_PORT -outputFile $outputFile -BaudRate $BAUD_RATE -totalBytesToRead $totalBytesToRead
		}
		"C" {$portOk = "N"}
        "W" { Write-Flash -PortName $COM_PORT -BaudRate $BAUD_RATE }
        "Q" { 
			$continue = 'N'
			Write-Host "Exiting the script. Goodbye!"
		}
        default { Write-Host "Invalid option. Please enter R, W, or Q." }
    }
	
	Write-Host "`n#################################################################"
}while ($continue.ToUpper() -eq 'Y')
