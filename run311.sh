#!/bin/sh

export OMP_NUM_THREADS=1
export PYTORCH_MPS_DISABLE=1
export LLAMA_NO_METAL=1

if [ "$(uname)" = "Darwin" ]; then
  # macOS specific env:
  export PYTORCH_ENABLE_MPS_FALLBACK=1
  export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
elif [ "$(uname)" != "Linux" ]; then
  echo "Unsupported operating system."
  exit 1
fi

# Check if aria2 is installed
if command -v aria2c >/dev/null 2>&1; then
  echo "aria2 command found"
else
  echo "failed. please install aria2"
  if command -v brew >/dev/null 2>&1; then
    brew update && brew install aria2
  else
    echo "aria2 is not installed. Install it and try again"
    exit 1
  fi
fi

if [ -d ".venv" ]; then
  echo "Activate venv..."
  . .venv/bin/activate
else
  echo "Create venv..."
  requirements_file="requirements-py311.txt"

  # Check if Python 3.11 is installed
  if ! command -v python3.11 >/dev/null 2>&1 || pyenv versions --bare | grep -q "3.11"; then
    echo "Python 3 not found. Attempting to install 3.11..."
    if [ "$(uname)" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
      brew install python@3.11
    elif [ "$(uname)" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install python3.11
    else
      echo "Please install Python 3.11 manually."
      exit 1
    fi
  fi

  python3.11 -m venv .venv
  . .venv/bin/activate

  # Check if required packages are installed and install them if not
  if [ -f "${requirements_file}" ]; then
    installed_packages=$(python3.11 -m pip freeze)
    while IFS= read -r package; do
      expr "${package}" : "^#.*" >/dev/null && continue
      package_name=$(echo "${package}" | sed 's/[<>=!].*//')
      if ! echo "${installed_packages}" | grep -q "${package_name}"; then
        echo "${package_name} not found. Attempting to install..."
        python3.11 -m pip install --upgrade "${package}"
      fi
    done <"${requirements_file}"
  else
    echo "${requirements_file} not found. Please ensure the requirements file with required packages exists."
    exit 1
  fi
fi

# Download models
chmod +x tools/dlmodels.sh
./tools/dlmodels.sh

if [ $? -ne 0 ]; then
  exit 1
fi

# Run the main script
python3.11 infer-web.py --pycmd python3.11