# Search the system path (Env:Path) directories for the existence for SQLite3.exe 

$path = (Get-ChildItem Env:Path).value.split("{;}");$i=0
foreach ($line in $path)
    {
        $i++; write-progress -Activity "Searching $line" -Status 'Progress->' -PercentComplete ($i/$path.count*100)
        Get-Childitem –Path $line -Recurse -Include 'sqlite3.exe' -ErrorAction SilentlyContinue
    }
