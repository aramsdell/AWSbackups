############## C O N F I G ##############
."C:\ec2api\ED\AWSConfig.ps1"

#Environment
$ENVIRONMENT_NAME = "Dept of Ed"
$ENVIRONMENT_TYPE = "Production"
$BACKUP_TYPE = "Weekly"
$stagingInstanceIDs="i-id"
#$stagingInstanceIDs="i-id2","i-id3","i-id4","i-id5"
$stagingInstanceIPs = @{"i-id" = "staticip"}
#$stagingInstanceIPs = @{"i-id" = "staticip"; "i-id2" = "staticip2"; "i-id3" = "staticip3"}

############## F U N C T I O N S ##############
."C:\ec2api\ED\AWSUtilities.ps1"

############## M A I N ##############

try
{
    $start = Get-Date
    WriteToLogAndEmail "$ENVIRONMENT_NAME $ENVIRONMENT_TYPE $BACKUP_TYPE Backup Starting" -excludeTimeStamp $true

    #StopInstances $stagingInstanceIDs
    #CreateSnapshotsForInstances $stagingInstanceIDs
    CreateImagesForInstances $stagingInstanceIDs
    #StartInstances $stagingInstanceIDs
    #AssociateElasticIPs $stagingInstanceIPs
    CleanupWeeklyAmis
    #CleanupWeeklySnapshots

    WriteToLogAndEmail "$ENVIRONMENT_NAME $ENVIRONMENT_TYPE $BACK_UPTYPE Backup Complete" -excludeTimeStamp $true

    $end = Get-Date
    $timespan = New-TimeSpan $start $end
    $hours=$timespan.Hours
    $minutes=$timespan.Minutes    
    
	WriteToLog "Backup took $hours hours and $minutes to complete" -isException $false
	
	#WriteToEmail "Backup took $hours hours and $minutes to complete"
    
    #WriteToEmail "Click here to test: $TEST_URL" -excludeTimeStamp $true

    #SendStatusEmail -successString "SUCCESS"
}
catch
{
    WriteToLog "FAILED" -isException $true
	#SendStatusEmail -successString "FAILED"
}