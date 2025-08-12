#!/usr/bin/env bash
# Setup a Python virtual environment at ~/Virtual_Env/ai
# Install common ML/data-science packages with error handling and a final report.
# Target OS: Debian/Ubuntu-family (uses apt). Safe to re-run.

set -u  # no unbound vars
# NOTE: deliberately NOT using `set -e` so one failure won't stop the whole script.

# ---------------------------
# Config
# ---------------------------
# Directory of this script (save logs here)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd -P)"

VENV_DIR="${HOME}/Virtual_Env/ai"   # virtual environment path
PYTHON_BIN="python3"                # interpreter to create the venv
SUDO_CMD="sudo"                     # use sudo for apt installs if needed

LOG_DIR="${SCRIPT_DIR}"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/ml_env_setup_$(date +%Y%m%d_%H%M%S).log"

# ensure venv parent directory exists
mkdir -p "$(dirname "${VENV_DIR}")"
# Packages (edit to taste)
BASE_PKGS=(
  numpy pandas scipy scikit-learn scikit-image
  matplotlib seaborn pillow opencv-python
  statsmodels sympy cython joblib tqdm requests beautifulsoup4 lxml
  pyarrow
  jupyterlab ipykernel
)

ML_PKGS=(
  tensorflow
  torch torchvision torchaudio
  xgboost lightgbm catboost
  transformers datasets tokenizers sentencepiece accelerate diffusers einops
  pytorch-lightning
  onnx onnxruntime
)

# ---------------------------
# Helpers
# ---------------------------
log() { printf "%s %s\n" "$(date +'%F %T')" "$*" | tee -a "$LOG_FILE"; }

apt_install_if_missing() {
  local pkg="$1"
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    log "Installing system package: $pkg"
    $SUDO_CMD apt-get update -y >>"$LOG_FILE" 2>&1 || true
    $SUDO_CMD apt-get install -y "$pkg" >>"$LOG_FILE" 2>&1 || return 1
  else
    log "System package already installed (skipping): $pkg"
  fi
  return 0
}

create_or_reuse_venv() {
  if [ ! -d "$VENV_DIR" ] || [ ! -x "$VENV_DIR/bin/python" ]; then
    log "Creating virtual environment: $VENV_DIR"
    # Ensure python + venv available
    if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
      log "python3 not found; installing..."
      apt_install_if_missing python3 || log "WARNING: failed to install python3"
    fi
    if ! "$PYTHON_BIN" -m venv --help >/dev/null 2>&1; then
      log "python3-venv missing; installing..."
      apt_install_if_missing python3-venv || log "WARNING: failed to install python3-venv"
    fi
    "$PYTHON_BIN" -m venv "$VENV_DIR" >>"$LOG_FILE" 2>&1 || {
      log "Attempting to install ensurepip into venv..."
      "$PYTHON_BIN" -m ensurepip --upgrade >>"$LOG_FILE" 2>&1 || true
      "$PYTHON_BIN" -m venv "$VENV_DIR" >>"$LOG_FILE" 2>&1 || log "WARNING: venv creation had issues (continuing)"
    }
  else
    log "Virtual environment already exists: $VENV_DIR (reusing)"
  fi

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  # Ensure pip inside venv
  if ! python -m pip --version >/dev/null 2>&1; then
    log "pip missing in venv; bootstrapping with ensurepip..."
    python -m ensurepip --upgrade >>"$LOG_FILE" 2>&1 || true
  fi
  log "Upgrading pip/setuptools/wheel in venv"
  python -m pip install --upgrade pip setuptools wheel >>"$LOG_FILE" 2>&1 || log "WARNING: failed to upgrade pip/setuptools/wheel"
}

# Arrays to summarize results
INSTALLED_OK=()
SKIPPED_ALREADY=()
FAILED_PKGS=()
FAILED_REASONS=()

is_installed() {
  # Check by pip metadata in current venv
  python -m pip show "$1" >/dev/null 2>&1
}

safe_install() {
  # Install one pip package (with optional extra args)
  local pkg="$1"; shift || true
  if is_installed "$pkg"; then
    SKIPPED_ALREADY+=("$pkg")
    log "pip: $pkg already installed (skipping)"
    return 0
  fi

  log "pip install: $pkg $*"
  if python -m pip install "$pkg" "$@" >>"$LOG_FILE" 2>&1; then
    INSTALLED_OK+=("$pkg")
    return 0
  else
    FAILED_PKGS+=("$pkg")
    FAILED_REASONS+=("pip install failed (see log)")
    log "ERROR: pip install failed for $pkg"
    return 1
  fi
}

