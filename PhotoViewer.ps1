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
$customTitle = "<<<  Your Own Name  >>>"
# ========================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Background transparency/lightness control variable for glass effect
$script:glassLightness = 255  # Default lightness (100-255, where 255 is white/lightest)

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Photo Viewer"
$form.WindowState = 'Normal'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.FormBorderStyle = 'None'  # Borderless for custom title bar
$form.BackColor = [System.Drawing.Color]::Magenta  # Magenta becomes transparent
$form.TransparencyKey = [System.Drawing.Color]::Magenta  # Make magenta fully transparent for glass effect
$form.KeyPreview = $true
$form.ShowIcon = $false
$form.ShowInTaskbar = $true  # Show in taskbar

# Prevent window from being minimized - restore immediately
$form.Add_Resize({
    if ($form.WindowState -eq 'Minimized') {
        $form.WindowState = 'Normal'
    }
})

# Add Win32 API to keep window behind others and enable blur effect
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
    
    [DllImport("dwmapi.dll")]
    public static extern int DwmEnableBlurBehindWindow(IntPtr hWnd, ref DWM_BLURBEHIND pBlurBehind);
    
    [DllImport("dwmapi.dll")]
    public static extern int DwmExtendFrameIntoClientArea(IntPtr hWnd, ref MARGINS pMargins);
    
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
    
    public static readonly IntPtr HWND_BOTTOM = new IntPtr(1);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TOOLWINDOW = 0x00000080;
    public const int WS_EX_LAYERED = 0x80000;
    public const int DWMWA_SYSTEMBACKDROP_TYPE = 38;
    public const int DWMSBT_AUTO = 0;
    public const int DWMSBT_NONE = 1;
    public const int DWMSBT_MAINWINDOW = 2;
    public const int DWMSBT_TRANSIENTWINDOW = 3;
    public const int DWMSBT_TABBEDWINDOW = 4;
    
    [StructLayout(LayoutKind.Sequential)]
    public struct DWM_BLURBEHIND {
        public int dwFlags;
        public bool fEnable;
        public IntPtr hRgnBlur;
        public bool fTransitionOnMaximized;
    }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct MARGINS {
        public int Left;
        public int Right;
        public int Top;
        public int Bottom;
    }
    
    public const int DWM_BB_ENABLE = 0x1;
    public const int DWM_BB_BLURREGION = 0x2;
}
"@

# Create background panel (this is what shows as "glass" in borders)
$backgroundPanel = New-Object System.Windows.Forms.Panel
$backgroundPanel.Dock = 'Fill'
$backgroundPanel.BackColor = [System.Drawing.Color]::FromArgb($script:glassLightness, $script:glassLightness, $script:glassLightness)  # Adjustable gray for glass

$form.Controls.Add($backgroundPanel)

# Create custom title bar at bottom
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Height = 40
$titleBar.Dock = 'Bottom'
$titleBar.BackColor = [System.Drawing.Color]::FromArgb($script:glassLightness, $script:glassLightness, $script:glassLightness)  # User-controllable glass

$backgroundPanel.Controls.Add($titleBar)

# Title label in the custom title bar
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Photo Viewer"
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 40, 40, 50)  # Dark text for contrast on light glass
$titleLabel.BackColor = [System.Drawing.Color]::Transparent
$titleLabel.AutoSize = $true
$titleLabel.TextAlign = 'MiddleCenter'
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$titleLabel.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)
$titleBar.Controls.Add($titleLabel)

# Center the title label in the title bar
$titleBar.Add_Resize({
    $titleLabel.Location = New-Object System.Drawing.Point(
        [int](($titleBar.Width - $titleLabel.Width) / 2),
        [int](($titleBar.Height - $titleLabel.Height) / 2)
    )
})

# Variables for resizing only (no dragging)
$script:isResizing = $false
$script:resizeDirection = ""
$script:dragStart = New-Object System.Drawing.Point(0, 0)
$script:resizeBorderWidth = 5

# Create PictureBox to display the image
# Magenta background makes empty areas transparent, showing backgroundPanel
$imageContainer = New-Object System.Windows.Forms.Panel
$imageContainer.Dock = 'Fill'
$imageContainer.BackColor = [System.Drawing.Color]::Magenta  # Transparent areas show background

