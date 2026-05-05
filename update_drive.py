import os
import sys
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Add scripts directory to path to import push_to_gdrive
sys.path.append(os.path.join(os.path.dirname(__file__), 'scripts'))
from push_to_gdrive import get_credentials

def update_version_on_drive():
    creds = get_credentials()
    if not creds:
        print("Failed to get credentials.")
        return
        
    service = build('drive', 'v3', credentials=creds)
    file_id = '19MoogiD9DYQ5Fnb_lHBcTAFxdy-nKQ6o'
    
    media = MediaFileUpload('version.json', resumable=True)
    
    print(f"Updating file ID {file_id} on Google Drive...")
    updated_file = service.files().update(
        fileId=file_id,
        media_body=media
    ).execute()
    
    print(f"Successfully updated! File ID: {updated_file.get('id')}")

if __name__ == '__main__':
    update_version_on_drive()
