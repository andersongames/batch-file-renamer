#!/usr/bin/env sh

# ==============================================================================

# SCRIPT NAME: file_rename.sh

# DESCRIPTION: Recursively renames and standardizes files based on config rules.

# AUTHOR: Anderson Games

# ==============================================================================

# Exit immediately if a command exits with a non-zero status - safety guard

set -eu

# ------------------------------------------------------------------------------

# CONSTANTS & CONFIGURATION DEFAULTS

# ------------------------------------------------------------------------------

CONFIG_FILE="config.cfg"
LOG_FILE="log.txt"

DEFAULT_SOURCE_DIR="."
DEFAULT_EXTENSIONS=""
DEFAULT_REMOVE_WORDS=""
DEFAULT_REMOVE_SPECIAL="true"
DEFAULT_REPLACE_SPACE="false"
DEFAULT_ADD_ZERO="true"
DEFAULT_DRY_RUN="false"

# ------------------------------------------------------------------------------

# LOGGING UTILITIES (Pure-ish side-effect boundaries)

# ------------------------------------------------------------------------------

write_log() {
  local prefix="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "[%s] [%s] %s\n" "$timestamp" "$prefix" "$message" >> "$LOG_FILE"
}

log_notice() {
  write_log "NOTICE" "$1"
  printf "[NOTICE] %s\n" "$1"
}

log_dry_run() {
  write_log "DRY-RUN" "$1"
  printf "[DRY-RUN] %s\n" "$1"
}

log_success() {
  write_log "SUCCESS" "$1"
  printf "[SUCCESS] %s\n" "$1"
}

log_skipped_unchanged() {
  write_log "SKIPPED/UNCHANGED" "$1"
  printf "[SKIPPED/UNCHANGED] %s\n" "$1"
}

log_skip_collision() {
  write_log "SKIP/COLLISION" "$1"
  printf "[SKIP/COLLISION] %s\n" "$1"
}

log_error() {
  write_log "ERROR" "$1"
  printf "[ERROR] %s\n" "$1" >&2
}

log_critical() {
  write_log "CRITICAL" "$1"
  printf "[CRITICAL] %s\n" "$1" >&2
  exit 1
}

# ------------------------------------------------------------------------------

# CONFIGURATION MANAGEMENT

# ------------------------------------------------------------------------------

generate_default_config() {
  cat << EOF > "$CONFIG_FILE"

  SOURCE_DIR=$DEFAULT_SOURCE_DIR
  EXTENSIONS=$DEFAULT_EXTENSIONS
  REMOVE_WORDS=$DEFAULT_REMOVE_WORDS
  REMOVE_SPECIAL=$DEFAULT_REMOVE_SPECIAL
  REPLACE_SPACE=$DEFAULT_REPLACE_SPACE
  ADD_ZERO=$DEFAULT_ADD_ZERO
  DRY_RUN=$DEFAULT_DRY_RUN
EOF
  log_notice "Generated default configuration file: $CONFIG_FILE"
}

init_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
  generate_default_config
  fi
}

