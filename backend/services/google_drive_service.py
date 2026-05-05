import os
import json
import logging
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# If modifying these scopes, delete the file token.json.
SCOPES = ['https://www.googleapis.com/auth/drive.file']

logger = logging.getLogger(__name__)

class GoogleDriveService:
    def __init__(self, credentials_path='client_secret.json', token_path='token.json'):
        self.credentials_path = credentials_path
        self.token_path = token_path
        self.service = self._get_service()

    def _get_service(self):
        creds = None
        # The file token.json stores the user's access and refresh tokens, and is
        # created automatically when the authorization flow completes for the first
        # time.
        if os.path.exists(self.token_path):
            creds = Credentials.from_authorized_user_file(self.token_path, SCOPES)
        
        # If there are no (valid) credentials available, let the user log in.
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                if not os.path.exists(self.credentials_path):
                    logger.error(f"Credentials file not found at {self.credentials_path}")
                    return None
                
                flow = InstalledAppFlow.from_client_secrets_file(self.credentials_path, SCOPES)
                # This will require interactive user input if run for the first time
                creds = flow.run_local_server(port=0)
            
            # Save the credentials for the next run
            with open(self.token_path, 'w') as token:
                token.write(creds.to_json())

        return build('drive', 'v3', credentials=creds)

    def upload_version_info(self, file_path, folder_id=None):
        """Uploads or updates the version.json file on Google Drive."""
        if not self.service:
            return None

        file_metadata = {
            'name': 'version.json',
            'mimeType': 'application/json'
        }
        if folder_id:
            file_metadata['parents'] = [folder_id]

        media = MediaFileUpload(file_path, mimetype='application/json', resumable=True)

        # Check if file already exists
        results = self.service.files().list(
            q="name='version.json' and trashed=false",
            fields="files(id, name)"
        ).execute()
        items = results.get('files', [])

        if items:
            # Update existing file
            file_id = items[0]['id']
            file = self.service.files().update(
                fileId=file_id,
                media_body=media
            ).execute()
            logger.info(f"Updated existing version.json with ID: {file_id}")
        else:
            # Create new file
            file = self.service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id'
            ).execute()
            file_id = file.get('id')
            logger.info(f"Created new version.json with ID: {file_id}")
        
        # Make the file public so the app can fetch it via direct link
        self._make_public(file_id)
        
        return file_id

    def _make_public(self, file_id):
        """Makes a file readable by anyone with the link."""
        permission = {
            'type': 'anyone',
            'role': 'reader',
        }
        self.service.permissions().create(
            fileId=file_id,
            body=permission
        ).execute()
        logger.info(f"Made file {file_id} public.")

def update_app_version(version_code: int, backend_url: str, apk_url: str, message: str):
    """Utility function to create version.json and upload to Drive."""
    version_data = {
        "latest_version": version_code,
        "backend_url": backend_url,
        "apk_url": apk_url,
        "update_message": message
    }
    
    file_path = 'version.json'
    with open(file_path, 'w') as f:
        json.dump(version_data, f, indent=4)
    
    drive_service = GoogleDriveService()
    file_id = drive_service.upload_version_info(file_path)
    
    if file_id:
        print(f"Successfully updated version.json on Google Drive!")
        print(f"Direct download URL: https://docs.google.com/uc?export=download&id={file_id}")
        return file_id
    else:
        print("Failed to upload version info.")
        return None
