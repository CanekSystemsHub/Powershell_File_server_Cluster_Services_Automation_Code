Get-ChildItem -Path C:\Windows\System32 | where {($_.Name -like "*.dll") -and ($_.Length -gt 20MB)} 

Get-ChildItem -Path C:\Windows\System32 | where {($_.Name -like "*.exe") -and ($_.LastAccessTime -ge (Get-Date).AddMonths(-1))} 


wwhile ($x -gt 0)
 {
     
 }