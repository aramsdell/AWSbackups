############## R E A D M E ##############
#--Variables in ALL CAPS live in AWSConfig.ps1

#Run next line only once; is is required to create source for Windows Event Log
#New-EventLog -Source "AWS PowerShell Utilities" -LogName "Application"


############## G L O B A L ##############
#global variable to hold email message
$global:email = ""

############## U T I L I T Y   F U N C T I O N S ##############

#Description: Returns true if function has been running longer than permitted 
#Returns: bool
function IsTimedOut([datetime] $start, [string] $functionName)
{    
    
    $current = new-timespan $start (get-date)
    
    If($current.Minutes -ge $MAX_FUNCTION_RUNTIME)
    {
        WriteToLogAndEmail "$FunctionName has taken longer than $MAX_FUNCTION_RUNTIME min. Aborting!"
        throw new-object System.Exception "$FunctionName has taken longer than $MAX_FUNCTION_RUNTIME min. Aborting!"
        return $true
    } 
    return $false
}
#Description: Adds a tag to an Amazon Web Services Resource
#Returns: n/a
function AddTagToResource([string] $resourceID, [string] $key, [string] $value)
{   
    try
    {
        $tag = new-object amazon.EC2.Model.Tag
        $tag.Key=$key
        $tag.Value=$value
        
        $createTagsRequest = new-object amazon.EC2.Model.CreateTagsRequest
        $createTagsResponse = $EC2_CLIENT.CreateTags($createTagsRequest.WithResourceId($resourceID).WithTag($tag))
        $createTagsResult = $createTagsResponse.CreateTagsResult; 
    }
    catch [Exception]
    {
        $function = "AddTagToResource"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
    }
}
#Description: Add carriage return characters for formatting purposes (ex. email)
#Returns: string[]
function FixNewLines([string[]] $text)
{    
    $returnText=""
    try
    {
        for($i=0;$i -le $text.Length;$i++)
        {
            $returnText+=$text[$i]+"`r`n"
        }
    }
    catch [Exception]
    {
        $function = "FixNewLines"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
    }
    finally
    {
        return $returnText
    }    
}
#Description: Returns the current log name by determining the timestamp for the first day of the current week
#Returns: string
function GetLogDate
{
    $dayOfWeek = (get-date).DayOfWeek
    switch($dayOfWeek)
    {
        "Sunday" {$dayOfWeekNumber=0}
        "Monday" {$dayOfWeekNumber=1}
        "Tuesday" {$dayOfWeekNumber=2}
        "Wednesday" {$dayOfWeekNumber=3}
        "Thursday" {$dayOfWeekNumber=4}
        "Friday" {$dayOfWeekNumber=5}
        "Saturday" {$dayOfWeekNumber=6}
    }
    if($dayOfWeekNumber -eq 0)
    {
        $logDate = get-date -f yyyyMMdd
    }
    else
    {
        $logDate = get-date ((get-date).AddDays($dayOfWeekNumber * -1)) -f yyyyMMdd
    } 
    $logName = $logDate + ".txt"
    return  $logName  
}
#Description: Writes a message to a log file, console
#Returns: n/a
function WriteToLog([string[]] $text, [bool] $isException = $false)
{    
    try
    {
        if((Test-Path $LOG_PATH) -eq $false)
        {
            [IO.Directory]::CreateDirectory($LOG_PATH) 
        }
        $date = GetLogDate
        $logFilePath = $LOG_PATH + $date + ".txt"
        $currentDatetime = get-date -format G 
        add-content -Path $logFilePath -Value "$currentDatetime $text"
        write-host "$datetime $text"
        if($isException)
        {
            write-eventlog -Logname "Application" -EntryType "Information" -EventID "0" -Source "AWS PowerShell Utilities" -Message $text
        }
    }
    catch [Exception]
    {
        $function = "WriteToLog"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
    }    
}
#Description: Writes a email variable for later usage
#Returns: n/a
function WriteToEmail([string[]] $text, [bool] $excludeTimeStamp = $false)
{    
    try
    {
        if($excludeTimeStamp)
        {
            $global:email += "$text`r`n"
        }
        else
        {
            $datetime = get-date -format G 
            $global:email += "$datetime $text`r`n"
        }
    }
    catch [Exception]
    {
        $function = "WriteToEmail"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
    }
}

