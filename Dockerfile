FROM zimage-base

# Set working directory
WORKDIR /app

# Keep Hugging Face download cache out of the final image layers.
ENV HF_HOME=/tmp/huggingface \
    HUGGINGFACE_HUB_CACHE=/tmp/huggingface/hub \
    TRANSFORMERS_CACHE=/tmp/huggingface/transformers

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Download model weights during build, then remove temporary caches so the
# final image does not keep both the checkpoint and the Hugging Face cache.
RUN python3 -c "from huggingface_hub import snapshot_download; import os; os.makedirs('ckpts/Z-Image-Turbo', exist_ok=True); snapshot_download(repo_id='Tongyi-MAI/Z-Image-Turbo', local_dir='ckpts/Z-Image-Turbo', local_dir_use_symlinks=False)"
RUN rm -rf /tmp/huggingface /root/.cache/huggingface

# Expose port (not used in serverless, but kept for compatibility)
EXPOSE 8000

# Health check (not used in serverless, but kept for compatibility)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run RunPod serverless handler
CMD ["python", "handler.py"]
