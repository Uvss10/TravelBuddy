import sys
import os
sys.path.append(os.getcwd())

from backend.services.cinematic_video_service import generate_cinematic_video, get_job_status
import time

job = generate_cinematic_video(
    image_paths=[], # pass some dummy paths
    captions=[],
    destination="test",
)

job_id = job["job_id"]
while True:
    status = get_job_status(job_id)
    print(status["message"])
    if status["status"] in ("done", "error"):
        if status["status"] == "error":
            print(status.get("traceback", ""))
        break
    time.sleep(1)
