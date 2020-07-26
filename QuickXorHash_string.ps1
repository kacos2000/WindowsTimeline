# Calculates the QuickXorHash from a user entered string eg. Filepath
#
# Run C# code in Powershell
# https://blog.stefan-gossner.com/2010/05/07/using-csharp-c-code-in-powershell-scripts/
# 
# QuickXorHash by Microsoft 
# https://docs.microsoft.com/en-us/onedrive/developer/code-snippets/quickxorhash
#
# Script partially sourced from:
# https://www.powershellgallery.com/packages/AADInternals/0.3.3/Content/OneDrive_utils.ps1
# Lines 230-383


# C# code
# NOTE: Original 'WidthInBits' value is 160. 
# Changed to 128 so that the Base64 hash is same size as in Timeline

$xorhash_code = @"
using System;
 
public class QuickXorHash : System.Security.Cryptography.HashAlgorithm
{
    private const int BitsInLastCell = 32;
    private const byte Shift = 11;
    private const int Threshold = 600;
    private const byte WidthInBits = 128; 

    private UInt64[] _data;
    private Int64 _lengthSoFar;
    private int _shiftSoFar;

    public QuickXorHash()
    {
        this.Initialize();
    }

    protected override void HashCore(byte[] array, int ibStart, int cbSize)
    {
        unchecked
        {
            int currentShift = this._shiftSoFar;

            // The bitvector where we'll start xoring
            int vectorArrayIndex = currentShift / 64;

            // The position within the bit vector at which we begin xoring
            int vectorOffset = currentShift % 64;
            int iterations = Math.Min(cbSize, QuickXorHash.WidthInBits);

            for (int i = 0; i < iterations; i++)
            {
                bool isLastCell = vectorArrayIndex == this._data.Length - 1;
                int bitsInVectorCell = isLastCell ? QuickXorHash.BitsInLastCell : 64;

                // There's at least 2 bitvectors before we reach the end of the array
                if (vectorOffset <= bitsInVectorCell - 8)
                {
                    for (int j = ibStart + i; j < cbSize + ibStart; j += QuickXorHash.WidthInBits)
                    {
                        this._data[vectorArrayIndex] ^= (ulong)array[j] << vectorOffset;
                    }
                }
                else
                {
                    int index1 = vectorArrayIndex;
                    int index2 = isLastCell ? 0 : (vectorArrayIndex + 1);
                    byte low = (byte)(bitsInVectorCell - vectorOffset);

                    byte xoredByte = 0;
                    for (int j = ibStart + i; j < cbSize + ibStart; j += QuickXorHash.WidthInBits)
                    {
                        xoredByte ^= array[j];
                    }
                    this._data[index1] ^= (ulong)xoredByte << vectorOffset;
                    this._data[index2] ^= (ulong)xoredByte >> low;
                }
                vectorOffset += QuickXorHash.Shift;
                while (vectorOffset >= bitsInVectorCell)
                {
                    vectorArrayIndex = isLastCell ? 0 : vectorArrayIndex + 1;
                    vectorOffset -= bitsInVectorCell;
                }
            }

            // Update the starting position in a circular shift pattern
            this._shiftSoFar = (this._shiftSoFar + QuickXorHash.Shift * (cbSize % QuickXorHash.WidthInBits)) % QuickXorHash.WidthInBits;
        }

        this._lengthSoFar += cbSize;
    }

    protected override byte[] HashFinal()
    {
        // Create a byte array big enough to hold all our data
        byte[] rgb = new byte[(QuickXorHash.WidthInBits - 1) / 8 + 1];

        // Block copy all our bitvectors to this byte array
        for (Int32 i = 0; i < this._data.Length - 1; i++)
        {
            Buffer.BlockCopy(
                BitConverter.GetBytes(this._data[i]), 0,
                rgb, i * 8,
                8);
        }

        Buffer.BlockCopy(
            BitConverter.GetBytes(this._data[this._data.Length - 1]), 0,
            rgb, (this._data.Length - 1) * 8,
            rgb.Length - (this._data.Length - 1) * 8);

        // XOR the file length with the least significant bits
        // Note that GetBytes is architecture-dependent, so care should
        // be taken with porting. The expected value is 8-bytes in length in little-endian format
        var lengthBytes = BitConverter.GetBytes(this._lengthSoFar);
        System.Diagnostics.Debug.Assert(lengthBytes.Length == 8);
        for (int i = 0; i < lengthBytes.Length; i++)
        {
            rgb[(QuickXorHash.WidthInBits / 8) - lengthBytes.Length + i] ^= lengthBytes[i];
        }

        return rgb;
    }

    public override sealed void Initialize()
    {
        this._data = new ulong[(QuickXorHash.WidthInBits - 1) / 64 + 1];
        this._shiftSoFar = 0;
        this._lengthSoFar = 0;
    }

    public override int HashSize
    {
        get
        {
            return QuickXorHash.WidthInBits;
        }
    }
}
"@
Add-Type -TypeDefinition $xorhash_code -Language CSharp    
Remove-Variable -name xorhash_code

# Get user input
clear-host
$UserString = Read-Host "Enter string eg Path"
write-host $UserString -f White

# Read the bytes
$bytes = [System.Text.Encoding]::utf8.GetBytes($UserString)

# Create the hash 
$xorhash = [quickxorhash]::new()
$xhash = $xorhash.ComputeHash($bytes)
$Hash = [System.BitConverter]::ToString($xhash)  -replace '-',''
write-host "XorHash: $($Hash)" -f Cyan
# Encode in Base64
$b64Hash =  [System.Convert]::ToBase64String([System.Text.Encoding]::Ascii.GetBytes($Hash))  
# Show result
write-host "QuickXorHash (Base64) = " -f Magenta -nonewline;write-host "$($b64Hash)" -f Yellow

       
Clear-Variable -Name *hash,bytes -Force -ErrorAction SilentlyContinue

