import random 
import argparse
import os

def gen():
    """Generates a random 64-bit integer using Python's built-in random."""
    # getrandbits(k) returns an integer with k random bits.
    value = random.getrandbits(64)
    return value

def main(output_directory, debug=False):
    """
    Simulates a memory pre-state generation and an addition operation,
    saving results to specified output files within the given directory.
    """
    # Ensure the output directory exists
    os.makedirs(output_directory, exist_ok=True)

    # Define file paths within the output directory
    pre_state_upper_file = os.path.join(output_directory, "memory_pre_state_upper.txt")
    pre_state_lower_file = os.path.join(output_directory, "memory_pre_state_lower.txt")
    post_state_upper_file = os.path.join(output_directory, "memory_post_state_upper.txt")
    post_state_lower_file = os.path.join(output_directory, "memory_post_state_lower.txt")
    
    # Debug file paths for combined binary+decimal output
    if debug:
        pre_state_dbg = os.path.join(output_directory, "memory_pre_state_dbg.txt")
        post_state_dbg = os.path.join(output_directory, "memory_post_state_dbg.txt")

    # read_start_addr = 0
    # read_end_addr = 255 
    # write_start_addr = 384
    # write_end_addr = 511 

    # Generate and write pre-state memory
    with open(pre_state_upper_file, "w") as u, open(pre_state_lower_file, "w") as l:
        # Open debug file if needed
        if debug:
            dbg = open(pre_state_dbg, "w")
        
        # Generate 256 random 64-bit values and split them into upper/lower 32-bit binary strings
        for i in range(256):
            value = gen()
            # Extract upper 32 bits
            upper = ((value >> 32) & 0xFFFFFFFF)
            # Extract lower 32 bits
            lower = (value & 0xFFFFFFFF)
            
            u.write(format(upper, '032b') + "\n") # Format as 32-bit binary string
            l.write(format(lower, '032b') + "\n") # Format as 32-bit binary string
            
            if debug:
                # Combine upper (MSB) and lower (LSB) into 64-bit value
                full_value = (upper << 32) | lower
                binary_64 = format(upper, '032b') + format(lower, '032b')
                dbg.write(f"{binary_64} ({full_value})\n")

        # Append another 256 lines of zeros to both files
        for i in range(256):
            u.write(format(0, '032b') + "\n")
            l.write(format(0, '032b') + "\n")
            if debug:
                dbg.write("0000000000000000000000000000000000000000000000000000000000000000 (0)\n")
        
        if debug:
            dbg.close()

    # Open output files for writing the post-state
    with open(post_state_upper_file, "w") as u_out, \
         open(post_state_lower_file, "w") as l_out:
        
        # Open pre-state files for reading
        with open(pre_state_upper_file, "r") as u_in, \
             open(pre_state_lower_file, "r") as l_in:
            
            # Read all lines from pre-state files into lists
            upper_lines = u_in.readlines()
            lower_lines = l_in.readlines()

        # Initialize write address to 384 where results are written
        write_addr = 384

        # Perform 128 addition operations: add (0+1), (2+3), (4+5), ..., (254+255)
        for i in range(128):
            read_addr = i * 2  # Read from addresses 0, 2, 4, ..., 254
            
            # Read first operand (address n)
            src1_upper = int(upper_lines[read_addr].strip(), 2)
            src1_lower = int(lower_lines[read_addr].strip(), 2)
            
            # Read second operand (address n+1)
            src2_upper = int(upper_lines[read_addr + 1].strip(), 2)
            src2_lower = int(lower_lines[read_addr + 1].strip(), 2)

            # Combine upper and lower 32-bits into full 64-bit values
            src1 = (src1_upper << 32) | src1_lower
            src2 = (src2_upper << 32) | src2_lower
            
            # Add the two 64-bit values
            result = (src1 + src2) & 0xFFFFFFFFFFFFFFFF  # Mask to ensure 64-bit wrap-around

            # Split result back into upper and lower 32-bits
            res_upper = (result >> 32) & 0xFFFFFFFF
            res_lower = result & 0xFFFFFFFF

            # Write result to addresses starting from 384
            upper_lines[write_addr] = format(res_upper, '032b') + "\n"
            lower_lines[write_addr] = format(res_lower, '032b') + "\n"
            
            write_addr += 1  # Increment write address for the next result

        # Write the modified 'upper_lines' and 'lower_lines' to the post-state files
        u_out.writelines(upper_lines)
        l_out.writelines(lower_lines)
    
    # Write debug version of post-state file with combined binary and decimal
    if debug:
        with open(post_state_dbg, "w") as dbg:
            with open(post_state_upper_file, "r") as u_in, open(post_state_lower_file, "r") as l_in:
                for upper_line, lower_line in zip(u_in, l_in):
                    upper_bin = upper_line.strip()
                    lower_bin = lower_line.strip()
                    upper_dec = int(upper_bin, 2)
                    lower_dec = int(lower_bin, 2)
                    # Combine upper (MSB) and lower (LSB) into 64-bit value
                    full_value = (upper_dec << 32) | lower_dec
                    binary_64 = upper_bin + lower_bin
                    dbg.write(f"{binary_64} ({full_value})\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate pre- and post-state memory contents.")
    parser.add_argument("output_directory", type=str,
                        help="The directory where output files will be saved.")
    parser.add_argument("--debug", action="store_true",
                        help="Generate additional debug files.")
    
    args = parser.parse_args()
    
    main(args.output_directory, debug=args.debug)