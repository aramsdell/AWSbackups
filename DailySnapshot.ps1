############## C O N F I G ##############
."C:\ec2api\ED\AWSConfig.ps1"

#Environment
$ENVIRONMENT_NAME = "Dept of Ed"
$ENVIRONMENT_TYPE = "Production"
$BACKUP_TYPE = "Daily"
$stagingInstanceIDs="i-id"
#$stagingInstanceIDs="i-id2","i-id3","i-id4","i-id5"
############## F U N C T I O N S ##############
."C:\ec2api\ED\AWSUtilities.ps1"

############## M A I N ##############

try
{
    $start = Get-Date
    WriteToLogAndEmail "$ENVIRONMENT_NAME $ENVIRONMENT_TYPE $BACKUP_TYPE Backup Starting" -excludeTimeStamp $true
    CreateSnapshotsForInstances $stagingInstanceIDs
    CleanupDailySnapshots

    WriteToLogAndEmail "$ENVIRONMENT_NAME $ENVIRONMENT_TYPE $BACK_UPTYPE Backup Complete" -excludeTimeStamp $true   
    
    $end = Get-Date
    $timespan = New-TimeSpan $start $end
    $hours=$timespan.Hours
    $minutes=$timespan.Minutes    
}
catch
{
	WriteToLog "FAILED" -isException $true
}