#Description: Write to log and email
#Returns: n/a
function WriteToLogAndEmail([string[]] $text, [bool] $isException = $false)
{
    WriteToLog $text $isException
    #WriteToEmail $text
}
############## E M A I L   F U N C T I O N S ##############

#Description: Sends an email via Amazone Simple Email Service
#Returns: n/a
function SendSesEmail([string] $from, [string[]]$toList, [string]$subject, [string]$body)
{   
    try
    {
        # Make an Email Request
        $request = new-object -TypeName Amazon.SimpleEmail.Model.SendEmailRequest
        
        # "$request | gm" provides a lot of neat things you can do
        $request.Source = $from
        $list = new-object 'System.Collections.Generic.List[string]'
        foreach($address in $toList)
        {
            $list.Add($address)
        }
        $request.Destination = $list
        $subjectObject = new-object -TypeName Amazon.SimpleEmail.Model.Content
        $subjectObject.data = $subject
        $bodyContent = new-object -TypeName Amazon.SimpleEmail.Model.Content
        $bodyContent.data = $body
        $bodyObject = new-object -TypeName Amazon.SimpleEmail.Model.Body
        $bodyObject.text = $bodyContent
        $message = new-object -TypeName Amazon.SimpleEmail.Model.Message
        $message.Subject = $subjectObject
        $message.Body = $bodyObject
        $request.Message = $message
        
        # Send the message
        $response = $SES_CLIENT.SendEmail($request)
    }
    catch [Exception]
    {
        $function = "SendSesEmail"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
    }
    
}
#Description: Sends an status email to administrators
#Returns: n/a
function SendStatusEmail([string[]] $toAddress, [string] $successString = "", [string] $subject = "")
{ 
    
    try
    {   
        if($subject -eq "")
        {
            $subject = $successString + ": $ENVIRONMENT_NAME $ENVIRONMENT_TYPE $BACKUP_TYPE Backup"
        }

        $body = $global:email
        
        if($toAddress -eq $null -or $toAddress -eq "") { $toAddress = $ADMIN_ADDRESSES }
        
        SendSesEmail $FROM_ADDRESS $toAddress $subject $body
    }
    catch [Exception]
    {
        $function = "SendStatusEmail"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
    }
} 
############## I N S T A N C E   F U N C T I O N S ##############

