# RunPod ComfyUI worker base (serverless-compatible)
FROM runpod/worker-comfyui:5.5.0-base

# Keep logs unbuffered; smaller pip installs
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# (Optional) Utilities & git-lfs for any nodes that need it
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      git git-lfs curl ca-certificates procps \
 && git lfs install \
 && rm -rf /var/lib/apt/lists/*
USER app

# ---- Install your custom nodes ----

# 1) Marigold custom node (as you already had)
#    This installs the node code; weights will be pulled at runtime via HF.
RUN comfy node install --exit-on-fail comfyui-marigold@1.0.1

# 2) URL loader node (lets a workflow load an image from https:// URL)
RUN git clone https://github.com/tsogzark/ComfyUI-load-image-from-url \
    /comfyui/custom_nodes/ComfyUI-load-image-from-url

# (Optional) Other commonly used packs:
# RUN git clone https://github.com/WASasquatch/was-node-suite-comfyui \
#     /comfyui/custom_nodes/was-node-suite-comfyui
# RUN pip install -r /comfyui/custom_nodes/was-node-suite-comfyui/requirements.txt

# ---- Python deps some nodes/utilities rely on ----
RUN pip install --no-cache-dir \
    huggingface_hub>=0.23.0 \
    safetensors \
    Pillow \
    numpy \
    opencv-python-headless

# ---- Model strategy ----
# Do NOT bake gated weights into the image. Provide token at runtime as a worker secret.
# The marigold node will download weights when the workflow references:
#    prs-eth/marigold-iid-lighting-v1-1
ENV HUGGING_FACE_HUB_TOKEN=""

# Persist model cache between runs (RunPod serverless volume)
VOLUME ["/runpod-volume"]

# If you ever want to ship a local sample input file, uncomment this:
# COPY input/ /comfyui/input/

# NOTE:
# - Do NOT change CMD/ENTRYPOINT; the base image already starts the serverless worker
#   that consumes the JSON "Export (API)" workflow you POST to the endpoint.
