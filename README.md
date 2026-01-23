# Photo Viewer - PowerShell Desktop Widget

A lightweight PowerShell-based photo viewer for Windows that displays images as a desktop widget - always visible, stays behind windows, and survives Windows+D. Perfect for keeping your favorite photos or reminders always in view.

## ✨ Features

- 🖼️ **Always Visible** - Stays on desktop even when pressing Windows+D
- 🎨 **Borderless Window** - Clean, minimalist design with custom black title bar
- 📌 **Background Layer** - Stays behind all other windows automatically
- 🔒 **Independent Process** - Runs separately, closing PowerShell won't affect it
- 📏 **Fully Resizable** - Drag edges/corners with mouse or use keyboard shortcuts
- 🔍 **Zoom Support** - Ctrl+Mouse Wheel or Ctrl+Plus/Minus to zoom
- 🎯 **Auto-Center** - Automatically centers when resized
- ⌨️ **Keyboard Shortcuts** - Full keyboard control
- 📋 **Taskbar Integration** - Shows in taskbar with custom title
- 🔐 **No Admin Required** - Runs with standard user permissions
- 🎨 **Custom Title** - Set your own window title
- 💾 **Hard-coded Path** - Configure default image path

## 🚀 Quick Start

### Method 1: Double-click the BAT file (Easiest)
```
PhotoViewer.bat
```

### Method 2: Run from Command (Win+R)
```
C:\SMS\Photo_Viewer\PhotoViewer.bat
```

### Method 3: PowerShell
```powershell
.\PhotoViewer.ps1
```

### Method 4: Add to Windows PATH
Add `C:\SMS\Photo_Viewer` to your PATH environment variable, then run from anywhere:
```
PhotoViewer.bat
```

## ⚙️ Configuration

Edit the script to customize:

```powershell
# Set your default image path
$hardCodedImagePath = "C:\Users\YourName\Desktop\photo.jpg"

# Set custom window title (leave empty to show filename)
$customTitle = "My Custom Title"
```

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **ESC** | Close the viewer |
| **Ctrl+Q** | Close the viewer |
| **Ctrl+O** | Open a new image |
| **Ctrl + Mouse Wheel** | Zoom in/out |
| **Ctrl + Plus (+)** | Zoom in |
| **Ctrl + Minus (-)** | Zoom out |
| **Ctrl + 0** | Reset zoom to 100% |
| **Ctrl + F** | Fit to window |
| **Ctrl + Shift + Arrow Keys** | Resize window |

## 🖱️ Mouse Controls

- **Drag title bar** - Move window
- **Drag edges/corners** - Resize window
- **Ctrl + Mouse Wheel** - Zoom in/out

## 📋 Window Behavior

- ✅ Shows in taskbar with custom title
- ✅ Stays behind all other windows
- ✅ Survives Windows+D (auto-restores if minimized)
- ✅ Auto-centers on resize
- ✅ Runs as independent process
- ✅ Only closeable via ESC or Ctrl+Q (no X button)

## 🖼️ Supported Image Formats

- JPEG (.jpg, .jpeg)
- PNG (.png)
- Bitmap (.bmp)
- GIF (.gif)
- TIFF (.tiff, .tif)
- Icon (.ico)

## 🔧 Troubleshooting

### Execution Policy Error
The BAT file automatically bypasses execution policy. If you still have issues:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Image Not Loading
- Verify the file path is correct
- Check that the image format is supported
- Ensure you have read permissions for the file

### Window Not Staying Visible
The window automatically restores if Windows+D is pressed. If it minimizes, it will immediately restore itself.

## 💻 System Requirements

- Windows 7, 8, 10, or 11
- PowerShell 5.1 or higher (built into Windows)
- .NET Framework 4.5+ (built into Windows)
- **No admin rights required**
- **No additional software installation needed**

## 🎯 Use Cases

- Display motivational images or quotes on your desktop
- Keep important reminders visible
- Show family photos while working
- Desktop widgets/decorations
- Always-visible reference images
- Company logos or branding on kiosk displays

## 📝 Notes

- The script uses Windows Forms, which is built into Windows
- Runs as a completely independent process
- PowerShell console is automatically hidden
- Window position is auto-centered on launch and resize
- No temporary files created
- Memory efficient with proper image disposal

## 🤝 Contributing

Feel free to fork this repository and submit pull requests for any improvements!

## 📄 License

This project is open source and available under the MIT License.

## 🙏 Acknowledgments

Built with PowerShell and Windows Forms for a clean, native Windows experience.