install_torch_stack() {
  # Try default PyPI first; on failure, try CPU wheels index as fallback.
  local torch_stack=(torch torchvision torchaudio)
  local need_fallback=0

  for p in "${torch_stack[@]}"; do
    if ! safe_install "$p"; then
      need_fallback=1
    fi
  done

  if (( need_fallback )); then
    log "Attempting PyTorch CPU wheel index fallback..."
    for p in "${torch_stack[@]}"; do
      # Remove from FAILED lists if fallback succeeds
      if python -m pip install --index-url https://download.pytorch.org/whl/cpu "$p" >>"$LOG_FILE" 2>&1; then
        # mark as OK if not already installed
        if ! is_installed "$p"; then
          INSTALLED_OK+=("$p")
        fi
        # Remove any previous failure record for $p
        for i in "${!FAILED_PKGS[@]}"; do
          if [[ "${FAILED_PKGS[$i]}" == "$p" ]]; then
            unset 'FAILED_PKGS[i]'; unset 'FAILED_REASONS[i]'
          fi
        done
        log "Installed via PyTorch CPU index: $p"
      else
        log "ERROR: Fallback also failed for $p"
      fi
    done
    # Compact arrays after unsets
    FAILED_PKGS=("${FAILED_PKGS[@]}")
    FAILED_REASONS=("${FAILED_REASONS[@]}")
  fi
}

register_ipykernel() {
  # Create a Jupyter kernel named "ai" pointing to this venv
  if safe_install ipykernel; then
    python -m ipykernel install --user --name ai --display-name "Python (ai)" >>"$LOG_FILE" 2>&1 || \
      log "WARNING: ipykernel registration failed (continuing)"
  fi
}

# ---------------------------
# Main
# ---------------------------
log "=== ML environment setup starting ==="
log "Log file: $LOG_FILE"

# Ensure basic system deps if pip missing system-wide (requested by user)
if ! command -v pip3 >/dev/null 2>&1; then
  log "System pip3 not found; installing python3-pip"
  apt_install_if_missing python3-pip || log "WARNING: failed to install python3-pip (venv pip should still work)"
else
  log "System pip3 detected"
fi

# Create/reuse venv and prep pip
create_or_reuse_venv

# Install base packages
for p in "${BASE_PKGS[@]}"; do
  safe_install "$p" || true
done

# Install ML packages (special handling for torch stack)
# 1) tensorflow (may fail on some Python/OS combos; that's OK)
safe_install tensorflow || true

# 2) torch stack with fallback
install_torch_stack

# 3) remaining ML packages (excluding torch/TF we already handled)
for p in xgboost lightgbm catboost transformers datasets tokenizers sentencepiece accelerate diffusers einops pytorch-lightning onnx onnxruntime; do
  safe_install "$p" || true
done

# Register Jupyter kernel
register_ipykernel

# ---------------------------
# Final report
# ---------------------------
echo
echo "==================== Summary ====================" | tee -a "$LOG_FILE"

if ((${#INSTALLED_OK[@]})); then
  echo "Installed successfully: ${#INSTALLED_OK[@]}" | tee -a "$LOG_FILE"
  printf '  - %s\n' "${INSTALLED_OK[@]}" | tee -a "$LOG_FILE"
else
  echo "Installed successfully: 0" | tee -a "$LOG_FILE"
fi

if ((${#SKIPPED_ALREADY[@]})); then
  echo "Skipped (already present in venv): ${#SKIPPED_ALREADY[@]}" | tee -a "$LOG_FILE"
  printf '  - %s\n' "${SKIPPED_ALREADY[@]}" | tee -a "$LOG_FILE"
else
  echo "Skipped (already present in venv): 0" | tee -a "$LOG_FILE"
fi

if ((${#FAILED_PKGS[@]})); then
  echo "Failed installs: ${#FAILED_PKGS[@]}" | tee -a "$LOG_FILE"
  for i in "${!FAILED_PKGS[@]}"; do
    echo "  - ${FAILED_PKGS[$i]} : ${FAILED_REASONS[$i]}" | tee -a "$LOG_FILE"
  done
  echo "See detailed logs: $LOG_FILE"
else
  echo "Failed installs: 0" | tee -a "$LOG_FILE"
fi

echo "Venv location: $VENV_DIR" | tee -a "$LOG_FILE"
echo "Activate with: source \"$VENV_DIR/bin/activate\"" | tee -a "$LOG_FILE"
echo "=================================================" | tee -a "$LOG_FILE"

