# --- Base: RunPod ComfyUI serverless worker ---
FROM runpod/worker-comfyui:5.5.0-base

# Quiet/fast pip, unbuffered logs
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# We will run installs as root (the base image may not have an 'app' user)
USER root

# --- Small OS utilities (git + git-lfs for node repos) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
      git git-lfs curl ca-certificates procps \
 && git lfs install \
 && rm -rf /var/lib/apt/lists/*

# --- Custom nodes baked into the image ---

# 1) Marigold custom node (code only; weights pulled at runtime via HF)
#    If this ever fails, the --exit-on-fail ensures the build stops with a clear error.
RUN comfy node install --exit-on-fail comfyui-marigold@1.0.1

# 2) URL loader node: allows loading images from https:// (used by your workflow)
RUN git clone https://github.com/tsogzark/ComfyUI-load-image-from-url \
    /comfyui/custom_nodes/ComfyUI-load-image-from-url

# --- Extra Python deps some nodes/utilities rely on (keep minimal) ---
RUN pip install --no-cache-dir \
    "huggingface_hub>=0.23.0" \
    safetensors \
    Pillow \
    numpy \
    opencv-python-headless

# --- Model strategy ---
# Provide your HF token at *runtime* as a worker secret so the Marigold model can be pulled.
ENV HUGGING_FACE_HUB_TOKEN=""

# Persist model/cache between runs on serverless workers
VOLUME ["/runpod-volume"]

# NOTE:
# Do not override CMD/ENTRYPOINT; the base image already starts the serverless
# ComfyUI worker that executes your Export(API) workflow JSON.
