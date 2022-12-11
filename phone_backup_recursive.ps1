

$ErrorActionPreference = [string]"Stop"
$Summary = [Hashtable]@{NewFilesCount=0; ExistingFilesCount=0; SkippedFilesCount=0; Total=0;}

function Create-Dir($path)
{
  if(! (Test-Path -Path $path))
  {
    Write-Host "Creating: $path"
    New-Item -Path $path -ItemType Directory
  }
  else
  {
    Write-Host "Path $path already exist"
  }
}


function Get-SubFolder($parentDir, $subPath)
{
  $result = $parentDir
  foreach($pathSegment in ($subPath -split "\\"))
  {
    $result = $result.GetFolder.Items() | Where-Object {$_.Name -eq $pathSegment} | select -First 1
    if($result -eq $null)
    {
      throw "Not found $subPath folder"
    }
  }
  return $result;
}


function Get-PhoneMainDir($phoneName)
{
  $o = New-Object -com Shell.Application
  $rootComputerDirectory = $o.NameSpace(0x11)
  $phoneDirectory = $rootComputerDirectory.Items() | Where-Object {$_.Name -eq $phoneName} | select -First 1
    
  if($phoneDirectory -eq $null)
  {
    throw "Not found '$phoneName' folder in This computer. Connect your phone."
  }
  
  return $phoneDirectory;
}


function Get-FullPathOfMtpDir($mtpDir)
{
 $fullDirPath = ""
 $directory = $mtpDir.GetFolder
 while($directory -ne $null)
 {
   $fullDirPath =  -join($directory.Title, '\', $fullDirPath)
   $directory = $directory.ParentFolder;
 }
 return $fullDirPath
}



function Copy-FromPhoneSource-ToBackup($sourceMtpDir, $destDirPath)
{

 $destDirPath = (Join-Path $destDirPath $sourceMtpDir.GetFolder.Title)
 Create-Dir $destDirPath
 $destDirShell = (new-object -com Shell.Application).NameSpace($destDirPath)
 $fullSourceDirPath = Get-FullPathOfMtpDir $sourceMtpDir

 
 Write-Host "Copying from: '" $fullSourceDirPath "' to '" $destDirPath "'"
 
 $copiedCount, $existingCount, $skippedCount = 0
 
 foreach ($item in $sourceMtpDir.GetFolder.Items())
  {
   $itemName = ($item.Name)
   $fullFilePath = Join-Path -Path $destDirPath -ChildPath $itemName

   if($item.IsFolder)
   {
      Write-Host $item.Name " is folder, stepping into"
      Copy-FromPhoneSource-ToBackup  $item (Join-Path $destDirPath $item.GetFolder.Title)
   }
   elseif(Test-Path $fullFilePath)
   {
      Write-Host "Element '$itemName' already exists"
      $existingCount++;
   }
   elseif($item.Name -notlike '*.AAE' <# -and $item.Name -notlike '*.MOV' #>)
   {
     $copiedCount++;
     Write-Host ("Copying #{0}: {1}{2}" -f $copiedCount, $fullSourceDirPath, $item.Name)
     $destDirShell.CopyHere($item)
   }
   else {
    $skippedCount++
    Write-Host ("Skipping {0}" -f $item.Name)
   }
  }
  $script:Summary.NewFilesCount += $copiedCount 
  $script:Summary.ExistingFilesCount += $existingCount 
  $script:Summary.SkippedFilesCount += $skippedCount 
  $script:Summary.Total = $copiedCount + $existingCount  + $skippedCount
  Write-Host "Copied '$copiedCount' elements from '$fullSourceDirPath'"
}


$DestDir = [string]"E:\iPhone 11PM Backup" #this is where backups will be placed
$phoneName = "Apple iPhone" #iPhone name as it appears in This PC
$phoneRootDir = Get-PhoneMainDir $phoneName

#Set the folder name after opening the folder in explorer. Otherwise it won't recognise all the files.
$folderName = "Internal Storage\DCIM\202208__" #have to do this manually for each folder.

Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir $folderName) $DestDir
write-host ($Summary | out-string)