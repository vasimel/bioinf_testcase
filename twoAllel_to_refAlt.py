import argparse
import pysam
import logging

VALID_ALLELES = {'A', 'T', 'G', 'C'}
CHROMOSOMES = [f"chr{str(i)}" for i in range(1, 23)] + ['chrX', 'chrY', 'chrM']

def parse_args():
    parser = argparse.ArgumentParser(description="Convert allele1 and allele2 to REF and ALT using reference genome.")
    parser.add_argument('--input', required=True, help='Input file name')
    parser.add_argument('--output', required=True, help='Output file name')
    parser.add_argument('--reference_dir', required=True, help='Directory with reference genome files')
    return parser.parse_args()

def setup_logging():
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def load_reference_files(reference_dir):
    fasta_files = {}
    for chrom in CHROMOSOMES:
        fasta_path = f"{reference_dir}/{chrom}.fa"
        try:
            fasta_files[chrom] = pysam.FastaFile(fasta_path)
        except OSError:
            logging.warning(f"Reference file not found for chromosome: {chrom}")
    return fasta_files

def determine_ref_alt(chrom, pos, allele1, allele2, fasta_files):
    fasta = fasta_files.get(chrom)
    if fasta is None:
        raise ValueError(f"No reference file loaded for chromosome: {chrom}")
    ref_base = fasta.fetch(chrom, pos-1, pos)  # pos-1 because pysam uses 0-based indexing
    if allele1 == ref_base:
        return allele1, allele2
    elif allele2 == ref_base:
        return allele2, allele1
    else:
        raise ValueError(f"None of the alleles match the reference base at {chrom}:{pos}")

def convert_file(input_file, output_file, reference_dir):
    expected_header = "#CHROM\tPOS\tID\tallele1\tallele2"
    fasta_files = load_reference_files(reference_dir)
    
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        header = infile.readline().strip()
        if header != expected_header:
            logging.error(f"Unexpected header in input file: {header}\nExpected: {expected_header}")
            raise ValueError(f"Unexpected header in input file: {header}\nExpected: {expected_header}")

        outfile.write("#CHROM\tPOS\tID\tREF\tALT\n")
        logging.info("Processing file...")
        
        for line in infile:
            if line.startswith('#'):
                continue
            fields = line.strip().split('\t')
            if len(fields) != 5:
                logging.warning(f"Skipping line due to incorrect number of fields: {line.strip()}")
                continue
            chrom, pos, id, allele1, allele2 = fields
            if chrom not in fasta_files:
                logging.warning(f"Skipping line due to missing reference file for chromosome: {chrom}. Skipping...")
                continue
            if allele1 not in VALID_ALLELES or allele2 not in VALID_ALLELES:
                logging.warning(f"Skipping line due to invalid alleles: {allele1}, {allele2}")
                continue
            try:
                pos = int(pos)
                ref, alt = determine_ref_alt(chrom, pos, allele1, allele2, fasta_files)
                outfile.write(f"{chrom}\t{pos}\t{id}\t{ref}\t{alt}\n")
            except ValueError as e:
                logging.warning(f"Skipping line due to error: {e}")

        logging.info("File processing completed.")

if __name__ == "__main__":
    setup_logging()
    args = parse_args()
    logging.info(f"Starting conversion: input={args.input}, output={args.output}, reference_dir={args.reference_dir}")
    convert_file(args.input, args.output, args.reference_dir)
    logging.info("Conversion finished.")