# nvidia-nvlog-fix

Stops the NVIDIA display container service from hammering the disk with a
log file it rewrites in a loop.

## Symptom

Task Manager shows `NVDisplay.Container.exe` (service
`NVDisplay.ContainerLocalSystem`) with constant high disk usage. The process
deletes and rewrites this file about once per second:

```
C:\ProgramData\NVIDIA Corporation\nvtopps\nct\nvlog.nvlgstg
```

On the machine where this was found the process had written 220 GB in four
hours (about 15 MB/s on average, bursts above 140 MB/s). Restarting the
service does not help: the loop starts again right away.

Seen with:

- Windows 11 Pro, build 26300
- GeForce RTX 2080 Ti, driver 32.0.16.2124 (dated 2026-11-07)

## Check that you have the same problem

Watch the folder for 30 seconds from an admin PowerShell:

```powershell
$w = New-Object IO.FileSystemWatcher 'C:\ProgramData\NVIDIA Corporation\nvtopps'
$w.IncludeSubdirectories = $true
$n = 0; $end = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $end) { if (-not $w.WaitForChanged('All', 1000).TimedOut) { $n++ } }
"$n file events"
```

Dozens of events on `nct\nvlog.nvlgstg` mean you have this problem.

## Fix

Run from an admin PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\nvidia-nvlog-fix.ps1
```

The script:

1. stops `NVDisplay.ContainerLocalSystem`,
2. deletes `nvlog.nvlgstg`,
3. adds deny rules on the `nct` folder so SYSTEM and Administrators cannot
   create files in it,
4. starts the service again.

After the fix the service wrote 0.5 MB in six minutes and used under one
second of CPU. The service keeps running normally without the file.

## Undo

```powershell
powershell -ExecutionPolicy Bypass -File .\nvidia-nvlog-fix.ps1 -Revert
```

This removes the deny rules and restarts the service.

## Notes

- The screen may flicker once while the service restarts.
- A driver update can reset the folder permissions. Run the script again if
  the disk usage comes back.
- This is a workaround, not a driver fix. It was tested on one machine, and
  not with every NVIDIA App feature. Use at your own risk.
