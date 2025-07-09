function compresch ([string]$inputFile, [string]$alternatedictionary, [string]$mode, [switch]$help) {# Customizable compression/compreschion mechanism.
# ----------------------------- Configuration ---------------------------------

# Load the user configuration.
$baseModulePath = "$powershell\Modules\Compreschon"; $configPath = Join-Path $baseModulePath "Compreschon.psd1"
if (!(Test-Path $configPath)) {throw "Config file not found at $configPath"}
$config = Import-PowerShellDataFile -Path $configPath
$minimumlength = $config.PrivateData.minimumlength; $script:dictionaryfile = $config.PrivateData.dictionaryfile

# Obtain default dictionary and clean it, if necessary.
function loaddictionary ($file) {if ($file -like '*.gz') {$stream = [IO.File]::OpenRead($file); $gzip = New-Object IO.Compression.GzipStream($stream, [IO.Compression.CompressionMode]::Decompress); $reader = New-Object IO.StreamReader($gzip); $lines = @()
while (-not $reader.EndOfStream) {$lines += $reader.ReadLine()}
$reader.Close(); $gzip.Close(); $stream.Close(); return $lines}
else {return Get-Content $file}}
$rawDict = loaddictionary (Join-Path $baseModulePath $script:dictionaryfile); $dictionary = $rawDict | ForEach-Object {($_ -replace '\W', '').Trim().ToLower()} | Where-Object {$_.Length -ge $minimumlength}

# ----------------------------- Help ------------------------------------------

# Modify fields sent to it with proper word wrapping.
function wordwrap ($field, $maximumlinelength) {if ($null -eq $field) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()
if (-not $maximumlinelength) {[int]$maximumlinelength = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($maximumlinelength -lt 60) {[int]$maximumlinelength = 60}
if ($maximumlinelength -gt $Host.UI.RawUI.BufferSize.Width) {[int]$maximumlinelength = $Host.UI.RawUI.BufferSize.Width}
foreach ($line in $field -split "`n", [System.StringSplitOptions]::None) {if ($line -eq "") {$wrapped += ""; continue}
$remaining = $line
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1
foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1}
$chunk = $segment.Substring(0, $breakIndex + 1); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1)}
if ($remaining.Length -gt 0 -or $line -eq "") {$wrapped += $remaining}}
return ($wrapped -join "`n")}

