import sys
from itertools import zip_longest
import os

def normalize_line(line):
    """Normalize a line by treating blank lines and all-x lines as equivalent (uninitialized)."""
    stripped = line.strip()
    # Check if line is all x's (32 x's for 32-bit values)
    if stripped and all(c == 'x' for c in stripped):
        return ''  # Treat as empty
    return stripped

def compare_files(expected_output_path, sim_output_path):
    mismatches = []
    mismatch_file = "mismatches.txt"
    
    try:
        with open(expected_output_path, 'r', encoding='utf-8') as f1, \
             open(sim_output_path, 'r', encoding='utf-8') as f2:
            
            for line_num, (line1, line2) in enumerate(zip_longest(f1, f2, fillvalue=''), 1):
                # Normalize both lines (treat blank and all-x as equivalent)
                norm_line1 = normalize_line(line1)
                norm_line2 = normalize_line(line2)
                
                if norm_line1 != norm_line2:
                    mismatches.append(f"Mismatch at line {line_num}:\n"
                                      f"  Expected: {line1.strip()!r}\n"
                                      f"  Sim output: {line2.strip()!r}\n")
        
        if not mismatches:
            print(f"PASSED: RTL simulation output matches expected results.")
            # Remove mismatch file if it exists from previous runs
            if os.path.exists(mismatch_file):
                os.remove(mismatch_file)
        else:
            print(f"FAILED: Mismatches found in {sim_output_path}")
            print(f"Writing mismatches to {mismatch_file}")
            
            # Write mismatches to file
            with open(mismatch_file, 'w', encoding='utf-8') as f_out:
                f_out.write(f"Comparison Results\n")
                f_out.write(f"Expected file: {expected_output_path}\n")
                f_out.write(f"Simulation file: {sim_output_path}\n")
                f_out.write(f"Total mismatches: {len(mismatches)}\n")
                f_out.write("="*70 + "\n\n")
                for mismatch in mismatches:
                    f_out.write(mismatch + "\n")
            
            # Print to console
            for mismatch in mismatches:
                print(mismatch)

    except FileNotFoundError:
        print(f"Error: One or both files not found. Please check paths:")
        print(f"  File 1: {expected_output_path}")
        print(f"  File 2: {sim_output_path}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python check_onboarding.py <expected_output_path> <sim_output_path>")
        sys.exit(1) # Exit with an error code

    file1 = sys.argv[1]
    file2 = sys.argv[2]
    
    compare_files(file1, file2)
