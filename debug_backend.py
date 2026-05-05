import sys
import os

print("Starting debug import...")
try:
    from backend import main
    print("Import successful!")
except Exception as e:
    print(f"Import failed with error: {e}")
    import traceback
    traceback.print_exc()
