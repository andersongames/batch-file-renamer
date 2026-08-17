# 📁 Batch Conditional File Renamer

A resilient and automated Windows Batch script designed to recursively scan folders and subdirectories to standardize, clean, and format file names. It provides case-insensitive extension filtering, targeted string removal, single-digit padding, space-to-underscore conversion, and collision prevention with complete session logging.

---

## ⚠️ Important Limitation Notice

> ⚠️ **Exclamation Mark (`!`) Limitation:** Due to native Windows Command Prompt parsing limitations with `DelayedExpansion`, **files containing an exclamation mark (`!`) in their filename are skipped by default**. Please ensure your files do not contain `!` in their filenames prior to processing if you require them to be renamed.

---

## 🚀 Features

* **Recursive Scanning:** Automatically scans the target directory and all nested subfolders.
* **Selective Extension Filtering:** Filter specific file extensions (case-insensitive) or process all files when left blank.
* **Word & Phrase Removal:** Easily strip unwanted terms, tags, or web domain branding from file names.
* **Single-Digit Padding (`ADD_ZERO`):** Converts isolated single digits `1-9` into two-digit formats `01-09` (e.g., `item1` → `item01`) while preserving multi-digit numbers and isolated zeros.
* **Space Normalization:** Trims leading/trailing spaces, collapses multiple spaces into a single space, and optionally converts spaces to underscores.
* **Collision & Mutation Prevention:** Safely skips unchanged files or renaming operations if a file with the target name already exists in the folder.
* **Dry-Run Mode:** Test your configuration settings by simulating name changes in the terminal and log without modifying actual files.
* **Session Logging:** Generates a detailed `log.txt` tracking skipped files, collisions, errors, and successful renaming operations with timestamps.

---

## ⚙️ Configuration (`config.cfg`)

You **do not** need to edit the `.bat` file. Upon its first launch, the script automatically generates a dedicated user configuration file named `config.cfg` in the execution directory if it is missing.

Open `config.cfg` in any text editor to customize your settings:

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `SOURCE_DIR` | *Script execution folder* | The root directory path to scan recursively. |
| `EXTENSIONS` | *Empty (All extensions)* | Comma-separated list of file extensions to process (e.g., `mp4, mkv, avi`). |
| `REMOVE_WORDS` | *Empty* | Comma-separated list of words, tags, or phrases to remove from file names. |
| `REPLACE_SPACE` | `false` | Converts spaces to underscores (`true`/`false`) and collapses multiple underscores. |
| `ADD_ZERO` | `true` | Adds a leading zero to isolated single digits `1-9` (`true`/`false`). |
| `DRY_RUN` | `false` | Simulates the renaming process without making changes (`true`/`false`). |

---

## 📊 Processing Rules & Order

The script isolates the file extension and applies transformations exclusively to the filename in the following strict order:

1. **Lowercasing:** Converts the entire filename to lowercase.
2. **Word Removal:** Strips all occurrences specified in `REMOVE_WORDS`.
3. **Leading Zero Padding:** Pads isolated single digits `1-9` with a leading zero (`01-09`).
4. **Space Trimming & Collapsing:** Removes leading/trailing whitespace and collapses multiple consecutive spaces.
5. **Underscore Replacement:** Converts remaining spaces into underscores if `REPLACE_SPACE=true`.
6. **Collision Check:** Re-attaches the original unchanged extension and verifies destination availability before executing.

---

## 📝 How To Use

1. **Download:** Clone or download this repository to your Windows system.
2. **First Run (Initialization):** Double-click the `.bat` file. If `config.cfg` is missing, the script generates default settings pointing to its current directory and exits.
3. **Customize:** Open `config.cfg` to set your target folder (`SOURCE_DIR`), word removal list (`REMOVE_WORDS`), or enable `DRY_RUN=true` to test safely.
4. **Execution:** Run the `.bat` file again to process your files.
5. **Monitor:** Review the terminal output or consult `log.txt` for full session summaries and status details.