$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.Dock = 'Fill'
$pictureBox.SizeMode = 'Zoom'  # Maintain aspect ratio while fitting window
$pictureBox.BackColor = [System.Drawing.Color]::Magenta  # Transparent where no image
$imageContainer.Controls.Add($pictureBox)

$backgroundPanel.Controls.Add($imageContainer)

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
            # Recenter the title label after text change
            $titleLabel.Location = New-Object System.Drawing.Point(
                [int](($titleBar.Width - $titleLabel.Width) / 2),
                [int](($titleBar.Height - $titleLabel.Height) / 2)
            )
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

# Function to update background transparency
function Update-BackgroundTransparency {
    # Update background panel color for glass tint control
    $backgroundPanel.BackColor = [System.Drawing.Color]::FromArgb($script:glassLightness, $script:glassLightness, $script:glassLightness)
    # Update title bar to match glassLightness
    $titleBar.BackColor = [System.Drawing.Color]::FromArgb($script:glassLightness, $script:glassLightness, $script:glassLightness)
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
        Apply-RoundedCorners -radius 20  # Reapply rounded corners after resize
        $e.Handled = $true
    }
    
    # Increase Transparency: Ctrl+Up Arrow (lighter glass, more see-through)
    if ($e.Control -and $e.KeyCode -eq 'Up' -and -not $e.Shift) {
        $script:glassLightness = [Math]::Max(100, $script:glassLightness - 10)
        Update-BackgroundTransparency
        $e.Handled = $true
    }
    
    # Decrease Transparency: Ctrl+Down Arrow (darker glass, more tinted)
    if ($e.Control -and $e.KeyCode -eq 'Down' -and -not $e.Shift) {
        $script:glassLightness = [Math]::Min(255, $script:glassLightness + 10)
        Update-BackgroundTransparency
        $e.Handled = $true
    }
    
    # Reset Transparency: Ctrl+R
    if ($e.Control -and $e.KeyCode -eq 'R') {
        $script:glassLightness = 255
        Update-BackgroundTransparency
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

# BackgroundPanel resize with mouse
$backgroundPanel.Add_MouseMove({
    param($sender, $e)
    
    $borderWidth = $script:resizeBorderWidth
    $panelWidth = $backgroundPanel.Width
    $panelHeight = $backgroundPanel.Height
    
    if (-not $script:isResizing) {
        $nearLeft = $e.X -lt $borderWidth
        $nearRight = $e.X -gt ($panelWidth - $borderWidth)
        $nearTop = $e.Y -lt $borderWidth
        $nearBottom = $e.Y -gt ($panelHeight - $borderWidth)
        
        if ($nearTop -and $nearLeft) {
            $backgroundPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
            $script:resizeDirection = "TopLeft"
        }
        elseif ($nearTop -and $nearRight) {
            $backgroundPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNESW
            $script:resizeDirection = "TopRight"
        }
        elseif ($nearBottom -and $nearLeft) {
            $backgroundPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNESW
            $script:resizeDirection = "BottomLeft"
        }
        elseif ($nearBottom -and $nearRight) {
            $backgroundPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
            $script:resizeDirection = "BottomRight"
        }
        elseif ($nearLeft) {
            $backgroundPanel.Cursor = [System.Windows.Forms.Cursors]::SizeWE
            $script:resizeDirection = "Left"
        }
        elseif ($nearRight) {
            $backgroundPanel.Cursor = [System.Windows.Forms.Cursors]::SizeWE
            $script:resizeDirection = "Right"
        }
        elseif ($nearTop) {
            $backgroundPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNS
            $script:resizeDirection = "Top"
        }
        elseif ($nearBottom) {
            $backgroundPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNS
            $script:resizeDirection = "Bottom"
        }
        else {
            $backgroundPanel.Cursor = [System.Windows.Forms.Cursors]::Default
            $script:resizeDirection = ""
        }
    }
})

$backgroundPanel.Add_MouseDown({
    param($sender, $e)
    if ($e.Button -eq 'Left' -and $script:resizeDirection -ne "") {
        $script:isResizing = $true
        $script:dragStart = [System.Windows.Forms.Control]::MousePosition
    }
})

$backgroundPanel.Add_MouseUp({
    param($sender, $e)
    if ($e.Button -eq 'Left') {
        $script:isResizing = $false
    }
})

$backgroundPanel.Add_MouseLeave({
    if (-not $script:isResizing) {
        $backgroundPanel.Cursor = [System.Windows.Forms.Cursors]::Default
    }
})

# TitleBar resize with mouse
$titleBar.Add_MouseMove({
    param($sender, $e)
    
    $borderWidth = $script:resizeBorderWidth
    $barWidth = $titleBar.Width
    $barHeight = $titleBar.Height
    
    if (-not $script:isResizing) {
        $nearLeft = $e.X -lt $borderWidth
        $nearRight = $e.X -gt ($barWidth - $borderWidth)
        $nearBottom = $e.Y -gt ($barHeight - $borderWidth)
        
        if ($nearBottom -and $nearLeft) {
            $titleBar.Cursor = [System.Windows.Forms.Cursors]::SizeNESW
            $script:resizeDirection = "BottomLeft"
        }
        elseif ($nearBottom -and $nearRight) {
            $titleBar.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
            $script:resizeDirection = "BottomRight"
        }
        elseif ($nearLeft) {
            $titleBar.Cursor = [System.Windows.Forms.Cursors]::SizeWE
            $script:resizeDirection = "Left"
        }
        elseif ($nearRight) {
            $titleBar.Cursor = [System.Windows.Forms.Cursors]::SizeWE
            $script:resizeDirection = "Right"
        }
        elseif ($nearBottom) {
            $titleBar.Cursor = [System.Windows.Forms.Cursors]::SizeNS
            $script:resizeDirection = "Bottom"
        }
        else {
            $titleBar.Cursor = [System.Windows.Forms.Cursors]::Default
            $script:resizeDirection = ""
        }
    }
})

$titleBar.Add_MouseDown({
    param($sender, $e)
    if ($e.Button -eq 'Left' -and $script:resizeDirection -ne "") {
        $script:isResizing = $true
        $script:dragStart = [System.Windows.Forms.Control]::MousePosition
    }
})

$titleBar.Add_MouseUp({
    param($sender, $e)
    if ($e.Button -eq 'Left') {
        $script:isResizing = $false
    }
})

$titleBar.Add_MouseLeave({
    if (-not $script:isResizing) {
        $titleBar.Cursor = [System.Windows.Forms.Cursors]::Default
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
            Apply-RoundedCorners -radius 20  # Reapply rounded corners after resize
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

# Function to enable glass blur effect
function Enable-BlurBehind {
    try {
        $blurBehind = New-Object WindowHelper+DWM_BLURBEHIND
        $blurBehind.dwFlags = [WindowHelper]::DWM_BB_ENABLE
        $blurBehind.fEnable = $true
        $blurBehind.hRgnBlur = [IntPtr]::Zero
        $blurBehind.fTransitionOnMaximized = $false
        
        [WindowHelper]::DwmEnableBlurBehindWindow($form.Handle, [ref]$blurBehind)
        
        # Extend glass frame into client area for better blur effect
        $margins = New-Object WindowHelper+MARGINS
        $margins.Left = -1
        $margins.Right = -1
        $margins.Top = -1
        $margins.Bottom = -1
        [WindowHelper]::DwmExtendFrameIntoClientArea($form.Handle, [ref]$margins)
    }
    catch {
        # Blur not available, continue without it
    }
}

# Function to apply rounded corners
function Apply-RoundedCorners {
    param([int]$radius = 20)
    
    try {
        $rect = New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        
        # Create rounded rectangle path
        $path.AddArc($rect.X, $rect.Y, $radius, $radius, 180, 90)
        $path.AddArc($rect.Right - $radius, $rect.Y, $radius, $radius, 270, 90)
        $path.AddArc($rect.Right - $radius, $rect.Bottom - $radius, $radius, $radius, 0, 90)
        $path.AddArc($rect.X, $rect.Bottom - $radius, $radius, $radius, 90, 90)
        $path.CloseFigure()
        
        $form.Region = New-Object System.Drawing.Region($path)
        $path.Dispose()
    }
    catch {
        # Rounded corners not available, continue without them
    }
}

# Set window to bottom when shown
$form.Add_Shown({
    Center-Window
    Enable-BlurBehind
    Apply-RoundedCorners -radius 20
    Set-WindowBottom
})

# Show the form
[void]$form.ShowDialog()

# Clean up
$form.Dispose()
