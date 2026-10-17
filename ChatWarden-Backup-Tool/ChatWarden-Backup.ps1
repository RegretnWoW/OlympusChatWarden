# Runs outside WoW. Copies the selected saved file; never parses or executes Lua.
[CmdletBinding()]
param(
    [ValidateSet('Gui','Backup','Restore','Inspect','Library')][string]$Mode='Gui',
    [string]$SavedFile,[string]$ArchiveFile,[switch]$GameClosed
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$script:DataName='OlympusChatWarden.lua';$script:BackupFormat='OCW-SAVED-FILE-1'
# Process-local .NET compatibility for deep paths on Windows PowerShell.
[AppContext]::SetSwitch('Switch.System.IO.UseLegacyPathHandling',$false)
[AppContext]::SetSwitch('Switch.System.IO.BlockLongPaths',$false)
function Normal-Path([string]$Path) {
    if ($Path.StartsWith('\\?\UNC\',[StringComparison]::OrdinalIgnoreCase)) {$Path='\\'+$Path.Substring(8)}
    elseif ($Path.StartsWith('\\?\')) {$Path=$Path.Substring(4)}
    if ($Path.StartsWith('\\.\')) {throw 'Choose a normal filesystem path.'}
    return [IO.Path]::GetFullPath($Path)
}
function IO-Path([string]$Path) {
    $full=Normal-Path $Path
    if ($full.StartsWith('\\')) {return '\\?\UNC\'+$full.Substring(2)}
    return '\\?\'+$full
}
function Get-ChatWardenGameProcesses { @(Get-Process -Name 'Wow*' -ErrorAction SilentlyContinue) }
function Assert-GameClosed([bool]$Confirmed) {
    if (-not $Confirmed) { throw 'Fully close WoW, then confirm that the game is closed.' }
    if (@(Get-ChatWardenGameProcesses).Count -gt 0) { throw 'A WoW process is running. Exit WoW normally before backup or restore.' }
}
function Resolve-SavedFile([string]$Path,[bool]$AllowMissing=$false) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Choose OlympusChatWarden.lua in the correct account SavedVariables folder.' }
    $full=Normal-Path $Path
    if ([IO.Path]::GetFileName($full) -cne $script:DataName) { throw 'Choose the exact file OlympusChatWarden.lua.' }
    $parent=[IO.Path]::GetDirectoryName($full)
    $account=[IO.Path]::GetDirectoryName($parent);$accounts=[IO.Path]::GetDirectoryName($account);$wtf=[IO.Path]::GetDirectoryName($accounts)
    if (-not [IO.Directory]::Exists((IO-Path $parent)) -or [IO.Path]::GetFileName($parent) -ine 'SavedVariables' -or [IO.Path]::GetFileName($accounts) -ine 'Account' -or [IO.Path]::GetFileName($wtf) -ine 'WTF') {
        throw 'Choose WTF\Account\<your account>\SavedVariables\OlympusChatWarden.lua. For restore, create the correct SavedVariables folder first.'
    }
    if ([IO.Directory]::Exists((IO-Path $full))) {throw 'The selected file path is a directory.'}
    if (-not $AllowMissing -and -not [IO.File]::Exists((IO-Path $full))) {throw 'The selected saved file does not exist. Exit WoW normally to save it first.'}
    if ([IO.File]::Exists((IO-Path $full)) -and ([IO.File]::GetAttributes((IO-Path $full)) -band [IO.FileAttributes]::ReparsePoint)) {throw 'Choose the actual saved file, not a file link.'}
    return $full
}
function Resolve-Archive([string]$Path,[string]$DataFile,[bool]$New=$false) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Choose a backup ZIP path.' }
    $DataFile=Normal-Path $DataFile
    $full=Normal-Path $Path
    if ([IO.Path]::GetExtension($full) -ine '.zip') { throw 'The backup must be a .zip file.' }
    if (-not [IO.Directory]::Exists((IO-Path ([IO.Path]::GetDirectoryName($full))))) { throw 'Choose an existing backup folder.' }
    $gameRoot=[IO.Path]::GetDirectoryName($DataFile)
    for ($level=0;$level -lt 4;$level++) {$gameRoot=[IO.Path]::GetDirectoryName($gameRoot)}
    $gameRoot=$gameRoot.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if ($full.StartsWith($gameRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Keep the backup ZIP outside the WoW installation, on another folder or drive.' }
    if ($New -and ([IO.File]::Exists((IO-Path $full)) -or [IO.Directory]::Exists((IO-Path $full)))) { throw 'That backup path already exists. Choose a new name; existing backups are never overwritten.' }
    return $full
}
function Get-StreamHash([IO.Stream]$Stream) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Stream))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Get-DataHash([string]$Path) {
    $stream=[IO.File]::Open((IO-Path $Path),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try { return Get-StreamHash $stream } finally { $stream.Dispose() }
}
function Assert-FreeSpace([string]$Path,[long]$Required) {
    $root=[IO.Path]::GetPathRoot($Path)
    if ($root.StartsWith('\\')) { return }
    $drive=[IO.DriveInfo]::new($root)
    if ($drive.IsReady -and $drive.AvailableFreeSpace -lt ($Required+1048576)) { throw 'Not enough free space for this complete backup/restore. Choose another drive.' }
}
function Read-Backup([string]$Path) {
    $stream=[IO.File]::Open((IO-Path $Path),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read);$zip=$null
    try {
        $zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Read,$false)
        if ($zip.Entries.Count -ne 2) { throw 'Invalid backup: expected exactly the saved file and manifest.json.' }
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -cne $script:DataName -and $entry.FullName -cne 'manifest.json') { throw 'Unexpected ZIP entry. Only ChatWarden backup files are accepted.' }
        }
        $data=$zip.GetEntry($script:DataName);$manifestEntry=$zip.GetEntry('manifest.json')
        if (-not $data -or -not $manifestEntry -or $manifestEntry.Length -gt 16384) { throw 'Missing or oversized backup manifest.' }
        $reader=[IO.StreamReader]::new($manifestEntry.Open(),[Text.Encoding]::UTF8)
        try { $manifest=$reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        if ((@($manifest.PSObject.Properties.Name | Sort-Object) -join ',') -cne 'bytes,createdUtc,file,format,sha256,toolVersion') { throw 'Unsupported backup manifest fields.' }
        if ($manifest.format -cne $script:BackupFormat -or $manifest.file -cne $script:DataName -or $manifest.sha256 -cnotmatch '^[a-f0-9]{64}$' -or ($manifest.bytes -isnot [long] -and $manifest.bytes -isnot [int]) -or $manifest.bytes -lt 0 -or $data.Length -ne $manifest.bytes) { throw 'Unsupported or inconsistent backup manifest.' }
        $entryStream=$data.Open();try { $hash=Get-StreamHash $entryStream } finally { $entryStream.Dispose() }
        if ($hash -cne $manifest.sha256) { throw 'Backup checksum mismatch. The saved file has not been changed.' }
        return [pscustomobject]@{Path=$Path;Bytes=[long]$manifest.bytes;Sha256=$hash;CreatedUtc=$manifest.createdUtc;ToolVersion=$manifest.toolVersion}
    } finally { if ($zip) { $zip.Dispose() };$stream.Dispose() }
}
function New-ChatWardenBackup([string]$DataFile,[string]$ZipFile,[bool]$Confirmed,[bool]$AllowEmptySafetyCopy=$false) {
    Assert-GameClosed $Confirmed
    $data=Resolve-SavedFile $DataFile;$archive=Resolve-Archive $ZipFile $data $true
    Assert-FreeSpace $archive ([IO.FileInfo](IO-Path $data)).Length
    $source=$null;$output=$null;$zip=$null;$created=$false
    try {
        $source=[IO.File]::Open((IO-Path $data),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        $hash=Get-StreamHash $source;$source.Position=0
        $manifest=[ordered]@{format=$script:BackupFormat;file=$script:DataName;toolVersion='1.0.3';createdUtc=[DateTime]::UtcNow.ToString('o');bytes=$source.Length;sha256=$hash}
        if ($source.Length -le 0 -and -not $AllowEmptySafetyCopy) { throw 'The saved file is empty. Exit WoW normally to save data first.' }
        $output=[IO.File]::Open((IO-Path $archive),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);$created=$true
        $zip=[IO.Compression.ZipArchive]::new($output,[IO.Compression.ZipArchiveMode]::Create,$false)
        $entry=$zip.CreateEntry($script:DataName,[IO.Compression.CompressionLevel]::Optimal);$target=$entry.Open()
        try { $source.CopyTo($target) } finally { $target.Dispose() }
        $entry=$zip.CreateEntry('manifest.json',[IO.Compression.CompressionLevel]::Optimal)
        $writer=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false))
        try { $writer.Write(($manifest | ConvertTo-Json -Compress)) } finally { $writer.Dispose() }
        $zip.Dispose();$zip=$null;$output.Dispose();$output=$null;$source.Dispose();$source=$null
        $verified=Read-Backup $archive
        return [pscustomobject]@{Archive=$archive;Bytes=$verified.Bytes;Sha256=$verified.Sha256}
    } catch {
        if ($zip) {$zip.Dispose();$zip=$null};if ($output) {$output.Dispose();$output=$null}
        if ($created -and [IO.File]::Exists((IO-Path $archive))) {[IO.File]::Delete((IO-Path $archive))}
        throw
    } finally {if ($zip) {$zip.Dispose()};if ($output) {$output.Dispose()};if ($source) {$source.Dispose()}}
}
function Restore-ChatWardenBackup([string]$DataFile,[string]$ZipFile,[bool]$Confirmed) {
    Assert-GameClosed $Confirmed
    $data=Resolve-SavedFile $DataFile $true;$archive=Resolve-Archive $ZipFile $data;$verified=Read-Backup $archive
    if ($verified.Bytes -le 0) {throw 'The selected backup contains an empty saved file. Existing data was kept.'}
    Assert-FreeSpace $data $verified.Bytes
    $existed=[IO.File]::Exists((IO-Path $data));$safety=$null;$originalHash=$null
    if ($existed) {
        $safetyPath=Join-Path ([IO.Path]::GetDirectoryName($archive)) ('ChatWarden-before-restore-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)+'.zip')
        $safety=New-ChatWardenBackup $data $safetyPath $Confirmed $true;$originalHash=$safety.Sha256
    }
    $temp=Join-Path ([IO.Path]::GetDirectoryName($data)) ('.chatwarden-restore-'+[Guid]::NewGuid().ToString('N')+'.tmp')
    if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($temp)) -ine [IO.Path]::GetDirectoryName($data)) {throw 'Invalid restore staging path.'}
    $zip=$null;$output=$null
    try {
        $zip=[IO.Compression.ZipFile]::OpenRead((IO-Path $archive));$entryStream=$zip.GetEntry($script:DataName).Open()
        try {
            $output=[IO.File]::Open((IO-Path $temp),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
            $entryStream.CopyTo($output)
        } finally {$entryStream.Dispose();if ($output) {$output.Dispose();$output=$null}}
        $zip.Dispose();$zip=$null
        if ((Get-DataHash $temp) -cne $verified.Sha256) {throw 'Restore staging checksum mismatch. Existing data was kept.'}
        Assert-GameClosed $Confirmed
        if ($existed) {
            if (-not [IO.File]::Exists((IO-Path $data)) -or (Get-DataHash $data) -cne $originalHash) {throw 'The saved file changed during restore. Nothing was replaced; keep WoW closed and try again.'}
            [IO.File]::Replace((IO-Path $temp),(IO-Path $data),[NullString]::Value)
        } else {
            if ([IO.File]::Exists((IO-Path $data))) {throw 'A saved file appeared during restore. Nothing was replaced.'}
            [IO.File]::Move((IO-Path $temp),(IO-Path $data))
        }
        if ((Get-DataHash $data) -cne $verified.Sha256) {throw 'Restored file verification failed. Keep your backup and before-restore safety copy.'}
        return [pscustomobject]@{SavedFile=$data;Sha256=$verified.Sha256;SafetyCopy=$(if ($safety) {$safety.Archive} else {$null})}
    } finally {if ($zip) {$zip.Dispose()};if ($output) {$output.Dispose()};if ([IO.File]::Exists((IO-Path $temp))) {[IO.File]::Delete((IO-Path $temp))}}
}
function Show-BackupWindow([switch]$BuildOnly) {
    Add-Type -AssemblyName System.Windows.Forms;Add-Type -AssemblyName System.Drawing
    [Windows.Forms.Application]::EnableVisualStyles();$nl=[Environment]::NewLine
    $form=[Windows.Forms.Form]::new();$form.Text='Olympus ChatWarden Backup';$form.ClientSize=[Drawing.Size]::new(650,485);$form.StartPosition='CenterScreen'
    $form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false;$form.BackColor=[Drawing.Color]::FromArgb(40,48,58);$form.ForeColor=[Drawing.Color]::FromArgb(238,224,197);$form.Font=[Drawing.Font]::new('Segoe UI',10)
    $title=[Windows.Forms.Label]::new();$title.Text='ChatWarden - keep your whole history';$title.Location=[Drawing.Point]::new(24,20);$title.Size=[Drawing.Size]::new(600,35);$title.Font=[Drawing.Font]::new('Segoe UI',17,[Drawing.FontStyle]::Bold);$title.ForeColor=[Drawing.Color]::Gold;$form.Controls.Add($title)
    $intro=[Windows.Forms.Label]::new();$intro.Text='One complete saved file. No numbered text pages.'+$nl+'Exit WoW normally first. Backups include settings, captures and private player notes.';$intro.Location=[Drawing.Point]::new(24,65);$intro.Size=[Drawing.Size]::new(600,55);$form.Controls.Add($intro)
    $label=[Windows.Forms.Label]::new();$label.Text='Saved file: WTF\Account\<account>\SavedVariables\OlympusChatWarden.lua';$label.Location=[Drawing.Point]::new(24,128);$label.Size=[Drawing.Size]::new(600,25);$form.Controls.Add($label)
    $file=[Windows.Forms.TextBox]::new();$file.Location=[Drawing.Point]::new(24,158);$file.Size=[Drawing.Size]::new(500,28);$form.Controls.Add($file)
    $choose=[Windows.Forms.Button]::new();$choose.Text='Choose file';$choose.Location=[Drawing.Point]::new(534,155);$choose.Size=[Drawing.Size]::new(93,32);$form.Controls.Add($choose)
    $choose.Add_Click({
        $dialog=[Windows.Forms.OpenFileDialog]::new();$dialog.Title='Choose the account saved file';$dialog.Filter='ChatWarden saved file|OlympusChatWarden.lua';$dialog.FileName=$script:DataName
        try {if ($dialog.ShowDialog() -eq 'OK') {$file.Text=$dialog.FileName}} finally {$dialog.Dispose()}
    })
    $closed=[Windows.Forms.CheckBox]::new();$closed.Text='I have fully closed WoW after saving normally.';$closed.Location=[Drawing.Point]::new(24,205);$closed.Size=[Drawing.Size]::new(600,27);$form.Controls.Add($closed)
    $backup=[Windows.Forms.Button]::new();$backup.Text='Create one backup ZIP';$backup.Location=[Drawing.Point]::new(24,249);$backup.Size=[Drawing.Size]::new(292,42);$form.Controls.Add($backup)
    $restore=[Windows.Forms.Button]::new();$restore.Text='Restore a backup ZIP';$restore.Location=[Drawing.Point]::new(334,249);$restore.Size=[Drawing.Size]::new(292,42);$form.Controls.Add($restore)
    $status=[Windows.Forms.TextBox]::new();$status.Location=[Drawing.Point]::new(24,310);$status.Size=[Drawing.Size]::new(602,110);$status.Multiline=$true;$status.ReadOnly=$true;$status.ScrollBars='Vertical';$status.Text='Choose your saved file. Store backup ZIPs outside WoW, preferably on another drive.';$form.Controls.Add($status)
    $note=[Windows.Forms.Label]::new();$note.Text='Restore replaces all saved ChatWarden data and keeps a safety ZIP first. Nothing is uploaded.';$note.Location=[Drawing.Point]::new(24,438);$note.Size=[Drawing.Size]::new(602,35);$form.Controls.Add($note)
    foreach ($control in $form.Controls) {
        if ($control -is [Windows.Forms.Button]) {
            $control.FlatStyle='Flat';$control.FlatAppearance.BorderColor=[Drawing.Color]::Goldenrod
            $control.BackColor=[Drawing.Color]::FromArgb(29,81,116);$control.ForeColor=[Drawing.Color]::White
        } elseif ($control -is [Windows.Forms.TextBox]) {
            $control.BackColor=[Drawing.Color]::FromArgb(24,33,43);$control.ForeColor=[Drawing.Color]::WhiteSmoke
        }
    }
    $backup.Add_Click({
        try {
            Assert-GameClosed $closed.Checked;$data=Resolve-SavedFile $file.Text
            $dialog=[Windows.Forms.SaveFileDialog]::new();$dialog.Title='Save backup outside WoW';$dialog.Filter='ChatWarden backup (*.zip)|*.zip';$dialog.FileName='ChatWarden-backup-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'.zip';$dialog.OverwritePrompt=$true
            try {if ($dialog.ShowDialog() -ne 'OK') {return};$path=$dialog.FileName} finally {$dialog.Dispose()}
            $backup.Enabled=$false;$restore.Enabled=$false;$status.Text='Creating and checking your complete backup...';$form.Refresh()
            $result=New-ChatWardenBackup $data $path $closed.Checked
            $status.Text='Backup verified:'+$nl+$result.Archive+$nl+'Keep this ZIP private and store an extra copy away from this PC.'
        } catch {$status.Text=$_.Exception.Message}
        finally {$backup.Enabled=$true;$restore.Enabled=$true}
    })
    $restore.Add_Click({
        try {
            Assert-GameClosed $closed.Checked
            $dialog=[Windows.Forms.OpenFileDialog]::new();$dialog.Title='Choose your own ChatWarden backup';$dialog.Filter='ChatWarden backup (*.zip)|*.zip'
            try {if ($dialog.ShowDialog() -ne 'OK') {return};$path=$dialog.FileName} finally {$dialog.Dispose()}
            $data=$file.Text
            if ([string]::IsNullOrWhiteSpace($data)) {
                $destination=[Windows.Forms.SaveFileDialog]::new();$destination.Title='Choose the correct account SavedVariables destination';$destination.Filter='ChatWarden saved file|OlympusChatWarden.lua';$destination.FileName=$script:DataName;$destination.OverwritePrompt=$false
                try {if ($destination.ShowDialog() -ne 'OK') {return};$data=$destination.FileName;$file.Text=$data} finally {$destination.Dispose()}
            }
            $data=Resolve-SavedFile $data $true;$path=Resolve-Archive $path $data;$info=Read-Backup $path
            $question='Replace all saved ChatWarden settings and history at:'+$nl+$data+$nl+$nl+'Backup created: '+$info.CreatedUtc+$nl+'A safety ZIP is kept first if data already exists. Use only your own trusted backup.'
            if ([Windows.Forms.MessageBox]::Show($form,$question,'Restore complete ChatWarden data','YesNo','Warning') -ne 'Yes') {return}
            $backup.Enabled=$false;$restore.Enabled=$false;$status.Text='Checking and restoring your saved file...';$form.Refresh()
            $result=Restore-ChatWardenBackup $data $path $closed.Checked
            $status.Text='Restore verified. You can reopen WoW.'+$nl+$result.SavedFile+$nl+'Safety copy: '+$result.SafetyCopy
        } catch {$status.Text=$_.Exception.Message}
        finally {$backup.Enabled=$true;$restore.Enabled=$true}
    })
    if ($BuildOnly) {return $form}
    try {[void]$form.ShowDialog()} finally {$form.Dispose()}
}
switch ($Mode) {
    'Gui' {Show-BackupWindow}
    'Backup' {New-ChatWardenBackup $SavedFile $ArchiveFile $GameClosed.IsPresent}
    'Restore' {Restore-ChatWardenBackup $SavedFile $ArchiveFile $GameClosed.IsPresent}
    'Inspect' {Read-Backup ([IO.Path]::GetFullPath($ArchiveFile))}
    'Library' {}
}