# Display a horizontal line.
function line ($colour, $length, [switch]$pre, [switch]$post, [switch]$double) {if (-not $length) {[int]$length = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($length) {if ($length -lt 60) {[int]$length = 60}
if ($length -gt $Host.UI.RawUI.BufferSize.Width) {[int]$length = $Host.UI.RawUI.BufferSize.Width}}
if ($pre) {Write-Host ""}
$character = if ($double) {"="} else {"-"}
Write-Host -f $colour ($character * $length)
if ($post) {Write-Host ""}}

# Inline help.
if ($help) {function scripthelp ($section) {line yellow 100 -pre; $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -f yellow; line yellow 100
if ($lines.Count -gt 1) {wordwrap $lines[1] 100 | Out-String | Out-Host -Paging}; line yellow 100}

$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -f cyan; scripthelp $sections[0].Groups[1].Value; ""; return}
$selection = $null
do {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help Sections:`n" -f cyan; for ($i = 0; $i -lt $sections.Count; $i++) {"{0}: {1}" -f ($i + 1), $sections[$i].Groups[1].Value}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
$input = Read-Host "`nEnter a section number to view"
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

# Obtain alternate dictionary if specified and clean it, if necessary.
if ($alternatedictionary) {$dictionary = Get-Content -Path (Join-Path $baseModulePath $alternatedictionary) | ForEach-Object {($_ -replace '\W', '').Trim().ToLower()} | Where-Object {$_.Length -ge $minimumlength}}

# Error-checking.
if (-not $inputFile) {Write-Host -f red "`nUsage: compresch <filename> <alternatedictionary> -mode <decompresch|extract> -help`n"; return}
if (-not (Test-Path $inputFile)) {Write-Host -f red "`nInput file not found: $inputFile`n"; return}

# ----------------------------- Decompreschon -----------------------------

if ($mode -match "(?i)^(decompresch|extract)") {# Decompression/decompreschion companion function.

# Base36 helper function.
function convertfrombase36 {param([string]$value)
$chars = '0123456789abcdefghijklmnopqrstuvwxyz'; $result = 0; $value.ToCharArray() | ForEach-Object {$result = $result * 36 + $chars.IndexOf($_)}
return $result}

# Read compressed file content and handle file extension logic.
$content = Get-Content -Raw -Path $inputFile; $content = $content.TrimEnd(); $extensionPattern = '¦¦(\.\w+)¦¦\r?\n?$'; $originalExtension = ''
if ($content -match $extensionPattern) {$originalExtension = $matches[1]; $content = $content -replace $extensionPattern, ''}
else {Write-Host -f red "`nOriginal file extension metadata not found. Using .txt instead.`n"; $originalExtension = '.txt'}

# Regex to match compressed words and replace with the original text. Also replace the § with the original #.
$pattern = '#([0-9a-z]+)(?:\|([0-9a-z]+))?¦'; $content = [regex]::Replace($content, $pattern, {param($match); $index36 = $match.Groups[1].Value; $meta36 = $match.Groups[2].Value; $index = convertfrombase36 $index36
if ($index -lt 0 -or $index -ge $dictionary.Count) {return $match.Value}
$word = $dictionary[$index]
if ($meta36) {$metaInt = convertfrombase36 $meta36; $mask = [Convert]::ToString($metaInt, 2).PadLeft($word.Length, '0'); $chars = $word.ToCharArray()
for ($i = 0; $i -lt $chars.Length; $i++) {if ($mask[$i] -eq '1') {$chars[$i] = $chars[$i].ToString().ToUpper()}}
return -join $chars} else {return $word}})
$content = $content -replace '§', '#' -replace '°', "`r" -replace '¬', "`n" -replace '†', ' ' -replace '‡', '-----'

# Output.
$outputFile = [System.IO.Path]::ChangeExtension($inputFile, $originalExtension); $outputFile = $outputFile -replace '.schvn.', '.'; Set-Content -Path $outputFile -Value $content -Encoding UTF8; Write-Host -f cyan "`nDecompressed file saved to: " -n; Write-Host -f yellow "$outputFile`n"; return}

# ----------------------------- End of Decompreschon -----------------------------
# ----------------------------- Dicschonary -----------------------------

if ($mode -match "(?i)^dic(schonary)?")  {# Randomize a dictionary file in order to create a unique "pre-shared key" mechanism.
$outputFile = $alternatedictionary

# Error-checking.
if (-not $inputFile -and -not $outputFile) {Write-Host -f red "`nUsage: dicschonary <inputFile> <outputFile>`nIf no inputFile is provided, the default dictionary will be used.`n"; return}
if ($inputFile -and -not $outputFile) {$outputFile = $inputFile; $inputFile = Join-Path $baseModulePath $script:dictionaryfile}
if (-not (Test-Path $inputFile)) {Write-Host -f red "`nInput file not found: $inputFile`n"; return}

# Read, shuffle, and write dictionary.
$words = Get-Content $inputFile | Where-Object {$_ -and $_.Trim() -ne ''}
$shuffled = $words | Get-Random -Count $words.Count; $shuffled | Set-Content $outputFile; Write-Host -f cyan "`nDictionary randomized and saved to: " -n; Write-Host -f yellow "$outputFile`n"; return}

# ----------------------------- End of Dicschonary -----------------------------

# Function to preserve case-sensitivity.
function getcasingmetadata {param($word); return ($word.ToCharArray() | ForEach-Object {if ($_ -cmatch '[A-Z]') {'1'} else {'0'}}) -join ''}

# Base36 helper function.
function converttobase36 {param([long]$value)
$chars = '0123456789abcdefghijklmnopqrstuvwxyz'
if ($value -eq 0) {return '0'}
$result = ''
while ($value -gt 0) {$result = $chars[$value % 36] + $result; $value = [math]::Floor($value / 36)}
return $result}

# compresch individual tokens helper function.
function compreschtoken {param([string]$token)
if ($token.Length -ge $minimumlength) {$fullIndex = $dictionary.IndexOf($token.ToLower())
if ($fullIndex -ge 0) {$binMeta = getcasingmetadata $token; $metaInt = [Convert]::ToInt64($binMeta, 2); $meta36 = converttobase36 $metaInt; $index36 = converttobase36 $fullIndex; Write-Host -f darkgreen "·" -n; return "#$index36|$meta36¦"}}

# Fallback to partial matches
$output = ''; $pos = 0
while ($pos -lt $token.Length) {$maxLen = 0; $maxIndex = -1
for ($j = 0; $j -lt $dictionary.Count; $j++) {$dictWord = $dictionary[$j]
if ($pos + $dictWord.Length -le $token.Length) {$substr = $token.Substring($pos, $dictWord.Length)
if ($substr.ToLower() -eq $dictWord) {if ($dictWord.Length -gt $maxLen) {$maxLen = $dictWord.Length; $maxIndex = $j}}}}

if ($maxLen -gt 0) {$matched = $token.Substring($pos, $maxLen); $binMeta = getcasingmetadata $matched; $metaInt = [Convert]::ToInt64($binMeta, 2); $meta36 = converttobase36 $metaInt; $index36 = converttobase36 $maxIndex; $output += "#$index36|$meta36¦"; Write-Host -f darkyellow "." -n; $pos += $maxLen}
else {$output += $token[$pos]; $pos++}}
return $output}

# ----------------------------- Begin Main Compreschon Logic -----------------------------

# Obtain input file content and replace true "#"
$content = Get-Content -Raw -Path $inputFile; $content = $content -replace '#', '§'; $tokens = [regex]::Split($content, '(\b)')
for ($i = 0; $i -lt $tokens.Length; $i++) {$tokens[$i] = compreschtoken $tokens[$i]}
$compressedContent = ($tokens -join '') -replace "`r", '°' -replace "`n", '¬' -replace ' ', '†' -replace '-----', '‡'

# Output
$extension = [System.IO.Path]::GetExtension($inputFile); $compressedContent += "¦¦$extension¦¦"; $basename = [System.IO.Path]::GetFileNameWithoutExtension($inputFile); $outfile = "$basename.schvn.dat"; Set-Content -Path $outfile -Value $compressedContent -Encoding UTF8; Write-Host -f cyan "`nCompressed file saved to: " -n; Write-Host -f yellow "$outfile`n"}

Export-ModuleMember -Function compresch

<#
## Overview

The two primary functions allow you to compresch and decompresch flat text files using a custom dictionary. In some cases, these files may even end up being smaller than their original. To be honest, this project started as a result of me investigating compression methodologies and attempting to understand how they work, thus the name compreschon.

The concept is reasonably simple. The module ships with an English dictionary consisting of nearly 5000 of the most popular English words according to Google, but with some modifications. I tried, through automated means, to reduce most words to their root, as opposed to keeping all of the extended versions of a word. So, I've included the word "impress", but not "impressed", "impresses" or "impressing". The word "impression" is actually included, but that's also because the automated method I used to strip words to their roots isn't perfect.

Secondly, I have only included words between 4 and 10 letters in length. This was done in the interests of performance and ensuring the highest probability of finding matching terms. I have also attempted to remove as many proper nouns as I could find. The result is a fairly streamlined dictionary which should provide a high ratio of matches. 

That being said, if you use this standard dictionary against a document that had highly specialized terms, such as medical terminology for example, it won't likely be very effective, but that's where the flexibility of this module comes into play though, because you don't have to use the included dictionary. You can use your own, custom dictionary and as soon as you do, the compreschion mechanism becomes entirely unique to you. It is due to the nature of this approach that I decided to publish this module publicly, thereby giving people a very simple method of compresching their own documents in a completely personalized way that does not require them to rely on a password to compresch or decompresch. The dictionary you use acts as a type of pre-shared key, if you will, making it very flexible and easy to use.

Is it fast? Nope. It took 3:59:22 to compresch the 2.7MB SOWPODS (International Scrabble English dictionary) file with 267,751 unique entries and the compresched result was 3.4MB, 28% larger than the original. The largest word in SOWPODS is "infantilisation", which if fully capitalized, would be represented as: #5QLJ|1EKF¦, only 4 letters smaller than the original word, in this case. So, my theory that it can compresch files is strained at best, since this would only happen if the file it was working with had more words greater than 6 characters in length than words smaller than that. So, it is possible, but unlikely. That doesn't make my research into compression a failure, nor does that make this project any less useful, because it still serves as an excellent custom compreschion mechanism, even if the name is more or less wishful thinking.
## How Does It Work?

Usage: compresch <filename> <alternatedictionary> -mode <decompresch|extract> -help

The default mode is to compresch a file, so no -mode is required at the command line, just the -filename and optional -alternatedictionary. Use the -mode "decompresch" or "extract" to reverse the process.

When you submit a file for compreschon, the function looks for a matching word in the dictionary. Failing that, it looks for the longest matching string within the word against a word in the dictionary. So, words I mentioned earlier like "impressed" may not be a direct match, but the first portion of that word would be a match. The function would then continue by replacing "impress" with the compresched value and leave the last two letters untouched. 

The function replaces as many words as possible with the numerical reference to that word in the dictionary, using a base36 value to represent its location and another base36 value to represent which letters are capitalized. The capitalization is actually a binary value representing each place in the word; 0 for lower-case and 1 for upper-case. The word "Frank" for example, is included in the dictionary, because it's an adjective and is found at location 1752, or "1co" via base36. The capitalization for that word would be represented in binary as "10000". While this is a very logical way to represent capitalization, it would also take up a lot of space. The base36 equivalent however would simply be "g". Put that together and the word "Frank" is replaced in the document with "frAming". While that's 2 characters longer than the original word, there are many instances where the replacement value will be shorter than the original word and when that happens, it's possible for the function to act as a form of masking, as well as a form of compreschion.

Once the compreschion of every word in the document is complete, the file will be saved with a .schvn.dat extension and it can only be decompresched by using the mode "decompresch", or "extract" if you prefer, and using the same dictionary to accomplish this that was used to create it. In the interests of simplicity, the original extension is stored in the compresched file, so when it is decompresched, the file will be restored with it's original name and extension.

One point of interest is that the following five characters should not appear in the original text, or they might break the logic: §°¬†‡

Secondly, the compreschon function will provide progress indicators as it completes its work. a middle dot "·" for a full word match, and a period "." for a partial word match. The longer the file, the more dots will appear.
## Configuration

The module includes a .PSD1 file for configuration. In it there are only 2 lines you need to adjust, if you so choose:

@{ModuleVersion = '1.1'
RootModule = 'Compresch.psm1'
PrivateData = @{minimumlength = 4
dictionaryfile = 'Common.dictionary.gz'}}

The minimumlength value tells the compreschon function the smallest words to replace with an indexed value. The default it set to 4. Smaller values will lead to compresched files that are larger than their original and setting a larger value, while it will likely compresch files faster, will lead to less compresched content, which means that the resulting file may be easier to read, even without the dictionary. So, I wouldn't reccommend using values less than 4 or greater than 6.

The dictionaryfile value is the name of your custom dictionary, which must be located in the same directory as the module in order for it to work properly.

## Dictionary Randomization/Pre-Shared Key Creation

Usage: compresch <inputfile> <outputfile> -mode "dic(schonary)"

I have also included a dictionary randomizer which allows you to take any dictionary and randomize the entries, thereby creating a unique version for your own use. If no input file is provided, the function will randomize the default dictionary and save it to the output location, instead.

If you're wondering how secure that method could possibly be, well it works out to log10(4717!) ≈ 14899 digits and since there are only about 10^80 atoms in the observable universe, which is 10 followed by 80 digits, I think we can assume that randomizing just this dictionary alone would be enough to make brute force impossible. Therefore, you can use this to create as many dictionaries as you need, but remember to share the randomized version of the dictionary with the user or system that needs to decompresch the files created using that dictionary. Otherwise, the content will be lost and very likely impossible to recover.
## License
MIT License

Copyright © 2025 Craig Plath

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
THE SOFTWARE.
##>