#Description: Returns an Amazon Web Service Instance object for a given instance Id
#Returns: Instance
function GetInstance([string] $instanceID)
{
    try
    {
        $instancesRequest = new-object amazon.EC2.Model.DescribeInstancesRequest
        $instancesResponse = $EC2_CLIENT.DescribeInstances($instancesRequest.WithInstanceId($instanceID))
        $instancesResult = $instancesResponse.DescribeInstancesResult.Reservation
        return $instancesResult[0].RunningInstance[0]
    }
    catch [Exception]
    {
        $function = "GetInstance"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return $null
    }
}
#Description: Returns all Amazon Web Service Instance objects
#Returns: ArrayList<Instance>
function GetAllInstances()
{
    try
    {
        $instancesRequest = new-object amazon.EC2.Model.DescribeInstancesRequest
        $instancesResponse = $EC2_CLIENT.DescribeInstances($instancesRequest)
        $instancesResult = $instancesResponse.DescribeInstancesResult.Reservation
        
         $allInstances = new-object System.Collections.ArrayList
        
        foreach($reservation in $instancesResult)
        {
            foreach($instance in $reservation.RunningInstance)
            {
                $allInstances.Add($instance) | out-null
            }
        }
        
        return $allInstances
    }
    catch [Exception]
    {
        $function = "GetAllInstances"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return $null
    }
}
#Description: Returns an ArrayList of all running Amazon Web Service Instance objects that are
#Returns: Instance
function GetRunningInstances()
{
    try
    {

        $allInstances = GetAllInstances
        $runningInstances = new-object System.Collections.ArrayList

        foreach($instance in $allInstances)
        {
            if($instance.InstanceState.Name -eq "running")
            {
                $runningInstances.Add($instance) | out-null
            }
        }
        
        return $runningInstances
    }
    catch [Exception]
    {
        $function = "GetRunningInstances"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return $null
    }
}
#Description: Gets the status of an Amazon Web Service Instance object for a given instance Id
#Returns: string
function GetInstanceStatus([string] $instanceID)
{
    try
    {
        $instance = GetInstance $instanceID
        return $instance.InstanceState.Name
    }
    catch [Exception]
    {
        $function = "GetInstanceStatus"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return $null
    }
}
#Description: Gets the name of an Amazon Web Service Instance object for a given instance Id
#Returns: string
function GetInstanceName([string] $instanceID)
{
    try
    {
        $instance = GetInstance $instanceID
        return $instance.Tag[0].WithKey("Name").Value
    }
    catch [Exception]
    {
        $function = "GetInstanceName"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return $null
    }
}
#Description: Starts an Amazon Web Service Instance object for a given instance Id
#Returns: n/a
function StartInstance([string] $instanceID)
{    
    try
    {
        $instanceStatus = GetInstanceStatus $instanceID
        $name = GetInstanceName $instanceID
        if($instanceStatus -eq "running")
        {   
            WriteToLog "Instance $name ($instanceID) Already started"
            #WriteToEmail "$name already started"
        }
        else
        {
            #Start instance    
            $startReq = new-object amazon.EC2.Model.StartInstancesRequest
            $startReq.InstanceId.Add($instanceID);    

            WriteToLog "Instance $name ($instanceID) Starting"    
            $startResponse = $EC2_CLIENT.StartInstances($startReq)
            $startResult = $startResponse.StartInstancesResult;
            
            #Wait for instance to finish starting. Unlike Stop instance,start one at a time (ex. DC, SQL, SP)
            $instancesRequest = new-object amazon.EC2.Model.DescribeInstancesRequest     
            
            $start = get-date
                       
            do{
                #abort if infinite loop or otherwise
                if(IsTimedOut $start) { break } 
                
                start-sleep -s 5
                $instancesResponse = $EC2_CLIENT.DescribeInstances($instancesRequest.WithInstanceId($instanceID))
                $instancesResult = $instancesResponse.DescribeInstancesResult.Reservation
            }
            while($instancesResult[0].RunningInstance[0].InstanceState.Name -ne "running") 
            
            WriteToLog "Instance $name ($instanceID) Started"  
            #WriteToEmail "$name started"               
        }
    }
    catch [Exception]
    {
        $function = "StartInstance"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
    }    
}
#Description: Starts one or more Amazon Web Service Instance object for a collection of instance Ids
#Returns: n/a
function StartInstances ([string[]] $instanceIDs)
{   
    try
    {
        $start = get-date
        
        foreach($instanceID in $instanceIDs)
        {
            StartInstance $instanceID            
        }
        
        $end = get-date
        $finish = new-timespan $start $end
        $finishMinutes = $finish.Minutes
        $finishSeconds = $finish.Seconds 
        WriteToLog "Start Instances completed in $finishMinutes min $finishSeconds sec"
        
    }
    catch [Exception]
    {
        $function = "Start Instances"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
    }
    
}
#Description: Starts all Amazon Web Service Instances
#Returns: n/a
function StartAllInstances()
{
    try
    {
        $instances = GetRunningInstances
        foreach($instance in $instances)
        {
            if($STARTALL_EXCEPTIONS -notcontains $instance.InstanceID)
            {
                StopInstance($instance)
            }
        }
    }
    catch [Exception]
    {
        $function = "StopRunningInstances"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
    }
}
#Description: Stops an Amazon Web Service Instance object for a given instance Id
#Returns: bool - is instance already stopped?
function StopInstance([string] $instanceID)
{    
    try
    {
        $instanceStatus = GetInstanceStatus $instanceID
        $name = GetInstanceName $instanceID
        if($instanceStatus -eq "stopped")
        {   
            WriteToLog "$name ($instanceID) Already Stopped"
            WriteToLog "$name already stopped"
            return $true
        }
        else
        {
            #Stop instance    
            $stopReq = new-object amazon.EC2.Model.StopInstancesRequest
            $stopReq.InstanceId.Add($instanceID);
       
            WriteToLog "Instance $name ($instanceID) Stopping"
            $stopResponse = $EC2_CLIENT.StopInstances($stopReq)
            $stopResult = $stopResponse.StopInstancesResult;  
            return $false      
        }
    }
    catch [Exception]
    {
        $function = "StopInstance"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return $null
    }
}
#Description: Stops one or more Amazon Web Service Instance object for a collection of instance Ids
#Returns: n/a
function StopInstances([string[]] $instanceIDs)
{    
    try
    {    
        $statusInstanceIDs = new-object System.Collections.ArrayList($null)
        $statusInstanceIDs.AddRange($instanceIDs)
        
        #Stop all instances
        foreach($instanceID in $instanceIDs)
        {        
            if(StopInstance $instanceID)
            {
                $statusInstanceIDs.Remove($instanceID)
            }
        }
        #Wait for all instances to finish stopping
        $instancesRequest = new-object amazon.EC2.Model.DescribeInstancesRequest   
        
        $start = get-date        
        do
        {
            #abort if infinite loop or otherwise
            if(IsTimedOut $start) { break } 
                
            start-sleep -s 5
            foreach($instanceID in $statusInstanceIDs)
            {
                $status = GetInstanceStatus $instanceID
                if($status -eq "stopped")
                {
                    $name = GetInstanceName $instanceID
                    WriteToLog "Instance $name ($instanceID) Stopped"
                    #WriteToEmail "$name stopped"
                    $statusInstanceIDs.Remove($instanceID)
                    break
                }
            }      
        }
        while($statusInstanceIDs.Count -ne 0)        
       
        $end = get-date
        $finish = new-timespan $start $end
        $finishMinutes = $finish.Minutes
        $finishSeconds = $finish.Seconds         
        WriteToLog "Stop Instances completed in $finishMinutes min $finishSeconds sec"
    }
    catch [Exception]
    {
        $function = "StopInstances"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
    }
}
#Description: Stops all Amazon Web Service Instances
#Returns: n/a
function StopAllInstances()
{
    try
    {
        [System.Collections.ArrayList]$instances = GetAllInstances
        foreach($instance in $instances)
        {
            if($STOPALL_EXCEPTIONS -notcontains $instance.InstanceID)
            {
                StopInstance($instance.InstanceID)
            }
        }
    }
    catch [Exception]
    {
        $function = "StopAllInstances"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
    }
}


