 # Exports ipswitch imail groupware database user folders to csv
 # for VCARD/VEVENT/VTODO conversion and import to IceWarp server
 function Invoke-Sqlcommand { 
          [CmdletBinding()] 
            param( 
            [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance, 
            [Parameter(Position=1, Mandatory=$false)] [string]$Database, 
            [Parameter(Position=2, Mandatory=$false)] [string]$Query, 
            [Parameter(Position=3, Mandatory=$false)] [string]$Username, 
            [Parameter(Position=4, Mandatory=$false)] [string]$Password, 
            [Parameter(Position=5, Mandatory=$false)] [Int32]$QueryTimeout=600, 
            [Parameter(Position=6, Mandatory=$false)] [Int32]$ConnectionTimeout=15, 
            [Parameter(Position=7, Mandatory=$false)] [ValidateScript({test-path $_})] [string]$InputFile, 
            [Parameter(Position=8, Mandatory=$false)] [ValidateSet("DataSet", "DataTable", "DataRow")] [string]$As="DataRow" 
            ) 

            if ($InputFile) 
            { 
                $filePath = $(resolve-path $InputFile).path 
                $Query =  [System.IO.File]::ReadAllText("$filePath") 
            } 

            $conn=new-object System.Data.SqlClient.SQLConnection 

            if ($Username) 
            { $ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4}" -f $ServerInstance,$Database,$Username,$Password,$ConnectionTimeout } 
            else 
            { $ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $ServerInstance,$Database,$ConnectionTimeout } 

            $conn.ConnectionString=$ConnectionString 

            #Following EventHandler is used for PRINT and RAISERROR T-SQL statements. Executed when -Verbose parameter specified by caller 
            if ($PSBoundParameters.Verbose) 
            { 
                $conn.FireInfoMessageEventOnUserErrors=$true 
                $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {Write-Verbose "$($_)"} 
                $conn.add_InfoMessage($handler) 
            } 

            $conn.Open() 
            $cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn) 
            $cmd.CommandTimeout=$QueryTimeout 
            $ds=New-Object system.Data.DataSet 
            $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd) 
            [void]$da.fill($ds) 
            $conn.Close() 
            switch ($As) 
            { 
                'DataSet'   { Write-Output ($ds) } 
                'DataTable' { Write-Output ($ds.Tables) } 
                'DataRow'   { Write-Output ($ds.Tables[0]) } 
            } 

        } 

