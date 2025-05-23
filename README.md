# Compreschon
PowerShell Module to encrypt and decrypt plaintext passwords using a personalized, custom pre-shared key.

# Overview

The two primary functions allow you to encrypt and decrypt flat text files using a custom dictionary. In some cases, these files may even end up being smaller than their original. To be honest, this project started as a result of me investigating compression methodologies and attempting to understand how they work, thus the names compresch and decompresch.

The concept is reasonably simple. The module ships with an English dictionary consisting of nearly 5000 of the most popular English words according to Google, but with some modifications. I tried, through automated means, to reduce most words to their root, as opposed to keeping all of the extended versions of a word. So, I've included the word "encrypt", but not "encrypted", "encrypts" or "encrypting". The word "encryption" is actually included, but that's also because the automated method I used to strip words to their roots isn't perfect.

Secondly, I have only included words between 4 and 10 letters in length. This was done in the interests of performance and ensuring the highest probability of finding matching terms. I have also attempted to remove as many proper nouns as I could find. The result is a fairly streamlined dictionary which should provide a high ratio of matches. 

That being said, if you use this standard dictionary against a document that had highly specialized terms, such as medical terminology for example, it won't likely be very effective, but that's where the flexibility of this module comes into play though, because you don't have to use the included dictionary. You can use your own, custom dictionary and as soon as you do, the encryption mechanism becomes entirely unique to you. It is due to the nature of this approach that I decided to publish this module publicly, thereby giving people a very simple method of encrypting their own documents in a completely personalized way that does not require them to rely on a password to encrypt or decrypt. The dictionary you use acts as a type of pre-shared key, if you will, making it very flexible and easy to use.

Is it fast? Nope. It took 3:59:22 to compresch the 2.7MB SOWPODS (International Scrabble English dictionary) file with 267,751 unique entries and the encrypted result was 3.4MB, 28% larger than the original. So, my theory that it can compress files is strained at best, since this would only happen if the file it was working with had more words greater than 6 characters in length than words smaller than that. So, it is possible, but unlikely. That doesn't make my research into compression a failure, nor does that make this project any less useful, because it still serves as an excellent custom encryption mechanism, even if the names of the functions are more or less wishful thinking.

## How Does It Work?

	Usage: (compresch/decompresch) <filename> <alternatedictionary> -help

When you submit a file for compreschon, the function looks for a matching word in the dictionary. Failing that, it looks for the longest matching string within the word against a word in the dictionary. So, words I mentioned earlier like "encrypted" may not be a direct match, but the first portion of that word would be a match. The function would then continue by replacing "encrypt" with the encrypted value and leave the last two letters untouched. 

The function replaces as many words as possible with the numerical reference to that word in the dictionary, using a base36 value to represent its location and another base36 value to represent which letters are capitalized. The capitalization is actually a binary value representing each place in the word; 0 for lower-case and 1 for upper-case. The word "Frank" for example, is included in the dictionary, because it's an adjective and is found at location 1752, or "1co" via base 36. The capitalization for that word would be represented in binary as "10000". While this is a very logical way to represent capitalization, it would also take up a lot of space. The base 36 equivalent however would simply be "g". Put that together and the word "Frank" is replaced in the document with "#1co|g¦". While that's 2 characters longer than the original word, there are many instances where the replacement value will be shorter than the original word and when that happens, it's possible for the function to act as a form of compression, as well as a form of encryption.

Once the encryption of every word in the document is complete, the file will be saved with a .schvn extension and it can only be decrypted by the accompanying decompresch function, using the same dictionary that was used to create it. In the interests of simplicity, the original extension is stored in the encrypted file, so when it is decrypted, the file will be restored with it's original name and extension.

As a couple points of interest is that the following five characters cannot appear in the original text, or they might break the logic: §°¬†‡
Secondly, the compreschon function will provide progress indicators as it completes its work. a middle dot "·" for a full word match, and a period "." for a partial word match. The longer the file, the more dots will appear.
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
