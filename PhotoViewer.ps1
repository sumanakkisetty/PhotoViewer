# Photo Viewer Script - PowerShell
# Opens images in a borderless, resizable window
# Press ESC to close, or Ctrl+O to open a new image

# Check if running in a regular console - if so, restart as independent process
param([switch]$Independent)

if (-not $Independent) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Independent" -WindowStyle Hidden
    exit
}

# ===== HARD-CODED FILE PATH =====
# Set your image path here (leave empty to show file dialog)
$hardCodedImagePath = "C:\Users\YourName\Desktop\photo.jpg"
# ================================

# ===== CUSTOM TITLE =====
# Set your custom title here (leave empty to show file name)
$customTitle = "<<<Your Own Name>>>"
# ========================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Photo Viewer"
$form.WindowState = 'Normal'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.FormBorderStyle = 'None'  # Borderless for custom title bar
$form.BackColor = [System.Drawing.Color]::Black
$form.KeyPreview = $true
$form.ShowIcon = $false
$form.ShowInTaskbar = $true  # Show in taskbar

# Prevent window from being minimized - restore immediately
$form.Add_Resize({
    if ($form.WindowState -eq 'Minimized') {
        $form.WindowState = 'Normal'
    }
})

# Add Win32 API to keep window behind others and prevent Windows+D minimize
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WindowHelper {
    [DllImport("user32.dll")]
    public static extern IntPtr SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    
    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    
    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    
    public static readonly IntPtr HWND_BOTTOM = new IntPtr(1);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TOOLWINDOW = 0x00000080;
}
"@

# Create custom black title bar
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Height = 30
$titleBar.Dock = 'Top'
$titleBar.BackColor = [System.Drawing.Color]::Black
$form.Controls.Add($titleBar)

# Title label in the custom title bar
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Photo Viewer"
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.Dock = 'Fill'
$titleLabel.TextAlign = 'MiddleCenter'
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$titleBar.Controls.Add($titleLabel)

# Variables for dragging and resizing
$script:isDragging = $false
$script:isResizing = $false
$script:resizeDirection = ""
$script:dragStart = New-Object System.Drawing.Point(0, 0)
$script:resizeBorderWidth = 5

# Title bar dragging
$titleBar.Add_MouseDown({
    param($sender, $e)
    if ($e.Button -eq 'Left') {
        $script:isDragging = $true
        $script:dragStart = $e.Location
    }
})

$titleBar.Add_MouseMove({
    param($sender, $e)
    if ($script:isDragging) {
        $currentScreenPos = [System.Windows.Forms.Control]::MousePosition
        $newLocation = New-Object System.Drawing.Point(
            ($currentScreenPos.X - $script:dragStart.X),
            ($currentScreenPos.Y - $script:dragStart.Y)
        )
        $form.Location = $newLocation
    }
})

$titleBar.Add_MouseUp({
    param($sender, $e)
    if ($e.Button -eq 'Left') {
        $script:isDragging = $false
    }
})

# Create PictureBox to display the image
$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.Dock = 'Fill'
$pictureBox.SizeMode = 'Zoom'  # Maintain aspect ratio while fitting window
$pictureBox.BackColor = [System.Drawing.Color]::Black
$form.Controls.Add($pictureBox)
$pictureBox.BringToFront()  # Ensure picture is behind title bar

# Zoom variables
$script:zoomFactor = 1.0
$script:originalImage = $null

# Function to center window on screen
function Center-Window {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $x = [int](($screen.Width - $form.Width) / 2)
    $y = [int](($screen.Height - $form.Height) / 2)
    $form.Location = New-Object System.Drawing.Point($x, $y)
}

# Function to apply zoom
function Apply-Zoom {
    if ($script:originalImage) {
        try {
            $newWidth = [int]($script:originalImage.Width * $script:zoomFactor)
            $newHeight = [int]($script:originalImage.Height * $script:zoomFactor)
            
            if ($newWidth -gt 0 -and $newHeight -gt 0) {
                $resizedImage = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
                $graphics = [System.Drawing.Graphics]::FromImage($resizedImage)
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.DrawImage($script:originalImage, 0, 0, $newWidth, $newHeight)
                $graphics.Dispose()
                
                # Dispose previous image if it exists
                if ($pictureBox.Image -and $pictureBox.Image -ne $script:originalImage) {
                    $pictureBox.Image.Dispose()
                }
                
                $pictureBox.Image = $resizedImage
                $pictureBox.SizeMode = 'CenterImage'
            }
        }
        catch {
            Write-Host "Error applying zoom: $_"
        }
    }
}