function notemptytable($a, $b, $c) {
$itemcount="";
$itemcount=Invoke-Sqlcommand -ServerInstance $SQLInstance -Database $Database -Query "SELECT COUNT(*) FROM ${a} WHERE Owner = ${b} AND Folder = ${c};" -Username $ID -Password $Password | ConvertTo-Csv -NoTypeInformation | Select -last 1
$itemcount=$itemcount.Replace("`"","")
#$itemcount=echo $itemcount.split(" ",[System.StringSplitOptions]::RemoveEmptyEntries) | Select -last 1
echo "Itemcount ${a} - ${b} - ${c}: [ ${itemcount}]." >> $logfile
if (([string]::IsNullOrEmpty($itemcount))) { return [bool]$false }
if ( $itemcount -eq 0 ) { return [bool]$false }
if ( $itemcount -gt 0 ) { return [bool]$true }
}

function runexport {
    foreach($line in $csv) { 
        $properties = $line | Get-Member -MemberType Properties
        $useremail = $properties[0]
        $userid = $properties[5]
        $userfoldername = $properties[3]
        $userfoldertype = $properties[2]
        $userfolderparent = $properties[4]
        $userfolderid = $properties[1]
        $email = $line | Select -ExpandProperty $useremail.Name
        $uid = $line | Select -ExpandProperty $userid.Name
        $foldername = $line | Select -ExpandProperty $userfoldername.Name
        $folderid = $line | Select -ExpandProperty $userfolderid.Name
        $foldertype = $line | Select -ExpandProperty $userfoldertype.Name
        $folderparent = $line | Select -ExpandProperty $userfolderparent.Name
        if ( $foldername -match '=\?.*\?=' )
           {
           $charset=$foldername -replace '=\?(.*)\?.\?(.*)\?=','$1'
           $foldername=$foldername -replace '=\?(.*)\?.\?(.*)\?=','$2'
           $foldername=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("$foldername"))   
           }
        $foldername=$foldername.replace(':','_')
        echo "Running user ID: [$uid], user email: [$email], folderid: [$folderid], foldername: [$foldername], foldertype: [$foldertype], folderparent: [$folderparent]." >> $logfile
        #New-Item -ItemType directory -Force "export/$email" 
        $dstpath=""
        while ($folderparent -ne 0) {
            $tmppath=Invoke-Sqlcommand -ServerInstance $SQLInstance -Database $Database -Query "SELECT Name FROM Folders WHERE ID = $folderparent;" -Username $ID -Password $Password | ConvertTo-Csv -NoTypeInformation | Select -last 1
            if ( $tmppath -match '=\?.*\?=' )
               {
               $tmppath=$tmppath.Replace("`"","")
               $charset=$tmppath -replace '=\?(.*)\?.\?(.*)\?=','$1'
               $tmppath=$tmppath -replace '=\?(.*)\?B\?(.*)\?=','$2'
               $tmppath=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("$tmppath"))   
               }
            if (-not ([string]::IsNullOrEmpty($tmppath))) { $tmppath=$tmppath.Replace("`"","") } else { $tmppath="VOID_" + "$folderparent" + "/" + "$dstpath"; break }
            $dstpath="$tmppath/$dstpath"
            $folderparent=Invoke-Sqlcommand -ServerInstance $SQLInstance -Database $Database -Query "SELECT Parent FROM Folders WHERE ID = $folderparent;" -Username $ID -Password $Password | ConvertTo-Csv -NoTypeInformation | Select -last 1
            if (-not ([string]::IsNullOrEmpty($folderparent))) { $folderparent=$folderparent.Replace("`"","") }
        }
        $dstpath="export/" + "$uid" + "_" + "$email" + "/" +"$dstpath"
        #echo "Dstpath test: [ $dstpath ]"
        $null = New-Item -ItemType directory -Force "$dstpath"
        switch ( $foldertype ) 
        {
            Contacts 
            {
            if (notemptytable Contacts $uid $folderid)
               {
                Invoke-Sqlcommand -ServerInstance $SQLInstance -Database $Database -Query "SELECT [ID]
      ,[Name]
      ,[Owner]
      ,[Folder]
      ,[JobTitle]
      ,[Company]
      ,[WebPageAddress]
      ,[IMAddress]
      ,[Private]
      ,[FileAs]
      ,[Department]
      ,[Office]
      ,[ManagersName]
      ,[AssistantsName]
      ,[Profession]
      ,[Spouse]
      ,[Anniversary]
      ,[Birthday]
      ,[Nickname]
      ,[MailingAddress]
      ,[DistList]
      ,[Title]
      ,[FirstName]
      ,[MiddleName]
      ,[LastName]
      ,[Suffix]
      ,[MessageClass]
      ,[Contacts]
	  , ( SELECT TOP 1 [Address] FROM [WorkgroupShare].[dbo].[EmailAddresses] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Email-1' ) AS Email1
	  , ( SELECT TOP 1 [Address] FROM [WorkgroupShare].[dbo].[EmailAddresses] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Email-2' ) AS Email2
	  , ( SELECT TOP 1 [Address] FROM [WorkgroupShare].[dbo].[EmailAddresses] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Email-3' ) AS Email3
	  , ( SELECT TOP 1 [Number] FROM [WorkgroupShare].[dbo].[PhoneNumbers] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Home-Phone' ) AS HomePhone
	  , ( SELECT TOP 1 [Number] FROM [WorkgroupShare].[dbo].[PhoneNumbers] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Mobile-Phone' ) AS MobilePhone
	  , ( SELECT TOP 1 [Number] FROM [WorkgroupShare].[dbo].[PhoneNumbers] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Bussiness-Phone' ) AS BussinessPhone
      , ( SELECT TOP 1 [Number] FROM [WorkgroupShare].[dbo].[PhoneNumbers] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Bussiness-Fax' ) AS BussinessFax
	  , ( SELECT TOP 1 [Address1] FROM [WorkgroupShare].[dbo].[Addresses] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Home-Address' ) AS HomeAddr1
	  , ( SELECT TOP 1 [Town] FROM [WorkgroupShare].[dbo].[Addresses] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Home-Address' ) AS HomeAddrTown
	  , ( SELECT TOP 1 [County] FROM [WorkgroupShare].[dbo].[Addresses] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Home-Address' ) AS HomeAddrCounty
	  , ( SELECT TOP 1 [Country] FROM [WorkgroupShare].[dbo].[Addresses] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Home-Address' ) AS HomeAddrCountry
	  , ( SELECT TOP 1 [Postcode] FROM [WorkgroupShare].[dbo].[Addresses] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Home-Address' ) AS HomeAddrPostcode
	  , ( SELECT TOP 1 [Address1] FROM [WorkgroupShare].[dbo].[Addresses] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Bussiness-Address' ) AS BussinessAddr1
	  , ( SELECT TOP 1 [Town] FROM [WorkgroupShare].[dbo].[Addresses] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Bussiness-Address' ) AS BussinessAddrTown
	  , ( SELECT TOP 1 [County] FROM [WorkgroupShare].[dbo].[Addresses] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Bussiness-Address' ) AS BussinessAddrCounty
	  , ( SELECT TOP 1 [Country] FROM [WorkgroupShare].[dbo].[Addresses] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Bussiness-Address' ) AS BussinessAddrCountry
	  , ( SELECT TOP 1 [Postcode] FROM [WorkgroupShare].[dbo].[Addresses] WHERE OwnerID = [WorkgroupShare].[dbo].[Contacts].[ID] AND Name = 'Bussiness-Address' ) AS BussinessAddrPostcode
      FROM [WorkgroupShare].[dbo].[Contacts]
      WHERE Owner = ${uid} AND Folder = ${folderid} AND DistList = 0;" -Username $ID -Password $Password | ConvertTo-Csv -NoTypeInformation | Out-File "${dstpath}/${foldername}.cnt.csv"
                $ctlt=(Get-Content ${dstpath}/${foldername}.cnt.csv).Length
                echo "Exported ${dstpath}/${foldername}.cnt.csv length: [$ctlt]" >> $logfile
               }
            }
            Appointments
            {
            if (notemptytable Appointments $uid $folderid)
               {
                Invoke-Sqlcommand -ServerInstance $SQLInstance -Database $Database -Query "SELECT a.ID
      ,a.Owner
	  ,a.Folder
	  ,a.Name
	  ,a.Start
	  ,a.Duration
	  ,a.Created
	  ,a.Modified
	  ,a.Location
	  ,a.AllDay
	  ,a.Private
	  ,a.Recurrence
	  ,a.Organizer
	  ,a.RequiredAttendees
	  ,a.OptionalAttendees
      ,REPLACE(REPLACE(n.Text, CHAR(13), ''), CHAR(10), '')
      ,r.*
	  FROM Appointments a
	  LEFT JOIN Notes n
	  ON a.ID = n.OwnerID
      LEFT JOIN Recurrences r
      ON a.ID = r.ID
	  WHERE a.Owner = ${uid} AND a.Folder = ${folderid};" -Username $ID -Password $Password | ConvertTo-Csv -NoTypeInformation | Out-File "${dstpath}/${foldername}.cal.csv"
                $ctlt=(Get-Content ${dstpath}/${foldername}.cal.csv).Length
                echo "Exported ${dstpath}/${foldername}.cal.csv length: [$ctlt]" >> $logfile
               }
            }
            Tasks 
            {
            if (notemptytable Tasks $uid $folderid)
               {
                Invoke-Sqlcommand -ServerInstance $SQLInstance -Database $Database -Query "SELECT t.ID
       ,t.Owner
	   ,t.Folder
	   ,t.Name
	   ,t.Start
	   ,t.Deadline
	   ,t.Created
	   ,t.Modified
	   ,t.Completed
	   ,t.Status
	   ,t.PercentageComplete
	   ,t.TotalWork
	   ,t.ActualWork
	   ,t.Mileage
	   ,t.BillingInformation
	   ,t.Private
	   ,t.Recurrence
	   ,t.Priority
	   ,t.Companies
	   ,t.AssignedTo
	   ,t.Reminder
	   ,t.RemindTime
       ,REPLACE(REPLACE(n.Text, CHAR(13), ''), CHAR(10), '')
       ,r.*
	   FROM Tasks t
	   LEFT JOIN Notes n
	   ON t.ID = n.OwnerID
       LEFT JOIN Recurrences r
       ON t.ID = r.ID
	   WHERE t.Owner = ${uid} AND t.Folder = ${folderid};" -Username $ID -Password $Password | ConvertTo-Csv -NoTypeInformation | Out-File "${dstpath}/${foldername}.tsk.csv"
                $ctlt=(Get-Content ${dstpath}/${foldername}.tsk.csv).Length
                echo "Exported ${dstpath}/${foldername}.cnt.csv length: [$ctlt]" >> $logfile
               }
            }
            NoteItems
            {if (notemptytable NoteItems $uid $folderid)
                {
                 Invoke-Sqlcommand -ServerInstance $SQLInstance -Database $Database -Query "SELECT i.ID, i.Owner, i.Folder, i.Private, i.Name FROM NoteItems AS i WHERE Owner = $uid AND Folder = $folderid;" -Username $ID -Password $Password | ConvertTo-Csv -NoTypeInformation | Out-File "${dstpath}/${foldername}.nts.csv"
                 $ctlt=(Get-Content ${dstpath}/${foldername}.nts.csv).Length
                 echo "Exported ${dstpath}/${foldername}.cnt.csv length: [$ctlt]" >> $logfile
                }
            }
        }
        #echo "Finished user ID: [$uid], user email: [$email], folderid: [$folderid], foldername: [$foldername]."
        #echo " --- "
        echo "" >> $logfile        
    }
}
# MAIN
$SQLInstance = "sqlsrv.example.local" # DB host/IP
$Database = "WorkgroupShare" # imail DB default name
$ID = "dbuser" # DB user with read access to WorkgroupShare DB 
$Password = "dbpass" # DB user password
Invoke-Sqlcommand -ServerInstance $SQLInstance -Database $Database -Query "SELECT u.ID AS UID, u.Email, f.Name, f.ID AS FID, f.ItemTable, f.Parent FROM Users AS u, Folders AS f WHERE u.ID = f.Owner ORDER BY UID, FID ASC;" -Username $ID -Password $Password | ConvertTo-Csv -NoTypeInformation | % {$_.Replace('"','')} | Out-File userid_email_foldername.csv
$csvpath = "userid_email_foldername.csv"
$csv = Import-Csv -path $csvpath 
$logfile = "export.log.txt"
echo "Started: $(Get-Date -UFormat "%A %m/%0/%Y %R %2")" > $logfile
echo "" >> $logfile
runexport
echo "Finished: $(Get-Date -UFormat "%A %m/%0/%Y %R %2")" >> $logfile
 