############## S N A P S H O T   F U N C T I O N S ##############

#Description: Returns a Amazon Web Service Snapshot with a given snapshot Id
#Returns: Snapshot
function GetSnapshot([string] $snapshotID)
{
    try
    {
        $snapshotsRequest = new-object amazon.EC2.Model.DescribeSnapshotsRequest
        $snapshotsResponse = $EC2_CLIENT.DescribeSnapshots($snapshotsRequest.WithSnapshotId($snapshotID))
        $snapshotsResult = $snapshotsResponse.DescribeSnapshotsResult
        return $snapshotsResult.Snapshot[0]
    }
    catch [Exception]
    {
        $function = "GetSnapshot"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return $null
    }
}
#Description: Returns a Amazon Web Service Image with a given image Id
#Returns: Image
function GetAmi([string] $amiID)
{
    try
    {
        $imagesRequest = new-object amazon.EC2.Model.DescribeImagesRequest
        $imagesResponse = $EC2_CLIENT.DescribeImages($imagesRequest.WithImageId($amiID))
        $imagesResult = $imagesResponse.DescribeImagesResult
        return $imagesResult.Image[0]
    }
    catch [Exception]
    {
        $function = "GetAmi"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return $null
    }
}
#Description: Returns all Amazon Web Service Snapshots
#Returns: Snapshot[]
function GetAllSnapshots
{
    try
    {
        $snapshotsRequest = new-object amazon.EC2.Model.DescribeSnapshotsRequest
        $snapshotsResponse = $EC2_CLIENT.DescribeSnapshots($snapshotsRequest.WithOwner($accountID))
        $snapshotsResult = $snapshotsResponse.DescribeSnapshotsResult
        return $snapshotsResult.Snapshot
    }
    catch [Exception]
    {
        $function = "GetAllSnapshots"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return $null
    }
}
#Description: Returns all Amazon Web Service Images
#Returns: Image[]
function GetAllAmis
{
    try
    {
        $imagesRequest = new-object amazon.EC2.Model.DescribeImagesRequest
        $imagesResponse = $EC2_CLIENT.DescribeImages($imagesRequest.WithOwner($accountID))
        $imagesResult = $imagesResponse.DescribeImagesResult
        return $imagesResult.Image
    }
    catch [Exception]
    {
        $function = "GetAllAmis"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return $null
    }
}
#Description: Returns the Description for Amazon Web Service Snapshot with a given snapshot Id
#Returns: string - description of snapshot
function GetSnapshotDescription([string] $snapshotID)
{
    try
    {
        $snapshot = GetSnapshot $snapshotID
        return $snapshot.Description
    }
    catch [Exception]
    {
        $function = "GetSnapshotDescription"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return $null
    }    
}
#Description: Returns the Description for Amazon Web Service Image with a given image Id
#Returns: string - description of image
function GetAmiDescription([string] $amiID)
{
    try
    {
        $ami = GetAmi $amiID
        return $ami.Description
    }
    catch [Exception]
    {
        $function = "GetAmiDescription"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return $null
    }    
}
#Description: Deletes an Amazon Web Service Snapshot with a given snapshot Id
#Returns: n/a
function DeleteSnapshot([string] $snapshotID)
{    
    try
    {
        $name = GetSnapshotDescription $snapshotID                 
        WriteToLog "Snapshot $name ($snapshotID) Deleting"

        $deleteSnapshotRequest = new-object amazon.EC2.Model.DeleteSnapshotRequest
        $deleteSnapshotResponse = $EC2_CLIENT.DeleteSnapshot($deleteSnapshotRequest.WithSnapshotId($snapshotID))
        $deleteSnapshotResult = $deleteSnapshotResponse.DeleteSnapshotResult; 
        
        WriteToLog "Snapshot $name ($snapshotID) Deleted" 
        #WriteToEmail "Snapshot Deleted: $name"    
        
    }
    catch [Exception]
    {
        $function = "DeleteSnapshot"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
    }
    
}
#Description: Deregisters an Amazon Web Service AMI with a given AMI Id
#Returns: n/a
function DeregisterAMI([string] $amiID)
{    
    try
    {
        $name = GetAmiDescription $amiID                 
        WriteToLog "AMI $name ($amiID) Deregistering"

        $deregisterImageRequest = new-object amazon.EC2.Model.DeregisterImageRequest
        $deregisterImageResponse = $EC2_CLIENT.DeregisterImage($deregisterImageRequest.WithImageId($amiID))
        
        WriteToLog "AMI $name ($amiID) Deregistered" 
    }
    catch [Exception]
    {
        $function = "DeregisterAMI"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
    }
    
}
#Description: Creates Amazon Web Service Images for a collection of instance Ids
#Parameters: $instanceIDs string[]
#Returns: n/a
function CreateImagesForInstances([string[]] $instanceIDs)
{
    try
    {
		if($InstanceIDs -ne $null)
        {
			foreach($InstanceID in $InstanceIDs)
            {
				#Create the image
				$imageId = CreateImageForInstance $InstanceId           
				
				#Wait for image creation to complete
				$imagesRequest = new-object amazon.EC2.Model.DescribeImagesRequest   
		
				$start = get-date             
				do
				{
					#abort if infinite loop or otherwise
					if(IsTimedOut $Start) { break } 
					
					#start-sleep -s 420
                    start-sleep -s 50
					$imagesResponse = $EC2_CLIENT.DescribeImages($imagesRequest.WithImageId($imageId))
					$imagesResult = $imagesResponse.DescribeImagesResult
				}
				while($imagesResult.Image[0].ImageState -ne "available") 
                AddTagToResource $imageId "Name" $imagesResult.Image[0].Description				
            }  
        }
        else
        {
            WriteToLogAndEmail "Image backup failed; no InstanceIDs to process"
        }
    }
    catch [Exception]
    {
        $function = "CreateImagesForInstances"
        $exception = $_.Exception.ToString()
        WriteToLogAndEmail "function$: $exception" -isException $true
    }
}
#Description: Creates an Amazon Web Service Image for a given instance Id
#Returns: string - newly created AMIID
function CreateImageForInstance([string] $instanceID)
{    
    try
    {
        #Generate meaningful description for image
        $date = get-date -format yyyyMMddhhmmss
        $name = GetInstanceName $instanceID
        $description = "{0} {1} {2}" -f $name, $BACKUP_TYPE, $date
                 
        WriteToLog "Instance $name ($instanceID) Creating Image"
                 
        $createImageRequest = new-object amazon.EC2.Model.CreateImageRequest
        $createImageResponse = $EC2_CLIENT.CreateImage($createImageRequest.WithInstanceId($instanceID).WithName($description).WithDescription($description).WithNoReboot($true))
		$createImageResult = $createImageResponse.CreateImageResult 

        WriteToLog "Image $name Created for $name ($instanceID)"
		return $createImageResult.ImageId
    }
    catch [Exception]
    {
        $function = "CreateImageForInstance"
        $exception = $_.Exception.ToString()
        #WriteToEmail "$name image failed, Exception:"
        WriteToLogAndEmail "function$: $exception" -isException $true
        return $null
    }
}

