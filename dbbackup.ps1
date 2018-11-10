# This Powershell script is used to backup a SQL Server database and move the backup file to S3
# It can be run as a scheduled task like this:
# C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe &'C:\ec2api\dbbackup.ps1'
# Written by Michael Friis (http://friism.com)

$key = "accesskey"
$secret = "secretkey"
$localfolder = "D:\\backups\\"
$s3folder = "ec2_dbbackups/"
$dbname = "SBDigitizer"
$dblogname = $dbname + "_log"
#$name = Get-Date -uformat "backup_%Y_%m_%d"
#$name = Get-Date -uformat "_%Y_%m_%d"
$name = $dbname
$filename = $name + ".bak"
$fullname = $localfolder + $filename
$zipfilename = $name + ".zip"
$ziplibloc = "C:\ziplib\zip-v1.9-Reduced\Release\Ionic.Zip.Reduced.dll"

# Remove existing db backup file
if(Test-Path -path ($fullname)) { Remove-Item ($fullname) }

#"BACKUP DATABASE [ProtectedAreas_2012_01] TO  DISK = N'D:\backups\ProtectedAreas_2012_01.bak' WITH NOFORMAT, NOINIT,  NAME = N'ProtectedAreas_2012_01-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10"

#sqlcmd -S "local\sqlexpress" -Q "BACKUP DATABASE [ProtectedAreas_2012_01] TO  DISK = N'D:\backups\ProtectedAreas_2012_01.bak' WITH NOFORMAT, NOINIT,  NAME = N'ProtectedAreas_2012_01-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,STATS = 10"
#sqlcmd -v testvar="'Testing This'" -Q"print $(testvar);"



#BACKUP DATABASE [SBDigitizer] TO  DISK = N'D:\backups\SBDigitizer.bak' WITH NOFORMAT, NOINIT,  NAME = N'SBDigitizer-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
#GO

$query =
"
USE [$dbname];
GO

DBCC SHRINKFILE([$dblogname,1]);

GO

BACKUP DATABASE [$dbname] TO  DISK = N'$fullname'
        WITH NOFORMAT, NOINIT,  NAME = N'$dbname-Full Database Backup', SKIP, REWIND, NOUNLOAD,  STATS = 10
GO
declare @backupSetId as int
select @backupSetId = position from msdb..backupset
where database_name=N'$dbname' and backup_set_id=(select max(backup_set_id)
from msdb..backupset where database_name=N'$dbname' )

if @backupSetId is null
begin
        raiserror(N'Verify failed. Backup information for database ''$dbname'' not found.', 16, 1)
end
RESTORE VERIFYONLY FROM  DISK = N'$fullname'
        WITH  FILE = @backupSetId,  NOUNLOAD,  NOREWIND" -f $localfolder, $filename, $dbname, $dblogname

sqlcmd -S "localhost\sqlexpress" -Q $query

# Remove existing zip file
if(Test-Path -path ($localfolder + $zipfilename)) { Remove-Item ($localfolder + $zipfilename) }

#Zip the backup file
[System.Reflection.Assembly]::LoadFrom($ziplibloc);
$zipfile =  new-object Ionic.Zip.ZipFile
#$e= $zipfile.AddSelectedFiles("name = *.bak", $localfolder, "home")
$e= $zipfile.AddFile($fullname, "")
#$e= $zipfile.AddDirectory($localfolder, "home")
#$zipfile.Save($localfolder + $zipfilename,"");
$zipfile.Save($zipfilename);
$zipfile.Dispose();

#Upload to S3
Add-PSSnapin CloudBerryLab.Explorer.PSSnapIn
$s3 = Get-CloudS3Connection -Key $key -Secret $secret
$destination = $s3 | Select-CloudFolder -path $s3folder
$src = Get-CloudFilesystemConnection | Select-CloudFolder $localfolder
$src | Copy-CloudItem $destination –filter $zipfilename