from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr
from backend.supabase_client import supabase

router = APIRouter()

# ── Schemas ──────────────────────────────────────────────────────────────────
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    name: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

# ── Endpoints ────────────────────────────────────────────────────────────────
@router.post("/register")
def register(user: UserCreate):
    try:
        # 1. Sign up user in Supabase Auth
        auth_response = supabase.auth.sign_up({
            "email": user.email,
            "password": user.password,
            "options": {
                "data": {"full_name": user.name}
            }
        })
        
        if not auth_response.user:
            raise HTTPException(status_code=400, detail="Registration failed")

        # 2. Add to public.users table (optional, but good for profile data)
        supabase.table("users").upsert({
            "id": auth_response.user.id,
            "email": user.email,
            "name": user.name
        }).execute()

        return {
            "status": "success", 
            "user_id": auth_response.user.id, 
            "name": user.name,
            "session": auth_response.session
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/login")
def login(user: UserLogin):
    try:
        auth_response = supabase.auth.sign_in_with_password({
            "email": user.email,
            "password": user.password
        })
        
        if not auth_response.user:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        # Get user profile info
        user_data = supabase.table("users").select("name").eq("id", auth_response.user.id).single().execute()
        name = user_data.data.get("name", "User") if user_data.data else "User"

        return {
            "status": "success", 
            "user_id": auth_response.user.id, 
            "name": name,
            "session": auth_response.session
        }
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid credentials or " + str(e))