# Function to load an image
function Load-Image {
    param([string]$imagePath)
    
    if (Test-Path $imagePath) {
        try {
            # Dispose previous images
            if ($pictureBox.Image) {
                $pictureBox.Image.Dispose()
            }
            if ($script:originalImage) {
                $script:originalImage.Dispose()
            }
            
            # Load image from file
            $script:originalImage = [System.Drawing.Image]::FromFile($imagePath)
            $script:zoomFactor = 1.0
            Apply-Zoom
            # Set title based on custom title or filename
            if ($customTitle) {
                $displayTitle = $customTitle
            } else {
                $displayTitle = [System.IO.Path]::GetFileNameWithoutExtension($imagePath)
            }
            $form.Text = $displayTitle
            $titleLabel.Text = $displayTitle
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to load image: $_", "Error", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
    else {
        [System.Windows.Forms.MessageBox]::Show("File not found: $imagePath", "Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Function to open file dialog
function Open-FileDialog {
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "Image Files|*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tiff;*.ico|All Files|*.*"
    $openFileDialog.Title = "Select an Image"
    $openFileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    
    if ($openFileDialog.ShowDialog() -eq 'OK') {
        Load-Image -imagePath $openFileDialog.FileName
    }
}

# Keyboard shortcuts
$form.Add_KeyDown({
    param($sender, $e)
    
    # ESC to close
    if ($e.KeyCode -eq 'Escape') {
        $form.Close()
    }
    
    # Ctrl+O to open new image
    if ($e.Control -and $e.KeyCode -eq 'O') {
        Open-FileDialog
    }
    
    # Ctrl+Q to quit
    if ($e.Control -and $e.KeyCode -eq 'Q') {
        $form.Close()
    }
    
    # Zoom In: Ctrl+Plus or Ctrl+Add (numpad)
    if ($e.Control -and ($e.KeyCode -eq 'Oemplus' -or $e.KeyCode -eq 'Add')) {
        $script:zoomFactor *= 1.2
        Apply-Zoom
        $e.Handled = $true
    }
    
    # Zoom Out: Ctrl+Minus or Ctrl+Subtract (numpad)
    if ($e.Control -and ($e.KeyCode -eq 'OemMinus' -or $e.KeyCode -eq 'Subtract')) {
        $script:zoomFactor /= 1.2
        if ($script:zoomFactor -lt 0.1) { $script:zoomFactor = 0.1 }
        Apply-Zoom
        $e.Handled = $true
    }
    
    # Reset Zoom: Ctrl+0
    if ($e.Control -and $e.KeyCode -eq 'D0') {
        $script:zoomFactor = 1.0
        Apply-Zoom
        $e.Handled = $true
    }
    
    # Fit to Window: Ctrl+F
    if ($e.Control -and $e.KeyCode -eq 'F') {
        $pictureBox.SizeMode = 'Zoom'
        $pictureBox.Image = $script:originalImage
        $e.Handled = $true
    }
    
    # Resize Window: Ctrl+Shift+Arrow keys
    if ($e.Control -and $e.Shift) {
        $currentSize = $form.Size
        $step = 50
        
        switch ($e.KeyCode) {
            'Right' { $form.Width += $step }
            'Left' { if ($form.Width -gt 200) { $form.Width -= $step } }
            'Down' { $form.Height += $step }
            'Up' { if ($form.Height -gt 200) { $form.Height -= $step } }
        }
        Center-Window
        $e.Handled = $true
    }
})

# Form resize with mouse - detect edges
$form.Add_MouseMove({
    param($sender, $e)
    
    $formRect = $form.ClientRectangle
    $borderWidth = $script:resizeBorderWidth
    
    if (-not $script:isResizing) {
        # Determine cursor position relative to edges
        $nearLeft = $e.X -lt $borderWidth
        $nearRight = $e.X -gt ($formRect.Width - $borderWidth)
        $nearTop = $e.Y -lt $borderWidth
        $nearBottom = $e.Y -gt ($formRect.Height - $borderWidth)
        
        # Set cursor based on position
        if ($nearTop -and $nearLeft) {
            $form.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
            $script:resizeDirection = "TopLeft"
        }
        elseif ($nearTop -and $nearRight) {
            $form.Cursor = [System.Windows.Forms.Cursors]::SizeNESW
            $script:resizeDirection = "TopRight"
        }
        elseif ($nearBottom -and $nearLeft) {
            $form.Cursor = [System.Windows.Forms.Cursors]::SizeNESW
            $script:resizeDirection = "BottomLeft"
        }
        elseif ($nearBottom -and $nearRight) {
            $form.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
            $script:resizeDirection = "BottomRight"
        }
        elseif ($nearLeft) {
            $form.Cursor = [System.Windows.Forms.Cursors]::SizeWE
            $script:resizeDirection = "Left"
        }
        elseif ($nearRight) {
            $form.Cursor = [System.Windows.Forms.Cursors]::SizeWE
            $script:resizeDirection = "Right"
        }
        elseif ($nearTop) {
            $form.Cursor = [System.Windows.Forms.Cursors]::SizeNS
            $script:resizeDirection = "Top"
        }
        elseif ($nearBottom) {
            $form.Cursor = [System.Windows.Forms.Cursors]::SizeNS
            $script:resizeDirection = "Bottom"
        }
        else {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            $script:resizeDirection = ""
        }
    }
})

# PictureBox resize with mouse - detect edges (since it covers most of the form)
$pictureBox.Add_MouseMove({
    param($sender, $e)
    
    $borderWidth = $script:resizeBorderWidth
    $pbWidth = $pictureBox.Width
    $pbHeight = $pictureBox.Height
    
    if (-not $script:isResizing) {
        # Determine cursor position relative to edges
        $nearLeft = $e.X -lt $borderWidth
        $nearRight = $e.X -gt ($pbWidth - $borderWidth)
        $nearTop = $e.Y -lt $borderWidth
        $nearBottom = $e.Y -gt ($pbHeight - $borderWidth)
        
        # Set cursor based on position
        if ($nearTop -and $nearLeft) {
            $pictureBox.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
            $script:resizeDirection = "TopLeft"
        }
        elseif ($nearTop -and $nearRight) {
            $pictureBox.Cursor = [System.Windows.Forms.Cursors]::SizeNESW
            $script:resizeDirection = "TopRight"
        }
        elseif ($nearBottom -and $nearLeft) {
            $pictureBox.Cursor = [System.Windows.Forms.Cursors]::SizeNESW
            $script:resizeDirection = "BottomLeft"
        }
        elseif ($nearBottom -and $nearRight) {
            $pictureBox.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
            $script:resizeDirection = "BottomRight"
        }
        elseif ($nearLeft) {
            $pictureBox.Cursor = [System.Windows.Forms.Cursors]::SizeWE
            $script:resizeDirection = "Left"
        }
        elseif ($nearRight) {
            $pictureBox.Cursor = [System.Windows.Forms.Cursors]::SizeWE
            $script:resizeDirection = "Right"
        }
        elseif ($nearTop) {
            $pictureBox.Cursor = [System.Windows.Forms.Cursors]::SizeNS
            $script:resizeDirection = "Top"
        }
        elseif ($nearBottom) {
            $pictureBox.Cursor = [System.Windows.Forms.Cursors]::SizeNS
            $script:resizeDirection = "Bottom"
        }
        else {
            $pictureBox.Cursor = [System.Windows.Forms.Cursors]::Default
            $script:resizeDirection = ""
        }
    }
})

$pictureBox.Add_MouseDown({
    param($sender, $e)
    if ($e.Button -eq 'Left' -and $script:resizeDirection -ne "") {
        $script:isResizing = $true
        $script:dragStart = [System.Windows.Forms.Control]::MousePosition
    }
})

$pictureBox.Add_MouseUp({
    param($sender, $e)
    if ($e.Button -eq 'Left') {
        $script:isResizing = $false
    }
})

$pictureBox.Add_MouseLeave({
    if (-not $script:isResizing) {
        $pictureBox.Cursor = [System.Windows.Forms.Cursors]::Default
    }
})

$form.Add_MouseDown({
    param($sender, $e)
    if ($e.Button -eq 'Left' -and $script:resizeDirection -ne "") {
        $script:isResizing = $true
        $script:dragStart = [System.Windows.Forms.Control]::MousePosition
    }
})

$form.Add_MouseUp({
    param($sender, $e)
    if ($e.Button -eq 'Left') {
        $script:isResizing = $false
    }
})

$form.Add_MouseLeave({
    if (-not $script:isResizing) {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
})

# Global mouse move for resizing
$script:resizeTimer = New-Object System.Windows.Forms.Timer
$script:resizeTimer.Interval = 1
$script:resizeTimer.Add_Tick({
    try {
        if ($script:isResizing -and -not $form.IsDisposed) {
            $currentPos = [System.Windows.Forms.Control]::MousePosition
            $deltaX = $currentPos.X - $script:dragStart.X
            $deltaY = $currentPos.Y - $script:dragStart.Y
            
            $newLocation = $form.Location
            $newSize = $form.Size
            
            switch ($script:resizeDirection) {
                "Right" {
                    $newSize.Width = [Math]::Max(200, $form.Width + $deltaX)
                }
                "Left" {
                    $newWidth = [Math]::Max(200, $form.Width - $deltaX)
                    if ($newWidth -ge 200) {
                        $newLocation.X = $form.Location.X + $deltaX
                        $newSize.Width = $newWidth
                    }
                }
                "Bottom" {
                    $newSize.Height = [Math]::Max(200, $form.Height + $deltaY)
                }
                "Top" {
                    $newHeight = [Math]::Max(200, $form.Height - $deltaY)
                    if ($newHeight -ge 200) {
                        $newLocation.Y = $form.Location.Y + $deltaY
                        $newSize.Height = $newHeight
                    }
                }
                "BottomRight" {
                    $newSize.Width = [Math]::Max(200, $form.Width + $deltaX)
                    $newSize.Height = [Math]::Max(200, $form.Height + $deltaY)
                }
                "BottomLeft" {
                    $newWidth = [Math]::Max(200, $form.Width - $deltaX)
                    if ($newWidth -ge 200) {
                        $newLocation.X = $form.Location.X + $deltaX
                        $newSize.Width = $newWidth
                    }
                    $newSize.Height = [Math]::Max(200, $form.Height + $deltaY)
                }
                "TopRight" {
                    $newSize.Width = [Math]::Max(200, $form.Width + $deltaX)
                    $newHeight = [Math]::Max(200, $form.Height - $deltaY)
                    if ($newHeight -ge 200) {
                        $newLocation.Y = $form.Location.Y + $deltaY
                        $newSize.Height = $newHeight
                    }
                }
                "TopLeft" {
                    $newWidth = [Math]::Max(200, $form.Width - $deltaX)
                    if ($newWidth -ge 200) {
                        $newLocation.X = $form.Location.X + $deltaX
                        $newSize.Width = $newWidth
                    }
                    $newHeight = [Math]::Max(200, $form.Height - $deltaY)
                    if ($newHeight -ge 200) {
                        $newLocation.Y = $form.Location.Y + $deltaY
                        $newSize.Height = $newHeight
                    }
                }
            }
            
            $form.Location = $newLocation
            $form.Size = $newSize
            $script:dragStart = $currentPos
            Center-Window
        }
    }
    catch {
        # Silently ignore errors during form disposal
    }
})
$script:resizeTimer.Start()

# Old dragging code removed (now handled by title bar)

# Mouse wheel zoom
$form.Add_MouseWheel({
    param($sender, $e)
    if ([System.Windows.Forms.Control]::ModifierKeys -eq 'Control') {
        if ($e.Delta -gt 0) {
            # Zoom in
            $script:zoomFactor *= 1.1
        }
        else {
            # Zoom out
            $script:zoomFactor /= 1.1
            if ($script:zoomFactor -lt 0.1) { $script:zoomFactor = 0.1 }
        }
        Apply-Zoom
    }
})

# Dispose of image when form closes to prevent memory leaks
$form.Add_FormClosing({
    if ($script:resizeTimer) {
        $script:resizeTimer.Stop()
        $script:resizeTimer.Dispose()
    }
    if ($pictureBox.Image) {
        $pictureBox.Image.Dispose()
    }
    if ($script:originalImage) {
        $script:originalImage.Dispose()
    }
})

# Check if an image path was provided as parameter
if ($args.Count -gt 0) {
    $imagePath = $args[0]
    Load-Image -imagePath $imagePath
}
elseif ($hardCodedImagePath -and (Test-Path $hardCodedImagePath)) {
    # Use hard-coded path if set and file exists
    Load-Image -imagePath $hardCodedImagePath
}
else {
    # If no parameter and no hard-coded path, open file dialog
    Open-FileDialog
}

# Function to keep window at bottom of Z-order
function Set-WindowBottom {
    [WindowHelper]::SetWindowPos(
        $form.Handle, 
        [WindowHelper]::HWND_BOTTOM, 
        0, 0, 0, 0,
        [WindowHelper]::SWP_NOMOVE -bor [WindowHelper]::SWP_NOSIZE -bor [WindowHelper]::SWP_NOACTIVATE
    )
}

# Set window to bottom when shown
$form.Add_Shown({
    Center-Window
    Set-WindowBottom
})

# Show the form
[void]$form.ShowDialog()

# Clean up
$form.Dispose()