#Description: Creates an Amazon Web Service Snapshot for a given instance Id
#Returns: string - newly created snapshotID
function CreateSnapshotForInstance([string] $volumeID, [string] $instanceID)
{    
    try
    {
        #Generate meaningful description for snapshot
        $date = get-date -format yyyyMMddhhmmss
        $name = GetInstanceName $instanceID
        $description = "{0} {1} {2}" -f $name, $BACKUP_TYPE, $date
                 
        WriteToLog "Instance $name ($instanceID) Creating Snapshot"
                 
        $createSnapshotRequest = new-object amazon.EC2.Model.CreateSnapshotRequest
        $createSnapshotResponse = $EC2_CLIENT.CreateSnapshot($createSnapshotRequest.WithVolumeId($volumeID).WithDescription($description))
        $createSnapshotResult = $createSnapshotResponse.CreateSnapshotResult; 
        
        WriteToLog "Snapshot $description Created for $name ($instanceID)"
        #WriteToEmail "$name snapshot successful"
        return $createSnapshotResult.Snapshot.SnapshotId
    }
    catch [Exception]
    {
        $function = "CreateSnapshotForInstance"
        $exception = $_.Exception.ToString()
        #WriteToEmail "$name snapshot failed, Exception:"
        WriteToLogAndEmail "function$: $exception" -isException $true
        return $null
    }
}

