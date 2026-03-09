import json
from backend.utils import call_llm
from rag.retriever import retrieve_top_chunks

def rag_generate_itinerary(destination, days, budget, interests, travel_style="cultural", group_type="solo", starting_location="", custom_constraints=""):
    """
    RAG pipeline: retrieves context and generates a professional itinerary using the dynamic template.
    """
    interests_str = ", ".join(interests) if interests else "general"
    query = f"Plan {days} days in {destination} with focus on {interests_str} and {budget} budget"
    context_chunks = retrieve_top_chunks(query)
    
    context_text = "\n\n".join(context_chunks)
    
    if context_chunks:
        instruction = f"Using primarily the following Wikivoyage information provided below, but supplementing with your knowledge if necessary:"
        context_block = f"\n[WIKIVOYAGE CONTEXT]\n{context_text}\n"
    else:
        instruction = "Using your general travel knowledge (as no specific Wikivoyage data was found for this query):"
        context_block = ""

    prompt = f"""
SYSTEM: You are a Professional AI Travel Route Optimization Engine.
Your job is NOT just to generate an itinerary.
Your responsibility is to create a structured, route-optimized, time-efficient travel plan designed to save tourists time and reduce unnecessary movement.

- Optimize activities based on geographical proximity.
- Group nearby attractions together.
- Minimize travel time between locations.
- Suggest logical time slots based on real-world travel patterns.
- Avoid unrealistic schedules.
- Include buffer time between destinations.
- Suggest walking vs local transport logically (Walking if < 1.5km).
- Avoid backtracking across the city.
- If multiple attractions are far apart, recommend splitting across different days instead of forcing inefficient travel.
- Keep route practical and efficient.
- Return structured JSON only.
- Do NOT generate explanations outside JSON.
- Be professional and concise.

USER:
Create a professional, route-optimized {days}-day itinerary for {destination}.

User Details:
- Budget Level: {budget}
- Travel Style: {travel_style}
- Group Type: {group_type}
- Starting Location (Hotel/Area): {starting_location or 'City Center'}
- Interests: {interests_str or 'Universal sightseeing'}
- Special Constraints: {custom_constraints or 'None'}

[KNOWLEDGE BASE]
{instruction}
{context_block}

Requirements:
1. Arrange daily activities in geographical order to minimize travel time.
2. Cluster nearby attractions.
3. Suggest walking routes when distance < 1.5km.
4. Suggest local transport when necessary.
5. Include realistic travel time between stops.
6. Include buffer time for traffic and rest.
7. Avoid backtracking across the city.
8. Keep total daily travel time optimized.
9. Make the route map-ready (clear place names + city + country).
10. Provide estimated total travel time per day.

Return strictly in this JSON format:
{{
  "trip_summary": {{
    "destination": "{destination}",
    "duration_days": {days},
    "optimization_focus": "time-saving & route-efficient",
    "estimated_total_travel_time": "Total travel time across all days",
    "estimated_total_trip_cost": "Total cost with currency",
    "intensity_score": "1-10",
    "style_adherence": "How it follows {travel_style}"
  }},
  "days": [
    {{
      "day": 1,
      "route_strategy": "Explain clustering logic briefly (e.g., 'Focusing on Old City area to minimize transit')",
      "starting_point": "{starting_location or 'City Center'}",
      "activities": [
        {{
          "order": 1,
          "place_name": "Exact Landmark Name",
          "city": "{destination}",
          "country": "Country Name",
          "category": "Sightseeing/Food/Market",
          "recommended_time": "e.g. 09:00 AM",
          "estimated_duration": "e.g. 2 hours",
          "travel_time_from_previous": "e.g. 10 mins",
          "transport_mode": "walking/auto/cab/public transport",
          "estimated_cost": "Cost per person",
          "buffer_time": "e.g. 15 mins",
          "map_ready_label": "Place Name, City, Country",
          "description": "Short professional tip"
        }}
      ],
      "total_daily_travel_time": "Sum of transit times",
      "daily_cost_estimate": "Total for the day"
    }}
  ],
  "routing_notes": "Explain how the route saves time and avoids unnecessary travel.",
  "map_integration_notes": "Ensure all place names are clear for OpenStreetMap geocoding."
}}
"""

    try:
        print(f"[RAG] Generating dynamic professional itinerary for {destination}...")
        output = call_llm(prompt)
        return output
    except Exception as e:
        print(f"Error in RAG pipeline: {e}")
        return None

def rag_edit_itinerary(existing_plan: dict, modification: str, interests: list = []):
    """
    Partial Update Pipeline: Modifies an existing plan based on user feedback.
    """
    interests_str = ", ".join(interests) if interests else "Universal"
    prompt = f"""
SYSTEM: You are a Professional AI Travel Route Optimization Engine.
You are updating an existing travel plan.
MANDATORY: 
1. Maintain focus on original interests: {interests_str}.
2. Ensure the NEW activities are geographically clustered with the existing ones.
3. Maintain the route-optimized, time-efficient logic.
4. Return full updated JSON in the same structure.
5. Make all new places map-ready (Place, City, Country).

[EXISTING PLAN]
{json.dumps(existing_plan, indent=2)}

[USER MODIFICATION REQUEST]
{modification}

Return strictly valid JSON in the exact same format as the existing plan.
"""
    try:
        print(f"[RAG] Processing partial edit request: {modification[:50]}...")
        output = call_llm(prompt)
        return output
    except Exception as e:
        print(f"Error in RAG partial edit: {e}")
        return None


if __name__ == "__main__":
    itinerary = rag_generate_itinerary("Udaipur", 3, "Medium", ["history"])
    print(itinerary)
