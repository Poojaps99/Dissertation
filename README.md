This project provides a Bash‑based implementation of LSB (Least Significant Bit) steganography for BMP images, allowing users to hide and recover secret text messages inside bitmap files. The script uses standard Linux tools (dd, xxd, bc) and works on any typical Linux environment.

Features:
Hide text inside 24‑bit BMP images using 1–4 LSBs
Recover hidden messages from stego BMP files
Automatic capacity calculation based on image size
Metadata stored inside BMP header region
Output saved to:
~/Desktop/stego_output
Pure Bash — no external libraries require

Hiding:
User selects: Cover BMP image; Text file to hide; Number of LSBs (1–4)
Script checks capacity and message size
Converts message to binary
Stores metadata: Byte 54 → LSB count; Bytes 55–58 → message length (bits)
Embeds message bits starting at byte 59
Outputs stego.bmp in the output folder

Recovering:
Reads metadata from BMP
Extracts LSBs from pixel data
Reconstructs binary → ASCII text
Saves recovered message to:~/Desktop/stego_output/recovered_message_lsbX.txt


Requirements
Kali Linux; Bash shell; dd, xxd, bc installed (default on most distros)

Limitations:
Works only with BMP images
Supports 1–4 LSBs
Message capacity depends on image size
Provides hiding, not encryption



Note: LSB steganography hides data but does not secure it. For confidential communication, combine steganography with encryption