#Description: Associates IPs for a collection of instance Ids
#Parameters: $stagingInstanceIPs hashtable[]
#Returns: n/a
function AssociateElasticIPs([hashtable] $stagingInstanceIPs)
{
    WriteToLogAndEmail "AssocElasicIPs."
    foreach ($ipKey in $stagingInstanceIPs.keys)  
    { 
        WriteToLogAndEmail "$ipKey assigned to $ipKey.value"
        $ipRequest = new-object amazon.EC2.Model.AssociateAddressRequest
        $ipResponse = $ipRequest.WithInstanceId($ipKey).WithPublicIp($stagingInstanceIPs.$ipKey)

        $ipResult = $EC2_CLIENT.AssociateAddress($ipResponse)
        if ($ipResult) {
          WriteToLogAndEmail "Address $stagingInstanceIPs.$ipKey assigned to $ipKey successfully."
        }
        else {
          WriteToLogAndEmail "Failed to assign $stagingInstanceIPs.$ipKey to $ipKey ."
        }
    }
}
#Description: Creates Amazon Web Service Snapshots for a collection of instance Ids
#Parameters: $instanceIDs string[]
#Returns: n/a
function CreateSnapshotsForInstances([string[]] $instanceIDs)
{
    try
    {
		if($InstanceIDs -ne $null)
        {
            
			$volumesRequest = new-object amazon.EC2.Model.DescribeVolumesRequest
            $volumesResponse = $EC2_CLIENT.DescribeVolumes($volumesRequest)
            $volumesResult = $volumesResponse.DescribeVolumesResult
            foreach($volume in $volumesResult.Volume)
            {

                if($InstanceIDs -contains $volume.Attachment[0].InstanceId)
                {            
                    #Create the snapshot
                    $snapshotId = CreateSnapshotForInstance $volume.VolumeId $volume.Attachment[0].InstanceId           

                    #Wait for snapshot creation to complete
                    $snapshotsRequest = new-object amazon.EC2.Model.DescribeSnapshotsRequest   
                    
                    $start = get-date             
                    do
                    {
                        #abort if infinite loop or otherwise
                        if(IsTimedOut $Start) { break } 
                        
                        start-sleep -s 5
                        $snapshotsResponse = $EC2_CLIENT.DescribeSnapshots($snapshotsRequest.WithSnapshotId($snapshotId))
                        $snapshotsResult = $snapshotsResponse.DescribeSnapshotsResult
                    }
                    while($snapshotsResult.Snapshot[0].Status -ne "completed")
                    AddTagToResource $snapshotId "Name" $snapshotsResult.Snapshot[0].Description	            
                    
                }            
            }  
        }
        else
        {
            WriteToLogAndEmail "Backup failed; no InstanceIDs to process"
        }
    }
    catch [Exception]
    {
        $function = "CreateSnapshotForInstances"
        $exception = $_.Exception.ToString()
        WriteToLogAndEmail "function$: $exception" -isException $true
    }
}
#Description: Returns true if passed date is before the current date minus $EXPIRATION_DAYS value
#Returns: bool
function IsDailySnapshotExpired([datetime] $backupDate)
{
    try
    {
        $expireDate = (get-date).AddDays($EXPIRATION_DAYS*-1)
        return ($backupDate) -lt ($expireDate)
    }
    catch [Exception]
    {
        $function = "IsDailySnapshotExpired"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return false
    }    
}
#Description: Returns true if passed date is before the current date minus $EXPIRATION_WEEKS value
#Parameters: $backupDate datetime
#Returns: bool
function IsWeeklySnapshotExpired([datetime] $backupDate)
{
    try
    {
        $expireDate = (get-date).AddDays(($EXPIRATION_WEEKS * 7) * -1)
        WriteToLog "Backup Date: $backupDate"
        WriteToLog "Expire Date: $expireDate"
        return ($backupDate) -lt ($expireDate)
    }
    catch [Exception]
    {
        $function = "IsWeeklySnapshotExpired"
        $exception = $_.Exception.ToString()
        WriteToLog "function$: $exception" -isException $true
        return false
    }    
}
#Description: Deleted old daily snapshots
#Parameters: n/a
#Returns: n/a
function CleanupDailySnapshots
{
    try
    {
        WriteToLog "Cleaning up daily snapshots"
        $deleteCount = 0
        
        $snapshots = GetAllSnapshots
        foreach($snapshot in $snapshots)
        {
            $description = $snapshot.Description
            $snapshotID = $snapshot.SnapshotId
            if($snapshot.Description.Contains("Daily"))
            {
                $backupDateTime = get-date $snapshot.StartTime
                $expired = IsDailySnapshotExpired $backupDateTime
                if($expired)
                {
                    DeleteSnapshot $snapshot.SnapshotId
                    $deleteCount ++
                    WriteToLog "$description ($snapshotID) Expired"
                }
                
            }
        }
        WriteToLogAndEmail "$deleteCount daily snapshots deleted"
    }
    catch [Exception]
    {
        $function = "CleanupDailySnapshots"
        $exception = $_.Exception.ToString()
        WriteToLogAndEmail "function$: $exception" -isException $true
        return false
    } 
}
#Description: Deregister old weekly amis
#Parameters: n/a
#Returns: n/a
function CleanupWeeklyAmis
{
    try
    {
        WriteToLog "Cleaning up weekly images"
        $deleteAmiCount = 0

        $amis = GetAllAmis
        foreach($ami in $amis)
        {
            $description = $ami.Description
            $amiID = $ami.ImageId
            if($ami.Description.Contains("Weekly"))
            {
                $a = $description.Substring($description.Length - 14)
                $backupDateTime=[datetime]::ParseExact($a,"yyyyMMddHHmmss",$null)
                $expired = IsWeeklySnapshotExpired $backupDateTime

                if($expired)
                {
                    DeregisterAMI $ami.ImageId
                    $deleteAmiCount ++
                    WriteToLog "$description ($amiID) Expired"
                    CleanupWeeklyImageSnapshots $amiID
                }
                
            }
        }
        WriteToLogAndEmail "$deleteAmiCount weekly amis deleted"
    }
    catch [Exception]
    {
        $function = "CleanupWeeklyAmis"
        $exception = $_.Exception.ToString()
        WriteToLogAndEmail "function$: $exception" -isException $true
        return false
    } 
}
#Description: Delete old weekly snapshots associated with images
#Parameters: Image Id
#Returns: n/a
function CleanupWeeklyImageSnapshots([string] $amiID)
{
    try
    {
        WriteToLog "Cleaning up old weekly image snapshots"
        $deleteCount = 0
        
        $snapshots = GetAllSnapshots
        foreach($snapshot in $snapshots)
        {
            $description = $snapshot.Description
            $snapshotID = $snapshot.SnapshotId
            WriteToLog "$amID"
            if($snapshot.Description.Contains("$amiID"))
            {
                $backupDateTime = get-date $snapshot.StartTime
                $expired = IsWeeklySnapshotExpired $backupDateTime
                if($expired)
                {
                    DeleteSnapshot $snapshot.SnapshotId
                    $deleteCount ++
                    WriteToLog "$description ($snapshotID) Expired"
                }
                
            }
        }
        WriteToLogAndEmail "$deleteCount weekly snapshots deleted"
    }
    catch [Exception]
    {
        $function = "CleanupWeeklyImageSnapshots"
        $exception = $_.Exception.ToString()
        WriteToLogAndEmail "function$: $exception" -isException $true
        return false
    } 
}
#Description: Deleted old weekly snapshots
#Parameters: n/a
#Returns: n/a
function CleanupWeeklySnapshots
{
    try
    {
        WriteToLog "Cleaning up weekly snapshots"
        $deleteCount = 0
        
        $snapshots = GetAllSnapshots
        foreach($snapshot in $snapshots)
        {
            $description = $snapshot.Description
            $snapshotID = $snapshot.SnapshotId
            if($snapshot.Description.Contains("Weekly"))
            {
                $backupDateTime = get-date $snapshot.StartTime
                $expired = IsWeeklySnapshotExpired $backupDateTime
                if($expired)
                {
                    DeleteSnapshot $snapshot.SnapshotId
                    $deleteCount ++
                    WriteToLog "$description ($snapshotID) Expired"
                }
                
            }
        }
        WriteToLogAndEmail "$deleteCount weekly snapshots deleted"
    }
    catch [Exception]
    {
        $function = "CleanupWeeklySnapshots"
        $exception = $_.Exception.ToString()
        WriteToLogAndEmail "function$: $exception" -isException $true
        return false
    } 
}