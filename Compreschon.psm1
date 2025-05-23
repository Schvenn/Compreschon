# ----------------------------- Configuration -----------------------------

# Load the user configuration.
$baseModulePath = "$powershell\Modules\Compreschon"; $configPath = Join-Path $baseModulePath "Compreschon.psd1"
if (!(Test-Path $configPath)) {throw "Config file not found at $configPath"}
$config = Import-PowerShellDataFile -Path $configPath
$minimumlength = $config.PrivateData.minimumlength; $script:dictionaryfile = $config.PrivateData.dictionaryfile

# Obtain default dictionary and clean it, if necessary.
$dictionary = Get-Content -Path (Join-Path $baseModulePath $script:dictionaryfile) | ForEach-Object {($_ -replace '\W', '').Trim().ToLower()} | Where-Object {$_.Length -ge $minimumlength}

# ----------------------------- GetHelp -----------------------------

function gethelp {function scripthelp ($section) {# (Internal) Generate the help sections from the comments section of the script.
""; Write-Host -f yellow ("-" * 100); $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -f yellow; Write-Host -f yellow ("-" * 100)
if ($lines.Count -gt 1) {$lines[1] | Out-String | Out-Host -Paging}; Write-Host -f yellow ("-" * 100)}
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -f cyan; scripthelp $sections[0].Groups[1].Value; ""; return}
$selection = $null
do {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help Sections:`n" -f cyan; for ($i = 0; $i -lt $sections.Count; $i++) {
"{0}: {1}" -f ($i + 1), $sections[$i].Groups[1].Value}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
$input = Read-Host "`nEnter a section number to view"
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

# ----------------------------- Compreschon -----------------------------

function compresch {# Customizable compression/encryption mechanism.
param([string]$inputFile, [string]$alternatedictionary, [switch]$help)

# Obtain alternate dictionary if specified and clean it, if necessary.
if ($alternatedictionary) {$dictionary = Get-Content -Path (Join-Path $baseModulePath $alternatedictionary) | ForEach-Object {($_ -replace '\W', '').Trim().ToLower()} | Where-Object {$_.Length -ge $minimumlength}}

# Error-checking.
if ($help) {gethelp; return}
if (-not $inputFile) {Write-Host -f red "`nUsage: compresch <filename> <alternatedictionary> -help`n"; return}
if (-not (Test-Path $inputFile)) {Write-Host -f red "`nInput file not found: $inputFile`n"; return}

# Function to preserve case-sensitivity.
function Get-CasingMetadata {param($word); return ($word.ToCharArray() | ForEach-Object {if ($_ -cmatch '[A-Z]') {'1'} else {'0'}}) -join ''}

# Base36 helper function.
function Convert-ToBase36 {param([long]$value)
$chars = '0123456789abcdefghijklmnopqrstuvwxyz'
if ($value -eq 0) {return '0'}
$result = ''
while ($value -gt 0) {$result = $chars[$value % 36] + $result; $value = [math]::Floor($value / 36)}
return $result}

# Encrypt individual tokens helper function.
function encrypt-token {param([string]$token)
if ($token.Length -ge $minimumlength) {$fullIndex = $dictionary.IndexOf($token.ToLower())
if ($fullIndex -ge 0) {$binMeta = Get-CasingMetadata $token; $metaInt = [Convert]::ToInt64($binMeta, 2); $meta36 = Convert-ToBase36 $metaInt; $index36 = Convert-ToBase36 $fullIndex; Write-Host -f green "." -NoNewline; return "#$index36|$meta36¦"}}

# Fallback to partial matches
$output = ''; $pos = 0
while ($pos -lt $token.Length) {$maxLen = 0; $maxIndex = -1
for ($j = 0; $j -lt $dictionary.Count; $j++) {$dictWord = $dictionary[$j]
if ($pos + $dictWord.Length -le $token.Length) {$substr = $token.Substring($pos, $dictWord.Length)
if ($substr.ToLower() -eq $dictWord) {if ($dictWord.Length -gt $maxLen) {$maxLen = $dictWord.Length; $maxIndex = $j}}}}

if ($maxLen -gt 0) {$matched = $token.Substring($pos, $maxLen); $binMeta = Get-CasingMetadata $matched; $metaInt = [Convert]::ToInt64($binMeta, 2); $meta36 = Convert-ToBase36 $metaInt; $index36 = Convert-ToBase36 $maxIndex; $output += "#$index36|$meta36¦"; Write-Host -f green "." -NoNewline; $pos += $maxLen}
else {$output += $token[$pos]; $pos++}}
return $output}

# ----------------------------- Begin Main Compreschon Logic -----------------------------

# Obtain input file content and replace true "#"
$content = Get-Content -Raw -Path $inputFile; $content = $content -replace '#', '§'; $tokens = [regex]::Split($content, '(\b)')
for ($i = 0; $i -lt $tokens.Length; $i++) {$tokens[$i] = encrypt-token $tokens[$i]}
$compressedContent = ($tokens -join '')

# Output
$extension = [System.IO.Path]::GetExtension($inputFile); $compressedContent += "¦¦$extension¦¦"; $basename = [System.IO.Path]::GetFileNameWithoutExtension($inputFile); $outfile = "$basename.schvn"; Set-Content -Path $outfile -Value $compressedContent -Encoding UTF8; Write-Host -f cyan "`nCompressed file saved to: " -n; Write-Host -f yellow "$outfile`n"}

# ----------------------------- Decompreschon -----------------------------

function decompresch {# Decompression/decryption companion function.
param([string]$inputFile, [string]$alternatedictionary, [switch]$help)

# Obtain alternate dictionary if specified and clean it, if necessary.
if ($alternatedictionary) {$dictionary = Get-Content -Path (Join-Path $baseModulePath $alternatedictionary) | ForEach-Object {($_ -replace '\W', '').Trim().ToLower()} | Where-Object {$_.Length -ge $minimumlength}}

# Error-checking.
if ($help) {gethelp; return}
if (-not $inputFile) {Write-Host -f red "`nUsage: decompresch <filename> <alternatedictionary> -help`n"; return}
if (-not (Test-Path $inputFile)) {Write-Host -f red "`nInput file not found: $inputFile`n"; return}

# Function to restore case-sensitivity.
function Apply-CasingMetadata {param($word, $meta); $chars = $word.ToCharArray(); for ($i = 0; $i -lt $chars.Length -and $i -lt $meta.Length; $i++) {if ($meta[$i] -eq '1') {$chars[$i] = $chars[$i].ToString().ToUpper()}}; return -join $chars}

# Base36 helper function.
function Convert-FromBase36 {param([string]$value)
$chars = '0123456789abcdefghijklmnopqrstuvwxyz'; $result = 0; $value.ToCharArray() | ForEach-Object {$result = $result * 36 + $chars.IndexOf($_)}
return $result}

# Read compressed file content and handle file extension logic.
$content = Get-Content -Raw -Path $inputFile; $content = $content.TrimEnd(); $extensionPattern = '¦¦(.+?)¦¦\s*$'; $originalExtension = ''
if ($content -match $extensionPattern) {$originalExtension = $matches[1]; $content = $content -replace $extensionPattern, ''}
else {Write-Host -f red "`nOriginal file extension metadata not found. Using .txt instead.`n"; $originalExtension = '.txt'}

# Regex to match compressed words and replace with the original text. Also replace the § with the original #.
$pattern = '#([0-9a-z]+)(?:\|([0-9a-z]+))?¦'; $content = [regex]::Replace($content, $pattern, {param($match); $index36 = $match.Groups[1].Value; $meta36 = $match.Groups[2].Value; $index = Convert-FromBase36 $index36
if ($index -lt 0 -or $index -ge $dictionary.Count) {return $match.Value}
$word = $dictionary[$index]
if ($meta36) {$metaInt = Convert-FromBase36 $meta36; $mask = [Convert]::ToString($metaInt, 2).PadLeft($word.Length, '0'); $chars = $word.ToCharArray()
for ($i = 0; $i -lt $chars.Length; $i++) {if ($mask[$i] -eq '1') {$chars[$i] = $chars[$i].ToString().ToUpper()}}
return -join $chars} else {return $word}})
$content = $content -replace '§', '#'

# Output.
$outputFile = [System.IO.Path]::ChangeExtension($inputFile, $originalExtension); Set-Content -Path $outputFile -Value $content -Encoding UTF8; Write-Host -f cyan "`nDecompressed file saved to: " -n; Write-Host -f yellow "$outputFile`n"}

# ----------------------------- Dicschonary -----------------------------

function dicschonary {# Randomize a dictionary file in order to create a unique "pre-shared key" mechanism.
param ([string]$inputFile, [string]$outputFile, [switch]$help)

# Error-checking.
if ($help) {gethelp; return}
if (-not $inputFile -and -not $outputFile) {Write-Host -f red "`nUsage: dicschonary <inputFile> <outputFile>`nIf no inputFile is provided, the default dictionary will be used.`n"; return}
if ($inputFile -and -not $outputFile) {$outputFile = $inputFile; $inputFile = Join-Path $baseModulePath $script:dictionaryfile}
if (-not (Test-Path $inputFile)) {Write-Host -f red "`nInput file not found: $inputFile`n"; return}

# Read, shuffle, and write dictionary.
$words = Get-Content $inputFile | Where-Object {$_ -and $_.Trim() -ne ''}
$shuffled = $words | Get-Random -Count $words.Count; $shuffled | Set-Content $outputFile; Write-Host -f cyan "`nDictionary randomized and saved to: " -n; Write-Host -f yellow "$outputFile`n"}

Export-ModuleMember -Function compresch, decompresch, dicschonary

# ----------------------------- Help -----------------------------

<#
## Overview

The two primary functions allow you to encrypt and decrypt flat text files using a custom dictionary. In some cases, these files may even end up being smaller than their original. To be honest, this project started as a result of me investigating compression methodologies and attempting to understand how they work, thus the names compresch and decompresch.

The concept is reasonably simple. The module ships with an English dictionary consisting of nearly 5000 of the most popular English words according to Google, but with some modifications. I tried, through automated means, to reduce most words to their root, as opposed to keeping all of the extended versions of a word. So, I've included the word "encrypt", but not "encrypted", "encrypts" or "encrypting". The word "encryption" is actually included, but that's also because the automated method I used to strip words to their roots isn't perfect.

Secondly, I have only included words between 4 and 10 letters in length. This was done in the interests of performance and ensuring the highest probability of finding matching terms. I have also attempted to remove as many proper nouns as I could find. The result is a fairly streamlined dictionary which should provide a high ratio of matches. 

That being said, if you use this standard dictionary against a document that had highly specialized terms, such as medical terminology for example, it won't likely be very effective, but that's where the flexibility of this module comes into play though, because you don't have to use the included dictionary. You can use your own, custom dictionary and as soon as you do, the encryption mechanism becomes entirely unique to you. It is due to the nature of this approach that I decided to publish this module publicly, thereby giving people a very simple method of encrypting their own documents in a completely personalized way that does not require them to rely on a password to encrypt or decrypt. The dictionary you use acts as a type of pre-shared key, if you will, making it very flexible and easy to use.

## How Does It Work?

Usage: (compresch/decompresch) <filename> <alternatedictionary> -help

When you submit a file for compreschon, the function looks for a matching word in the dictionary. Failing that, it looks for the longest matching string within the word against a word in the dictionary. So, words I mentioned earlier like "encrypted" may not be a direct match, but the first portion of that word would be a match. The function would then continue by replacing "encrypt" with the encrypted value and leave the last two letters untouched. 

The function replaces as many words as possible with the numerical reference to that word in the dictionary, using a base36 value to represent its location and another base36 value to represent which letters are capitalized. The capitalization is actually a binary value representing each place in the word; 0 for lower-case and 1 for upper-case. The word "Frank" for example, is included in the dictionary, because it's an adjective and is found at location 1752, or "1co" via base 36. The capitalization for that word would be represented in binary as "10000". While this is a very logical way to represent capitalization, it would also take up a lot of space. The base 36 equivalent however would simply be "g". Put that together and the word "Frank" is replaced in the document with "#1co|g¦". While that's 2 characters longer than the original word, there are many instances where the replacement value will be shorter than the original word and when that happens, it's possible for the function to act as a form of compression, as well as a form of encryption.

Once the encryption of every word in the document is complete, the file will be saved with a .schvn extension and it can only be decrypted by the accompanying decompresch function, using the same dictionary that was used to create it. In the interests of simplicity, the original extension is stored in the encrypted file, so when it is decrypted, the file will be restored with it's original name and extension.
## Configuration

The module includes a .PSD1 file for configuration. In it there are only 2 lines you need to adjust, if you so choose:

@{ModuleVersion = '1.0'
RootModule = 'Compresch.psm1'
PrivateData = @{minimumlength = 4
dictionaryfile = 'Dictionary.schvn'}}

The minimumlength value tells the compresch function the smallest words to replace with an indexed value. The default it set to 4. Smaller values will lead to encrypted files that are larger than their original and setting a larger value, while it will likely encrypt files faster, will lead to less encrypted content, which means that the resulting file may be easier to read, even without the dictionary. So, I wouldn't reccommend using values less than 4 or greater than 6.

The dictionaryfile value is the name of your custom dictionary, which must be located in the same directory as the module in order for it to work properly.

## Dictionary Randomization/Pre-Shared Key Creation

Usage: dicschonary <inputfile> <outputfile>

I have also included a dictionary randomizer which allows you to take any dictionary and randomize the entries, thereby creating a unique version for your own use. If no input file is provided, the function will randomize the default dictionary and save it to the output location, instead.

If you're wondering how secure that method could possibly be, well it works out to log10(4717!) ≈ 14899 digits and since there are only about 10^80 atoms in the observable universe, which is 10 followed by 80 digits, I think we can assume that randomizing just this dictionary alone would be enough to make brute force impossible. Therefore, you can use this to create as many dictionaries as you need, but remember to share the randomized version of the dictionary with the user or system that needs to decrypt the files created using that dictionary. Otherwise, the content will be lost and very likely impossible to recover.
##>
