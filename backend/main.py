from fastapi import FastAPI

app = FastAPI(title="TravelBuddy API")

@app.get("/")
def root(): 
    return {"message": "Hello from TravelBuddy"}

@app.get("/health")
def health_check(): 
    return{"status": "ok"}