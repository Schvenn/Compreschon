@{RootModule = 'Compreschon.psm1'
ModuleVersion = '1.3'
GUID = 'eb90c3ff-883f-407b-b72c-fce9a4069077'
Author = 'Craig Plath'
CompanyName = 'Plath Consulting Incorporated'
Copyright = '© Craig Plath. All rights reserved.'
Description = 'PowerShell module to encrypt and decrypt plaintext files using a personalized, custom, pre-shared key.'
PowerShellVersion = '5.1'
FunctionsToExport = @('Compreschon')
CmdletsToExport = @()
VariablesToExport = @()
AliasesToExport = @()
FileList = @('Compreschon.psm1', 'Common.dictionary.gz')

PrivateData = @{PSData = @{Tags = @('encode', 'decode', 'pre-shared key', 'powershell', 'secret', 'security')
LicenseUri = 'https://github.com/Schvenn/Compreschon/blob/main/LICENSE'
ProjectUri = 'https://github.com/Schvenn/Compreschon'
ReleaseNotes = 'Initial release.'}

minimumlength = '4'
dictionaryfile = 'Common.dictionary.gz'}}
