<#
.SYNOPSIS
    Prints sample lines in each standard PowerShell console foreground color for quick visual reference.

.DESCRIPTION
    Clears the console and writes one line per color (Black through Yellow) using -ForegroundColor so users can preview how each color renders in their terminal theme.

.NOTES
- Created 2024.09.17 by Joe McLain (joe@bvu.edu)
- Last modified 2024.09.17 at 1005 by Joe McLain (joe@bvu.edu)
#>

Clear-Host
Write-Host
Write-Host "Displaying all possible color options..."
Write-Host

Write-Host "The color of this font is Black. How do you like it?" -ForegroundColor Black
Write-Host "The color of this font is Blue. How do you like it?" -ForegroundColor Blue
Write-Host "The color of this font is Cyan. How do you like it?" -ForegroundColor Cyan
Write-Host "The color of this font is DarkBlue. How do you like it?" -ForegroundColor DarkBlue
Write-Host "The color of this font is DarkCyan. How do you like it?" -ForegroundColor DarkCyan
Write-Host "The color of this font is DarkGray. How do you like it?" -ForegroundColor DarkGray
Write-Host "The color of this font is DarkGreen. How do you like it?" -ForegroundColor DarkGreen
Write-Host "The color of this font is DarkMagenta. How do you like it?" -ForegroundColor DarkMagenta
Write-Host "The color of this font is DarkRed. How do you like it?" -ForegroundColor DarkRed
Write-Host "The color of this font is DarkYellow. How do you like it?" -ForegroundColor DarkYellow
Write-Host "The color of this font is Gray. How do you like it?" -ForegroundColor Gray
Write-Host "The color of this font is Green. How do you like it?" -ForegroundColor Green
Write-Host "The color of this font is Magenta. How do you like it?" -ForegroundColor Magenta
Write-Host "The color of this font is Red. How do you like it?" -ForegroundColor Red
Write-Host "The color of this font is White. How do you like it?" -ForegroundColor White
Write-Host "The color of this font is Yellow. How do you like it?" -ForegroundColor Yellow