get_config_value() {
  local key="$1"
  local val

  # Extract value, remove carriage returns, strip quotes if any
  val=$(grep "^[[:space:]]*$key=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '\r' | sed 's/^[[:space:]]//;s/[[:space:]]*$//')

  printf "%s" "$val"
}

ensure_config_key() {
  local key="$1"
  local default_val="$2"
  if ! grep -q "^[[:space:]]*$key=" "$CONFIG_FILE" 2>/dev/null; then
  printf "%s=%s\n" "$key" "$default_val" >> "$CONFIG_FILE"
  log_notice "Added missing configuration key '$key' with default value."
  fi
}

validate_and_fix_config() {
  init_config

  ensure_config_key "SOURCE_DIR" "$DEFAULT_SOURCE_DIR"
  ensure_config_key "EXTENSIONS" "$DEFAULT_EXTENSIONS"
  ensure_config_key "REMOVE_WORDS" "$DEFAULT_REMOVE_WORDS"
  ensure_config_key "REMOVE_SPECIAL" "$DEFAULT_REMOVE_SPECIAL"
  ensure_config_key "REPLACE_SPACE" "$DEFAULT_REPLACE_SPACE"
  ensure_config_key "ADD_ZERO" "$DEFAULT_ADD_ZERO"
  ensure_config_key "DRY_RUN" "$DEFAULT_DRY_RUN"
}

# ------------------------------------------------------------------------------

# STRING TRANSFORMATION FUNCTIONS (Pure Functions)

# ------------------------------------------------------------------------------

# Step C1: Case Standardization (Lowercase)

transform_lowercase() {
  printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
}

transform_remove_words() {
local text="$1"
local remove_words_str="$2"

if [ -z "$remove_words_str" ]; then
    printf "%s" "$text"
    return
fi

  # Split remove words by comma and process each
  old_ifs="$IFS"
  IFS=','

  for word in $remove_words_str; do
      # Trim leading/trailing whitespace and lowercase the filter word
      word=$(printf "%s" "$word" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
      if [ -n "$word" ]; then
          # Replace occurrences of the word globally using safe string removal via sed
          # Escaping special regex characters in the word if needed, or simple replacement
          text=$(printf "%s" "$text" | sed "s|$word||g")
      fi
  done

  IFS="$old_ifs"
  printf "%s" "$text"
}

# Step C3: Remove Special Characters

transform_remove_special() {
  local text="$1"
  local remove_special="$2"

  if [ "$remove_special" = "true" ]; then
      # Keep alphanumeric, spaces, and hyphens/underscores, remove others
      printf "%s" "$text" | tr -cd '[:alnum:] _-'
  else
      printf "%s" "$text"
  fi
}

# Step C4: Add Leading Zero to single digits 1-9

transform_add_zero() {
  local text="$1"
  local add_zero="$2"

  if [ "$add_zero" = "true" ]; then
      # Use sed to find isolated digits 1-9 (surrounded by non-digits or start/end) and pad with 0
      # E.g., match boundary or non-digit, single digit 1-9, non-digit or boundary
      printf "%s" "$text" | sed -E 's/\b([1-9])\b/0\1/g'
  else
      printf "%s" "$text"
  fi
}

# Step C5: Residual Space Cleanup

transform_cleanup_spaces() {
  local text="$1"

  # Reduce multiple consecutive spaces to a single space and trim edges
  printf "%s" "$text" | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Step C6: Replace Spaces with Underlines

transform_replace_space() {
  local text="$1"
  local replace_space="$2"

  if [ "$replace_space" = "true" ]; then
      # Replace spaces with underscores and compress multiple underscores
      printf "%s" "$text" | tr ' ' '_' | tr -s '_'
  else
      printf "%s" "$text"
  fi
}

# Composite transformation pipeline

sanitize_filename() {
  local filename="$1"
  local remove_words="$2"
  local remove_special="$3"
  local replace_space="$4"
  local add_zero="$5"
  local result

  result=$(transform_lowercase "$filename")
  result=$(transform_remove_words "$result" "$remove_words")
  result=$(transform_remove_special "$result" "$remove_special")
  result=$(transform_add_zero "$result" "$add_zero")
  result=$(transform_cleanup_spaces "$result")
  result=$(transform_replace_space "$result" "$replace_space")

  printf "%s" "$result"
}

# ------------------------------------------------------------------------------

# FILTERS AND EXTENSION CHECKERS

# ------------------------------------------------------------------------------

is_extension_allowed() {
  local ext="$1"
  local extensions_cfg="$2"

  # If extensions list is empty, all extensions are allowed
  if [ -z "$extensions_cfg" ]; then
      return 0
  fi

  local normalized_ext
  normalized_ext=$(printf "\%s" "$ext" | tr '[:upper:]' '[:lower:]')

  old_ifs="$IFS"
  IFS=','
  for allowed in $extensions_cfg; do
      allowed=$(printf "%s" "$allowed" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
      if [ "$normalized_ext" = "$allowed" ]; then
          IFS="$old_ifs"
          return 0
      fi
  done
  IFS="$old_ifs"
  return 1
}

# ------------------------------------------------------------------------------

# MAIN EXECUTION FLOW

# ------------------------------------------------------------------------------

main() {
  # Ensure log file exists or create it
  touch "$LOG_FILE"

  log_notice "Session started."

  # Phase A: Initialization and Environment Validation
  validate_and_fix_config

  SOURCE_DIR=$(get_config_value "SOURCE_DIR")
  EXTENSIONS=$(get_config_value "EXTENSIONS")
  REMOVE_WORDS=$(get_config_value "REMOVE_WORDS")
  REMOVE_SPECIAL=$(get_config_value "REMOVE_SPECIAL")
  REPLACE_SPACE=$(get_config_value "REPLACE_SPACE")
  ADD_ZERO=$(get_config_value "ADD_ZERO")
  DRY_RUN=$(get_config_value "DRY_RUN")

  if [ ! -d "$SOURCE_DIR" ]; then
      log_critical "Source directory '$SOURCE_DIR' does not exist or is not a directory."
  fi

  log_notice "Scanning directory: $SOURCE_DIR (Dry Run:$DRY_RUN)"

  # Counters for summary
  total_processed=0
  total_renamed=0
  total_skipped=0
  total_errors=0

  # Phase B & C & D & E: Scanning and Processing via find
  # Using find to recursively traverse files safely
  while IFS= read -r file_path; do
      [ -z "$file_path" ] && continue

      parent_dir=$(dirname "$file_path")
      full_filename=$(basename "$file_path")

      # Isolate name and extension
      # If filename has an extension
      if printf "%s" "$full_filename" | grep -q '\.'; then
          ext="${full_filename##*.}"
          base_name="${full_filename%.*}"
      else
          ext=""
          base_name="$full_filename"
      fi

      # Check extension filter
      if ! is_extension_allowed "$ext" "$EXTENSIONS"; then
          continue
      fi

      total_processed=$((total_processed + 1))

      # Sanitize base name
      new_base_name=$(sanitize_filename "$base_name" "$REMOVE_WORDS" "$REMOVE_SPECIAL" "$REPLACE_SPACE" "$ADD_ZERO")

      # Reattach original extension (or keep clean if none)
      if [ -n "$ext" ]; then
          new_filename="${new_base_name}.${ext}"
      else
          new_filename="$new_base_name"
      fi

      new_file_path="$parent_dir/$new_filename"

      # Check if unchanged
      if [ "$full_filename" = "$new_filename" ]; then
          log_skipped_unchanged "\"$full_filename\""
          total_skipped=$((total_skipped + 1))
          continue
      fi

      # Check for collision
      if [ -e "$new_file_path" ]; then
          log_skip_collision "Target \"$new_filename\" already exists in \"$parent_dir\"."
          total_skipped=$((total_skipped + 1))
          continue
      fi

      # Phase E: Execution or Dry-Run
      if [ "$DRY_RUN" = "true" ]; then
          log_dry_run "\"$full_filename\" -> \"$new_filename\""
          total_renamed=$((total_renamed + 1))
      else
          if mv "$file_path" "$new_file_path"; then
              log_success "\"$full_filename\" -> \"$new_filename\""
              total_renamed=$((total_renamed + 1))
          else
              log_error "Failed to rename \"$full_filename\""
              total_errors=$((total_errors + 1))
          fi
      fi

  done <<EOF

$(find "$SOURCE_DIR" -type f ! -name "$CONFIG_FILE" ! -name "$LOG_FILE")
EOF

  # Phase F: Finalization and Summary
  log_notice "Session finished."
  log_notice "Summary -> Total Processed: $total_processed | Renamed/Simulated:$total_renamed | Skipped: $total_skipped | Errors:$total_errors"
  printf "Execution complete. Check %s for details.\n" "$LOG_FILE"
}

main "$@"