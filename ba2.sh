#!/bin/bash

echo "--------------------------------------------"
echo "   BMP Steganography using LSB- Hide or Recover"
echo "--------------------------------------------"

# Output folder
out_dir="$HOME/Desktop/stego_output"
mkdir -p "$out_dir"

# Convert char to 8-bit binary
char_to_bin() {
    printf "%08d" "$(echo "obase=2; $(printf "%d" "'$1")" | bc)"
}

# Convert string to binary
str_to_bin() {
    local str="$1"
    local bin=""
    for ((i=0; i<${#str}; i++)); do
        bin+=$(char_to_bin "${str:$i:1}")
    done
    echo "$bin"
}

# Hide message in BMP
hide_message() {
    read -p "Enter path to cover BMP image: " cover
    read -p "Enter path to message file (e.g., txt): " msgfile
    read -p "Enter number of LSBs to use (1-4): " lsbs

    if [[ ! -f "$cover" || ! -f "$msgfile" ]]; then
        echo " File not found."
        exit 1
    fi
    if (( lsbs < 1 || lsbs > 4 )); then
        echo " LSB count must be between 1 and 4."
        exit 1
    fi

    # Calculate available capacity
    filesize=$(stat -c%s "$cover")
    pixel_data_size=$((filesize - 54 - 5))  # subtract header (54) and metadata (5)
    total_bits_available=$((pixel_data_size * lsbs))
    max_msg_bytes=$((total_bits_available / 8))

    echo "The text to hide must not exceed $max_msg_bytes bytes."

    msg_size=$(stat -c%s "$msgfile")

    if (( msg_size > max_msg_bytes )); then
        echo "The text is too large to hide with $lsbs LSB(s) (needs $msg_size bytes)."
        for try_lsb in {4..1}; do
            bits_possible=$((pixel_data_size * try_lsb))
            bytes_possible=$((bits_possible / 8))
            if (( msg_size <= bytes_possible )); then
                echo "The text will fit if you select $try_lsb LSB(s)."
                exit 1
            fi
        done
        echo "The text is too large to fit even with 4 LSBs."
        exit 1
    fi

    msg=$(<"$msgfile")
    msg_bin=$(str_to_bin "$msg")
    msg_len=${#msg_bin}
    out="$out_dir/stego.bmp"
    cp "$cover" "$out"

    # Write metadata: 1 byte for LSBs and 4 bytes for message length
    printf "%02x" "$lsbs" | xxd -r -p | dd of="$out" bs=1 seek=54 count=1 conv=notrunc status=none
    printf "%08x" "$msg_len" | xxd -r -p | dd of="$out" bs=1 seek=55 count=4 conv=notrunc status=none

    data_start=59
    offset=$data_start
    index=0

    while (( index < msg_len )); do
        byte_hex=$(dd if="$out" bs=1 skip=$offset count=1 status=none | xxd -p)
        byte_bin=$(printf "%08d" "$(echo "obase=2; ibase=16; ${byte_hex^^}" | bc)")
        bits="${msg_bin:index:lsbs}"
        bits=$(printf "%-${lsbs}s" "$bits" | tr ' ' '0')
        new_bin="${byte_bin:0:$((8-lsbs))}$bits"
        new_byte=$(printf "%02X" "$((2#$new_bin))")
        printf "\\x$new_byte" | dd of="$out" bs=1 seek=$offset count=1 conv=notrunc status=none

        ((index+=lsbs))
        ((offset++))
    done

    echo "Message hidden in: $out"
}

# Recover message from BMP
recover_message() {
    read -p "Enter path to stego BMP image: " stego

    if [[ ! -f "$stego" ]]; then
        echo "File not found."
        exit 1
    fi

    # Read metadata
    lsbs=$(dd if="$stego" bs=1 skip=54 count=1 status=none | xxd -p | awk '{print "ibase=16;" toupper($1)}' | bc)
    msg_len=$(dd if="$stego" bs=1 skip=55 count=4 status=none | xxd -p | awk '{print "ibase=16;" toupper($1)}' | bc)

    if (( lsbs < 1 || lsbs > 4 || msg_len < 1 )); then
        echo "Invalid metadata in BMP file."
        return
    fi

    data_start=59
    offset=$data_start
    bits=""

    for ((i=0; i<msg_len; i+=lsbs)); do
        byte_hex=$(dd if="$stego" bs=1 skip=$offset count=1 status=none | xxd -p)
        byte_bin=$(printf "%08d" "$(echo "obase=2; ibase=16; ${byte_hex^^}" | bc)")
        bits+="${byte_bin: -$lsbs}"
        ((offset++))
    done

    bits=${bits:0:$msg_len}
    msg=""

    for ((i=0; i<${#bits}; i+=8)); do
        byte="${bits:i:8}"
        [[ ${#byte} -eq 8 ]] || continue
        dec=$((2#$byte))
        msg+=$(printf "\\$(printf '%03o' "$dec")")
    done

    fileout="$out_dir/recovered_message_lsb${lsbs}.txt"
    echo "$msg" > "$fileout"
    echo "Recovered Message saved to $fileout"
}

# Menu
read -p "Choose mode (hide/recover): " mode
case "$mode" in
    hide) hide_message ;;
    recover) recover_message ;;
    *) echo " Invalid mode." ;;
esac
