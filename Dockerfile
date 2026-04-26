# ─── TravelBuddy AI Engine Dockerfile ───
# Optimized for Render.com Free Tier (Memory & Speed)

FROM python:3.10-slim

# Install system dependencies (FFmpeg is critical for video generation)
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsm6 \
    libxext6 \
    libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the code
COPY . .

# Set PYTHONPATH to include the root directory
ENV PYTHONPATH=/app

# Expose the port FastAPI runs on
EXPOSE 8000

# Start the application
# We use uvicorn to serve the FastAPI app
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
