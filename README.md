# AI Virtual Environment Bootstrapper

Sets up a Python virtual environment at `~/Virtual_Env/ai` and installs a practical, general-purpose ML/DS toolkit with error handling and a final install report.

> Target OS: Debian/Ubuntu (or derivatives). Safe to re-run; already-installed packages are skipped.

---

## What this installs (high level)

- **Core scientific stack:** `numpy`, `pandas`, `scipy`, `scikit-learn`, `scikit-image`, `statsmodels`, `sympy`, `joblib`, `tqdm`, `requests`, `beautifulsoup4`, `lxml`, `pyarrow`
- **Plotting & imaging:** `matplotlib`, `seaborn`, `pillow`, `opencv-python`
- **Deep learning:** `tensorflow`, `torch`, `torchvision`, `torchaudio` *(falls back to CPU wheels if needed)*
- **Tree/GBM & model tooling:** `xgboost`, `lightgbm`, `catboost`, `pytorch-lightning`, `onnx`, `onnxruntime`
- **NLP/LLM base:** `transformers`, `datasets`, `tokenizers`, `sentencepiece`, `accelerate`, `diffusers`, `einops`
- **Jupyter:** `jupyterlab`, `ipykernel` (registers a kernel named `ai`)

> The script auto-upgrades `pip`, `setuptools`, `wheel` in the venv and keeps going if any package fails. A timestamped log is written to `~/Virtual_Env/`.

---

## Quick start

### 1) Clone this repository
```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
```

### 2) Make the script executable and run
```bash
chmod +x setup_ai_env.sh
./setup_ai_env.sh
```

### 3) Use the environment
```bash
# activate
source ~/Virtual_Env/ai/bin/activate

# launch jupyter
jupyter lab
# choose kernel: "Python (ai)"
```

---

## Requirements

- Debian/Ubuntu with `apt` (the script will install `python3-pip` and `python3-venv` if missing)
- Internet access for PyPI wheels
- Recommended once (if you hit build errors): `sudo apt-get install -y build-essential cmake libsndfile1 ffmpeg git-lfs`

---

## Outputs & logs

- Summary at the end:
  - Installed successfully
  - Skipped (already present)
  - Failed installs (with reasons)
- Full log file path printed in the summary (e.g. `~/Virtual_Env/ml_env_setup_YYYYMMDD_HHMMSS.log`).

---

## Notes

- PyTorch automatically falls back to the official **CPU** wheel index if the default install fails.
- TensorFlow is installed from PyPI (CPU by default). If you require GPU builds, follow vendor instructions for CUDA/cuDNN and adjust the script accordingly.

---

## Uninstall / Cleanup

```bash
# remove the virtual environment
rm -rf ~/Virtual_Env/ai

# remove the Jupyter kernel
jupyter kernelspec uninstall ai

# optional: clear caches
rm -rf ~/.cache/pip ~/.cache/huggingface
```

---

## License

MIT
