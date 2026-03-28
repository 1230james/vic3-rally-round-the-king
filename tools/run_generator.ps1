Write-Output "Rally Round the King - Monarchy Law Auto Replacer"
Write-Output ""

$game_dir = Read-Host "Enter path to Victora 3 folder"

Write-Output "Starting generator..."
./lua54.exe ./main.lua $game_dir | tee -append -filepath ./generator_log.log

Read-Host -Prompt "Press Enter to continue"
