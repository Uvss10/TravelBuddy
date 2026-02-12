def estimate_budget(days: int, budget: str):
    # Hotel pricing per night
    hotel_prices = {
        "Low": 1200,
        "Medium": 3000,
        "High": 7000
    }

    # Daily food cost
    food_costs = {
        "Low": 500,
        "Medium": 900,
        "High": 1500
    }

    # Daily local transport cost
    transport_costs = {
        "Low": 300,
        "Medium": 600,
        "High": 1200
    }

    # Approx ticket cost for entire trip
    ticket_costs = {
        "Low": 300,
        "Medium": 600,
        "High": 1200
    }

    hotel_per_night = hotel_prices.get(budget, 3000)
    food_per_day = food_costs.get(budget, 900)
    transport_per_day = transport_costs.get(budget, 600)
    ticket_total = ticket_costs.get(budget, 600)

    hotel_total = hotel_per_night * (days - 1)
    food_total = food_per_day * days
    transport_total = transport_per_day * days

    total_cost = hotel_total + food_total + transport_total + ticket_total

    return {
        "hotel": {
            "category": f"{budget} Budget Hotel",
            "price_per_night": hotel_per_night,
            "total_nights": days - 1,
            "total_cost": hotel_total
        },
        "food": {
            "daily_cost": food_per_day,
            "total_cost": food_total
        },
        "transport": {
            "daily_cost": transport_per_day,
            "total_cost": transport_total
        },
        "tickets": {
            "estimated_total": ticket_total
        },
        "grand_total_estimated_cost": total_cost
    }
