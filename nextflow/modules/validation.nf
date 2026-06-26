/*
 * Input validation module
 */

def validate_inputs(input_path, sample_sheet) {
  if (!input_path && !sample_sheet) {
    error "No input specified: provide --input or --sample_sheet"
  }
  
  if (input_path) {
    def input = file(input_path)
    if (!input.exists()) {
      error "Input path does not exist: ${input_path}"
    }
  }
  
  if (sample_sheet) {
    def ss = file(sample_sheet)
    if (!ss.exists()) {
      error "Sample sheet not found: ${sample_sheet}"
    }
  }
}
