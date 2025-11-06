import os
import json
import time
from typing import Any, Dict

import runpod

# Optional deps; safe to import even if unused yet
import torch
from huggingface_hub import snapshot_download

# -------- Globals (persist across invocations on warm workers) --------
CACHE_DIR = "/runpod-volume/models/marigold"
HF_REPO = "prs-eth/marigold-iid-lighting-v1-1"
HF_TOKEN = os.environ.get("HUGGING_FACE_HUB_TOKEN") or os.environ.get("HF_TOKEN")

_model_ready = False
_model_path = None


def ensure_gpu() -> Dict[str, Any]:
    has_cuda = torch.cuda.is_available()
    device_count = torch.cuda.device_count() if has_cuda else 0
    name = torch.cuda.get_device_name(0) if has_cuda and device_count > 0 else None
    return {"cuda": has_cuda, "gpus": device_count, "name": name}


def warm_download_model() -> Dict[str, Any]:
    """Download (or reuse) HF model into the persistent RunPod volume."""
    global _model_ready, _model_path

    os.makedirs(CACHE_DIR, exist_ok=True)
    start = time.time()
    _model_path = snapshot_download(
        repo_id=HF_REPO,
        local_dir=CACHE_DIR,
        local_dir_use_symlinks=False,
        token=HF_TOKEN,
        revision=None  # main
    )
    _model_ready = True
    return {"model_path": _model_path, "seconds": round(time.time() - start, 2)}


def handler(event):
    """
    Inputs:
      mode: "ping" | "warm" | "infer"
      image_url: string (when mode="infer")
    """
    data = event.get("input", {}) or {}
    mode = str(data.get("mode", "ping")).lower()

    # Always report GPU status
    gpu = ensure_gpu()

    if mode == "ping":
        return {"ok": True, "gpu": gpu, "message": "pong"}

    if mode == "warm":
        if not HF_TOKEN:
            return {"ok": False, "gpu": gpu, "error": "Missing HF token (set HUGGING_FACE_HUB_TOKEN)"}        
        info = warm_download_model()
        return {"ok": True, "gpu": gpu, "warmed": info}

    if mode == "infer":
        if not _model_ready:
            if not HF_TOKEN:
                return {"ok": False, "gpu": gpu, "error": "Missing HF token (set HUGGING_FACE_HUB_TOKEN)"}
            warm_download_model()

        image_url = data.get("image_url")
        if not image_url:
            return {"ok": False, "gpu": gpu, "error": "image_url is required for mode=infer"}

        # TODO: Replace this with actual Marigold inference.
        # For now we just echo inputs to prove serverless plumbing works.
        return {
            "ok": True,
            "gpu": gpu,
            "model_path": _model_path,
            "echo": {"image_url": image_url},
            "note": "Replace TODO block in handler() with real inference."
        }

    return {"ok": False, "gpu": gpu, "error": f"Unknown mode '{mode}'"}


runpod.serverless.start({"handler": handler})
