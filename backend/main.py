from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI()

# CORS for local frontend development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class Message(BaseModel):
    content: str

@app.get("/")
def read_root():
    return {"message": "Civic Chatter API is running"}

@app.post("/api/message")
def post_message(msg: Message):
    # Later: store this in Supabase
    return {"status": "received", "content": msg.content}
