# TravelBuddy AI

A comprehensive travel planning and content creation platform built with full-stack technology.

## About TravelBuddy

TravelBuddy is an innovative travel companion application that combines:
- **AI-Powered Itinerary Planning**: RAG-based intelligent trip generation
- **Cinematic Content Creation**: Automatic video generation from travel photos
- **Smart Media Processing**: Advanced image analysis and video enhancement
- **Cloud-First Architecture**: Scalable backend infrastructure

## Primary Developer

**Hem Singh** (@Hemsingh3)
- Full architecture and implementation of the entire TravelBuddy platform
- All core features, backend services, and mobile client
- See [CONTRIBUTORS.md](CONTRIBUTORS.md) for detailed contributions

## Tech Stack

### Frontend
- **Mobile**: Dart/Flutter (Cross-platform: iOS, Android, Web)
- **Web**: Responsive web interface

### Backend
- **Language**: Python 3.10+
- **Framework**: FastAPI
- **Database**: Supabase (PostgreSQL)
- **Vector DB**: ChromaDB (RAG embeddings)
- **AI/ML**: 
  - OpenAI Vision API (Image analysis)
  - Ollama (Local LLMs)
  - RAG Implementation (Retrieval Augmented Generation)
  - Cinematic Motion Engine (Video generation)

### Infrastructure
- **Deployment**: Render.com
- **Cloud Services**: Supabase, OpenAI API
- **Media Processing**: FFmpeg (Video encoding)
- **Containerization**: Docker

## Key Features

### 1. Smart Trip Planning
- RAG-based itinerary generation from travel knowledge base
- Personalized recommendations based on preferences
- Location-based insights and tips
- Multi-day trip organization

### 2. Cinematic Video Generation
- Automatic video creation from travel photos
- Music-synchronized transitions and effects
- Advanced motion effects and keyframe support
- Professional-quality reel generation

### 3. Media Intelligence
- Image quality scoring (blur detection, sharpness analysis)
- Aesthetic evaluation and filtering
- Travel-specific image analysis
- Automated media organization

### 4. User Experience
- Responsive mobile interface with smooth navigation
- Real-time preview capabilities
- Gallery integration for photo management
- Video caching and optimization for performance

## Architecture Highlights

- **Microservices Design**: Modular backend services
- **AI Integration**: Multi-model approach (Vision, LLM, Embeddings)
- **Performance Optimized**: Efficient video processing pipeline
- **Cloud-Native**: Scalable infrastructure with Render deployment
- **Full-Stack**: Complete mobile and backend implementation

## Project Structure

```
TravelBuddy/
├── mobile/              # Flutter mobile app
│   ├── lib/
│   │   ├── screens/     # UI screens
│   │   ├── providers/   # State management
│   │   ├── services/    # API client
│   │   ├── models/      # Data models
│   │   └── theme/       # Design system
│   ├── android/         # Android native code
│   ├── ios/             # iOS native code
│   └── pubspec.yaml     # Flutter dependencies
│
├── backend/             # FastAPI backend
│   ├── main.py          # FastAPI app entry point
│   ├── routes/          # API endpoints
│   ├── services/        # Business logic
│   ├── models/          # Data models
│   └── requirements.txt # Python dependencies
│
├── CONTRIBUTORS.md      # Contributor information
├── README.md            # This file
└── LICENSE              # Project license
```

## Getting Started

### Prerequisites

1. **Python 3.10+** - For backend
2. **Flutter SDK** - For mobile development
3. **Ollama** - For local AI (optional, for development)
4. **Docker** - For containerized deployment

### Backend Setup

```bash
# Navigate to backend directory
cd backend

# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the server
python -m uvicorn main:app --reload
```

The API will be available at `http://localhost:8000`

### Mobile Setup

```bash
# Navigate to mobile directory
cd mobile

# Get Flutter dependencies
flutter pub get

# Run the app
flutter run
```

## API Documentation

Once the backend is running, visit `http://localhost:8000/docs` for interactive API documentation (Swagger UI).

## Deployment

### Cloud Deployment (Render)

The project is configured for deployment on Render.com:

```bash
# Environment variables required:
# - OPENAI_API_KEY (for Vision API)
# - DATABASE_URL (Supabase PostgreSQL)
# - CHROMA_HOST (ChromaDB instance)
```

## Development & Contributing

This is a solo-developed project by Hem Singh. For project inquiries or collaboration, see CONTRIBUTORS.md.

## License

See LICENSE file for details.

---

**Created and maintained by Hem Singh (@Hemsingh3)**

For detailed contributor information, see [CONTRIBUTORS.md](CONTRIBUTORS.md)
