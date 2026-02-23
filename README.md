# TravelBuddy AI

## Privacy & Open Source First
This project is designed to be **100% private and independent**. It does not require any paid subscriptions, external cloud accounts, or internet-based APIs to function. All AI generation is handled locally on your machine via open-source models.

## Prerequisites

1.  **Python 3.10+**
2.  **Ollama** (Free, Open-Source local AI engine)

## Setup Instructions

### 1. Install Python Dependencies
```bash
pip install -r requirements.txt
```

### 2. Install Ollama (Required for AI Features)
The project uses **Ollama** to generate travel itineraries.
1.  Download Ollama for Windows: [https://ollama.com/download](https://ollama.com/download)
2.  Run the installer.
3.  Open a **new** terminal window (to refresh environment variables).
4.  Run the following command to download the model:
    ```bash
    ollama pull llama3
    ```

### 3. Run the Backend
```bash
python -m uvicorn backend.main:app --reload
```
The API will be available at `http://localhost:8000`.

### 4. Frontend
Open `frontend/index.html` in your browser.
*(Note: Frontend is currently a work in progress)*
